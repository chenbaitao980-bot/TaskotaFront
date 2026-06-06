/**
 * 支付宝当面付 SDK（Deno 版）
 * 支持：alipay.trade.precreate（生成二维码）、alipay.trade.query（查询订单）
 * 签名算法：RSA2 (SHA256WithRSA)
 */

// --- 配置 ---
export interface AlipayConfig {
  appId: string;
  privateKey: string;      // 应用私钥（PKCS1 或 PKCS8 PEM 格式）
  alipayPublicKey: string; // 支付宝公钥（PEM 格式）
  gateway?: string;
  notifyUrl?: string;
}

export function getAlipayConfig(): AlipayConfig {
  return {
    appId: Deno.env.get("ALIPAY_APP_ID") || "",
    privateKey: (Deno.env.get("ALIPAY_PRIVATE_KEY") || "").replace(/\\n/g, "\n"),
    alipayPublicKey: (Deno.env.get("ALIPAY_PUBLIC_KEY") || "").replace(/\\n/g, "\n"),
    gateway: Deno.env.get("ALIPAY_GATEWAY") || "https://openapi.alipay.com/gateway.do",
    notifyUrl: Deno.env.get("ALIPAY_NOTIFY_URL") || "",
  };
}

// --- 工具 ---
function sortParams(params: Record<string, string>): string {
  return Object.keys(params)
    .filter((k) => params[k] !== "" && params[k] !== undefined && k !== "sign")
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join("&");
}

function formatDate(d: Date): string {
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

// --- RSA2 签名 ---
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  let cleaned = pem
    .replace(/-----BEGIN (RSA )?PRIVATE KEY-----/g, "")
    .replace(/-----END (RSA )?PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));

  // 先尝试 PKCS8，失败则尝试 PKCS1（需要转换）
  try {
    return await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );
  } catch {
    throw new Error("私钥格式不正确，请使用 PKCS8 格式的 PEM 私钥");
  }
}

async function importPublicKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "spki",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}

async function rsaSign(content: string, privateKey: CryptoKey): Promise<string> {
  const encoded = new TextEncoder().encode(content);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", privateKey, encoded);
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}

async function rsaVerify(content: string, sign: string, publicKey: CryptoKey): Promise<boolean> {
  const encoded = new TextEncoder().encode(content);
  const signBytes = Uint8Array.from(atob(sign), (c) => c.charCodeAt(0));
  return await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, signBytes, encoded);
}

// --- 支付宝 API 调用 ---
export async function alipayRequest(
  config: AlipayConfig,
  method: string,
  bizContent: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const params: Record<string, string> = {
    app_id: config.appId,
    method,
    format: "JSON",
    charset: "utf-8",
    sign_type: "RSA2",
    timestamp: formatDate(new Date()),
    version: "1.0",
    biz_content: JSON.stringify(bizContent),
  };

  if (config.notifyUrl && method === "alipay.trade.precreate") {
    params.notify_url = config.notifyUrl;
  }

  const signContent = sortParams(params);
  const privateKey = await importPrivateKey(config.privateKey);
  params.sign = await rsaSign(signContent, privateKey);

  const formBody = Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join("&");

  const resp = await fetch(config.gateway!, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
    body: formBody,
  });

  return await resp.json();
}

// --- 验签（异步通知） ---
export async function verifyAlipayNotify(
  params: Record<string, string>,
  alipayPublicKey: string
): Promise<boolean> {
  const sign = params.sign;
  const signType = params.sign_type;
  if (!sign || signType !== "RSA2") return false;

  const filtered = { ...params };
  delete filtered.sign;
  delete filtered.sign_type;
  const content = sortParams(filtered);

  const publicKey = await importPublicKey(alipayPublicKey);
  return await rsaVerify(content, sign, publicKey);
}

// --- 预创建订单（当面付二维码） ---
export async function precreate(
  config: AlipayConfig,
  outTradeNo: string,
  totalAmount: string,
  subject: string
): Promise<{ qrCode: string | null; outTradeNo: string; error?: string }> {
  const result = await alipayRequest(config, "alipay.trade.precreate", {
    out_trade_no: outTradeNo,
    total_amount: totalAmount,
    subject,
  });

  const resp = result["alipay_trade_precreate_response"] as Record<string, unknown> | undefined;
  if (resp && resp["code"] === "10000") {
    return { qrCode: resp["qr_code"] as string, outTradeNo };
  }
  return {
    qrCode: null,
    outTradeNo,
    error: `${resp?.["code"]}: ${resp?.["sub_msg"] || resp?.["msg"]}`,
  };
}

// --- 查询订单状态 ---
export async function queryTrade(
  config: AlipayConfig,
  outTradeNo: string
): Promise<{ tradeStatus: string; tradeNo?: string; error?: string }> {
  const result = await alipayRequest(config, "alipay.trade.query", {
    out_trade_no: outTradeNo,
  });

  const resp = result["alipay_trade_query_response"] as Record<string, unknown> | undefined;
  if (resp && resp["code"] === "10000") {
    return {
      tradeStatus: resp["trade_status"] as string,
      tradeNo: resp["trade_no"] as string | undefined,
    };
  }
  return {
    tradeStatus: "UNKNOWN",
    error: `${resp?.["code"]}: ${resp?.["sub_msg"] || resp?.["msg"]}`,
  };
}
