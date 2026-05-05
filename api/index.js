const { handleEndpoint, sendJSON } = require("../lib/api/response");
const { hasOpenAIConfig, modelName } = require("../lib/api/openaiClient");
const { appAttestEnabled } = require("../lib/api/appAttest");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  sendJSON(res, 200, {
    ok: true,
    service: "anchor-api",
    ai: hasOpenAIConfig() ? "configured" : "unconfigured",
    model: modelName(),
    appAttest: appAttestEnabled() ? "enforced" : "optional",
    endpoints: [
      "GET /api/health",
      "GET /api/attest/challenge",
      "POST /api/attest/verify",
      "POST /api/daily-review",
      "POST /api/weekly-review",
      "POST /api/monthly-review",
      "POST /api/goals/from-review",
      "POST /api/conversation/start",
      "POST /api/conversation/reply"
    ]
  });
});
