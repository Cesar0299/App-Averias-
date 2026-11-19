import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization") || "";
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return reply({ error: "Faltan secretos de Supabase en la función" }, 500);
  const caller = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: { user }, error: authError } = await caller.auth.getUser();
  if (authError || !user) return reply({ error: "No autenticado" }, 401);
  const admin = createClient(url, service);
  const { data: profile } = await admin.from("profiles").select("role,active").eq("id", user.id).single();
  if (!profile || profile.role !== "supervisor" || !profile.active) return reply({ error: "Solo un supervisor puede crear usuarios" }, 403);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply({ error: "JSON inválido" }, 400); }
  const username = String(body.username || "").trim().toLowerCase();
  const full_name = String(body.full_name || "").trim();
  const password = String(body.password || "");
  const role = body.role === "supervisor" ? "supervisor" : "technician";
  if (!/^[a-z0-9._-]{3,32}$/.test(username) || !full_name || password.length < 8) {
    return reply({ error: "Verifica nombre, usuario (3-32 caracteres) y contraseña (mínimo 8)" }, 400);
  }
  const email = username + "@informesmax.login";
  const { data, error } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name, username },
  });
  if (error) return reply({ error: error.message }, 400);
  const { error: insertError } = await admin.from("profiles").insert({ id: data.user.id, full_name, username, role });
  if (insertError) {
    await admin.auth.admin.deleteUser(data.user.id);
    return reply({ error: insertError.message }, 400);
  }
  return reply({ ok: true, username });
});