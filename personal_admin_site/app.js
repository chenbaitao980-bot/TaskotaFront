const config = window.APP_CONFIG || {};
const isConfigured =
  config.supabaseUrl &&
  config.supabaseAnonKey &&
  !config.supabaseUrl.includes("YOUR_PROJECT_REF") &&
  !config.supabaseAnonKey.includes("YOUR_SUPABASE_ANON_KEY");
const client = isConfigured
  ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey)
  : null;

const state = {
  session: null,
  cryptoKey: null,
  keys: [],
  data: [],
  apps: []
};

const $ = (selector) => document.querySelector(selector);

const authPanel = $("#authPanel");
const dashboard = $("#dashboard");
const loginForm = $("#loginForm");
const loginMessage = $("#loginMessage");
const cryptoMessage = $("#cryptoMessage");
const itemTemplate = $("#itemTemplate");

function setMessage(node, text) {
  node.textContent = text || "";
}

function requireSession() {
  if (!state.session?.user?.id) throw new Error("未登录");
  return state.session.user.id;
}

function encodeText(value) {
  return new TextEncoder().encode(value);
}

function decodeText(value) {
  return new TextDecoder().decode(value);
}

function toBase64(bytes) {
  return btoa(String.fromCharCode(...new Uint8Array(bytes)));
}

function fromBase64(value) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}

async function deriveKey(passphrase, userId) {
  const material = await crypto.subtle.importKey("raw", encodeText(passphrase), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: encodeText(`personal-control-desk:${userId}`),
      iterations: 180000,
      hash: "SHA-256"
    },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"]
  );
}

async function encryptSecret(value) {
  if (!state.cryptoKey) throw new Error("请先输入本地加密口令");
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, state.cryptoKey, encodeText(value));
  return { iv: toBase64(iv), ciphertext: toBase64(encrypted) };
}

async function decryptSecret(row) {
  if (!state.cryptoKey) return "已加密，解锁后查看";
  try {
    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: fromBase64(row.iv) },
      state.cryptoKey,
      fromBase64(row.ciphertext)
    );
    return decodeText(decrypted);
  } catch {
    return "口令不正确，无法解密";
  }
}

async function initSession() {
  if (!client) {
    setMessage(loginMessage, "请先在 config.js 中配置 Supabase Project URL 和 anon public key。");
    return;
  }

  const { data } = await client.auth.getSession();
  state.session = data.session;
  renderAuthState();
  if (state.session) await loadAll();

  client.auth.onAuthStateChange(async (_event, session) => {
    state.session = session;
    renderAuthState();
    if (session) await loadAll();
  });
}

function renderAuthState() {
  const loggedIn = Boolean(state.session);
  authPanel.classList.toggle("hidden", loggedIn);
  dashboard.classList.toggle("hidden", !loggedIn);
}

async function loadAll() {
  const userId = requireSession();
  const [keys, dataRows, apps] = await Promise.all([
    client.from("dynamic_secrets").select("*").eq("user_id", userId).order("updated_at", { ascending: false }),
    client.from("dynamic_data").select("*").eq("user_id", userId).order("updated_at", { ascending: false }),
    client.from("managed_apps").select("*").eq("user_id", userId).order("updated_at", { ascending: false })
  ]);

  if (keys.error) throw keys.error;
  if (dataRows.error) throw dataRows.error;
  if (apps.error) throw apps.error;

  state.keys = keys.data || [];
  state.data = dataRows.data || [];
  state.apps = apps.data || [];
  await renderLists();
}

async function renderLists() {
  $("#keyCount").textContent = state.keys.length;
  $("#dataCount").textContent = state.data.length;
  $("#appCount").textContent = state.apps.length;
  await renderKeys();
  renderData();
  renderApps();
}

async function renderKeys() {
  const list = $("#keyList");
  list.replaceChildren();

  for (const row of state.keys) {
    const item = createItem();
    const value = await decryptSecret(row);
    item.main.innerHTML = `
      <div class="item-title">${escapeHtml(row.name)}</div>
      <div class="item-meta">${escapeHtml(row.environment || "default")}</div>
      <div class="item-value">${escapeHtml(value)}</div>
    `;
    item.actions.append(deleteButton("dynamic_secrets", row.id));
    list.append(item.root);
  }
}

function renderData() {
  const list = $("#dataList");
  list.replaceChildren();
  state.data.forEach((row) => {
    const item = createItem();
    item.main.innerHTML = `
      <div class="item-title">${escapeHtml(row.key)}</div>
      <div class="item-value">${escapeHtml(row.value)}</div>
    `;
    item.actions.append(deleteButton("dynamic_data", row.id));
    list.append(item.root);
  });
}

function renderApps() {
  const list = $("#appList");
  list.replaceChildren();
  state.apps.forEach((row) => {
    const item = createItem();
    const link = row.url ? `<a href="${escapeAttribute(row.url)}" target="_blank" rel="noreferrer">${escapeHtml(row.url)}</a>` : "";
    item.main.innerHTML = `
      <div class="item-title">${escapeHtml(row.name)}</div>
      <div class="item-meta">${escapeHtml(row.status)} ${link}</div>
      <div class="item-value">${escapeHtml(row.notes || "")}</div>
    `;
    item.actions.append(deleteButton("managed_apps", row.id));
    list.append(item.root);
  });
}

function createItem() {
  const root = itemTemplate.content.firstElementChild.cloneNode(true);
  return {
    root,
    main: root.querySelector(".item-main"),
    actions: root.querySelector(".item-actions")
  };
}

function deleteButton(table, id) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "danger";
  button.textContent = "删除";
  button.addEventListener("click", async () => {
    await client.from(table).delete().eq("id", id);
    await loadAll();
  });
  return button;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replaceAll("`", "&#096;");
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!client) {
    setMessage(loginMessage, "Supabase 尚未配置。");
    return;
  }
  const email = $("#emailInput").value.trim();
  const { error } = await client.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: window.location.origin + window.location.pathname }
  });
  setMessage(loginMessage, error ? error.message : "登录链接已发送，请查看邮箱。");
});

$("#unlockButton").addEventListener("click", async () => {
  const passphrase = $("#passphraseInput").value;
  if (!passphrase) {
    setMessage(cryptoMessage, "请输入本地加密口令。");
    return;
  }
  state.cryptoKey = await deriveKey(passphrase, requireSession());
  setMessage(cryptoMessage, "已解锁。");
  await renderKeys();
});

$("#logoutButton").addEventListener("click", async () => {
  state.cryptoKey = null;
  await client.auth.signOut();
});

$("#refreshButton").addEventListener("click", loadAll);

$("#keyForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const userId = requireSession();
  const form = new FormData(event.currentTarget);
  const encrypted = await encryptSecret(form.get("secret"));
  const { error } = await client.from("dynamic_secrets").insert({
    user_id: userId,
    name: form.get("name"),
    environment: form.get("environment") || "default",
    ciphertext: encrypted.ciphertext,
    iv: encrypted.iv
  });
  if (error) throw error;
  event.currentTarget.reset();
  await loadAll();
});

$("#dataForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const userId = requireSession();
  const form = new FormData(event.currentTarget);
  const { error } = await client.from("dynamic_data").insert({
    user_id: userId,
    key: form.get("key"),
    value: form.get("value")
  });
  if (error) throw error;
  event.currentTarget.reset();
  await loadAll();
});

$("#appForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const userId = requireSession();
  const form = new FormData(event.currentTarget);
  const { error } = await client.from("managed_apps").insert({
    user_id: userId,
    name: form.get("name"),
    url: form.get("url") || null,
    status: form.get("status"),
    notes: form.get("notes") || null
  });
  if (error) throw error;
  event.currentTarget.reset();
  await loadAll();
});

initSession().catch((error) => {
  setMessage(loginMessage, error.message);
  setMessage(cryptoMessage, error.message);
});
