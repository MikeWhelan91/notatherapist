const assert = require("node:assert/strict");
const { createConversation, replyToConversation } = require("../lib/api/conversationEngine");
const { createDailyReview, createGoalFromReview, createMonthlyReview, createWeeklyReview } = require("../lib/api/reviewEngine");
const { crisisDailyReview, detectSafety, validateGeneratedText } = require("../lib/api/safety");
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

const calmDailyReview = createDailyReview({
  date: "2026-05-04T00:00:00.000Z",
  entries: normalizeEntries([
    {
      id: "calm-entry",
      date: "2026-05-04T18:00:00.000Z",
      mood: "okay",
      entryType: "reflection",
      text: "I felt calm today and got through work without spiralling about the meeting."
    }
  ]),
  profile: { preferredName: "Mike" },
  healthSummary: null
});
assert.equal(calmDailyReview.insight.pattern.includes("Progress signal"), true);
assert.equal(calmDailyReview.suggestedGoalTitle, "");

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

const thinWeeklyResult = createWeeklyReview({
  entries: normalizeEntries([
    {
      id: "thin-1",
      date: "2026-05-01T18:00:00.000Z",
      mood: "okay",
      entryType: "reflection",
      text: "A fairly normal day.",
      themes: []
    },
    {
      id: "thin-2",
      date: "2026-05-02T18:00:00.000Z",
      mood: "good",
      entryType: "quickThought",
      text: "Nothing major to add.",
      themes: []
    },
    {
      id: "thin-3",
      date: "2026-05-03T18:00:00.000Z",
      mood: "okay",
      entryType: "win",
      text: "Kept things steady.",
      themes: []
    }
  ])
});
assert.equal(thinWeeklyResult.canReview, true);
assert.equal(thinWeeklyResult.weeklyReview.patterns.length, 0);
assert.equal(thinWeeklyResult.weeklyReview.risk, "");

const freeMonthlyResult = createMonthlyReview({ entries, planTier: "free" });
assert.equal(freeMonthlyResult.canReview, false);
assert.equal(freeMonthlyResult.monthlyReview, null);

const monthlyEntries = normalizeEntries(Array.from({ length: 14 }, (_, index) => ({
  id: `month-${index}`,
  date: new Date(Date.UTC(2026, 4, index + 1, 18)).toISOString(),
  mood: index % 3 === 0 ? "low" : "okay",
  entryType: index % 4 === 0 ? "win" : "reflection",
  text: index % 2 === 0 ? "Work decisions kept coming up." : "I tried to park one work loop.",
  themes: ["Work"]
})));
const monthlyResult = createMonthlyReview({
  entries: monthlyEntries,
  weeklyReviews: [premiumWeeklyResult.weeklyReview],
  healthSummary,
  goals: [],
  planTier: "premium"
});
assert.equal(monthlyResult.canReview, true);
assert.equal(monthlyResult.monthlyReview.patterns.length > 0, true);
assert.equal(monthlyResult.monthlyReview.nextExperiment.includes("30 days"), true);

const conversation = createConversation({
  weeklyReview: weeklyResult.weeklyReview,
  profile: { preferredName: "Mike" }
});
assert.equal(conversation.remainingTurns, 6);
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
assert.equal(reply.remainingTurns, 5);
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
assert.equal(deeper.remainingTurns, 11);
assert.equal(deeper.deepeningUsed, true);
assert.equal(deeper.phase, "deeper");
assert.equal(typeof deeper.replyContext, "string");

const monthlyConversation = createConversation({
  monthlyReview: monthlyResult.monthlyReview,
  profile: { preferredName: "Mike" },
  cadence: "monthly"
});
assert.equal(monthlyConversation.remainingTurns, 12);
assert.equal(monthlyConversation.reviewCadence, "monthly");

const monthlyAction = replyToConversation({
  text: "",
  action: "Give me one action",
  remainingTurns: monthlyConversation.remainingTurns,
  profile: {},
  conversation: monthlyConversation,
  planTier: "premium"
});
assert.equal(monthlyAction.suggestedGoal.dueDate.length > 0, true);

const safety = detectSafety(["I might kill myself tonight"]);
assert.equal(safety.level, "crisis");

const crisisReview = crisisDailyReview({
  date: "2026-05-04T00:00:00.000Z",
  entries: entries.slice(0, 1)
});
assert.equal(crisisReview.source, "safety");
assert.equal(crisisReview.review.suggestedGoalTitle, "");

assert.throws(() => validateGeneratedText({ reply: "You have depression." }), /diagnostic/i);
assert.doesNotThrow(() => validateGeneratedText({ reply: "This could resemble a worry loop." }));

console.log("API tests passed");
