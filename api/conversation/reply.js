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
    conversation: body.conversation,
    planTier: normalizePlanTier(body.planTier)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result,
    actions: result.status === "active"
      ? availableActions({
          planTier: normalizePlanTier(body.planTier),
          deepeningUsed: result.deepeningUsed
        })
      : []
  });
});

const normalizePlanTier = (value) => value === "premium" ? "premium" : "free";

const availableActions = ({ planTier, deepeningUsed }) => {
  const actions = ["Break this down", "Reframe it", "Give me one action", "End for today"];
  if (planTier === "premium" && !deepeningUsed) {
    actions.splice(3, 0, "Go deeper");
  }
  return actions;
};
