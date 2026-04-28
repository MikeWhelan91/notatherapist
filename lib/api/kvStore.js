const kvURL = () => process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL || "";
const kvToken = () => process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || "";

const hasKV = () => Boolean(kvURL() && kvToken());

const kvRequest = async (path) => {
  if (!hasKV()) {
    return null;
  }

  const response = await fetch(`${kvURL().replace(/\/$/, "")}${path}`, {
    headers: {
      Authorization: `Bearer ${kvToken()}`
    }
  });

  if (!response.ok) {
    throw new Error(`KV request failed with ${response.status}`);
  }

  return response.json();
};

const kvGet = async (key) => {
  const payload = await kvRequest(`/get/${encodeURIComponent(key)}`);
  const value = payload?.result;
  if (!value) {
    return null;
  }
  return typeof value === "string" ? JSON.parse(value) : value;
};

const kvSet = async (key, value, ttlSeconds = 300) => {
  const serialized = encodeURIComponent(JSON.stringify(value));
  await kvRequest(`/set/${encodeURIComponent(key)}/${serialized}?EX=${ttlSeconds}`);
};

const kvDel = async (key) => {
  await kvRequest(`/del/${encodeURIComponent(key)}`);
};

module.exports = {
  hasKV,
  kvDel,
  kvGet,
  kvSet
};
