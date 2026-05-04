const allowedMethods = (req, res, methods) => {
  const configuredOrigin = process.env.CORS_ALLOW_ORIGIN || "*";
  res.setHeader("Access-Control-Allow-Origin", configuredOrigin);
  res.setHeader("Access-Control-Allow-Methods", ["OPTIONS", ...methods].join(", "));
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-App-Attest, X-Request-ID");
  res.setHeader("Vary", "Origin");

  if (req.method === "OPTIONS") {
    res.statusCode = 204;
    res.end();
    return false;
  }

  if (!methods.includes(req.method)) {
    sendError(res, 405, "method_not_allowed", `Use ${methods.join(" or ")} for this endpoint.`);
    return false;
  }

  return true;
};

const enforceRequestLimit = (req, maxBytes = 120_000) => {
  const length = Number(req.headers["content-length"] || 0);
  if (length > maxBytes) {
    const error = new Error("Request is too large.");
    error.statusCode = 413;
    error.code = "request_too_large";
    throw error;
  }
};

const sendJSON = (res, statusCode, payload) => {
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(payload));
};

const sendError = (res, statusCode, code, message, details = undefined) => {
  sendJSON(res, statusCode, {
    ok: false,
    error: {
      code,
      message,
      ...(details ? { details } : {})
    }
  });
};

const readJSON = async (req) => {
  if (req.body && typeof req.body === "object") {
    req.rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body));
    return req.body;
  }

  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }

  const rawBuffer = Buffer.concat(chunks);
  req.rawBody = rawBuffer;
  const raw = rawBuffer.toString("utf8").trim();
  if (!raw) {
    return {};
  }

  return JSON.parse(raw);
};

const handleEndpoint = async (req, res, methods, handler) => {
  const requestID = req.headers["x-request-id"] || randomRequestID();
  res.setHeader("X-Request-ID", requestID);
  if (!allowedMethods(req, res, methods)) {
    return;
  }

  try {
    enforceRequestLimit(req);
    await handler(req, res);
  } catch (error) {
    console.error("[api]", {
      requestID,
      path: req.url,
      method: req.method,
      code: error.code || "server_error",
      statusCode: error.statusCode || 500,
      message: error.message
    });
    if (error instanceof SyntaxError) {
      sendError(res, 400, "invalid_json", "Request body must be valid JSON.");
      return;
    }

    sendError(res, error.statusCode || 500, error.code || "server_error", error.message || "Something went wrong.");
  }
};

const randomRequestID = () => {
  try {
    return require("node:crypto").randomUUID();
  } catch {
    return String(Date.now());
  }
};

module.exports = {
  handleEndpoint,
  readJSON,
  sendError,
  sendJSON
};
