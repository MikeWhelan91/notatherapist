const crypto = require("node:crypto");
const { generateStructured, moderateText } = require("./openaiClient");
const { crisisDailyReview, detectSafety, validateGeneratedText } = require("./safety");
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
  const evidenceContext = buildDailyEvidenceContext({ entries: sortedEntries, recentEntries: [], profile });
  const improvementSignals = detectImprovementSignals(sortedEntries);

  const summary = sortedEntries.length === 1
    ? dailySingleEntrySummary(firstEntry, evidenceContext)
    : dailyMultiEntrySummary(sortedEntries, evidenceContext);

  const emotionalRead = dailyEmotionalRead({ sortedEntries, lowerText, averageMood, topTheme, topIssue, evidenceContext, improvementSignals });
  const pattern = dailyPattern({ sortedEntries, lowerText, averageMood, topTheme, topIssue, healthSummary, evidenceContext, improvementSignals });
  const reframe = dailyReframe({ sortedEntries, lowerText, evidenceContext, topIssue, improvementSignals });
  const action = dailyAction({ sortedEntries, lowerText, themes, profile, evidenceContext, improvementSignals });
  const evidenceStrength = dailyEvidenceStrength({ sortedEntries, themes });
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
    evidenceStrength,
    suggestedGoalTitle: goal.title,
    suggestedGoalReason: goal.reason,
    acceptedGoalID: null,
    entryIDs: sortedEntries.map((entry) => entry.id),
    createdAt: new Date().toISOString()
  };
};

const createAIDailyReview = async ({ date, entries, recentEntries = [], profile, healthSummary, goals = [], context = {} }) => {
  const safety = detectSafety(entries.map((entry) => entry.text));
  if (safety.level === "crisis") {
    return crisisDailyReview({ date, entries });
  }

  await moderateEntries(entries);
  const evidenceSignals = summarizeEvidenceSignals(entries);
  const evidenceContext = buildDailyEvidenceContext({ entries, recentEntries, profile });
  const generated = await safeGenerateStructured({
    name: "daily_review",
    schema: dailyReviewSchema,
    system: dailyReviewSystem,
    input: {
      date,
      profile,
      healthSummary,
      goals,
      context,
      entries: entries.map(publicEntry),
      recentEntries: recentEntries.map(publicEntry),
      evidenceSignals,
      evidenceContext
    }
  });

  if (!generated) {
    throwAIError("daily_review_empty", "AI daily review did not return structured output.");
  }

  return validateGeneratedText({
    source: "openai",
    review: {
      id: crypto.randomUUID(),
      date,
      summary: generated.summary,
      insight: {
        emotionalRead: generated.emotionalRead,
        pattern: generated.pattern,
        reframe: generated.reframe,
        action: generated.action
      },
      evidenceStrength: generated.evidenceStrength,
      suggestedGoalTitle: generated.suggestedGoalTitle,
      suggestedGoalReason: generated.suggestedGoalReason,
      acceptedGoalID: null,
      entryIDs: entries.map((entry) => entry.id),
      createdAt: new Date().toISOString(),
      source: "openai"
    }
  });
};

const createWeeklyReview = ({ entries, healthSummary, goals = [], planTier = "free" }) => {
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
    ? "Lower mood repeated this week, so keep next steps very small and steady."
    : (themeCounts.Work || 0) >= 2
      ? "Work is taking extra headspace; protect one clear stop point each day."
      : "Keep building consistency so next week's patterns are even clearer.";

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
      patternShift: weeklyPatternShift(sortedEntries),
      goalFollowThrough: weeklyGoalFollowThrough(goals, sortedEntries),
      healthPatterns: weeklyHealthPatterns(sortedEntries, healthSummary),
      progressSignal: weeklyProgressSignal(sortedEntries),
      primaryLoop: weeklyPrimaryLoop(themeCounts),
      nextExperiment: weeklyNextExperiment(themeCounts),
      baselineComparison: weeklyBaselineComparison(sortedEntries),
      suggestedTemplate: weeklySuggestedTemplate(themeCounts),
      researchPrompt: weeklyResearchPrompt(sortedEntries, themeCounts)
    }, planTier)
  };
};

const createAIWeeklyReview = async ({ entries, profile, healthSummary, goals = [], planTier = "free" }) => {
  const safety = detectSafety(entries.map((entry) => entry.text));
  if (safety.level === "crisis") {
    return {
      canReview: true,
      reason: "",
      source: "safety",
      weeklyReview: shapeWeeklyReviewForTier({
        id: crypto.randomUUID(),
        dateRange: dateRange([...entries].sort((a, b) => new Date(a.date) - new Date(b.date))),
        patterns: ["A safety concern appeared in the entries."],
        risk: "This needs real-world support rather than weekly pattern analysis.",
        suggestion: "Contact local emergency services, a crisis line, or a trusted nearby person now.",
        healthPatterns: [],
        patternShift: "",
        goalFollowThrough: "",
        progressSignal: "",
        primaryLoop: "Immediate safety matters more than reflection.",
        nextExperiment: "Pause the app and seek urgent support.",
        baselineComparison: "",
        suggestedTemplate: "",
        researchPrompt: ""
      }, planTier)
    };
  }

  await moderateEntries(entries);
  const eligibility = createWeeklyReview({ entries, healthSummary, goals, planTier });
  if (!eligibility.canReview) {
    return { ...eligibility, source: "local" };
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
    throwAIError("weekly_review_empty", "AI weekly review did not return structured output.");
  }

  const patterns = Array.isArray(generated.patterns) ? generated.patterns : [];
  const healthPatterns = Array.isArray(generated.healthPatterns) ? generated.healthPatterns : [];

  return validateGeneratedText({
    canReview: true,
    reason: "",
    source: "openai",
    weeklyReview: {
      id: crypto.randomUUID(),
      dateRange: dateRange([...entries].sort((a, b) => new Date(a.date) - new Date(b.date))),
      ...shapeWeeklyReviewForTier({
      patterns: patterns.slice(0, 3),
      risk: generated.risk,
      suggestion: generated.suggestion,
      patternShift: generated.patternShift,
      goalFollowThrough: generated.goalFollowThrough,
      healthPatterns: healthPatterns.slice(0, 2),
      progressSignal: generated.progressSignal,
      primaryLoop: generated.primaryLoop,
      nextExperiment: generated.nextExperiment,
      baselineComparison: generated.baselineComparison,
      suggestedTemplate: generated.suggestedTemplate,
      researchPrompt: generated.researchPrompt
      }, planTier)
    }
  });
};

const moderateEntries = async (entries) => {
  const combined = entries.map((entry) => entry.text).join("\n\n");
  const moderation = await moderateText(combined);
  if (moderation.flagged) {
    const error = new Error("Entry content needs a safer support response.");
    error.statusCode = 422;
    error.code = "moderation_flagged";
    error.details = moderation.categories;
    throw error;
  }
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
    risk: review.risk || "Keep one manageable focus for next week and track how it feels.",
    healthPatterns: (review.healthPatterns || []).slice(0, 1),
    patternShift: "",
    goalFollowThrough: "",
    primaryLoop: review.primaryLoop || "",
    nextExperiment: "",
    baselineComparison: "",
    suggestedTemplate: review.suggestedTemplate || "",
    researchPrompt: ""
  };
};

const safeGenerateStructured = async (options) => {
  try {
    return await generateStructured(options);
  } catch (error) {
    console.error("[reviewEngine] OpenAI structured generation failed", {
      name: options?.name,
      code: error?.code,
      statusCode: error?.statusCode,
      message: error?.message
    });
    throw error;
  }
};

const throwAIError = (code, message) => {
  const error = new Error(message);
  error.statusCode = 502;
  error.code = code;
  throw error;
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

const dailySingleEntrySummary = (entry, evidenceContext) => {
  const label = entryTypeLabel[entry.entryType] || "entry";
  if (evidenceContext.primaryExcerpt) {
    return `You logged one ${label}: ${evidenceContext.primaryExcerpt}.`;
  }
  return `You logged one ${label} today.`;
};

const dailyMultiEntrySummary = (entries, evidenceContext) => {
  if (evidenceContext.primaryExcerpt && evidenceContext.secondaryExcerpt) {
    return `${entries.length} entries: ${evidenceContext.primaryExcerpt}, then ${evidenceContext.secondaryExcerpt}.`;
  }
  if (evidenceContext.primaryExcerpt) {
    return `${entries.length} entries, led by ${evidenceContext.primaryExcerpt}.`;
  }
  return `You wrote ${entries.length} entries today.`;
};

const deriveThemes = (entry) => {
  const lower = entry.text.toLowerCase();
  const themes = [];
  if (lower.includes("work") || lower.includes("meeting") || lower.includes("deadline")) {
    themes.push("Work");
  }
  if (lower.includes("sleep") || lower.includes("tired") || lower.includes("night")) {
    themes.push("Sleep");
  }
  if (lower.includes("flu") || lower.includes("sick") || lower.includes("unwell") || lower.includes("illness") || lower.includes("crappy")) {
    themes.push("Physical health");
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

const dailyEmotionalRead = ({ sortedEntries, lowerText, averageMood, topTheme, topIssue, evidenceContext, improvementSignals }) => {
  const anxietySignal = hasAnxietySignal(lowerText);
  if (improvementSignals.length) {
    return evidenceContext.primaryExcerpt
      ? `The strongest signal is progress around "${evidenceContext.primaryExcerpt}".`
      : `The strongest signal is progress: ${improvementSignals[0]}.`;
  }
  if (topIssue) {
    return evidenceContext.primaryExcerpt
      ? `${topIssue.label} is the clearest signal around "${evidenceContext.primaryExcerpt}".`
      : `${topIssue.label} is the clearest signal in today's entries.`;
  }
  if (anxietySignal && topTheme === "Anxiety" && sortedEntries.some((entry) => entry.entryType === "win")) {
    return "You noted anxiety, and also recorded something that went well.";
  }
  if (anxietySignal && topTheme === "Anxiety") {
    return "Anxiety seems to be part of today's context.";
  }
  if (sortedEntries.some((entry) => entry.entryType === "win") || averageMood >= 4) {
    return evidenceContext.primaryExcerpt
      ? `The useful signal is steadiness around "${evidenceContext.primaryExcerpt}".`
      : "There is a steady moment in today's entries.";
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
  if (averageMood >= 3) {
    return evidenceContext.primaryExcerpt
      ? `No strong struggle stands out; "${evidenceContext.primaryExcerpt}" is useful baseline data.`
      : "No strong struggle stands out today, which is useful baseline data.";
  }
  return evidenceContext.primaryExcerpt
    ? `The main thread sits around "${evidenceContext.primaryExcerpt}".`
    : "Today has a few threads worth noticing.";
};

const dailyPattern = ({ sortedEntries, lowerText, averageMood, topTheme, topIssue, healthSummary, evidenceContext, improvementSignals }) => {
  const sleepEntry = sortedEntries.find((entry) => entry.sleepHours);
  const stepsEntry = sortedEntries.find((entry) => entry.steps);

  if (improvementSignals.length) {
    return `Progress signal: ${improvementSignals[0]}.`;
  }

  if (topIssue) {
    const countText = topIssue.count > 1 ? `${topIssue.count} entries` : "1 entry";
    const recentLine = evidenceContext.recentComparison ? ` ${evidenceContext.recentComparison}` : "";
    return `${topIssue.label} came up in ${countText}.${recentLine}`.trim();
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
    return evidenceContext.primaryExcerpt
      ? `${topTheme} is the clearest theme, especially around "${evidenceContext.primaryExcerpt}".`
      : `${topTheme} was the clearest theme today.`;
  }
  return "The useful signal is still early.";
};

const dailyReframe = ({ sortedEntries, lowerText, evidenceContext, topIssue, improvementSignals }) => {
  if (improvementSignals.length) {
    return `This is evidence of what helped, not proof that the old pattern is gone.`;
  }
  if (sortedEntries.some((entry) => entry.entryType === "win")) {
    return "This is worth recording as evidence of what can go right.";
  }
  if (!topIssue && evidenceContext.primaryExcerpt) {
    return `A quieter entry is not empty; it shows what may be worth preserving tomorrow.`;
  }
  if (lowerText.includes("again") || lowerText.includes("same")) {
    return "A repeated thought may need one clear next step, not more time in your head.";
  }
  return "You do not need to solve the whole pattern from one day.";
};

const dailyAction = ({ sortedEntries, lowerText, themes, evidenceContext, improvementSignals }) => {
  if (improvementSignals?.length) {
    return `Tomorrow, repeat one condition that helped this happen, then check whether the same pressure stays smaller.`;
  }
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
  if (evidenceContext.primaryExcerpt && sortedEntries.every((entry) => (moodScore[entry.mood] || 3) >= 3)) {
    return `Protect one condition around "${evidenceContext.primaryExcerpt}" tomorrow, then see if the day stays steadier.`;
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
    if (lower.includes("flu") || lower.includes("sick") || lower.includes("unwell") || lower.includes("illness") || lower.includes("crappy")) {
      signals.keyTopics.push("physical illness");
      if (signals.struggles.length === 0) {
        signals.improvements.push("no clear mental-health struggle; physical illness may explain feeling off");
      }
    }
  }

  return {
    improvements: [...new Set(signals.improvements)],
    struggles: [...new Set(signals.struggles)],
    wins: signals.wins,
    keyTopics: [...new Set(signals.keyTopics)].slice(0, 6)
  };
};

const buildDailyEvidenceContext = ({ entries = [], recentEntries = [], profile = {} }) => {
  const cleanEntries = entries
    .map((entry) => ({
      id: entry.id,
      mood: entry.mood,
      entryType: entry.entryType,
      excerpt: extractUsefulExcerpt(entry.text)
    }))
    .filter((entry) => entry.excerpt);

  const recentIssueSignals = detectIssueSignals(recentEntries);
  const todayIssueSignals = detectIssueSignals(entries);
  const todayTop = todayIssueSignals[0]?.key;
  const recentTop = recentIssueSignals[0]?.key;

  let recentComparison = "";
  if (todayTop && recentTop && todayTop === recentTop) {
    recentComparison = "This also appeared recently, so it may be repeating.";
  } else if (todayTop && recentTop && todayTop !== recentTop) {
    recentComparison = "This differs from the strongest recent theme.";
  }

  return {
    primaryExcerpt: cleanEntries[0]?.excerpt || "",
    secondaryExcerpt: cleanEntries[1]?.excerpt || "",
    entryExcerpts: cleanEntries.slice(0, 4),
    profileFocus: Array.isArray(profile.focusAreas) ? profile.focusAreas.slice(0, 4) : [],
    reflectionGoal: profile.reflectionGoal || "",
    personalStoryAnchor: extractUsefulExcerpt(profile.personalStory || ""),
    recentComparison
  };
};

const extractUsefulExcerpt = (value) => {
  const text = String(value || "")
    .replace(/\s+/g, " ")
    .replace(/[“”]/g, "\"")
    .trim();
  if (!text) {
    return "";
  }

  const sentences = text
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
  const candidate = sentences.find((sentence) => /work|sleep|anx|panic|stress|overwhelm|drive|friend|family|partner|focus|tired|calm|better|worse|again|decision|avoid/i.test(sentence))
    || sentences[0]
    || text;

  return trimSnippet(candidate.replace(/[.!?]+$/, ""), 96);
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
  { key: "workPressure", label: "Work pressure", includes: ["deadline", "manager", "client", "urgent email", "work pressure", "work stress", "workload"], excludes: ["without spiralling", "without spiraling", "less stressed", "not stressed"] }
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

const detectImprovementSignals = (entries) => {
  const combined = entries.map((entry) => String(entry.text || "")).join(" ").toLowerCase();
  const signals = [];
  if (/without (spiralling|spiraling|panic|panicking|anxiety|worry)/.test(combined)) {
    signals.push("you got through something without the old spiral taking over");
  }
  if (/less (anxious|anxiety|stressed|stress|overwhelmed)/.test(combined)) {
    signals.push("the intensity was lower than usual");
  }
  if (/\b(calm|calmer|steady|steadier|settled)\b/.test(combined)) {
    signals.push("calm or steadiness was present");
  }
  if (/\bmanaged|handled|got through|finished|completed\b/.test(combined)) {
    signals.push("you handled something concrete");
  }
  return [...new Set(signals)].slice(0, 3);
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

const trimSnippet = (value, max = 96) => {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (text.length <= max) {
    return text;
  }
  return `${text.slice(0, max - 1)}…`;
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
const dailyEvidenceStrength = ({ sortedEntries, themes }) => {
  const distinctTypes = new Set(sortedEntries.map((entry) => entry.entryType)).size;
  const repeatedThemes = Object.values(countBy(themes)).filter((count) => count >= 2).length;

  if (sortedEntries.length >= 3 || repeatedThemes >= 2) {
    return "Strong evidence from repeated notes today.";
  }
  if (sortedEntries.length === 2 || distinctTypes > 1) {
    return "Moderate evidence from today's entries.";
  }
  return "Light evidence from a single entry.";
};

const weeklyPatternShift = (entries) => {
  if (entries.length < 4) {
    return "Early pattern baseline is still forming.";
  }

  const midpoint = Math.floor(entries.length / 2);
  const earlier = entries.slice(0, midpoint);
  const recent = entries.slice(midpoint);
  const earlierMood = average(earlier.map((entry) => moodScore[entry.mood] || 3));
  const recentMood = average(recent.map((entry) => moodScore[entry.mood] || 3));
  const delta = recentMood - earlierMood;

  if (delta >= 0.5) {
    return "Recent entries read steadier than earlier in the week.";
  }
  if (delta <= -0.5) {
    return "Recent entries read heavier than earlier in the week.";
  }
  return "Overall tone stayed fairly consistent this week.";
};

const weeklyGoalFollowThrough = (goals, entries) => {
  const activeGoals = goals.filter((goal) => goal.status === "active").length;
  const completedGoals = goals.filter((goal) => goal.status === "completed").length;
  const helpedGoals = goals.filter((goal) => goal.feedback === "helped").length;
  const skippedGoals = goals.filter((goal) => goal.feedback === "skipped").length;
  const didNotHelpGoals = goals.filter((goal) => goal.feedback === "didnt_help").length;
  if (!goals.length) {
    return "No active goals were tracked this week.";
  }

  const progressSignals = entries
    .map((entry) => String(entry.text || "").toLowerCase())
    .filter((text) => /done|finished|closed|completed|sent|followed through/.test(text))
    .length;

  if (helpedGoals >= 1) {
    return "At least one experiment was marked helpful, so repeat the condition before changing the plan.";
  }
  if (didNotHelpGoals >= 1) {
    return "One experiment did not help; that is useful data for choosing a smaller or different next step.";
  }
  if (skippedGoals >= 1 && activeGoals >= 1) {
    return "Some next steps were skipped, so next week should reduce friction rather than add pressure.";
  }
  if (completedGoals >= 1 || progressSignals >= 2) {
    return "Your notes show follow-through on at least one planned step.";
  }
  if (activeGoals >= 1) {
    return "Goals stayed active, but progress signals were limited this week.";
  }
  return "Goal follow-through was mixed this week.";
};

const weeklyProgressSignal = (entries) => {
  const progress = entries.filter((entry) => {
    const text = String(entry.text || "").toLowerCase();
    return entry.entryType === "win" || /calmer|better|easier|managed|handled|finished|started|done/.test(text);
  });
  if (progress.length) {
    return "Progress signal: at least one entry named something working or shifting.";
  }
  return "Progress signal is still light; track what helps, not only what hurts.";
};

const weeklyPrimaryLoop = (themeCounts) => {
  if ((themeCounts.Anxiety || 0) >= 2 || (themeCounts["Open loops"] || 0) >= 2) {
    return "Likely loop: worry or unfinished decisions build pressure, then action gets harder.";
  }
  if ((themeCounts.Stress || 0) >= 2 || (themeCounts.Work || 0) >= 2) {
    return "Likely loop: load builds, recovery gets delayed, then everything feels more urgent.";
  }
  if ((themeCounts.Sleep || 0) >= 2) {
    return "Likely loop: sleep disruption lowers energy, then smaller tasks feel heavier.";
  }
  if ((themeCounts.Relationships || 0) >= 2) {
    return "Likely loop: an interaction sticks, the story grows, and repair gets delayed.";
  }
  return "Likely loop is still forming; keep entries concrete so next week can compare better.";
};

const weeklyNextExperiment = (themeCounts) => {
  if ((themeCounts.Anxiety || 0) >= 1 || (themeCounts["Open loops"] || 0) >= 1) {
    return "Next 7 days: use one 60-second reset before the hardest decision, then log whether it changed the next step.";
  }
  if ((themeCounts.Sleep || 0) >= 1) {
    return "Next 7 days: set one wind-down cue and log sleep quality the next morning.";
  }
  if ((themeCounts.Work || 0) >= 1) {
    return "Next 7 days: close or park one work loop before opening a new one.";
  }
  return "Next 7 days: pick one small action daily and mark whether it helped.";
};

const weeklyBaselineComparison = (entries) => {
  const low = entries.filter((entry) => (moodScore[entry.mood] || 3) <= 2).length;
  const high = entries.filter((entry) => (moodScore[entry.mood] || 3) >= 4).length;
  if (high > low) {
    return "Compared with your starting baseline, this week contains more steadiness signals than strain signals.";
  }
  if (low > high) {
    return "Compared with your starting baseline, this week still needs a smaller, stabilizing plan.";
  }
  return "Compared with your starting baseline, this week looks mixed rather than clearly better or worse.";
};

const weeklySuggestedTemplate = (themeCounts) => {
  if ((themeCounts.Anxiety || 0) >= 1) return "Worry loop";
  if ((themeCounts.Sleep || 0) >= 1) return "Sleep";
  if ((themeCounts.Relationships || 0) >= 1) return "Interaction";
  if ((themeCounts.Stress || 0) >= 1 || (themeCounts.Work || 0) >= 1) return "Overload";
  return "Harder today";
};

const weeklyResearchPrompt = (entries, themeCounts) => {
  const text = entries.map((entry) => String(entry.text || "").toLowerCase()).join(" ");
  if (/avoid|procrastinat/.test(text)) return "Worth learning about: avoidance loops and behavioral activation.";
  if (/overthinking|replay|spiral/.test(text)) return "Worth learning about: rumination and worry windows.";
  if (/ignored|rejected|ashamed/.test(text)) return "Worth learning about: rejection sensitivity and repair conversations.";
  if (/burnout|too much|overwhel/.test(text) || (themeCounts.Stress || 0) >= 2) return "Worth learning about: burnout load and recovery debt.";
  return "Worth learning about: the pattern that repeats most, not every possible label.";
};
