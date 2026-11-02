// SuRoute · Fogatas en vivo (Supabase Edge Function)
//
// Entrega el permiso para entrar a una fogata en LiveKit y lleva su registro.
// Secretos necesarios (Supabase › Edge Functions › Secrets), del proyecto de cloud.livekit.io:
//   LIVEKIT_URL         wss://<su-proyecto>.livekit.cloud
//   LIVEKIT_API_KEY     la API key
//   LIVEKIT_API_SECRET  el API secret
// Despliegue:  supabase functions deploy fogata
//
// Entrada (POST JSON) según "accion":
//   encender { titulo, eje }   enciende una fogata nueva (moderadores y coaches verificados)
//   entrar   { id }            permiso para mirar (o para transmitir, si es suya)
//   latido   { id, personas }  quien transmite avisa que sigue ahí (cada minuto)
//   apagar   { id }            quien la encendió la apaga; un moderador la corta
// Salida: { fogata, url, token } o { ok } o { error }

import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (cuerpo: unknown, estado = 200) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors, "Content-Type": "application/json" } });

const URL_LK = Deno.env.get("LIVEKIT_URL") ?? "";
const CLAVE = Deno.env.get("LIVEKIT_API_KEY") ?? "";
const SECRETO = Deno.env.get("LIVEKIT_API_SECRET") ?? "";
const EJES = ["VOL", "MAE", "VOZ", "VAL", "EVO", "TRA", "CAM"];

const b64url = (b: Uint8Array | string) => {
  const bytes = typeof b === "string" ? new TextEncoder().encode(b) : b;
  let s = ""; for (const x of bytes) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

/** Permiso de LiveKit: un JWT HS256 firmado con el secreto del proyecto. */
async function permiso(identidad: string, nombre: string, video: Record<string, unknown>, segundos = 6 * 3600, metadata = "") {
  const ahora = Math.floor(Date.now() / 1000);
  const cuerpo = { iss: CLAVE, sub: identidad, jti: identidad, name: nombre, nbf: ahora - 10, exp: ahora + segundos, video, metadata };
  const datos = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" })) + "." + b64url(JSON.stringify(cuerpo));
  const llave = await crypto.subtle.importKey("raw", new TextEncoder().encode(SECRETO), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const firma = new Uint8Array(await crypto.subtle.sign("HMAC", llave, new TextEncoder().encode(datos)));
  return datos + "." + b64url(firma);
}

/** Cierra la sala en LiveKit: todos salen al instante (apagar o cortar). */
async function cerrarSala(sala: string) {
  try {
    const t = await permiso("suroute-servidor", "SuRoute", { roomCreate: true, room: sala }, 120);
    await fetch(URL_LK.replace(/^ws/, "http").replace(/\/$/, "") + "/twirp/livekit.RoomService/DeleteRoom", {
      method: "POST", headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/json" }, body: JSON.stringify({ room: sala }),
    });
  } catch (e) { console.error(e); }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!URL_LK || !CLAVE || !SECRETO) return json({ error: "Falta configurar LiveKit (LIVEKIT_URL, LIVEKIT_API_KEY y LIVEKIT_API_SECRET) en los secretos de la función." }, 500);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "Inicia sesión para entrar a la fogata." }, 401);
    // SuRoute Web entra como usuario anónimo: actúa a nombre de la cuenta que lo vinculó
    let yo = user.id;
    if (user.is_anonymous) {
      const { data: d } = await admin.from("dispositivos").select("user_id").eq("web_uid", user.id).maybeSingle();
      if (!d) return json({ error: "Vincula este computador desde la app para entrar a las fogatas." }, 401);
      yo = d.user_id;
    }
    const { data: perfil } = await admin.from("profiles").select("nombre,username,avatar_url").eq("id", yo).maybeSingle();
    const nombre = perfil?.nombre || perfil?.username || "Senderista";
    const meta = JSON.stringify({ avatar: perfil?.avatar_url || "", usuario: perfil?.username || "" });

    const cuerpo = await req.json().catch(() => ({}));
    const accion = String(cuerpo.accion ?? "");

    if (accion === "encender") {
      const { data: puede } = await admin.rpc("puede_encender", { p_usuario: yo });
      if (!puede) return json({ error: "Por ahora encienden fogatas los coaches verificados. Muy pronto podrás encender la tuya." }, 403);
      const titulo = String(cuerpo.titulo ?? "").trim().slice(0, 90);
      if (titulo.length < 3) return json({ error: "Escribe de qué hablarás en la fogata." }, 400);
      const eje = EJES.includes(cuerpo.eje) ? cuerpo.eje : null;
      // Una sola fogata encendida por persona: la anterior se apaga
      const { data: viejas } = await admin.from("fogatas").select("id,sala").eq("user_id", yo).eq("estado", "EN_VIVO");
      for (const v of viejas ?? []) { await admin.from("fogatas").update({ estado: "TERMINADA", termino_at: new Date().toISOString() }).eq("id", v.id); cerrarSala(v.sala); }
      const { data: f, error } = await admin.from("fogatas").insert({ user_id: yo, titulo, eje }).select("*").single();
      if (error) throw error;
      const t = await permiso(yo, nombre, { room: f.sala, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true }, 6 * 3600, meta);
      return json({ fogata: f, url: URL_LK, token: t, anfitrion: true });
    }

    const id = String(cuerpo.id ?? "");
    const { data: f } = await admin.from("fogatas").select("*").eq("id", id).maybeSingle();
    if (!f) return json({ error: "Esa fogata ya no existe." }, 404);
    const mia = f.user_id === yo;

    if (accion === "entrar") {
      if (f.estado !== "EN_VIVO") return json({ error: "Esta fogata ya se apagó.", apagada: true }, 410);
      const t = await permiso(yo, nombre, { room: f.sala, roomJoin: true, canPublish: mia, canSubscribe: true, canPublishData: true }, 6 * 3600, meta);
      return json({ fogata: f, url: URL_LK, token: t, anfitrion: mia });
    }
    if (accion === "latido") {
      if (!mia) return json({ error: "Solo quien la encendió" }, 403);
      const personas = Math.max(0, Math.min(100000, Number(cuerpo.personas) || 0));
      await admin.from("fogatas").update({ latido_at: new Date().toISOString(), pico: Math.max(f.pico ?? 0, personas) }).eq("id", f.id);
      return json({ ok: true });
    }
    if (accion === "apagar") {
      const { data: modera } = await admin.from("moderadores").select("user_id").eq("user_id", yo).maybeSingle();
      if (!mia && !modera) return json({ error: "Solo quien la encendió puede apagarla." }, 403);
      await admin.from("fogatas").update({ estado: mia ? "TERMINADA" : "CORTADA", termino_at: new Date().toISOString() }).eq("id", f.id);
      await cerrarSala(f.sala);
      return json({ ok: true });
    }
    return json({ error: "Acción desconocida" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "No se pudo completar. Inténtalo de nuevo." }, 500);
  }
});
