const { createAIDailyReview } = require("../lib/api/reviewEngine");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../lib/api/response");
const {
  normalizeDate,
  normalizeEntries,
  normalizeGoals,
  normalizeHealthSummary,
  normalizeProfile
} = require("../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const entries = normalizeEntries(body.entries || []);

  if (!entries.length) {
    sendError(res, 422, "no_entries", "Daily review needs at least one entry.");
    return;
  }

  const result = await createAIDailyReview({
    date: normalizeDate(body.date, new Date(entries[0].date)),
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
