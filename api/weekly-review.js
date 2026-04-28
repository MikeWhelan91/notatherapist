const { createWeeklyReview } = require("../lib/api/reviewEngine");
const { handleEndpoint, readJSON, sendJSON } = require("../lib/api/response");
const {
  normalizeEntries,
  normalizeHealthSummary
} = require("../lib/api/validation");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const entries = normalizeEntries(body.entries || []);
  const result = createWeeklyReview({
    entries,
    healthSummary: normalizeHealthSummary(body.healthSummary)
  });

  sendJSON(res, 200, {
    ok: true,
    ...result
  });
});
