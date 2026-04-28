const { handleEndpoint, sendJSON } = require("../lib/api/response");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  sendJSON(res, 200, {
    ok: true,
    service: "notatherapist-api",
    status: "healthy",
    timestamp: new Date().toISOString()
  });
});
