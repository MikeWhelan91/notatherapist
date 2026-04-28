const { createGoalFromReview } = require("../../lib/api/reviewEngine");
const { handleEndpoint, readJSON, sendError, sendJSON } = require("../../lib/api/response");

module.exports = (req, res) => handleEndpoint(req, res, ["POST"], async () => {
  const body = await readJSON(req);
  const goal = createGoalFromReview(body.review);

  if (!goal) {
    sendError(res, 422, "no_goal", "Review does not include a suggested goal.");
    return;
  }

  sendJSON(res, 200, {
    ok: true,
    goal
  });
});
