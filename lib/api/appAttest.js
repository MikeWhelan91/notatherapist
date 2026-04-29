const crypto = require("node:crypto");
const { hasKV, kvDel, kvGet, kvSet } = require("./kvStore");

const challengeTTLSeconds = 300;
const attestationTTLSeconds = 60 * 60 * 24 * 365;

const appAttestEnabled = () => process.env.APP_ATTEST_ENFORCE === "true";
const allowDevelopmentEnvironment = () => process.env.APP_ATTEST_ENV !== "production";

const bundleIdentifier = () => process.env.APP_BUNDLE_ID || "";
const teamIdentifier = () => process.env.APPLE_TEAM_ID || "";

let nodeAppAttestModulePromise;
const loadNodeAppAttest = async () => {
  if (!nodeAppAttestModulePromise) {
    nodeAppAttestModulePromise = import("node-app-attest");
  }
  return nodeAppAttestModulePromise;
};

const createChallenge = async () => {
  const challenge = crypto.randomBytes(32).toString("base64url");
  if (hasKV()) {
    await kvSet(challengeKey(challenge), { createdAt: Date.now() }, challengeTTLSeconds);
  }
  return challenge;
};

const verifyAttestationRequest = async ({ keyId, challenge, attestation }) => {
  requireProductionConfig();
  const { verifyAttestation } = await loadNodeAppAttest();

  if (hasKV()) {
    const storedChallenge = await kvGet(challengeKey(challenge));
    if (!storedChallenge) {
      throw unauthorized("Challenge is missing or expired.");
    }
  } else if (appAttestEnabled()) {
    throw unavailable("App Attest requires KV storage when enforcement is enabled.");
  }

  const result = verifyAttestation({
    attestation: Buffer.from(attestation, "base64"),
    challenge,
    keyId,
    bundleIdentifier: bundleIdentifier(),
    teamIdentifier: teamIdentifier(),
    allowDevelopmentEnvironment: allowDevelopmentEnvironment()
  });

  if (hasKV()) {
    await kvSet(attestationKey(keyId), {
      keyId,
      publicKey: result.publicKey,
      signCount: 0,
      createdAt: Date.now(),
      environment: result.environment
    }, attestationTTLSeconds);
    await kvDel(challengeKey(challenge));
  }

  return result;
};

const verifyProtectedRequest = async (req, rawBody, body) => {
  if (!appAttestEnabled()) {
    return { verified: false, reason: "not_enforced" };
  }

  requireProductionConfig();
  const { verifyAssertion } = await loadNodeAppAttest();

  if (!hasKV()) {
    throw unavailable("App Attest enforcement requires KV storage.");
  }

  const authentication = req.headers["x-app-attest"];
  if (!authentication) {
    throw unauthorized("Missing App Attest assertion.");
  }

  const challenge = body?.attestChallenge;
  if (!challenge) {
    throw unauthorized("Missing App Attest challenge.");
  }

  const storedChallenge = await kvGet(challengeKey(challenge));
  if (!storedChallenge) {
    throw unauthorized("Challenge is missing or expired.");
  }

  const parsed = JSON.parse(Buffer.from(authentication, "base64").toString("utf8"));
  const storedAttestation = await kvGet(attestationKey(parsed.keyId));
  if (!storedAttestation) {
    throw unauthorized("Device is not attested.");
  }

  const result = verifyAssertion({
    assertion: Buffer.from(parsed.assertion, "base64"),
    payload: rawBody,
    publicKey: storedAttestation.publicKey,
    bundleIdentifier: bundleIdentifier(),
    teamIdentifier: teamIdentifier(),
    signCount: storedAttestation.signCount || 0
  });

  await kvSet(attestationKey(parsed.keyId), {
    ...storedAttestation,
    signCount: result.signCount,
    updatedAt: Date.now()
  }, attestationTTLSeconds);
  await kvDel(challengeKey(challenge));

  return { verified: true };
};

const requireProductionConfig = () => {
  if (!bundleIdentifier() || !teamIdentifier()) {
    throw unavailable("APP_BUNDLE_ID and APPLE_TEAM_ID are required for App Attest.");
  }
};

const challengeKey = (challenge) => `app-attest:challenge:${challenge}`;
const attestationKey = (keyId) => `app-attest:key:${keyId}`;

const unauthorized = (message) => {
  const error = new Error(message);
  error.statusCode = 401;
  error.code = "app_attest_failed";
  return error;
};

const unavailable = (message) => {
  const error = new Error(message);
  error.statusCode = 503;
  error.code = "app_attest_unavailable";
  return error;
};

module.exports = {
  appAttestEnabled,
  createChallenge,
  verifyAttestationRequest,
  verifyProtectedRequest
};
