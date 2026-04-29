const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5-mini";
const DEFAULT_FALLBACK_MODELS = ["gpt-4.1-mini", "gpt-4o-mini"];

const hasOpenAIConfig = () => Boolean(process.env.OPENAI_API_KEY);

const modelName = () => process.env.OPENAI_MODEL || DEFAULT_MODEL;

const fallbackModelNames = () => {
  const raw = process.env.OPENAI_MODEL_FALLBACKS || "";
  const parsed = raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  return parsed.length ? parsed : DEFAULT_FALLBACK_MODELS;
};

const generateStructured = async ({ name, schema, system, input, maxOutputTokens = 900 }) => {
  if (!hasOpenAIConfig()) {
    return null;
  }

  const models = [modelName(), ...fallbackModelNames()].filter((value, index, arr) => arr.indexOf(value) === index);
  const attempts = models.flatMap((model) => ([
    { strict: true, model },
    { strict: false, model }
  ]));

  let lastError;
  for (const attempt of attempts) {
    try {
      return await requestStructured({
        name,
        schema,
        system,
        input,
        maxOutputTokens,
        strict: attempt.strict,
        model: attempt.model
      });
    } catch (error) {
      if (shouldSkipModel(error)) {
        continue;
      }
      lastError = error;
    }
  }

  throw lastError || new Error("OpenAI structured generation failed.");
};

const requestStructured = async ({ name, schema, system, input, maxOutputTokens, strict, model }) => {
  const response = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
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
          strict,
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
    error.model = model;
    throw error;
  }

  return parseStructuredOutput(payload);
};

const shouldSkipModel = (error) => {
  const status = Number(error?.statusCode || 0);
  const message = String(error?.message || "").toLowerCase();
  if (status !== 404) {
    return false;
  }
  return (
    message.includes("must be verified") ||
    message.includes("does not exist") ||
    message.includes("not found") ||
    message.includes("not available")
  );
};

const parseStructuredOutput = (payload) => {
  const directObject = findOutputJSONObject(payload?.output);
  if (directObject && typeof directObject === "object") {
    return directObject;
  }

  const outputText = payload?.output_text || findOutputText(payload?.output);
  if (!outputText) {
    const error = new Error("OpenAI response did not include parsable structured content.");
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
      if (content.type === "text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }
  return "";
};

const findOutputJSONObject = (output = []) => {
  for (const item of output) {
    for (const content of item.content || []) {
      if (content.type === "output_json" && content.json && typeof content.json === "object") {
        return content.json;
      }
      if (content.type === "json" && content.json && typeof content.json === "object") {
        return content.json;
      }
    }
  }
  return null;
};

module.exports = {
  DEFAULT_MODEL,
  DEFAULT_FALLBACK_MODELS,
  generateStructured,
  hasOpenAIConfig,
  fallbackModelNames,
  modelName
};
