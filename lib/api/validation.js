const crypto = require("node:crypto");

const MOODS = new Set(["terrible", "low", "okay", "good", "great"]);
const ENTRY_TYPES = new Set(["quickThought", "rant", "reflection", "win"]);
const TRENDS = new Set(["up", "down", "stable"]);

const badRequest = (message, details) => {
  const error = new Error(message);
  error.statusCode = 400;
  error.code = "bad_request";
  if (details) {
    error.details = details;
  }
  return error;
};

const requireArray = (value, name) => {
  if (!Array.isArray(value)) {
    throw badRequest(`${name} must be an array.`);
  }
  return value;
};

const normalizeDate = (value, fallback = new Date()) => {
  const date = value ? new Date(value) : fallback;
  if (Number.isNaN(date.getTime())) {
    throw badRequest("Date values must be ISO-8601 strings.");
  }
  return date.toISOString();
};

const normalizeAssessment = (assessment) => {
  if (!assessment || typeof assessment !== "object") {
    return null;
  }

  const answers = Array.isArray(assessment.answers)
    ? assessment.answers.map((value) => {
      const numeric = Number(value);
      return Number.isFinite(numeric) ? Math.max(0, Math.min(3, Math.round(numeric))) : 0;
    }).slice(0, 32)
    : [];

  const questionLabels = Array.isArray(assessment.questionLabels)
    ? assessment.questionLabels.map(cleanString).filter(Boolean).slice(0, 32)
    : [];

  const domains = Array.isArray(assessment.domains)
    ? assessment.domains.map((item) => ({
      domain: cleanString(item?.domain).slice(0, 32),
      score: Math.max(0, Math.round(toNumber(item?.score))),
      maxScore: Math.max(0, Math.round(toNumber(item?.maxScore))),
      level: cleanString(item?.level).slice(0, 24)
    })).filter((item) => item.domain)
    : [];

  return {
    instrument: cleanString(assessment.instrument).slice(0, 32),
    version: cleanString(assessment.version).slice(0, 16),
    totalScore: Math.max(0, Math.round(toNumber(assessment.totalScore))),
    maxScore: Math.max(0, Math.round(toNumber(assessment.maxScore))),
    answers,
    questionLabels,
    domains,
    completedAt: normalizeDate(assessment.completedAt, new Date())
  };
};

const normalizeProfile = (profile = {}) => ({
  preferredName: cleanString(profile.preferredName),
  ageRange: cleanString(profile.ageRange),
  lifeContext: cleanStringArray(profile.lifeContext),
  reflectionGoal: cleanString(profile.reflectionGoal),
  personalStory: cleanString(profile.personalStory).slice(0, 1000),
  assessment: normalizeAssessment(profile.assessment)
});

const normalizeHealthSummary = (summary) => {
  if (!summary || typeof summary !== "object") {
    return null;
  }

  const trend = TRENDS.has(summary.trend) ? summary.trend : "stable";
  return {
    averageSleep: toNumber(summary.averageSleep),
    lastNightSleep: toNumber(summary.lastNightSleep),
    averageSteps: Math.max(0, Math.round(toNumber(summary.averageSteps))),
    trend
  };
};

const normalizeGoals = (goals) => {
  if (!Array.isArray(goals)) {
    return [];
  }

  return goals.slice(0, 8).map((goal) => ({
    id: cleanString(goal.id),
    title: cleanString(goal.title).slice(0, 160),
    reason: cleanString(goal.reason).slice(0, 240),
    status: cleanString(goal.status) || "active",
    checkInPrompt: cleanString(goal.checkInPrompt).slice(0, 200)
  })).filter((goal) => goal.title);
};

const normalizeEntries = (entries) => {
  return requireArray(entries, "entries").map((entry, index) => normalizeEntry(entry, index));
};

const normalizeEntry = (entry, index) => {
  if (!entry || typeof entry !== "object") {
    throw badRequest(`entries[${index}] must be an object.`);
  }

  const text = cleanString(entry.text);
  if (!text) {
    throw badRequest(`entries[${index}].text is required.`);
  }

  const mood = MOODS.has(entry.mood) ? entry.mood : "okay";
  const entryType = ENTRY_TYPES.has(entry.entryType) ? entry.entryType : "quickThought";

  return {
    id: cleanString(entry.id) || crypto.randomUUID(),
    date: normalizeDate(entry.date),
    mood,
    entryType,
    text: text.slice(0, 4000),
    themes: cleanStringArray(entry.themes),
    sleepHours: optionalNumber(entry.sleepHours),
    steps: optionalInteger(entry.steps)
  };
};

const cleanString = (value) => {
  return typeof value === "string" ? value.trim() : "";
};

const cleanStringArray = (value) => {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map(cleanString).filter(Boolean).slice(0, 12);
};

const toNumber = (value) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
};

const optionalNumber = (value) => {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
};

const optionalInteger = (value) => {
  const number = optionalNumber(value);
  return number === null ? null : Math.max(0, Math.round(number));
};

module.exports = {
  badRequest,
  cleanString,
  cleanStringArray,
  normalizeDate,
  normalizeEntries,
  normalizeGoals,
  normalizeHealthSummary,
  normalizeProfile
};
