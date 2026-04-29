const crypto = require("node:crypto");
const { generateStructured } = require("./openaiClient");
const {
  dailyReviewSchema,
  dailyReviewSystem,
  weeklyReviewSchema,
  weeklyReviewSystem
} = require("./prompts");

const moodScore = {
  terrible: 1,
  low: 2,
  okay: 3,
  good: 4,
  great: 5
};

const entryTypeLabel = {
  quickThought: "quick thought",
  rant: "rant",
  reflection: "reflection",
  win: "win"
};

const createDailyReview = ({ date, entries, profile, healthSummary }) => {
  if (!entries.length) {
    return null;
  }

  const sortedEntries = [...entries].sort((a, b) => new Date(a.date) - new Date(b.date));
  const combinedText = sortedEntries.map((entry) => entry.text).join(" ");
  const lowerText = combinedText.toLowerCase();
  const averageMood = average(sortedEntries.map((entry) => moodScore[entry.mood] || 3));
  const themes = sortedEntries.flatMap((entry) => deriveThemes(entry));
  const topTheme = mostCommon(themes);
  const issueSignals = detectIssueSignals(sortedEntries);
  const topIssue = issueSignals[0];
  const firstEntry = sortedEntries[0];

  const summary = sortedEntries.length === 1
    ? `You logged one ${entryTypeLabel[firstEntry.entryType] || "entry"} today.`
    : `You wrote ${sortedEntries.length} entries today.`;

  const emotionalRead = dailyEmotionalRead({ sortedEntries, lowerText, averageMood, topTheme, topIssue });
  const pattern = dailyPattern({ sortedEntries, lowerText, averageMood, topTheme, topIssue, healthSummary });
  const reframe = dailyReframe({ sortedEntries, lowerText });
  const action = dailyAction({ sortedEntries, lowerText, themes, profile });
  const goal = suggestedGoal({ sortedEntries, lowerText, themes, action });

  return {
    id: crypto.randomUUID(),
    date,
    summary,
    insight: {
      emotionalRead,
      pattern,
      reframe,
      action
    },
    suggestedGoalTitle: goal.title,
    suggestedGoalReason: goal.reason,
    acceptedGoalID: null,
    entryIDs: sortedEntries.map((entry) => entry.id),
    createdAt: new Date().toISOString()
  };
};

const createAIDailyReview = async ({ date, entries, recentEntries = [], profile, healthSummary, goals = [] }) => {
  const fallback = createDailyReview({ date, entries, profile, healthSummary });
  const evidenceSignals = summarizeEvidenceSignals(entries);
  const generated = await safeGenerateStructured({
    name: "daily_review",
    schema: dailyReviewSchema,
    system: dailyReviewSystem,
    input: {
      date,
      profile,
      healthSummary,
      goals,
      entries: entries.map(publicEntry),
      recentEntries: recentEntries.map(publicEntry),
      evidenceSignals
    }
  });

  if (!generated) {
    return { review: fallback, source: "fallback" };
  }

  return {
    source: "openai",
    review: {
      id: fallback.id,
      date: fallback.date,
      summary: generated.summary,
      insight: {
        emotionalRead: generated.emotionalRead,
        pattern: generated.pattern,
        reframe: generated.reframe,
        action: generated.action
      },
      suggestedGoalTitle: generated.suggestedGoalTitle,
      suggestedGoalReason: generated.suggestedGoalReason,
      acceptedGoalID: null,
      entryIDs: fallback.entryIDs,
      createdAt: fallback.createdAt,
      source: "openai"
    }
  };
};

const createWeeklyReview = ({ entries, healthSummary, planTier = "free" }) => {
  if (!entries.length) {
    return {
      canReview: false,
      reason: "No entries yet.",
      weeklyReview: null
    };
  }

  const distinctDays = new Set(entries.map((entry) => startOfDay(entry.date))).size;
  if (distinctDays < 3 && entries.length < 5) {
    return {
      canReview: false,
      reason: "Weekly review unlocks after 3 writing days or 5 entries.",
      weeklyReview: null
    };
  }

  const sortedEntries = [...entries].sort((a, b) => new Date(a.date) - new Date(b.date));
  const themes = sortedEntries.flatMap((entry) => deriveThemes(entry));
  const themeCounts = countBy(themes);
  const lowMoodCount = sortedEntries.filter((entry) => (moodScore[entry.mood] || 3) <= 2).length;
  const activeGoodDays = sortedEntries.filter((entry) => {
    return (entry.steps || 0) >= (healthSummary?.averageSteps || Number.MAX_SAFE_INTEGER)
      && (moodScore[entry.mood] || 3) >= 4;
  }).length;

  const patterns = [];
  const topTheme = Object.entries(themeCounts).sort((a, b) => b[1] - a[1])[0];
  if (topTheme && topTheme[1] >= 2) {
    patterns.push(`${topTheme[0]} came up ${topTheme[1]} times.`);
  }
  if (lowMoodCount >= 2) {
    patterns.push("Lower mood appeared more than once.");
  }
  if (activeGoodDays >= 1) {
    patterns.push("Better mood tended to follow more active days.");
  }
  if (!patterns.length) {
    patterns.push("Your entries are starting to show early themes.");
  }

  const risk = lowMoodCount >= 2
    ? "Lower mood repeated this week. Keep the next step small."
    : (themeCounts.Work || 0) >= 2
      ? "Work may be taking up more attention than usual."
      : "There is not enough history for a strong pattern yet.";

  const suggestion = (themeCounts.Work || 0) >= 2
    ? "Choose one work decision to finish or park."
    : (themeCounts.Sleep || 0) >= 2
      ? "Write down a stop point before tonight."
      : "Pick one small next step and leave the rest written down.";

  return {
    canReview: true,
    reason: "",
    weeklyReview: shapeWeeklyReviewForTier({
      id: crypto.randomUUID(),
      dateRange: dateRange(sortedEntries),
      patterns: patterns.slice(0, 3),
      risk,
      suggestion,
      healthPatterns: weeklyHealthPatterns(sortedEntries, healthSummary)
    }, planTier)
  };
};

const createAIWeeklyReview = async ({ entries, profile, healthSummary, goals = [], planTier = "free" }) => {
  const fallback = createWeeklyReview({ entries, healthSummary, planTier });
  if (!fallback.canReview) {
    return { ...fallback, source: "fallback" };
  }

  const generated = await safeGenerateStructured({
    name: "weekly_review",
    schema: weeklyReviewSchema,
    system: weeklyReviewSystem,
    input: {
      profile,
      healthSummary,
      planTier,
      goals,
      entries: entries.map(publicEntry)
    }
  });

  if (!generated) {
    return { ...fallback, source: "fallback" };
  }

  const patterns = Array.isArray(generated.patterns) ? generated.patterns : fallback.weeklyReview.patterns;
  const healthPatterns = Array.isArray(generated.healthPatterns) ? generated.healthPatterns : fallback.weeklyReview.healthPatterns;

  return {
    canReview: true,
    reason: "",
    source: "openai",
    weeklyReview: {
      ...fallback.weeklyReview,
      ...shapeWeeklyReviewForTier({
      patterns: patterns.slice(0, 3),
      risk: generated.risk,
      suggestion: generated.suggestion,
      healthPatterns: healthPatterns.slice(0, 2)
      }, planTier)
    }
  };
};

const shapeWeeklyReviewForTier = (review, planTier = "free") => {
  if (planTier === "premium") {
    return {
      ...review,
      patterns: (review.patterns || []).slice(0, 3),
      healthPatterns: (review.healthPatterns || []).slice(0, 2)
    };
  }

  return {
    ...review,
    patterns: (review.patterns || []).slice(0, 2),
    risk: "A fuller weekly review is available with Premium.",
    healthPatterns: (review.healthPatterns || []).slice(0, 1)
  };
};

const safeGenerateStructured = async (options) => {
  try {
    return await generateStructured(options);
  } catch {
    return null;
  }
};

const publicEntry = (entry) => ({
  id: entry.id,
  date: entry.date,
  mood: entry.mood,
  entryType: entry.entryType,
  text: entry.text,
  sleepHours: entry.sleepHours,
  steps: entry.steps
});

const deriveThemes = (entry) => {
  const lower = entry.text.toLowerCase();
  const themes = [];
  if (lower.includes("work") || lower.includes("meeting") || lower.includes("deadline")) {
    themes.push("Work");
  }
  if (lower.includes("sleep") || lower.includes("tired") || lower.includes("night")) {
    themes.push("Sleep");
  }
  if (lower.includes("run") || lower.includes("walk") || lower.includes("gym") || lower.includes("movement")) {
    themes.push("Movement");
  }
  if (lower.includes("friend") || lower.includes("family") || lower.includes("message")) {
    themes.push("Relationships");
  }
  if (lower.includes("focus") || lower.includes("distract") || lower.includes("attention") || lower.includes("procrastinat") || lower.includes("adhd")) {
    themes.push("Focus");
  }
  if (lower.includes("stress") || lower.includes("overwhelm") || lower.includes("burnout")) {
    themes.push("Stress");
  }
  if (lower.includes("stuck") || lower.includes("loop") || lower.includes("decision") || lower.includes("unfinished")) {
    themes.push("Open loops");
  }
  if (hasAnxietySignal(lower)) {
    themes.push("Anxiety");
  }
  if (entry.entryType === "win") {
    themes.push("Progress");
  }
  return themes.length ? [...new Set(themes)].sort() : ["Reflection"];
};

const dailyEmotionalRead = ({ sortedEntries, lowerText, averageMood, topTheme, topIssue }) => {
  const anxietySignal = hasAnxietySignal(lowerText);
  if (topIssue) {
    return `You mentioned ${topIssue.label.toLowerCase()} in today's entries.`;
  }
  if (anxietySignal && topTheme === "Anxiety" && sortedEntries.some((entry) => entry.entryType === "win")) {
    return "You noted anxiety, and also recorded something that went well.";
  }
  if (anxietySignal && topTheme === "Anxiety") {
    return "Anxiety seems to be part of today's context.";
  }
  if (sortedEntries.some((entry) => entry.entryType === "win") || averageMood >= 4) {
    return "There is a steady moment in today's entries.";
  }
  if (topTheme === "Work") {
    return "Work seems to have taken a lot of attention today.";
  }
  if (topTheme === "Sleep") {
    return "Energy and sleep look relevant to today's tone.";
  }
  if (topTheme === "Focus") {
    return "Focus and attention seem to have taken effort today.";
  }
  if (topTheme === "Relationships") {
    return "People and relationships seem central in today's entries.";
  }
  if (topTheme === "Open loops") {
    return "Unfinished decisions seem to be taking up space.";
  }
  if (lowerText.includes("overwhel") || lowerText.includes("too much") || averageMood <= 2.4) {
    return "Today sounds heavy and a little crowded.";
  }
  return "Today has a few threads worth noticing.";
};

const dailyPattern = ({ sortedEntries, lowerText, averageMood, topTheme, topIssue, healthSummary }) => {
  const sleepEntry = sortedEntries.find((entry) => entry.sleepHours);
  const stepsEntry = sortedEntries.find((entry) => entry.steps);

  if (topIssue) {
    const countText = topIssue.count > 1 ? `${topIssue.count} entries` : "1 entry";
    return `${topIssue.label} came up in ${countText}.`;
  }

  if ((sleepEntry?.sleepHours || healthSummary?.lastNightSleep || 0) < 6.25 && averageMood <= 3.2) {
    return "Lower sleep may have shaped the tone of the day.";
  }
  if ((stepsEntry?.steps || 0) >= 7500 && averageMood >= 3.5) {
    return "More movement may be linked with a steadier day.";
  }
  if (lowerText.includes("drove") || lowerText.includes("driving")) {
    return "Driving showed up as something you were watching closely.";
  }
  if (topTheme) {
    return `${topTheme} was the clearest theme today.`;
  }
  return "The useful signal is still early.";
};

const dailyReframe = ({ sortedEntries, lowerText }) => {
  if (sortedEntries.some((entry) => entry.entryType === "win")) {
    return "This is worth recording as evidence of what can go right.";
  }
  if (lowerText.includes("again") || lowerText.includes("same")) {
    return "A repeated thought may need one clear next step, not more time in your head.";
  }
  return "You do not need to solve the whole pattern from one day.";
};

const dailyAction = ({ sortedEntries, lowerText, themes }) => {
  if (lowerText.includes("drove") || lowerText.includes("driving")) {
    return "If driving feels tense again, pause and repeat one thing that helped today.";
  }
  if (sortedEntries.some((entry) => entry.entryType === "win")) {
    return "If a good moment appears tomorrow, write one line on what made it possible.";
  }
  if (themes.includes("Work")) {
    return "If work loops start spinning tomorrow, close or park one decision in under 10 minutes.";
  }
  if (themes.includes("Anxiety")) {
    return "If anxiety rises tomorrow, do a 60-second reset before deciding what to do next.";
  }
  return "If the same thought comes back tomorrow, write one next action and stop there.";
};

const suggestedGoal = ({ sortedEntries, lowerText, themes }) => {
  const strongSignals =
    Number(lowerText.includes("drove") || lowerText.includes("driving")) +
    Number(sortedEntries.some((entry) => entry.entryType === "win")) +
    Number(themes.includes("Work")) +
    Number(themes.includes("Anxiety")) +
    Number(themes.includes("Open loops"));

  if (strongSignals < 1 || sortedEntries.length < 2) {
    return {
      title: "",
      reason: ""
    };
  }

  if (lowerText.includes("drove") || lowerText.includes("driving")) {
    return {
      title: "Repeat what helped on the drive",
      reason: "You mentioned driving; repeat one thing that worked tomorrow."
    };
  }
  if (sortedEntries.some((entry) => entry.entryType === "win")) {
    return {
      title: "Repeat what worked today",
      reason: "You logged a clear win; repeat the same condition tomorrow."
    };
  }
  if (themes.includes("Work")) {
    return {
      title: "Finish one work item",
      reason: "Work came up today, so one finished item is a useful test."
    };
  }
  if (themes.includes("Anxiety")) {
    return {
      title: "Try one short reset",
      reason: "If anxiety rises, use one short reset before your next decision."
    };
  }
  return {
    title: "",
    reason: ""
  };
};

const summarizeEvidenceSignals = (entries) => {
  const signals = {
    improvements: [],
    struggles: [],
    wins: 0,
    keyTopics: []
  };

  for (const entry of entries) {
    const text = String(entry.text || "");
    const lower = text.toLowerCase();

    if (entry.entryType === "win") {
      signals.wins += 1;
    }

    if (
      lower.includes("no anxiety")
      || lower.includes("without anxiety")
      || lower.includes("less anxious")
      || lower.includes("low anxiety")
      || lower.includes("anxiety was low")
      || lower.includes("less anxiety")
      || lower.includes("no panic")
      || lower.includes("without panic")
      || lower.includes("not panicking")
    ) {
      signals.improvements.push("anxiety felt lower");
    }

    if (
      lower.includes("anxiety")
      || lower.includes("panic")
      || lower.includes("overwhelmed")
      || lower.includes("stressed")
      || lower.includes("burnout")
    ) {
      if (signals.improvements.includes("anxiety felt lower") === false) {
        signals.struggles.push("anxiety or stress came up");
      }
    }

    if (lower.includes("drive") || lower.includes("driving")) {
      signals.keyTopics.push("driving");
    }
    if (lower.includes("work") || lower.includes("meeting") || lower.includes("deadline")) {
      signals.keyTopics.push("work");
    }
    if (lower.includes("sleep") || lower.includes("tired")) {
      signals.keyTopics.push("sleep");
    }
  }

  return {
    improvements: [...new Set(signals.improvements)],
    struggles: [...new Set(signals.struggles)],
    wins: signals.wins,
    keyTopics: [...new Set(signals.keyTopics)].slice(0, 6)
  };
};

const hasAnxietySignal = (text) => {
  const lower = String(text || "").toLowerCase();
  const negativePhrases = [
    "no anxiety", "not anxious", "without anxiety", "no panic", "not panicking",
    "no worry", "no worries", "not worried", "low anxiety", "anxiety was low", "less anxiety"
  ];
  if (negativePhrases.some((phrase) => lower.includes(phrase))) {
    return false;
  }
  return (
    lower.includes("anxiety") ||
    lower.includes("anxious") ||
    lower.includes("panic") ||
    lower.includes("worry") ||
    lower.includes("worried")
  );
};

const issueMatchers = [
  { key: "anxiety", label: "Anxiety", includes: ["anxiety", "anxious"], excludes: ["no anxiety", "not anxious", "without anxiety", "low anxiety", "anxiety was low", "less anxiety"] },
  { key: "lowMood", label: "Low mood", includes: ["low mood", "flat", "empty", "down", "depressed"], excludes: ["not depressed"] },
  { key: "stress", label: "Stress load", includes: ["stress", "overwhelm", "overwhelmed", "burnout", "too much"], excludes: [] },
  { key: "panic", label: "Panic signal", includes: ["panic", "panicky"], excludes: ["no panic", "not panicking", "without panic"] },
  { key: "sleep", label: "Sleep disruption", includes: ["sleep", "insomnia", "woke", "waking", "tired", "exhausted"], excludes: [] },
  { key: "focus", label: "Focus friction", includes: ["focus", "distracted", "attention", "procrastinat", "adhd"], excludes: [] },
  { key: "social", label: "Social tension", includes: ["social", "people", "friend", "family", "partner", "relationship"], excludes: [] },
  { key: "workPressure", label: "Work pressure", includes: ["work", "deadline", "meeting", "manager", "client", "email"], excludes: [] }
];

const detectIssueSignals = (entries) => {
  const counts = new Map();
  for (const entry of entries) {
    const lower = String(entry.text || "").toLowerCase();
    for (const matcher of issueMatchers) {
      const excluded = matcher.excludes.some((phrase) => lower.includes(phrase));
      const included = matcher.includes.some((phrase) => lower.includes(phrase));
      if (!excluded && included) {
        counts.set(matcher.key, (counts.get(matcher.key) || 0) + 1);
      }
    }
  }
  return issueMatchers
    .map((matcher) => ({ key: matcher.key, label: matcher.label, count: counts.get(matcher.key) || 0 }))
    .filter((item) => item.count > 0)
    .sort((a, b) => b.count - a.count);
};

const weeklyHealthPatterns = (entries, summary) => {
  if (!summary) {
    return [];
  }

  const patterns = [];
  const activeGoodDays = entries.filter((entry) => {
    return (entry.steps || 0) >= summary.averageSteps && (moodScore[entry.mood] || 3) >= 4;
  }).length;

  if (activeGoodDays >= 1 || summary.trend === "up") {
    patterns.push("Better mood tends to follow more active days.");
  }
  if (summary.lastNightSleep < 6.25 || summary.averageSleep < 6.5) {
    patterns.push("Lower sleep may affect energy.");
  }
  if (!patterns.length && summary.averageSleep >= 7) {
    patterns.push("Steadier days often follow longer sleep.");
  }

  return patterns.slice(0, 2);
};

const createGoalFromReview = (review) => {
  if (!review || typeof review !== "object") {
    return null;
  }

  const title = String(review.suggestedGoalTitle || "").trim();
  if (!title) {
    return null;
  }

  return {
    id: crypto.randomUUID(),
    title,
    reason: String(review.suggestedGoalReason || "Agreed from a review.").trim(),
    createdAt: new Date().toISOString(),
    dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    status: "active",
    sourceConversationID: null,
    checkInPrompt: `How did this go: ${title.toLowerCase()}?`
  };
};

const average = (values) => {
  if (!values.length) {
    return 0;
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
};

const mostCommon = (values) => {
  const counts = countBy(values);
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  return top ? top[0] : null;
};

const countBy = (values) => {
  return values.reduce((counts, value) => {
    counts[value] = (counts[value] || 0) + 1;
    return counts;
  }, {});
};

const startOfDay = (dateValue) => {
  const date = new Date(dateValue);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).toISOString();
};

const dateRange = (entries) => {
  const first = new Date(entries[0].date);
  const last = new Date(entries[entries.length - 1].date);
  const formatter = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
  const firstText = formatter.format(first);
  const lastText = formatter.format(last);
  return firstText === lastText ? firstText : `${firstText} - ${lastText}`;
};

module.exports = {
  createAIDailyReview,
  createAIWeeklyReview,
  createDailyReview,
  createGoalFromReview,
  createWeeklyReview,
  deriveThemes
};
