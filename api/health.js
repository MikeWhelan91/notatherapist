const { handleEndpoint, sendJSON } = require("../lib/api/response");
const { hasOpenAIConfig, modelName } = require("../lib/api/openaiClient");
const { appAttestEnabled } = require("../lib/api/appAttest");
const { hasKV } = require("../lib/api/kvStore");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  sendJSON(res, 200, {
    ok: true,
    service: "anchor-api",
    status: "healthy",
    ai: hasOpenAIConfig() ? "configured" : "unconfigured",
    model: modelName(),
    appAttest: appAttestEnabled() ? "enforced" : "optional",
    kv: hasKV() ? "configured" : "missing",
    timestamp: new Date().toISOString()
  });
});
