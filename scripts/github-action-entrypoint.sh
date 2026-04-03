#!/bin/bash
# Sashiko GitHub Action Entrypoint
# Reviews pull requests and issues using sashiko's AI review pipeline.
set -euo pipefail

###############################################################################
# Configuration from GitHub Actions inputs (passed as environment variables)
###############################################################################
AI_PROVIDER="${INPUT_AI_PROVIDER:-gemini}"
AI_MODEL="${INPUT_AI_MODEL:-gemini-3.1-pro-preview}"
AI_API_KEY="${INPUT_AI_API_KEY:-}"
MAX_INPUT_TOKENS="${INPUT_MAX_INPUT_TOKENS:-900000}"
MAX_INTERACTIONS="${INPUT_MAX_INTERACTIONS:-50}"
REVIEW_COMMENT_TAG="${INPUT_REVIEW_COMMENT_TAG:-<!-- sashiko-review -->}"
SEVERITY_THRESHOLD="${INPUT_SEVERITY_THRESHOLD:-low}"
CUSTOM_PROMPT="${INPUT_CUSTOM_PROMPT:-}"
POST_REVIEW="${INPUT_POST_REVIEW:-true}"
REVIEW_ON_ISSUES="${INPUT_REVIEW_ON_ISSUES:-false}"
PROMPTS_PATH="${INPUT_PROMPTS_PATH:-}"

# GitHub-provided environment
GITHUB_EVENT_PATH="${GITHUB_EVENT_PATH:-}"
GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-/github/workspace}"

###############################################################################
# Helpers
###############################################################################
log() { echo "[sashiko] $*" >&2; }
error() { echo "::error::$*" >&2; }
warning() { echo "::warning::$*" >&2; }
set_output() { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/null}"; }

severity_rank() {
    case "$1" in
        critical) echo 5 ;;
        high)     echo 4 ;;
        medium)   echo 3 ;;
        low)      echo 2 ;;
        info)     echo 1 ;;
        *)        echo 0 ;;
    esac
}

###############################################################################
# Validate environment
###############################################################################
if [ -z "$GITHUB_EVENT_PATH" ] || [ ! -f "$GITHUB_EVENT_PATH" ]; then
    error "GITHUB_EVENT_PATH is not set or file does not exist"
    exit 1
fi

if [ -z "$AI_API_KEY" ]; then
    error "ai_api_key input is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    error "github_token is required"
    exit 1
fi

# Configure GitHub CLI authentication
export GH_TOKEN="$GITHUB_TOKEN"

# Set AI provider API key based on provider type
case "$AI_PROVIDER" in
    gemini)
        export GEMINI_API_KEY="$AI_API_KEY"
        ;;
    claude|claude-cli)
        export ANTHROPIC_API_KEY="$AI_API_KEY"
        ;;
    openai-compat)
        export OPENAI_API_KEY="$AI_API_KEY"
        ;;
    bedrock)
        # Bedrock uses AWS credentials, not a simple API key
        export AWS_ACCESS_KEY_ID="${AI_API_KEY%%:*}"
        export AWS_SECRET_ACCESS_KEY="${AI_API_KEY#*:}"
        ;;
esac

###############################################################################
# Generate Settings.toml for the review binary
###############################################################################
generate_settings() {
    local prompts_dir="/app/third_party/prompts/kernel"
    if [ -n "$PROMPTS_PATH" ] && [ -d "${GITHUB_WORKSPACE}/${PROMPTS_PATH}" ]; then
        prompts_dir="${GITHUB_WORKSPACE}/${PROMPTS_PATH}"
        log "Using custom prompts from: $prompts_dir"
    fi

    cat > /app/Settings.toml <<EOF
log_level = "info"

[database]
url = "/data/db/sashiko.db"
token = ""

[mailing_lists]
track = []

[nntp]
server = "localhost"
port = 119

[ai]
provider = "${AI_PROVIDER}"
model = "${AI_MODEL}"
max_input_tokens = ${MAX_INPUT_TOKENS}
max_interactions = ${MAX_INTERACTIONS}
temperature = 1.0

[server]
host = "127.0.0.1"
port = 8080

[git]
repository_path = "${GITHUB_WORKSPACE}"

[review]
concurrency = 1
worktree_dir = "/tmp/sashiko_worktrees"
timeout_seconds = 3600
max_retries = 3
ignore_files = []
EOF
}

###############################################################################
# Extract PR information from the GitHub event payload
###############################################################################
get_pr_info() {
    local event_data
    event_data=$(cat "$GITHUB_EVENT_PATH")

    PR_NUMBER=$(echo "$event_data" | jq -r '.pull_request.number // .number // empty')
    PR_TITLE=$(echo "$event_data" | jq -r '.pull_request.title // .issue.title // empty')
    PR_AUTHOR=$(echo "$event_data" | jq -r '.pull_request.user.login // .issue.user.login // empty')
    PR_BASE_SHA=$(echo "$event_data" | jq -r '.pull_request.base.sha // empty')
    PR_HEAD_SHA=$(echo "$event_data" | jq -r '.pull_request.head.sha // empty')
    PR_BODY=$(echo "$event_data" | jq -r '.pull_request.body // .issue.body // ""')

    if [ -z "$PR_NUMBER" ]; then
        error "Could not determine PR/issue number from event payload"
        exit 1
    fi

    log "PR #${PR_NUMBER}: ${PR_TITLE} (by ${PR_AUTHOR})"
    log "Base: ${PR_BASE_SHA:-N/A} -> Head: ${PR_HEAD_SHA:-N/A}"
}

###############################################################################
# Fetch the PR diff
###############################################################################
fetch_pr_diff() {
    log "Fetching diff for PR #${PR_NUMBER}..."
    PR_DIFF=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" \
        -H "Accept: application/vnd.github.v3.diff" 2>/dev/null || true)

    if [ -z "$PR_DIFF" ]; then
        error "Failed to fetch PR diff"
        exit 1
    fi

    # Count changed files and lines for summary
    local files_changed
    files_changed=$(echo "$PR_DIFF" | grep -c '^diff --git' || true)
    local lines_added
    lines_added=$(echo "$PR_DIFF" | grep -c '^+[^+]' || true)
    local lines_removed
    lines_removed=$(echo "$PR_DIFF" | grep -c '^-[^-]' || true)

    log "Diff stats: ${files_changed} files, +${lines_added}/-${lines_removed} lines"
}

###############################################################################
# Fetch PR commit list for multi-commit review
###############################################################################
fetch_pr_commits() {
    log "Fetching commits for PR #${PR_NUMBER}..."
    PR_COMMITS_JSON=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/commits" \
        --paginate 2>/dev/null || echo "[]")

    PR_COMMIT_COUNT=$(echo "$PR_COMMITS_JSON" | jq 'length')
    log "PR has ${PR_COMMIT_COUNT} commits"
}

###############################################################################
# Build the review input JSON for the sashiko review binary
###############################################################################
build_review_input() {
    local patches_json="[]"

    if [ "$PR_COMMIT_COUNT" -gt 1 ]; then
        # Multi-commit PR: create one patch entry per commit
        log "Building multi-commit review input (${PR_COMMIT_COUNT} commits)..."
        patches_json=$(echo "$PR_COMMITS_JSON" | jq -c '
            [to_entries[] | {
                index: (.key + 1),
                diff: "",
                subject: .value.commit.message,
                author: (.value.commit.author.name + " <" + .value.commit.author.email + ">"),
                date: (.value.commit.author.date | if . then (. | split("T") | .[0]) else null end),
                message_id: .value.sha,
                commit_id: .value.sha
            }]
        ')

        # Fetch individual commit diffs
        local i=0
        for sha in $(echo "$PR_COMMITS_JSON" | jq -r '.[].sha'); do
            local commit_diff
            commit_diff=$(gh api "repos/${GITHUB_REPOSITORY}/commits/${sha}" \
                -H "Accept: application/vnd.github.v3.diff" 2>/dev/null || true)

            if [ -n "$commit_diff" ]; then
                # Update the diff field for this commit
                patches_json=$(echo "$patches_json" | jq \
                    --arg idx "$i" \
                    --arg diff "$commit_diff" \
                    '.[$idx | tonumber].diff = $diff')
            fi
            i=$((i + 1))
        done
    else
        # Single-commit or squash PR: one patch entry with the full diff
        log "Building single-patch review input..."
        patches_json=$(jq -n \
            --arg diff "$PR_DIFF" \
            --arg subject "$PR_TITLE" \
            --arg author "$PR_AUTHOR" \
            '[{
                index: 1,
                diff: $diff,
                subject: $subject,
                author: $author,
                date: null,
                message_id: "github-pr",
                commit_id: null
            }]')
    fi

    REVIEW_INPUT=$(jq -n \
        --arg id "1" \
        --arg subject "$PR_TITLE" \
        --argjson patches "$patches_json" \
        '{
            id: ($id | tonumber),
            subject: $subject,
            patches: $patches
        }')
}

###############################################################################
# Run the sashiko review binary
###############################################################################
run_review() {
    log "Starting sashiko review..."
    local review_args=(
        --baseline "${PR_BASE_SHA:-HEAD}"
        --worktree-dir /tmp/sashiko_worktrees
        --ai-provider "$AI_PROVIDER"
    )

    if [ -n "$CUSTOM_PROMPT" ]; then
        review_args+=(--custom-prompt "$CUSTOM_PROMPT")
    fi

    # Determine prompts path
    if [ -n "$PROMPTS_PATH" ] && [ -d "${GITHUB_WORKSPACE}/${PROMPTS_PATH}" ]; then
        review_args+=(--prompts "${GITHUB_WORKSPACE}/${PROMPTS_PATH}")
    elif [ -d "/app/third_party/prompts/kernel" ]; then
        review_args+=(--prompts "/app/third_party/prompts/kernel")
    fi

    review_args+=(--reuse-worktree "${GITHUB_WORKSPACE}")

    log "Review args: ${review_args[*]}"
    log "Review input (truncated): $(echo "$REVIEW_INPUT" | head -c 500)..."

    REVIEW_OUTPUT=$(echo "$REVIEW_INPUT" | review "${review_args[@]}" 2>/tmp/review-stderr.log || true)

    if [ -f /tmp/review-stderr.log ]; then
        log "Review stderr output:"
        cat /tmp/review-stderr.log >&2 || true
    fi

    if [ -z "$REVIEW_OUTPUT" ]; then
        warning "Review produced no output"
        REVIEW_OUTPUT='{"error": "Review produced no output"}'
    fi

    log "Review completed. Output length: ${#REVIEW_OUTPUT} bytes"
}

###############################################################################
# Parse review output and extract findings
###############################################################################
parse_review_output() {
    REVIEW_ERROR=$(echo "$REVIEW_OUTPUT" | jq -r '.error // empty')
    REVIEW_BODY=$(echo "$REVIEW_OUTPUT" | jq -r '.inline_review // .review.review_inline // empty')
    FINDINGS_JSON=$(echo "$REVIEW_OUTPUT" | jq -c '.review.findings // []')
    FINDINGS_COUNT=$(echo "$FINDINGS_JSON" | jq 'length')
    REVIEW_SUMMARY=$(echo "$REVIEW_OUTPUT" | jq -r '.review.summary // empty')
    TOKENS_IN=$(echo "$REVIEW_OUTPUT" | jq -r '.tokens_in // 0')
    TOKENS_OUT=$(echo "$REVIEW_OUTPUT" | jq -r '.tokens_out // 0')

    # Determine max severity
    MAX_SEVERITY="none"
    if [ "$FINDINGS_COUNT" -gt 0 ]; then
        MAX_SEVERITY=$(echo "$FINDINGS_JSON" | jq -r '
            [.[].severity] |
            map(ascii_downcase) |
            if any(. == "critical") then "critical"
            elif any(. == "high") then "high"
            elif any(. == "medium") then "medium"
            elif any(. == "low") then "low"
            else "info" end
        ')
    fi

    log "Findings: ${FINDINGS_COUNT}, Max severity: ${MAX_SEVERITY}"
    log "Tokens: ${TOKENS_IN} in / ${TOKENS_OUT} out"

    if [ -n "$REVIEW_ERROR" ]; then
        warning "Review error: ${REVIEW_ERROR}"
    fi
}

###############################################################################
# Filter findings based on severity threshold
###############################################################################
filter_findings() {
    local threshold_rank
    threshold_rank=$(severity_rank "$SEVERITY_THRESHOLD")

    FILTERED_FINDINGS=$(echo "$FINDINGS_JSON" | jq -c \
        --arg threshold "$threshold_rank" '
        [.[] | select(
            (if .severity == "critical" then 5
             elif .severity == "high" then 4
             elif .severity == "medium" then 3
             elif .severity == "low" then 2
             else 1 end) >= ($threshold | tonumber)
        )]
    ')

    FILTERED_COUNT=$(echo "$FILTERED_FINDINGS" | jq 'length')
    log "Findings after threshold filter: ${FILTERED_COUNT} (threshold: ${SEVERITY_THRESHOLD})"
}

###############################################################################
# Format the review body as GitHub-flavored markdown
###############################################################################
format_review_body() {
    local severity_emoji
    local findings_table=""

    if [ "$FILTERED_COUNT" -gt 0 ]; then
        findings_table="### Findings\n\n"
        findings_table+="| Severity | Problem |\n"
        findings_table+="|----------|---------|"

        # Build the table rows
        local rows
        rows=$(echo "$FILTERED_FINDINGS" | jq -r '.[] |
            "| **" + (.severity // "unknown") + "** | " +
            (.problem // "No description" | gsub("\n"; " ") | gsub("\\|"; "\\|")) + " |"
        ')
        findings_table+="\n${rows}"
    fi

    # Use the inline review if available, otherwise build from findings
    if [ -n "$REVIEW_BODY" ]; then
        FORMATTED_REVIEW="${REVIEW_COMMENT_TAG}
## Sashiko Code Review

${REVIEW_BODY}
"
    elif [ -n "$REVIEW_SUMMARY" ]; then
        FORMATTED_REVIEW="${REVIEW_COMMENT_TAG}
## Sashiko Code Review

### Summary
${REVIEW_SUMMARY}

$(echo -e "$findings_table")
"
    elif [ "$FILTERED_COUNT" -gt 0 ]; then
        FORMATTED_REVIEW="${REVIEW_COMMENT_TAG}
## Sashiko Code Review

$(echo -e "$findings_table")
"
    else
        FORMATTED_REVIEW="${REVIEW_COMMENT_TAG}
## Sashiko Code Review

No significant issues found. The code looks good.
"
    fi

    # Add metadata footer
    FORMATTED_REVIEW+="
---
<sub>Reviewed by [Sashiko](https://github.com/sashiko-dev/sashiko) | Model: ${AI_MODEL} | Tokens: ${TOKENS_IN} in / ${TOKENS_OUT} out</sub>
"
}

###############################################################################
# Post the review to the GitHub PR
###############################################################################
post_pr_review() {
    if [ "$POST_REVIEW" != "true" ]; then
        log "Skipping PR review post (post_review=false)"
        return
    fi

    log "Posting review to PR #${PR_NUMBER}..."

    # First, check for and delete any existing sashiko review comment
    local existing_comment_id
    existing_comment_id=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --paginate --jq ".[] | select(.body | contains(\"${REVIEW_COMMENT_TAG}\")) | .id" \
        2>/dev/null | head -1 || true)

    if [ -n "$existing_comment_id" ]; then
        log "Updating existing review comment (ID: ${existing_comment_id})..."
        gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${existing_comment_id}" \
            --method PATCH \
            -f body="$FORMATTED_REVIEW" \
            > /dev/null 2>&1 || warning "Failed to update existing comment"
    else
        log "Creating new review comment..."
        gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
            --method POST \
            -f body="$FORMATTED_REVIEW" \
            > /dev/null 2>&1 || warning "Failed to create review comment"
    fi

    # If there are findings, also submit a PR review with the appropriate verdict
    if [ "$FILTERED_COUNT" -gt 0 ]; then
        local review_event="COMMENT"
        local max_rank
        max_rank=$(severity_rank "$MAX_SEVERITY")

        # Request changes for high/critical findings
        if [ "$max_rank" -ge 4 ]; then
            review_event="REQUEST_CHANGES"
        fi

        log "Submitting PR review with event: ${review_event}"

        # Build the review body (shorter version for the review itself)
        local review_body="Sashiko found ${FILTERED_COUNT} issue(s) (max severity: ${MAX_SEVERITY}). See the detailed comment above."

        gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/reviews" \
            --method POST \
            -f body="$review_body" \
            -f event="$review_event" \
            -f commit_id="$PR_HEAD_SHA" \
            > /dev/null 2>&1 || warning "Failed to submit PR review"
    fi

    log "Review posted successfully"
}

###############################################################################
# Handle issue events (analyze code references in issues)
###############################################################################
handle_issue() {
    if [ "$REVIEW_ON_ISSUES" != "true" ]; then
        log "Issue review disabled. Skipping."
        set_output "status" "skipped"
        exit 0
    fi

    local event_data
    event_data=$(cat "$GITHUB_EVENT_PATH")

    local issue_number
    issue_number=$(echo "$event_data" | jq -r '.issue.number')
    local issue_title
    issue_title=$(echo "$event_data" | jq -r '.issue.title')
    local issue_body
    issue_body=$(echo "$event_data" | jq -r '.issue.body // ""')

    log "Analyzing issue #${issue_number}: ${issue_title}"

    # Extract file references from the issue body (e.g., src/main.rs:42)
    local file_refs
    file_refs=$(echo "$issue_body" | grep -oE '[a-zA-Z0-9_/.-]+\.[a-zA-Z]+:[0-9]+' || true)

    if [ -z "$file_refs" ]; then
        log "No code references found in issue body. Skipping."
        set_output "status" "no_findings"
        exit 0
    fi

    # Build a pseudo-diff from referenced files
    local pseudo_diff=""
    while IFS= read -r ref; do
        local file="${ref%%:*}"
        local line="${ref#*:}"
        if [ -f "${GITHUB_WORKSPACE}/${file}" ]; then
            local start=$((line > 10 ? line - 10 : 1))
            local context
            context=$(sed -n "${start},$((line + 10))p" "${GITHUB_WORKSPACE}/${file}" 2>/dev/null || true)
            if [ -n "$context" ]; then
                pseudo_diff+="
--- a/${file}
+++ b/${file}
@@ -${start},21 +${start},21 @@
$(echo "$context" | sed 's/^/ /')
"
            fi
        fi
    done <<< "$file_refs"

    if [ -z "$pseudo_diff" ]; then
        log "Could not read referenced files. Skipping."
        set_output "status" "no_findings"
        exit 0
    fi

    # Set PR variables for the review flow
    PR_NUMBER="$issue_number"
    PR_TITLE="$issue_title"
    PR_AUTHOR=$(echo "$event_data" | jq -r '.issue.user.login // "unknown"')
    PR_BASE_SHA="HEAD"
    PR_HEAD_SHA="HEAD"
    PR_DIFF="$pseudo_diff"
    PR_COMMIT_COUNT=1

    CUSTOM_PROMPT="${CUSTOM_PROMPT}

Context: This review is for a GitHub issue, not a pull request. The code snippets are
referenced in issue #${issue_number}: ${issue_title}. Focus on the specific concerns
mentioned in the issue description:

${issue_body}"

    build_review_input
    run_review
    parse_review_output
    filter_findings
    format_review_body

    # Post as issue comment (not PR review)
    if [ "$POST_REVIEW" = "true" ]; then
        local existing_comment_id
        existing_comment_id=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${issue_number}/comments" \
            --paginate --jq ".[] | select(.body | contains(\"${REVIEW_COMMENT_TAG}\")) | .id" \
            2>/dev/null | head -1 || true)

        if [ -n "$existing_comment_id" ]; then
            gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${existing_comment_id}" \
                --method PATCH \
                -f body="$FORMATTED_REVIEW" \
                > /dev/null 2>&1 || warning "Failed to update issue comment"
        else
            gh api "repos/${GITHUB_REPOSITORY}/issues/${issue_number}/comments" \
                --method POST \
                -f body="$FORMATTED_REVIEW" \
                > /dev/null 2>&1 || warning "Failed to create issue comment"
        fi
    fi

    set_output "review_body" "$FORMATTED_REVIEW"
    set_output "findings_count" "$FILTERED_COUNT"
    set_output "max_severity" "$MAX_SEVERITY"
    set_output "status" "success"
}

###############################################################################
# Main flow
###############################################################################
main() {
    log "Sashiko GitHub Action starting..."
    log "Event: ${GITHUB_EVENT_NAME}, Repository: ${GITHUB_REPOSITORY}"
    log "AI Provider: ${AI_PROVIDER}, Model: ${AI_MODEL}"

    # Generate settings file
    generate_settings

    case "$GITHUB_EVENT_NAME" in
        pull_request|pull_request_target)
            get_pr_info
            fetch_pr_diff
            fetch_pr_commits
            build_review_input
            run_review
            parse_review_output
            filter_findings
            format_review_body
            post_pr_review

            set_output "review_body" "$FORMATTED_REVIEW"
            set_output "findings_count" "$FILTERED_COUNT"
            set_output "max_severity" "$MAX_SEVERITY"

            if [ -n "$REVIEW_ERROR" ]; then
                set_output "status" "error"
            elif [ "$FILTERED_COUNT" -gt 0 ]; then
                set_output "status" "success"
            else
                set_output "status" "no_findings"
            fi
            ;;
        issues)
            handle_issue
            ;;
        *)
            error "Unsupported event type: ${GITHUB_EVENT_NAME}"
            error "Supported events: pull_request, pull_request_target, issues"
            exit 1
            ;;
    esac

    log "Sashiko GitHub Action completed."
}

main "$@"
