const { createDailyReview } = require("../lib/api/reviewEngine");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../lib/api/response");
const {
  normalizeDate,
  normalizeEntries,
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

  const review = createDailyReview({
    date: normalizeDate(body.date, new Date(entries[0].date)),
    entries,
    profile: normalizeProfile(body.profile),
    healthSummary: normalizeHealthSummary(body.healthSummary)
  });

  sendJSON(res, 200, {
    ok: true,
    review
  });
});
