const { createAIWeeklyReview } = require("../lib/api/reviewEngine");
const { verifyProtectedRequest } = require("../lib/api/appAttest");
const { handleEndpoint, readJSON, sendJSON } = require("../lib/api/response");
const {
  normalizeEntries,
  normalizeCalmSessions,
  normalizeGoals,
  normalizeHealthSummary,
  normalizeProfile
} = require("../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  await verifyProtectedRequest(req, req.rawBody, body);
  const entries = normalizeEntries(body.entries || []);
  const result = await createAIWeeklyReview({
    entries,
    profile: normalizeProfile(body.profile),
    healthSummary: normalizeHealthSummary(body.healthSummary),
    goals: normalizeGoals(body.goals),
    calmSessions: normalizeCalmSessions(body.calmSessions),
    planTier: normalizePlanTier(body.planTier)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result
  });
});

const normalizePlanTier = (value) => value === "premium" ? "premium" : "free";
