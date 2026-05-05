const CRISIS_PATTERNS = [
  /\bkill myself\b/i,
  /\bend my life\b/i,
  /\bsuicide\b/i,
  /\bsuicidal\b/i,
  /\bself[- ]?harm\b/i,
  /\bhurt myself\b/i,
  /\boverdose\b/i,
  /\bcan't stay safe\b/i,
  /\bcannot stay safe\b/i
];

const ABUSE_PATTERNS = [
  /\babuse\b/i,
  /\bassault\b/i,
  /\bdomestic violence\b/i,
  /\bunsafe at home\b/i
];

const DIAGNOSIS_OUTPUT_PATTERNS = [
  /\byou have (depression|anxiety|adhd|ptsd|bipolar|ocd)\b/i,
  /\byou likely have\b/i,
  /\bdiagnosis\b/i,
  /\bdiagnose\b/i,
  /\btreatment plan\b/i,
  /\bcure\b/i
];

const MEDICAL_ADVICE_OUTPUT_PATTERNS = [
  /\btake \d+ ?mg\b/i,
  /\bstop taking\b/i,
  /\bstart taking\b/i,
  /\bmedical advice\b/i,
  /\bsee a doctor immediately\b/i
];

const CRISIS_RESPONSE = {
  summary: "This needs urgent real-world support.",
  emotionalRead: "Your safety matters more than reflection right now. Please contact local emergency services, a crisis line, or a trusted nearby person now.",
  pattern: "This is not a pattern to analyze inside the app.",
  reframe: "You do not need to handle this alone or wait until it feels worse.",
  action: "Pause the app and contact emergency services, a crisis line, or someone nearby who can stay with you now.",
  evidenceStrength: "High safety concern from the entry.",
  suggestedGoalTitle: "",
  suggestedGoalReason: "",
  supportInfoTitle: "Urgent support",
  supportInfoBody: "This is outside self-help. The next step is real-world safety support now.",
  supportSteps: ["Contact emergency help", "Tell a trusted person", "Do not stay alone"]
};

const detectSafety = (texts = []) => {
  const joined = texts.map((value) => String(value || "")).join("\n");
  if (CRISIS_PATTERNS.some((pattern) => pattern.test(joined))) {
    return {
      level: "crisis",
      code: "crisis_detected",
      message: "Immediate safety concern detected."
    };
  }
  if (ABUSE_PATTERNS.some((pattern) => pattern.test(joined))) {
    return {
      level: "sensitive",
      code: "abuse_or_safety_context",
      message: "Sensitive safety context detected."
    };
  }
  return { level: "clear", code: "clear", message: "" };
};

const crisisDailyReview = ({ date, entries = [] }) => ({
  source: "safety",
  review: {
    id: cryptoRandomID(),
    date,
    insight: {
      emotionalRead: CRISIS_RESPONSE.emotionalRead,
      pattern: CRISIS_RESPONSE.pattern,
      reframe: CRISIS_RESPONSE.reframe,
      action: CRISIS_RESPONSE.action
    },
    summary: CRISIS_RESPONSE.summary,
    evidenceStrength: CRISIS_RESPONSE.evidenceStrength,
    suggestedGoalTitle: "",
    suggestedGoalReason: "",
    supportInfoTitle: CRISIS_RESPONSE.supportInfoTitle,
    supportInfoBody: CRISIS_RESPONSE.supportInfoBody,
    supportSteps: CRISIS_RESPONSE.supportSteps,
    acceptedGoalID: null,
    entryIDs: entries.map((entry) => entry.id),
    createdAt: new Date().toISOString(),
    source: "safety"
  }
});

const validateGeneratedText = (payload, { allowCrisisLanguage = false } = {}) => {
  const strings = collectStrings(payload);
  const joined = strings.join("\n");

  if (!allowCrisisLanguage && CRISIS_PATTERNS.some((pattern) => pattern.test(joined))) {
    throwUnsafeOutput("unsafe_crisis_language", "Generated text included crisis language outside the safety response.");
  }
  if (DIAGNOSIS_OUTPUT_PATTERNS.some((pattern) => pattern.test(joined))) {
    throwUnsafeOutput("unsafe_diagnostic_language", "Generated text included diagnostic or treatment language.");
  }
  if (MEDICAL_ADVICE_OUTPUT_PATTERNS.some((pattern) => pattern.test(joined))) {
    throwUnsafeOutput("unsafe_medical_language", "Generated text included medical advice.");
  }
  if (strings.some((value) => value.length > 900)) {
    throwUnsafeOutput("unsafe_output_length", "Generated text exceeded the maximum field length.");
  }
  return payload;
};

const collectStrings = (value) => {
  if (typeof value === "string") {
    return [value];
  }
  if (Array.isArray(value)) {
    return value.flatMap(collectStrings);
  }
  if (value && typeof value === "object") {
    return Object.values(value).flatMap(collectStrings);
  }
  return [];
};

const throwUnsafeOutput = (code, message) => {
  const error = new Error(message);
  error.statusCode = 502;
  error.code = code;
  throw error;
};

const cryptoRandomID = () => {
  try {
    return require("node:crypto").randomUUID();
  } catch {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
};

module.exports = {
  crisisDailyReview,
  detectSafety,
  validateGeneratedText
};
