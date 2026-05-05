const { createAIConversation } = require("../../lib/api/conversationEngine");
const { verifyProtectedRequest } = require("../../lib/api/appAttest");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");
const { normalizeProfile } = require("../../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  await verifyProtectedRequest(req, req.rawBody, body);

  const cadence = body.cadence === "monthly" ? "monthly" : "weekly";
  if (cadence === "weekly" && (!body.weeklyReview || typeof body.weeklyReview !== "object")) {
    sendError(res, 422, "missing_weekly_review", "Starting a conversation needs a weekly review.");
    return;
  }
  if (cadence === "monthly" && (!body.monthlyReview || typeof body.monthlyReview !== "object")) {
    sendError(res, 422, "missing_monthly_review", "Starting a monthly conversation needs a monthly review.");
    return;
  }

  const result = await createAIConversation({
    weeklyReview: body.weeklyReview,
    monthlyReview: body.monthlyReview,
    cadence,
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
