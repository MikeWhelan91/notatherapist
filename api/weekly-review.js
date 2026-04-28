const { createAIWeeklyReview } = require("../lib/api/reviewEngine");
const { handleEndpoint, readJSON, sendJSON } = require("../lib/api/response");
const {
  normalizeEntries,
  normalizeGoals,
  normalizeHealthSummary,
  normalizeProfile
} = require("../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const entries = normalizeEntries(body.entries || []);
  const result = await createAIWeeklyReview({
    entries,
    profile: normalizeProfile(body.profile),
    healthSummary: normalizeHealthSummary(body.healthSummary),
    goals: normalizeGoals(body.goals)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result
  });
});
