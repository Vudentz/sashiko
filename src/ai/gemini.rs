use crate::ai::{AiProvider, AiRequest, AiResponse};
use anyhow::Result;
use async_trait::async_trait;
use regex::Regex;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::time::Duration;
use tokio::time::sleep;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Content {
    pub role: String,
    pub parts: Vec<Part>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(untagged)]
pub enum Part {
    Text {
        text: String,
        #[serde(rename = "thoughtSignature", skip_serializing_if = "Option::is_none")]
        thought_signature: Option<String>,
    },
    FunctionCall {
        #[serde(rename = "functionCall")]
        function_call: FunctionCall,
        #[serde(rename = "thoughtSignature", skip_serializing_if = "Option::is_none")]
        thought_signature: Option<String>,
    },
    FunctionResponse {
        #[serde(rename = "functionResponse")]
        function_response: FunctionResponse,
    },
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct FunctionCall {
    pub name: String,
    pub args: Value,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct FunctionResponse {
    pub name: String,
    pub response: Value,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Tool {
    pub function_declarations: Vec<FunctionDeclaration>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct FunctionDeclaration {
    pub name: String,
    pub description: String,
    pub parameters: Value, // JSON Schema
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerateContentRequest {
    pub contents: Vec<Content>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tools: Option<Vec<Tool>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub system_instruction: Option<Content>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub generation_config: Option<GenerationConfig>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerationConfig {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub response_mime_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub response_schema: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub temperature: Option<f32>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GenerateContentResponse {
    pub candidates: Option<Vec<Candidate>>,
    pub usage_metadata: Option<UsageMetadata>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Candidate {
    pub content: Content,
    pub finish_reason: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageMetadata {
    pub prompt_token_count: u32,
    pub candidates_token_count: Option<u32>,
    pub total_token_count: u32,
    #[serde(flatten)]
    pub extra: Option<std::collections::HashMap<String, Value>>,
}

#[async_trait]
pub trait GenAiClient: Send + Sync {
    async fn generate_content(
        &self,
        request: GenerateContentRequest,
    ) -> Result<GenerateContentResponse>;
}

#[derive(Debug)]
pub struct QuotaError(pub Duration);
impl std::fmt::Display for QuotaError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Quota exceeded, retry in {:?}", self.0)
    }
}
impl std::error::Error for QuotaError {}

pub struct GeminiClient {
    api_key: String,
    model: String,
    client: Client,
}

impl GeminiClient {
    pub fn new(model: String) -> Self {
        let api_key = std::env::var("LLM_API_KEY").unwrap_or_default();
        Self {
            api_key,
            model,
            client: Client::new(),
        }
    }

    pub async fn generate_content_single(
        &self,
        request: &GenerateContentRequest,
    ) -> Result<GenerateContentResponse> {
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
            self.model, self.api_key
        );
        let re = Regex::new(r"Please retry in ([0-9.]+)s").unwrap();

        let res = self.client.post(&url).json(request).send().await?;

        if res.status().is_success() {
            let body_text = res.text().await?;
            match serde_json::from_str::<GenerateContentResponse>(&body_text) {
                Ok(response) => return Ok(response),
                Err(e) => {
                    anyhow::bail!("Failed to decode response: {}. Body: {}", e, body_text);
                }
            }
        }

        if res.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            let error_text = res.text().await?;
            let retry_seconds = if let Some(caps) = re.captures(&error_text) {
                caps[1].parse::<f64>().unwrap_or(30.0)
            } else {
                30.0
            };

            return Err(anyhow::Error::new(QuotaError(Duration::from_secs_f64(
                retry_seconds + 1.0,
            ))));
        }

        let status = res.status();
        let error_text = res.text().await?;
        anyhow::bail!("Gemini API error ({}): {}", status, error_text);
    }
}

#[async_trait]
impl GenAiClient for GeminiClient {
    async fn generate_content(
        &self,
        request: GenerateContentRequest,
    ) -> Result<GenerateContentResponse> {
        loop {
            match self.generate_content_single(&request).await {
                Ok(resp) => return Ok(resp),
                Err(e) => {
                    if let Some(quota_err) = e.downcast_ref::<QuotaError>() {
                        let sleep_duration = quota_err.0;
                        tracing::warn!(
                            "Gemini API quota exceeded. Retrying in {:.2}s...",
                            sleep_duration.as_secs_f64()
                        );
                        sleep(sleep_duration).await;
                        continue;
                    }
                    return Err(e);
                }
            }
        }
    }
}

pub struct StdioGeminiClient;

#[async_trait]
impl GenAiClient for StdioGeminiClient {
    async fn generate_content(
        &self,
        request: GenerateContentRequest,
    ) -> Result<GenerateContentResponse> {
        let msg = json!({
            "type": "ai_request",
            "payload": request
        });

        tokio::task::spawn_blocking(move || -> Result<GenerateContentResponse> {
            println!("{}", serde_json::to_string(&msg)?);
            // Ensure line is written
            use std::io::Write;
            std::io::stdout().flush()?;

            // Read response
            let stdin = std::io::stdin();
            let mut line = String::new();
            if stdin.read_line(&mut line)? == 0 {
                anyhow::bail!("Unexpected EOF from stdin waiting for AI response");
            }

            let resp_msg: Value = serde_json::from_str(&line)?;
            if resp_msg["type"] == "ai_response" {
                let payload = serde_json::from_value(resp_msg["payload"].clone())?;
                Ok(payload)
            } else if resp_msg["type"] == "error" {
                let err_msg = resp_msg["payload"].as_str().unwrap_or("Unknown error");
                anyhow::bail!("Remote AI Error: {}", err_msg)
            } else {
                anyhow::bail!("Unexpected response type: {:?}", resp_msg["type"])
            }
        })
        .await?
    }
}

#[async_trait]
impl AiProvider for GeminiClient {
    async fn completion(&self, request: AiRequest) -> Result<AiResponse> {
        // Implementation remains same, assuming AiRequest to GenerateContentRequest mapping
        // For brevity, I'll copy the existing logic or simpler:
        // Since Agent uses GenAiClient, AiProvider might not be used anymore by review.rs?
        // review.rs uses Agent.
        // But reviewer.rs (parent) uses AiProvider for create_review DB logging?
        // reviewer.rs: `db.create_review(..., &settings.ai.provider, ...)`
        // `reviewer.rs` does NOT call `completion`.
        // So `AiProvider` is legacy or used elsewhere?
        // It's used in `src/ai/mod.rs` trait definition.
        // `src/ai/gemini.rs` implemented it.
        // I will keep it implemented for `GeminiClient` to be safe.

        let contents = vec![Content {
            role: "user".to_string(),
            parts: vec![Part::Text {
                text: request.prompt,
                thought_signature: None,
            }],
        }];

        let system_instruction = request.system_prompt.map(|s| Content {
            role: "user".to_string(),
            parts: vec![Part::Text {
                text: s,
                thought_signature: None,
            }],
        });

        let gen_req = GenerateContentRequest {
            contents,
            tools: None,
            system_instruction,
            generation_config: None,
        };

        // Use the trait method
        let resp = GenAiClient::generate_content(self, gen_req).await?;

        let candidate = resp
            .candidates
            .as_ref()
            .and_then(|c| c.first())
            .ok_or_else(|| anyhow::anyhow!("No candidates returned from Gemini"))?;

        let mut content = String::new();
        for part in &candidate.content.parts {
            if let Part::Text { text, .. } = part {
                content.push_str(text);
            }
        }

        let usage = resp.usage_metadata.unwrap_or(UsageMetadata {
            prompt_token_count: 0,
            candidates_token_count: Some(0),
            total_token_count: 0,
            extra: None,
        });

        Ok(AiResponse {
            content,
            tokens_in: usage.prompt_token_count,
            tokens_out: usage.candidates_token_count.unwrap_or(0),
        })
    }
}
