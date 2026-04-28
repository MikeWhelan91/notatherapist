const { replyToConversation } = require("../../lib/api/conversationEngine");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");
const { cleanString, normalizeProfile } = require("../../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const text = cleanString(body.text);
  const action = cleanString(body.action);

  if (!text && !action) {
    sendError(res, 422, "missing_reply", "Send text or a structured action.");
    return;
  }

  const result = replyToConversation({
    text,
    action,
    remainingTurns: body.remainingTurns,
    profile: normalizeProfile(body.profile)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result,
    actions: result.status === "active"
      ? ["Break this down", "Reframe it", "Give me one action", "End for today"]
      : []
  });
});
