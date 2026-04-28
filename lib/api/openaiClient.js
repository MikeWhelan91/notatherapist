const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5-mini";

const hasOpenAIConfig = () => Boolean(process.env.OPENAI_API_KEY);

const modelName = () => process.env.OPENAI_MODEL || DEFAULT_MODEL;

const generateStructured = async ({ name, schema, system, input, maxOutputTokens = 900 }) => {
  if (!hasOpenAIConfig()) {
    return null;
  }

  const response = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: modelName(),
      input: [
        {
          role: "system",
          content: system
        },
        {
          role: "user",
          content: JSON.stringify(input)
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name,
          strict: true,
          schema
        }
      },
      max_output_tokens: maxOutputTokens
    })
  });

  const payload = await response.json().catch(() => null);

  if (!response.ok) {
    const message = payload?.error?.message || "OpenAI request failed.";
    const error = new Error(message);
    error.statusCode = response.status;
    error.code = "openai_error";
    throw error;
  }

  return parseStructuredOutput(payload);
};

const parseStructuredOutput = (payload) => {
  const outputText = payload?.output_text || findOutputText(payload?.output);
  if (!outputText) {
    const error = new Error("OpenAI response did not include output text.");
    error.statusCode = 502;
    error.code = "openai_empty_output";
    throw error;
  }

  try {
    return JSON.parse(outputText);
  } catch {
    const error = new Error("OpenAI response was not valid JSON.");
    error.statusCode = 502;
    error.code = "openai_invalid_json";
    throw error;
  }
};

const findOutputText = (output = []) => {
  for (const item of output) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }
  return "";
};

module.exports = {
  DEFAULT_MODEL,
  generateStructured,
  hasOpenAIConfig,
  modelName
};
