const { createChallenge } = require("../../lib/api/appAttest");
const { handleEndpoint, sendJSON } = require("../../lib/api/response");

module.exports = (req, res) => handleEndpoint(req, res, ["GET"], async () => {
  const challenge = await createChallenge();
  sendJSON(res, 200, {
    ok: true,
    challenge
  });
});
