const WXPUSHER_API = "https://wxpusher.zjiecode.com/api";

export async function sendWxPusherMessage(
  uid: string,
  title: string,
  content: string
): Promise<boolean> {
  const appToken = Deno.env.get("WXPUSHER_APP_TOKEN");
  if (!appToken) {
    console.error("[wxpusher] WXPUSHER_APP_TOKEN not set");
    return false;
  }

  try {
    const resp = await fetch(`${WXPUSHER_API}/send/message`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        appToken,
        content,
        summary: title,
        contentType: 1, // 1=text
        uids: [uid],
      }),
    });
    const data = await resp.json();
    if (data.code !== 1000) {
      console.error("[wxpusher] send failed:", data);
      return false;
    }
    return true;
  } catch (e) {
    console.error("[wxpusher] send error:", e);
    return false;
  }
}

export function getWxPusherQrUrl(appToken: string, extra: string): string {
  return `${WXPUSHER_API}/fun/create/qrcode?appToken=${appToken}&extra=${encodeURIComponent(extra)}`;
}
