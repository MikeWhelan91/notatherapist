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
assert.equal(Boolean(dailyReview.suggestedGoalTitle), true);

const goal = createGoalFromReview(dailyReview);
assert.equal(goal.status, "active");
assert.equal(goal.title, dailyReview.suggestedGoalTitle);

const weeklyResult = createWeeklyReview({ entries, healthSummary });
assert.equal(weeklyResult.canReview, true);
assert.equal(weeklyResult.weeklyReview.patterns.length > 0, true);
assert.equal(weeklyResult.weeklyReview.healthPatterns.length > 0, true);
assert.equal(weeklyResult.weeklyReview.patterns.length <= 2, true);

const premiumWeeklyResult = createWeeklyReview({ entries, healthSummary, planTier: "premium" });
assert.equal(premiumWeeklyResult.canReview, true);
assert.equal(premiumWeeklyResult.weeklyReview.patterns.length <= 3, true);
assert.equal(premiumWeeklyResult.weeklyReview.risk.includes("Premium"), false);

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
  profile: {}
});
assert.equal(reply.status, "active");
assert.equal(reply.remainingTurns, 2);
assert.equal(Boolean(reply.suggestedGoal), true);

console.log("API tests passed");
