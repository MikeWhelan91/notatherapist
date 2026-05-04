const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODERATIONS_URL = "https://api.openai.com/v1/moderations";
const DEFAULT_MODEL = "gpt-5-mini";
const DEFAULT_MODERATION_MODEL = "omni-moderation-latest";

const hasOpenAIConfig = () => Boolean(process.env.OPENAI_API_KEY);

const modelName = () => process.env.OPENAI_MODEL || DEFAULT_MODEL;
const moderationModelName = () => process.env.OPENAI_MODERATION_MODEL || DEFAULT_MODERATION_MODEL;

const moderateText = async (input) => {
  if (!hasOpenAIConfig()) {
    return { flagged: false, skipped: true };
  }

  const response = await fetch(OPENAI_MODERATIONS_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: moderationModelName(),
      input: String(input || "").slice(0, 20_000)
    })
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const error = new Error(payload?.error?.message || "OpenAI moderation request failed.");
    error.statusCode = response.status;
    error.code = "openai_moderation_error";
    throw error;
  }

  const result = payload?.results?.[0] || {};
  return {
    flagged: Boolean(result.flagged),
    categories: result.categories || {},
    categoryScores: result.category_scores || {}
  };
};

const generateStructured = async ({ name, schema, system, input, maxOutputTokens = 900 }) => {
  if (!hasOpenAIConfig()) {
    const error = new Error("OpenAI API key is not configured.");
    error.statusCode = 503;
    error.code = "openai_unconfigured";
    throw error;
  }

  const attempts = [
    { strict: true, model: modelName() },
    { strict: false, model: modelName() }
  ];

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
  generateStructured,
  hasOpenAIConfig,
  modelName,
  moderateText,
  moderationModelName
};
