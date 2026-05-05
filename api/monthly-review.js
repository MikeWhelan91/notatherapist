const { createAIMonthlyReview } = require("../lib/api/reviewEngine");
const { verifyProtectedRequest } = require("../lib/api/appAttest");
const { handleEndpoint, readJSON, sendJSON } = require("../lib/api/response");
const {
  normalizeEntries,
  normalizeGoals,
  normalizeHealthSummary,
  normalizeProfile
} = require("../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  await verifyProtectedRequest(req, req.rawBody, body);
  const result = await createAIMonthlyReview({
    entries: normalizeEntries(body.entries || []),
    weeklyReviews: Array.isArray(body.weeklyReviews) ? body.weeklyReviews : [],
    profile: normalizeProfile(body.profile),
    healthSummary: normalizeHealthSummary(body.healthSummary),
    goals: normalizeGoals(body.goals),
    planTier: normalizePlanTier(body.planTier)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result
  });
});

const normalizePlanTier = (value) => value === "premium" ? "premium" : "free";
