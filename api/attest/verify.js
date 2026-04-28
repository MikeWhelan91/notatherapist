const { verifyAttestationRequest } = require("../../lib/api/appAttest");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");
const { cleanString } = require("../../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const keyId = cleanString(body.keyId);
  const challenge = cleanString(body.challenge);
  const attestation = cleanString(body.attestation);

  if (!keyId || !challenge || !attestation) {
    sendError(res, 422, "missing_attestation", "keyId, challenge, and attestation are required.");
    return;
  }

  await verifyAttestationRequest({ keyId, challenge, attestation });

  sendJSON(res, 200, {
    ok: true,
    keyId
  });
});
