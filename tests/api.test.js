const assert = require("node:assert/strict");
const { createConversation, replyToConversation } = require("../lib/api/conversationEngine");
const { createDailyReview, createGoalFromReview, createWeeklyReview } = require("../lib/api/reviewEngine");
const { normalizeEntries } = require("../lib/api/validation");

const entries = normalizeEntries([
  {
    id: "entry-1",
    date: "2026-04-26T18:00:00.000Z",
    mood: "okay",
    entryType: "reflection",
    text: "Work felt noisy again and I need to park one decision.",
    themes: ["Work"]
  },
  {
    id: "entry-2",
    date: "2026-04-27T19:00:00.000Z",
    mood: "good",
    entryType: "win",
    text: "Went for a walk and felt steadier.",
    themes: ["Movement", "Progress"],
    steps: 8400
  },
  {
    id: "entry-3",
    date: "2026-04-28T20:00:00.000Z",
    mood: "low",
    entryType: "rant",
    text: "Too many unfinished work decisions.",
    themes: ["Work"]
  }
]);

const healthSummary = {
  averageSleep: 6.4,
  lastNightSleep: 5.8,
  averageSteps: 6000,
  trend: "up"
};

const dailyReview = createDailyReview({
  date: "2026-04-28T00:00:00.000Z",
  entries: entries.slice(2),
  profile: { preferredName: "Mike" },
  healthSummary
});

assert.equal(Boolean(dailyReview), true);
assert.equal(dailyReview.entryIDs.length, 1);
assert.equal(typeof dailyReview.insight.action, "string");
assert.equal(typeof dailyReview.suggestedGoalTitle, "string");
assert.equal(typeof dailyReview.evidenceStrength, "string");

const goal = createGoalFromReview(dailyReview);
if (dailyReview.suggestedGoalTitle.trim().length > 0) {
  assert.equal(goal.status, "active");
  assert.equal(goal.title.length > 0, true);
} else {
  assert.equal(goal, null);
}

const weeklyResult = createWeeklyReview({ entries, healthSummary });
assert.equal(weeklyResult.canReview, true);
assert.equal(weeklyResult.weeklyReview.patterns.length > 0, true);
assert.equal(weeklyResult.weeklyReview.healthPatterns.length > 0, true);
assert.equal(weeklyResult.weeklyReview.patterns.length <= 2, true);

const premiumWeeklyResult = createWeeklyReview({ entries, healthSummary, planTier: "premium" });
assert.equal(premiumWeeklyResult.canReview, true);
assert.equal(premiumWeeklyResult.weeklyReview.patterns.length <= 3, true);
assert.equal(premiumWeeklyResult.weeklyReview.risk.includes("Premium"), false);
assert.equal(typeof premiumWeeklyResult.weeklyReview.patternShift, "string");
assert.equal(typeof premiumWeeklyResult.weeklyReview.goalFollowThrough, "string");

const conversation = createConversation({
  weeklyReview: weeklyResult.weeklyReview,
  profile: { preferredName: "Mike" }
});
assert.equal(conversation.remainingTurns, 3);
assert.equal(conversation.messages[0].sender, "ai");

const reply = replyToConversation({
  text: "",
  action: "Give me one action",
  remainingTurns: conversation.remainingTurns,
  profile: {},
  conversation,
  planTier: "free"
});
assert.equal(reply.status, "active");
assert.equal(reply.remainingTurns, 2);
assert.equal(Boolean(reply.suggestedGoal), true);
assert.equal(typeof reply.replyContext, "string");

const deeper = replyToConversation({
  text: "",
  action: "Go deeper",
  remainingTurns: reply.remainingTurns,
  profile: {},
  conversation,
  planTier: "premium"
});
assert.equal(deeper.status, "active");
assert.equal(deeper.remainingTurns, 7);
assert.equal(deeper.deepeningUsed, true);
assert.equal(deeper.phase, "deeper");
assert.equal(typeof deeper.replyContext, "string");

console.log("API tests passed");
