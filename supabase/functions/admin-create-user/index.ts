import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
Deno.serve(async (req) => {
 if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
 const auth = req.headers.get("Authorization") || "";
 const url = Deno.env.get("SUPABASE_URL")!;
 const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
 const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const caller = createClient(url, anon, { global: { headers: { Authorization: auth } } });
 const { data: { user }, error: authError } = await caller.auth.getUser();
 if (authError || !user) return Response.json({ error: "No autenticado" }, { status: 401 });
 const admin = createClient(url, service);
 const { data: profile } = await admin.from("profiles").select("role,active").eq("id", user.id).single();
 if (!profile || profile.role !== "supervisor" || !profile.active) return Response.json({ error: "Solo un supervisor puede crear usuarios" }, { status: 403 });
 const body = await req.json();
 const username = String(body.username || "").trim().toLowerCase();
 const full_name = String(body.full_name || "").trim();
 const password = String(body.password || "");
 const role = body.role === "supervisor" ? "supervisor" : "technician";
 if (!/^[a-z0-9._-]{3,32}$/.test(username) || !full_name || password.length < 8) return Response.json({ error: "Verifica nombre, usuario (3-32 caracteres) y contraseña (mínimo 8)" }, { status: 400 });
 const email = username + "@informesmax.login";
 const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name, username } });
 if (error) return Response.json({ error: error.message }, { status: 400 });
 const { error: insertError } = await admin.from("profiles").insert({ id: data.user.id, full_name, username, role });
 if (insertError) { await admin.auth.admin.deleteUser(data.user.id); return Response.json({ error: insertError.message }, { status: 400 }); }
 return Response.json({ ok: true, username });
});