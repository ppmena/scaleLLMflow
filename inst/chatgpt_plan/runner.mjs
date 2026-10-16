import fs from "node:fs/promises";
import { createServer } from "node:http";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { createRemoteJWKSet, jwtVerify } from "jose";

const root = process.env.SCALELLMFLOW_CHATGPT_DIR || join(homedir(), ".scaleLLMflow", "chatgpt-plan");
const statePath = join(root, "connection.json");
const redirectPort = Number(process.env.SCALELLMFLOW_CHATGPT_PORT || 8787);
const resource = "https://api.openai.com/v1";
const sharingScope = "chatgpt.tokens.use.direct";
const callbackPath = "/auth/callback";

const json = (value) => JSON.stringify(value);
const random = (n = 32) => randomBytes(n).toString("base64url");
const errorResult = (message, code = "bridge_error") => ({ error: true, code, message });

async function readState() {
  try { return JSON.parse(await fs.readFile(statePath, "utf8")); }
  catch { return { hostId: `urn:uuid:${randomUUID()}` }; }
}

async function writeState(state) {
  await fs.mkdir(root, { recursive: true });
  await fs.writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
}

async function discovery() {
  const response = await fetch("https://auth.openai.com/.well-known/openid-configuration");
  if (!response.ok) throw new Error(`OpenAI discovery failed (${response.status}).`);
  return response.json();
}

function openBrowser(url) {
  if (process.platform === "win32") return execFile("cmd.exe", ["/c", "start", "", url]);
  if (process.platform === "darwin") return execFile("open", [url]);
  return execFile("xdg-open", [url]);
}

async function authorize(state, label) {
  const config = await discovery();
  const verifier = random(48);
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const nonce = random(32);
  const csrf = random(32);
  const callback = `http://127.0.0.1:${redirectPort}${callbackPath}`;
  const server = createServer();
  const result = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { server.close(); reject(new Error("ChatGPT sign-in timed out after 30 minutes.")); }, 30 * 60 * 1000);
    server.on("request", (request, response) => {
      try {
        const url = new URL(request.url, callback);
        if (url.pathname !== callbackPath) { response.writeHead(404); response.end(); return; }
        if (url.searchParams.get("state") !== csrf) throw new Error("Invalid OAuth state.");
        const code = url.searchParams.get("code");
        if (!code) throw new Error(url.searchParams.get("error_description") || "ChatGPT authorization was denied.");
        const issuedClientId = url.searchParams.get("client_id") || state.clientId || "";
        if (!issuedClientId) throw new Error("OpenAI did not return an issued client ID.");
        clearTimeout(timer);
        response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
        response.end("<h2>ChatGPT conectado</h2><p>Puedes volver a R/RStudio y continuar.</p>");
        server.close(); resolve({ code, issuedClientId });
      } catch (error) {
        clearTimeout(timer); response.writeHead(400); response.end(error.message); server.close(); reject(error);
      }
    });
    server.on("error", reject);
  });
  await new Promise((resolve, reject) => server.listen(redirectPort, "127.0.0.1", resolve).on("error", reject));
  await writeState({ ...state, hostId: state.hostId });
  const clientId = state.clientId || "dynamic_agent_client";
  const params = new URLSearchParams({
    client_id: clientId, redirect_uri: callback, response_type: "code",
    scope: `openid profile email offline_access resource.invoke ${sharingScope}`,
    state: csrf, nonce, code_challenge: challenge, code_challenge_method: "S256",
    resource, ext_agent_host_id: state.hostId
  });
  if (!state.clientId) params.set("agent_name_hint", "scaleLLMflow");
  openBrowser(`https://auth.openai.com/api/accounts/authorize?${params}`);
  const callbackResult = await result;
  state.clientId = callbackResult.issuedClientId;
  await writeState(state);
  const tokenResponse = await fetch("https://auth.openai.com/api/accounts/oauth/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", client_id: callbackResult.issuedClientId,
      code: callbackResult.code, code_verifier: verifier, redirect_uri: callback, resource })
  });
  const tokenText = await tokenResponse.text();
  let tokens;
  try { tokens = JSON.parse(tokenText); } catch { tokens = {}; }
  if (!tokenResponse.ok || !tokens.access_token) {
    const detail = tokens.error_description || tokens.error || `HTTP ${tokenResponse.status}`;
    throw new Error(`OpenAI token exchange failed: ${detail}`);
  }
  if (tokens.id_token && config.jwks_uri) {
    const verified = await jwtVerify(tokens.id_token, createRemoteJWKSet(new URL(config.jwks_uri)),
      { issuer: config.issuer, audience: callbackResult.issuedClientId, nonce });
    state.identity = { subject: verified.payload.sub, email: verified.payload.email, name: verified.payload.name };
  }
  state.clientId = callbackResult.issuedClientId; state.label = label || state.label || "scaleLLMflow";
  state.scope = tokens.scope || "";
  state.credentials = { accessToken: tokens.access_token, refreshToken: tokens.refresh_token,
    expiresAt: Date.now() + Number(tokens.expires_in || 3600) * 1000 };
  await writeState(state); return state;
}

async function refresh(state) {
  if (!state.credentials?.refreshToken || !state.clientId) throw new Error("Sign in with ChatGPT first.");
  const response = await fetch("https://auth.openai.com/api/accounts/oauth/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "refresh_token", client_id: state.clientId,
      refresh_token: state.credentials.refreshToken, resource })
  });
  const tokens = await response.json();
  if (!response.ok || !tokens.access_token) throw new Error(tokens.error_description || "ChatGPT token renewal failed. Sign in again.");
  state.credentials = { accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token || state.credentials.refreshToken,
    expiresAt: Date.now() + Number(tokens.expires_in || 3600) * 1000 };
  state.scope = tokens.scope || state.scope || ""; await writeState(state); return state;
}

async function accessToken(state) {
  if (!state.credentials?.accessToken) throw new Error("Sign in with ChatGPT first.");
  if (!(state.scope || "").includes(sharingScope)) throw new Error("ChatGPT plan usage is not enabled for this connection.");
  if (state.credentials.expiresAt <= Date.now() + 60_000) state = await refresh(state);
  return [state, state.credentials.accessToken];
}

async function disconnect(state) {
  let revoked = true;
  if (state.credentials?.refreshToken && state.clientId) {
    try {
      const config = await discovery();
      const response = await fetch(config.revocation_endpoint || "https://auth.openai.com/api/accounts/oauth/revoke", {
        method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ token: state.credentials.refreshToken, token_type_hint: "refresh_token", client_id: state.clientId })
      });
      revoked = response.ok;
    } catch { revoked = false; }
  }
  await writeState({ hostId: state.hostId, clientId: state.clientId, label: state.label });
  return revoked;
}

async function api(state, path, init = {}) {
  const [current, token] = await accessToken(state);
  const response = await fetch(`https://api.openai.com/v1${path}`, {
    ...init, headers: { authorization: `Bearer ${token}`, ...(init.headers || {}) }
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error?.message || `ChatGPT request failed (${response.status}).`);
  return { state: current, body };
}

async function models(state) {
  const result = await api(state, "/models");
  return (result.body.data || []).map((item) => ({ slug: item.id, name: item.id, owned_by: item.owned_by }));
}

async function run(state, request) {
  if (!request.model) throw new Error("A ChatGPT model is required.");
  const body = { model: request.model, input: request.input };
  if (request.reasoning_effort) body.reasoning = { effort: request.reasoning_effort };
  if (!/^gpt-5/i.test(request.model) || request.reasoning_effort === "none") body.temperature = request.temperature ?? 0;
  if (request.response_schema) body.text = { format: { type: "json_schema", name: "scale_rating", strict: true, schema: request.response_schema } };
  const result = await api(state, "/responses", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  const text = result.body.output_text || (result.body.output || []).flatMap((item) => item.content || []).map((item) => item.text || "").filter(Boolean).join("\n");
  if (!text) throw new Error("ChatGPT response did not contain readable output text.");
  return { state: result.state, text, model: request.model };
}

async function handle(command, payload) {
  let state = await readState();
  if (command === "status") return { status: state.credentials ? "connected" : "disconnected", sharing: Boolean(state.credentials && (state.scope || "").includes(sharingScope)), identity: state.identity || null };
  if (command === "login") { state = await authorize(state, payload.label || "scaleLLMflow"); return { status: "connected", sharing: (state.scope || "").includes(sharingScope), identity: state.identity || null }; }
  if (command === "logout") return { status: "disconnected", revocation_confirmed: await disconnect(state) };
  if (command === "models") return { models: await models(state) };
  if (command === "run") { const result = await run(state, payload); if (result.state !== state) await writeState(result.state); return { text: result.text, model: result.model }; }
  throw new Error(`Unknown bridge command: ${command}`);
}

const [command, inputPath] = process.argv.slice(2);
let payload = {};
if (inputPath) payload = JSON.parse(await fs.readFile(inputPath, "utf8"));
try { process.stdout.write(`${json(await handle(command, payload))}\n`); }
catch (error) { process.stdout.write(`${json(errorResult(error.message))}\n`); process.exitCode = 1; }
