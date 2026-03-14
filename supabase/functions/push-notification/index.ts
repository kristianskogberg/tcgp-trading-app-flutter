import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Get a short-lived OAuth2 access token from a service account JSON
async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const unsignedToken = `${encode(header)}.${encode(claimSet)}`;

  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedToken = `${unsignedToken}.${btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signedToken}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Received payload:", JSON.stringify(payload));

    // Supabase Database Webhooks send: { type, table, record, schema, old_record }
    const record = payload.record;
    if (!record || !record.conversation_id || !record.sender_id) {
      console.error("Invalid payload - missing record fields");
      return new Response(
        JSON.stringify({ error: "Invalid payload", payload }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get the conversation to find the recipient
    const { data: conversation, error: convError } = await supabase
      .from("conversations")
      .select("user_a, user_b")
      .eq("id", record.conversation_id)
      .single();

    if (convError || !conversation) {
      console.error("Conversation error:", convError);
      return new Response(
        JSON.stringify({ error: "Conversation not found", detail: convError }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const recipientId =
      conversation.user_a === record.sender_id
        ? conversation.user_b
        : conversation.user_a;

    // Get recipient's device tokens
    const { data: tokens, error: tokenError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", recipientId);

    if (tokenError) {
      console.error("Token fetch error:", tokenError);
    }

    if (!tokens || tokens.length === 0) {
      console.log("No device tokens for recipient:", recipientId);
      return new Response(JSON.stringify({ message: "No tokens found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get sender's profile name
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("player_name")
      .eq("user_id", record.sender_id)
      .single();

    const senderName = senderProfile?.player_name ?? "Someone";

    // Format notification body
    let body: string;
    const content = record.content;
    if (content.startsWith("TRADE:")) {
      body = `${senderName} sent you a trade proposal`;
    } else if (content.startsWith("TRADERESULT:accepted:")) {
      body = `${senderName} accepted your trade!`;
    } else if (content.startsWith("TRADERESULT:denied:")) {
      body = `${senderName} denied your trade`;
    } else if (content.startsWith("FRIENDID:")) {
      body = `${senderName} shared their Friend ID`;
    } else {
      const text = content.length > 80 ? content.substring(0, 80) + "..." : content;
      body = `${senderName}: ${text}`;
    }

    // Get FCM v1 access token
    const accessToken = await getAccessToken();
    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const projectId = serviceAccount.project_id;

    console.log("Sending to", tokens.length, "device(s) for project:", projectId);

    // Send to each device token
    const results = await Promise.all(
      tokens.map(async (t: { token: string }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                notification: {
                  title: "Pocket Trading",
                  body: body,
                },
                data: {
                  conversation_id: record.conversation_id,
                  sender_id: record.sender_id,
                },
                android: {
                  priority: "high",
                },
              },
            }),
          }
        );
        const result = await res.json();
        console.log("FCM response:", JSON.stringify(result));
        return result;
      })
    );

    return new Response(JSON.stringify(results), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Function error:", error);
    return new Response(
      JSON.stringify({ error: String(error), stack: (error as Error).stack }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
