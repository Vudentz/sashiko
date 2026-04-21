# Review Report Template

## Instructions

When regressions are found, create the review report following this template.

## Formatting Rules

1. **Plain text only** - no markdown, no backticks for code
2. **Wrap at 78 characters** - except code snippets
3. **No line numbers** - use function names and file paths
4. **No dramatic language** - factual descriptions only
5. **Suitable for linux-bluetooth mailing list** or GitHub PR comment
6. **No Signed-off-by** - BlueZ does not use them

## Template

```
commit <hash>
Author: <author>

<subject line>

<brief summary, max 3 sentences>

> diff --git a/<file> b/<file>
> --- a/<file>
> +++ b/<file>

[ ... ]

> @@ <hunk header> @@
> <quoted diff context>
>  		<relevant code>
> +		<new code with issue>

<your question/comment about the issue here, as close as possible to
the problematic code>

<any additional details, call chains, or code snippets to support>

[ ... ]

```

## Guidelines

- The report must be conversational with undramatic wording, fit for sending
  as a reply to the patch on the linux-bluetooth mailing list
  - Report must be factual, just technical observations
  - Report should be framed as questions, not accusations
  - Call issues "regressions" or "potential issues", never use the word critical
  - NEVER USE ALL CAPS

- Explain regressions as questions about the code, do not mention the author
  - don't say: Did you leak memory here?
  - instead say: Can this leak the gatt_db reference?

- Vary your question phrasing. Don't start with "Does this code ..." every time.

- Ask specifically about the resources you're referencing:
  - Don't say: 'Does this have a resource leak?' Ask specifically:
    'Does this leak the bt_att reference?'
  - Don't say: 'Is there a bounds issue?' Ask specifically:
    'Can this overflow the PDU buffer?'

- NEVER QUOTE LINE NUMBERS - use function names, file paths, and code snippets

- Use short, clear paragraphs. Break up dense text with blank lines between
  logical groups of statements.

- Aggressively snip portions of the diff unrelated to review comments
  - Replace snipped content with [ ... ]
  - Keep enough quoted material for the review to make sense
  - Keep diff headers for files with remaining hunks

- Do not add explanatory content about why something matters. State the
  issue and the suggestion, nothing more.

## Checklist Before Writing Report

- [ ] Issue verified against false-positive-guide.md
- [ ] Code path is actually reachable
- [ ] Concrete evidence provided (code snippets)
- [ ] No speculative issues included
- [ ] Formatting rules followed
- [ ] No line numbers referenced
