const crypto = require("node:crypto");
const { generateStructured } = require("./openaiClient");
const {
  conversationReplySchema,
  conversationReplySystem,
  conversationStartSchema,
  conversationStartSystem
} = require("./prompts");

const MAX_TURNS = 6;
const DEEPER_BONUS_TURNS = 6;
const DEEPER_MAX_TURNS = MAX_TURNS + DEEPER_BONUS_TURNS;
const END_MESSAGE = "That's enough for today. Let it sit.";
const RECENT_MESSAGES_LIMIT = 8;
const RECENT_MESSAGE_CHARS = 180;
const OLDER_MESSAGES_SUMMARY_CHARS = 520;
const CONTEXT_HINTS_LIMIT = 6;

const createConversation = ({ weeklyReview, profile }) => {
  const patterns = Array.isArray(weeklyReview?.patterns) ? weeklyReview.patterns : [];
  const namePrefix = profile?.preferredName ? `${profile.preferredName}, ` : "";
  const patternText = patterns.length
    ? patterns.slice(0, 2).join(", ").toLowerCase()
    : "a few early themes";
  const opener = `${namePrefix}I noticed ${patternText}. What feels most useful to look at?`;
  const now = new Date().toISOString();
  const contextHints = [
    profile?.personalStory ? `Story: ${String(profile.personalStory).slice(0, 180)}` : null,
    Array.isArray(profile?.lifeContext) && profile.lifeContext.length
      ? `Context: ${profile.lifeContext.slice(0, 3).join(", ")}`
      : null,
    profile?.reflectionGoal ? `Goal: ${profile.reflectionGoal}` : null,
    ...(Array.isArray(weeklyReview?.patterns) ? weeklyReview.patterns.slice(0, 3) : []),
    weeklyReview?.suggestion,
    weeklyReview?.patternShift,
    weeklyReview?.goalFollowThrough
  ].filter(Boolean);

  return {
    id: crypto.randomUUID(),
    title: "Weekly check-in",
    date: now,
    preview: opener,
    messages: [
      {
        id: crypto.randomUUID(),
        sender: "ai",
        text: opener,
        date: now
      }
    ],
    status: "active",
    remainingTurns: MAX_TURNS,
    maxTurns: MAX_TURNS,
    deepeningUsed: false,
    phase: "core",
    contextHints
  };
};

const createAIConversation = async ({ weeklyReview, profile }) => {
  const fallback = createConversation({ weeklyReview, profile });
  const generated = await safeGenerateStructured({
    name: "conversation_start",
    schema: conversationStartSchema,
    system: conversationStartSystem,
    input: {
      profile,
      weeklyReview
    },
    maxOutputTokens: 260
  });

  if (!generated) {
    return { conversation: fallback, source: "fallback" };
  }

  const now = new Date().toISOString();
  return {
    source: "openai",
    conversation: {
      ...fallback,
      title: generated.title || "Weekly check-in",
      preview: generated.opener,
      messages: [
        {
          id: crypto.randomUUID(),
          sender: "ai",
          text: generated.opener,
          date: now
        }
      ]
    }
  };
};

const replyToConversation = ({ text, action, remainingTurns, profile, conversation, planTier = "free" }) => {
  const turnsLeft = Math.max(0, Number(remainingTurns || 0));
  const displayText = String(action || text || "").trim();
  const deepeningUsed = Boolean(conversation?.deepeningUsed);
  const isPremium = planTier === "premium";

  if (action === "Go deeper") {
    if (!isPremium) {
      return {
        status: turnsLeft > 0 ? "active" : "ended",
        remainingTurns: turnsLeft,
        reply: "Go deeper is available in Premium mode.",
        replyContext: "",
        suggestedGoal: null,
        maxTurns: MAX_TURNS,
        deepeningUsed,
        phase: "core"
      };
    }
    if (deepeningUsed) {
      return {
        status: turnsLeft > 0 ? "active" : "ended",
        remainingTurns: turnsLeft,
        reply: "Deeper mode is already active for this check-in.",
        replyContext: "",
        suggestedGoal: null,
        maxTurns: DEEPER_MAX_TURNS,
        deepeningUsed: true,
        phase: "deeper"
      };
    }
    if (turnsLeft <= 0) {
      return {
        status: "ended",
        remainingTurns: 0,
        reply: END_MESSAGE,
        replyContext: "",
        suggestedGoal: null,
        maxTurns: DEEPER_MAX_TURNS,
        deepeningUsed: true,
        phase: "deeper"
      };
    }
    return {
      status: "active",
      remainingTurns: turnsLeft + DEEPER_BONUS_TURNS,
      reply: "We can go deeper. What part feels most emotionally charged or most repeated this week?",
      replyContext: "This deeper pass builds on your weekly patterns and prior replies in this check-in.",
      suggestedGoal: null,
      maxTurns: DEEPER_MAX_TURNS,
      deepeningUsed: true,
      phase: "deeper"
    };
  }

  if (!turnsLeft || action === "End for today") {
    return {
      status: "ended",
      remainingTurns: 0,
      reply: END_MESSAGE,
      replyContext: "",
      suggestedGoal: null,
      maxTurns: deepeningUsed ? DEEPER_MAX_TURNS : MAX_TURNS,
      deepeningUsed,
      phase: deepeningUsed ? "deeper" : "core"
    };
  }

  const nextTurns = Math.max(0, turnsLeft - 1);
  const reply = nextTurns === 0 ? END_MESSAGE : guidedReply({ text, action, remainingTurns: nextTurns, profile });
  const suggestedGoal = action === "Give me one action"
    ? {
        id: crypto.randomUUID(),
        title: "Finish one small unfinished thing",
        reason: "Agreed during the weekly check-in.",
        createdAt: new Date().toISOString(),
        dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
        status: "active",
        sourceConversationID: null,
        checkInPrompt: "How did this go: finish one small unfinished thing?"
      }
    : null;

  return {
    status: nextTurns === 0 ? "ended" : "active",
    remainingTurns: nextTurns,
    reply,
    replyContext: buildReplyContext({ conversation, action, text }),
    userMessage: displayText,
    suggestedGoal,
    maxTurns: deepeningUsed ? DEEPER_MAX_TURNS : MAX_TURNS,
    deepeningUsed,
    phase: deepeningUsed ? "deeper" : "core"
  };
};

const replyToAIConversation = async ({ text, action, remainingTurns, profile, conversation, planTier = "free" }) => {
  const fallback = replyToConversation({ text, action, remainingTurns, profile, conversation, planTier });

  if (fallback.status === "ended") {
    return { ...fallback, source: "fallback" };
  }
  if (action === "Go deeper") {
    return { ...fallback, source: "fallback" };
  }

  const compactRecentMessages = buildCompactRecentMessages(conversation);
  const compactContextHints = compactConversationHints(conversation);

  const generated = await safeGenerateStructured({
    name: "conversation_reply",
    schema: conversationReplySchema,
    system: conversationReplySystem,
    input: {
      profile,
      action,
      text,
      remainingTurns: fallback.remainingTurns,
      recentMessages: compactRecentMessages,
      memory: buildConversationMemory(conversation, profile),
      contextHints: compactContextHints,
      phase: fallback.phase
    },
    maxOutputTokens: 320
  });

  if (!generated) {
    return { ...fallback, source: "fallback" };
  }

  const suggestedGoal = action === "Give me one action" && generated.suggestedGoalTitle
    ? {
        id: crypto.randomUUID(),
        title: generated.suggestedGoalTitle,
        reason: generated.suggestedGoalReason || "Agreed during the weekly check-in.",
        createdAt: new Date().toISOString(),
        dueDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
        status: "active",
        sourceConversationID: null,
        checkInPrompt: `How did this go: ${generated.suggestedGoalTitle.toLowerCase()}?`
      }
    : null;

  return {
    ...fallback,
    source: "openai",
    reply: generated.reply,
    replyContext: generated.replyContext || fallback.replyContext,
    suggestedGoal
  };
};

const safeGenerateStructured = async (options) => {
  try {
    return await generateStructured(options);
  } catch {
    return null;
  }
};

const guidedReply = ({ text, action, remainingTurns }) => {
  const prompt = String(action || text || "").toLowerCase();

  if (prompt.includes("break")) {
    return "Break it into three parts: what happened, what is still open, and what needs one decision.";
  }
  if (prompt.includes("reframe")) {
    return "This may not mean you are behind. It may mean too many things are asking for attention.";
  }
  if (prompt.includes("action")) {
    return "One useful next step: finish one small unfinished thing before Wednesday.";
  }
  if (prompt.includes("work")) {
    return "Work is showing up as unfinished decisions. Which one can you finish or park today?";
  }
  if (remainingTurns <= 1) {
    return "Keep this small. Pick one thread, write the next step, then stop.";
  }
  return "This seems to come up often. What part of it feels most unresolved right now?";
};

const buildReplyContext = ({ conversation, action, text }) => {
  const hints = Array.isArray(conversation?.contextHints) ? conversation.contextHints : [];
  const latestUserMessage = Array.isArray(conversation?.messages)
    ? [...conversation.messages].reverse().find((message) => message.sender === "user")
    : null;

  if (action === "Give me one action") {
    if (hints[0]) {
      return `Action based on repeated weekly pattern: ${hints[0]}`;
    }
    return "Action based on your latest concern in this check-in.";
  }
  if (latestUserMessage?.text) {
    return `This reply references your recent message: "${trimSnippet(latestUserMessage.text)}".`;
  }
  if (text) {
    return `This reply references your recent message: "${trimSnippet(text)}".`;
  }
  if (hints[0]) {
    return `This reply references your weekly pattern: ${hints[0]}`;
  }
  return "This reply uses the current check-in context.";
};

const trimSnippet = (value, max = 72) => {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (text.length <= max) {
    return text;
  }
  return `${text.slice(0, max - 1)}…`;
};

const buildConversationMemory = (conversation, profile) => {
  const messages = Array.isArray(conversation?.messages) ? conversation.messages : [];
  const userMessages = messages.filter((message) => message.sender === "user").map((message) => message.text || "");
  const aiMessages = messages.filter((message) => message.sender === "ai").map((message) => message.text || "");
  const repeatedThreads = detectRepeatedThreads(userMessages);

  return {
    userStoryAnchor: profile?.personalStory ? String(profile.personalStory).slice(0, 220) : "",
    repeatedThreads,
    olderMessagesSummary: summarizeOlderConversation(messages),
    firstUserMessage: userMessages[0] ? trimSnippet(userMessages[0], 140) : "",
    latestUserMessage: userMessages[userMessages.length - 1] ? trimSnippet(userMessages[userMessages.length - 1], 140) : "",
    lastAIPoint: aiMessages[aiMessages.length - 1] ? trimSnippet(aiMessages[aiMessages.length - 1], 140) : ""
  };
};

const buildCompactRecentMessages = (conversation) => {
  if (!Array.isArray(conversation?.messages)) {
    return [];
  }
  return conversation.messages
    .slice(-RECENT_MESSAGES_LIMIT)
    .map((message) => ({
      sender: message.sender,
      text: trimSnippet(message.text || "", RECENT_MESSAGE_CHARS),
      date: message.date
    }));
};

const summarizeOlderConversation = (messages) => {
  if (!Array.isArray(messages) || messages.length <= RECENT_MESSAGES_LIMIT) {
    return "";
  }

  const older = messages.slice(0, -RECENT_MESSAGES_LIMIT);
  const lines = older
    .filter((message) => message?.text)
    .slice(-10)
    .map((message) => `${message.sender === "user" ? "U" : "A"}: ${trimSnippet(message.text, 90)}`);
  const joined = lines.join(" | ");
  return trimSnippet(joined, OLDER_MESSAGES_SUMMARY_CHARS);
};

const compactConversationHints = (conversation) => {
  if (!Array.isArray(conversation?.contextHints)) {
    return [];
  }
  return conversation.contextHints
    .slice(0, CONTEXT_HINTS_LIMIT)
    .map((hint) => trimSnippet(hint, 120));
};

const detectRepeatedThreads = (userMessages) => {
  const buckets = [
    { key: "work", words: ["work", "job", "deadline", "meeting", "office"] },
    { key: "anxiety", words: ["anxiety", "panic", "nervous", "fear"] },
    { key: "sleep", words: ["sleep", "tired", "insomnia", "awake"] },
    { key: "relationship", words: ["partner", "relationship", "family", "friend"] },
    { key: "focus", words: ["focus", "adhd", "attention", "distracted"] }
  ];

  const matches = [];
  const combined = userMessages.join(" ").toLowerCase();
  for (const bucket of buckets) {
    const hitCount = bucket.words.reduce((count, word) => count + (combined.includes(word) ? 1 : 0), 0);
    if (hitCount > 0) {
      matches.push(bucket.key);
    }
  }
  return matches.slice(0, 3);
};

module.exports = {
  END_MESSAGE,
  MAX_TURNS,
  createAIConversation,
  createConversation,
  replyToAIConversation,
  replyToConversation
};
