const { handleEndpoint, sendJSON } = require("../lib/api/response");
const { hasOpenAIConfig, modelName } = require("../lib/api/openaiClient");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  sendJSON(res, 200, {
    ok: true,
    service: "notatherapist-api",
    status: "healthy",
    ai: hasOpenAIConfig() ? "configured" : "fallback",
    model: modelName(),
    timestamp: new Date().toISOString()
  });
});
