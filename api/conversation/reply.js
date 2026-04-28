const { replyToAIConversation } = require("../../lib/api/conversationEngine");
const { verifyProtectedRequest } = require("../../lib/api/appAttest");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");
const { cleanString, normalizeProfile } = require("../../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  await verifyProtectedRequest(req, req.rawBody, body);
  const text = cleanString(body.text);
  const action = cleanString(body.action);

  if (!text && !action) {
    sendError(res, 422, "missing_reply", "Send text or a structured action.");
    return;
  }

  const result = await replyToAIConversation({
    text,
    action,
    remainingTurns: body.remainingTurns,
    profile: normalizeProfile(body.profile),
    conversation: body.conversation
  });

  sendJSON(res, 200, {
    ok: true,
    ...result,
    actions: result.status === "active"
      ? ["Break this down", "Reframe it", "Give me one action", "End for today"]
      : []
  });
});
