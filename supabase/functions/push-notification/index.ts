import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

// Cache OAuth2 token across invocations (Deno isolate stays warm)
let cachedToken: string | null = null;
let tokenExpiry = 0;

// Get a short-lived OAuth2 access token from a service account JSON
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now < tokenExpiry - 60) {
    return cachedToken;
  }

  const header = { alg: "RS256", typ: "JWT" };
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

  cachedToken = tokenData.access_token;
  tokenExpiry = now + 3600;
  return cachedToken!;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();

    // Supabase Database Webhooks send: { type, table, record, schema, old_record }
    const record = payload.record;
    if (!record || !record.conversation_id || !record.sender_id) {
      console.error("Invalid payload - missing record fields");
      return new Response(
        JSON.stringify({ error: "Invalid payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("Received message for conversation:", record.conversation_id);

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
        JSON.stringify({ error: "Conversation not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const recipientId =
      conversation.user_a === record.sender_id
        ? conversation.user_b
        : conversation.user_a;

    // Fetch device tokens and sender profile in parallel
    const [{ data: tokens, error: tokenError }, { data: senderProfile }] =
      await Promise.all([
        supabase
          .from("device_tokens")
          .select("token")
          .eq("user_id", recipientId),
        supabase
          .from("profiles")
          .select("player_name")
          .eq("user_id", record.sender_id)
          .single(),
      ]);

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
    const projectId = serviceAccount.project_id;

    console.log("Sending to", tokens.length, "device(s)");

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
                  notification: {
                    channel_id: "messages",
                  },
                },
              },
            }),
          }
        );
        const result = await res.json();

        // Clean up stale tokens that FCM reports as unregistered
        if (result.error) {
          const details = result.error.details ?? [];
          const isStale =
            details.some(
              (d: { errorCode?: string }) => d.errorCode === "UNREGISTERED"
            ) || result.error.code === 404;
          if (isStale) {
            console.log("Removing stale token for recipient:", recipientId);
            await supabase
              .from("device_tokens")
              .delete()
              .eq("token", t.token);
          } else {
            console.error("FCM error for token:", JSON.stringify(result.error));
          }
        }

        return result;
      })
    );

    return new Response(JSON.stringify(results), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
