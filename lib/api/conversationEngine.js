const crypto = require("node:crypto");
const { generateStructured } = require("./openaiClient");
const {
  conversationReplySchema,
  conversationReplySystem,
  conversationStartSchema,
  conversationStartSystem
} = require("./prompts");

const MAX_TURNS = 3;
const END_MESSAGE = "That's enough for today. Let it sit.";

const createConversation = ({ weeklyReview, profile }) => {
  const patterns = Array.isArray(weeklyReview?.patterns) ? weeklyReview.patterns : [];
  const namePrefix = profile?.preferredName ? `${profile.preferredName}, ` : "";
  const patternText = patterns.length
    ? patterns.slice(0, 2).join(", ").toLowerCase()
    : "a few early themes";
  const opener = `${namePrefix}I noticed ${patternText}. What feels most useful to look at?`;
  const now = new Date().toISOString();

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
    remainingTurns: MAX_TURNS
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
    maxOutputTokens: 350
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

const replyToConversation = ({ text, action, remainingTurns, profile }) => {
  const turnsLeft = Math.max(0, Number(remainingTurns || 0));
  const displayText = String(action || text || "").trim();

  if (!turnsLeft || action === "End for today") {
    return {
      status: "ended",
      remainingTurns: 0,
      reply: END_MESSAGE,
      suggestedGoal: null
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
    userMessage: displayText,
    suggestedGoal
  };
};

const replyToAIConversation = async ({ text, action, remainingTurns, profile, conversation }) => {
  const fallback = replyToConversation({ text, action, remainingTurns, profile });

  if (fallback.status === "ended") {
    return { ...fallback, source: "fallback" };
  }

  const generated = await safeGenerateStructured({
    name: "conversation_reply",
    schema: conversationReplySchema,
    system: conversationReplySystem,
    input: {
      profile,
      action,
      text,
      remainingTurns: fallback.remainingTurns,
      recentMessages: Array.isArray(conversation?.messages)
        ? conversation.messages.slice(-8).map((message) => ({
            sender: message.sender,
            text: message.text,
            date: message.date
          }))
        : []
    },
    maxOutputTokens: 450
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

module.exports = {
  END_MESSAGE,
  MAX_TURNS,
  createAIConversation,
  createConversation,
  replyToAIConversation,
  replyToConversation
};
