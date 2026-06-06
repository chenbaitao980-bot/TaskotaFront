/**
 * 阿里云 RPC 风格 API 签名 + 调用工具
 * 文档：https://help.aliyun.com/document_detail/52974.html
 */

function encodeRfc3986(str: string): string {
  return encodeURIComponent(str)
    .replace(/\+/g, "%20")
    .replace(/\*/g, "%2A")
    .replace(/%7E/g, "~");
}

async function hmacSha1Base64(key: string, data: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(key);
  const dataBytes = new TextEncoder().encode(data);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, dataBytes);
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

/**
 * 调用阿里云 cloudpush.aliyuncs.com RPC 接口
 */
export async function callAliyunPush(
  accessKeyId: string,
  accessKeySecret: string,
  action: string,
  bizParams: Record<string, string>
): Promise<Record<string, unknown>> {
  const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const nonce = crypto.randomUUID().replace(/-/g, "");

  const allParams: Record<string, string> = {
    Format: "JSON",
    Version: "2016-08-01",
    AccessKeyId: accessKeyId,
    SignatureMethod: "HMAC-SHA1",
    Timestamp: timestamp,
    SignatureVersion: "1.0",
    SignatureNonce: nonce,
    Action: action,
    ...bizParams,
  };

  // 按字典序排列后编码
  const sortedKeys = Object.keys(allParams).sort();
  const canonicalQuery = sortedKeys
    .map((k) => `${encodeRfc3986(k)}=${encodeRfc3986(allParams[k])}`)
    .join("&");

  const stringToSign = `POST&%2F&${encodeRfc3986(canonicalQuery)}`;
  const signature = await hmacSha1Base64(accessKeySecret + "&", stringToSign);

  allParams["Signature"] = signature;

  const body = new URLSearchParams(allParams).toString();
  const resp = await fetch("https://cloudpush.aliyuncs.com/", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!resp.ok) {
    const text = await resp.text();
    console.error("[aliyun] API error:", resp.status, text);
    throw new Error(`Aliyun API ${resp.status}: ${text}`);
  }

  return resp.json();
}
