const { createAIConversation } = require("../../lib/api/conversationEngine");
const { verifyProtectedRequest } = require("../../lib/api/appAttest");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");
const { normalizeProfile } = require("../../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  await verifyProtectedRequest(req, req.rawBody, body);

  if (!body.weeklyReview || typeof body.weeklyReview !== "object") {
    sendError(res, 422, "missing_weekly_review", "Starting a conversation needs a weekly review.");
    return;
  }

  const result = await createAIConversation({
    weeklyReview: body.weeklyReview,
    profile: normalizeProfile(body.profile)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result,
    actions: [
      "Break this down",
      "Reframe it",
      "Give me one action",
      "End for today"
    ]
  });
});
