const { handleEndpoint, sendJSON } = require("../lib/api/response");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  sendJSON(res, 200, {
    ok: true,
    service: "notatherapist-api",
    endpoints: [
      "GET /api/health",
      "POST /api/daily-review",
      "POST /api/weekly-review",
      "POST /api/goals/from-review",
      "POST /api/conversation/start",
      "POST /api/conversation/reply"
    ]
  });
});
