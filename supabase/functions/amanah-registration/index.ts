import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
const AUTH_EMAIL_DOMAIN = "members.amanah.invalid";

async function hashCode(code: string) {
  const bytes = new TextEncoder().encode(code.trim().toUpperCase());
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
function makeCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  return "AM-" + [...bytes].map((b) => alphabet[b % alphabet.length]).join("");
}
function internalEmail(username: string) {
  return username.toLowerCase() + "@" + AUTH_EMAIL_DOMAIN;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST required" }, 405);
  try {
    const body = await req.json();
    const action = String(body.action || "");

    if (action === "create_batch") {
      const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
      if (!token) return json({ error: "Admin sign-in required." }, 401);
      const { data: authData, error: authError } = await admin.auth.getUser(token);
      if (authError || !authData.user) return json({ error: "Admin session is invalid." }, 401);
      const { data: profile } = await admin.from("profiles").select("role").eq("id", authData.user.id).maybeSingle();
      if (profile?.role !== "administrator") return json({ error: "Administrator access required." }, 403);

      const count = Math.max(1, Math.min(100, Math.floor(Number(body.count) || 0)));
      const days = Math.max(1, Math.min(365, Math.floor(Number(body.expiry_days) || 30)));
      const batchId = crypto.randomUUID();
      const expiresAt = new Date(Date.now() + days * 86400000).toISOString();
      const codes: string[] = [];
      for (let i = 0; i < count; i++) codes.push(makeCode());
      const rows = await Promise.all(codes.map(async (code) => ({
        code_hash: await hashCode(code), batch_id: batchId,
        created_by: authData.user.id, expires_at: expiresAt,
      })));
      const { error } = await admin.from("activation_codes").insert(rows);
      if (error) return json({ error: "Could not save activation codes: " + error.message }, 500);
      return json({ batch_id: batchId, expires_at: expiresAt, codes });
    }

    if (action === "register") {
      const username = String(body.username || "").trim().toLowerCase();
      const phone = String(body.phone || "").trim();
      const password = String(body.password || "");
      const fullName = String(body.full_name || "").trim();
      const sponsorCode = String(body.sponsor_code || "").trim().toUpperCase();
      const activationCode = String(body.activation_code || "").trim().toUpperCase();

      if (!/^[a-z0-9._-]{4,24}$/.test(username)) return json({ error: "Username must be 4–24 characters: letters, numbers, dot, dash or underscore." }, 400);
      if (!/^\+[1-9]\d{7,14}$/.test(phone)) return json({ error: "Enter mobile number in international format, e.g. +639171234567." }, 400);
      if (password.length < 8) return json({ error: "Password must be at least 8 characters." }, 400);
      if (fullName.length < 2 || !activationCode) return json({ error: "Full name and activation code are required." }, 400);

      const { data: duplicateUsername } = await admin.from("profiles").select("id").ilike("username", username).maybeSingle();
      if (duplicateUsername) return json({ error: "That username is already taken." }, 409);
      const { data: duplicatePhone } = await admin.from("profiles").select("id").eq("phone", phone).maybeSingle();
      if (duplicatePhone) return json({ error: "That mobile number is already registered. Contact the administrator if you need help." }, 409);

      let sponsorId: string | null = null;
      if (sponsorCode) {
        const { data: sponsor } = await admin.from("profiles").select("id").eq("member_code", sponsorCode).eq("is_active", true).maybeSingle();
        if (!sponsor) return json({ error: "Active sponsor code not found. Check the code with your sponsor." }, 400);
        sponsorId = sponsor.id;
      }

      const codeHash = await hashCode(activationCode);
      const { data: validCode } = await admin.from("activation_codes").select("id")
        .eq("code_hash", codeHash).is("used_at", null).gt("expires_at", new Date().toISOString()).maybeSingle();
      if (!validCode) return json({ error: "Activation code is invalid, expired, or already used." }, 400);

      // Supabase Auth requires an email or phone identity. This private .invalid
      // address is never emailed; the member signs in using their AMANAH username.
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: internalEmail(username),
        email_confirm: true,
        password,
        user_metadata: {
          full_name: fullName, phone, username,
          sponsor_code: sponsorCode || null,
        },
      });
      if (createError || !created.user) return json({ error: createError?.message || "Could not create account." }, 400);

      // Consume the activation code only after Auth creation. The SQL update is
      // atomic; if another request used the code first, delete this new Auth user.
      const { data: consumed, error: consumeError } = await admin.rpc("consume_amanah_activation_code", {
        p_code_hash: codeHash, p_user_id: created.user.id,
      });
      if (consumeError || consumed !== true) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: "This activation code was just used or expired. Please request another code." }, 409);
      }
      // Keep the validated sponsor relationship explicit and correct.
      if (sponsorId) {
        const { error: sponsorUpdateError } = await admin.from("profiles").update({ sponsor_id: sponsorId }).eq("id", created.user.id);
        if (sponsorUpdateError) {
          await admin.auth.admin.deleteUser(created.user.id);
          return json({ error: "Account setup could not be completed. Please contact the administrator." }, 500);
        }
      }
      return json({
        success: true, username,
        member_code: "AM-" + created.user.id.replaceAll("-", "").slice(0, 8).toUpperCase(),
      });
    }

    if (action === "login") {
      const username = String(body.username || "").trim().toLowerCase();
      const password = String(body.password || "");
      if (!/^[a-z0-9._-]{4,24}$/.test(username) || !password) return json({ error: "Username or password is incorrect." }, 401);
      const { data: profile, error: lookupError } = await admin.from("profiles")
        .select("id,is_active").ilike("username", username).maybeSingle();
      if (lookupError || !profile) return json({ error: "Username or password is incorrect." }, 401);
      if (!profile.is_active) return json({ error: "This account is inactive. Contact the administrator." }, 403);
      const publicClient = createClient(url, anonKey, { auth: { persistSession: false } });
      const { data, error } = await publicClient.auth.signInWithPassword({
        email: internalEmail(username), password,
      });
      if (error || !data.session) return json({ error: "Username or password is incorrect." }, 401);
      return json({ session: data.session, user: data.user });
    }
    return json({ error: "Unknown action." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected server error." }, 500);
  }
});
