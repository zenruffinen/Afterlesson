// Grünbuch Cloud — Push-Funktion
// Wird vom Datenbank-Webhook bei jedem neuen Paket (packages INSERT)
// und jeder neuen Mitteilung (messages INSERT) aufgerufen und schickt
// dem Schüler eine Apple-Push-Nachricht.
// Secrets: APNS_TEAM_ID, APNS_KEY_ID, APNS_P8 (Inhalt der .p8-Datei),
// optional APNS_SANDBOX ("true" für Entwicklungs-Builds).

import { createClient } from "npm:@supabase/supabase-js@2";

const TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const P8 = Deno.env.get("APNS_P8") ?? "";
const BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.hansruffin.AfterLesson";
const SANDBOX = (Deno.env.get("APNS_SANDBOX") ?? "true") === "true";

function b64url(data: string): string {
  return btoa(data).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJWT(): Promise<string> {
  const pem = P8
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const header = b64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) }));
  const input = `${header}.${claims}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)),
  );
  return `${input}.${b64url(String.fromCharCode(...sig))}`;
}

Deno.serve(async (req) => {
  const payload = await req.json();
  const record = payload?.record;
  if (!record?.student_id) {
    return new Response("kein Datensatz", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", record.student_id);
  console.log(`Geräte-Tokens gefunden: ${tokens?.length ?? 0}`);
  if (!tokens || tokens.length === 0) {
    return new Response("keine Geraete registriert", { status: 200 });
  }

  const jwt = await apnsJWT();
  const host = SANDBOX ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";

  // Mitteilung oder Lernpaket? Der Webhook verrät die Tabelle.
  let alertTitle = "Neues von deinem Pro";
  let alertBody = record.title && record.title.length > 0 ? record.title : "Ein neues Lernpaket wartet auf dich.";
  if (payload?.table === "messages") {
    alertTitle = "Mitteilung von deinem Pro";
    const body = (record.body ?? "").trim();
    alertBody = body.length > 120 ? body.slice(0, 117) + "…" : (body || "Du hast eine neue Mitteilung.");
  }
  const push = {
    aps: {
      alert: { title: alertTitle, body: alertBody },
      sound: "default",
      badge: 1,
    },
  };

  const results: string[] = [];
  for (const row of tokens) {
    const res = await fetch(`${host}/3/device/${row.token}`, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(push),
    });
    const body = await res.text();
    results.push(`${row.token.slice(0, 8)}...: ${res.status} ${body}`);
  }
  console.log("APNs-Antworten:", results.join(" | "));
  return new Response(results.join("\n"), { status: 200 });
});
