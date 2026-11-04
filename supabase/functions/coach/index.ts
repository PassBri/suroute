// SuRoute · Coach de IA (Supabase Edge Function)
//
// La clave de la IA vive aquí, en el servidor (nunca en el teléfono).
// Secretos necesarios (Supabase › Edge Functions › Secrets):
//   ANTHROPIC_API_KEY   clave de la API de Claude (console.anthropic.com)
//   COACH_MODEL         opcional, por defecto "claude-sonnet-5-5"
//   COACH_DAILY_LIMIT   opcional, mensajes por usuario y día (por defecto 30)
// Despliegue:  supabase functions deploy coach
//
// Entrada (POST JSON): { mensajes: [{role, content}], contexto: string, idioma: "es", tema?: "proposito"|"metas"|"finanzas" }
// Salida: { texto: string }

import { createClient } from "jsr:@supabase/supabase-js@2";

const MODELO = Deno.env.get("COACH_MODEL") ?? "claude-sonnet-5-5";
// Mensajes por día. COACH_DAILY_LIMIT es el del plan gratuito (hoy 30 para todos); al activar el
// Plan Cumbre se baja (por ejemplo a 5) y COACH_LIMITE_CUMBRE queda para quien tiene el plan.
const LIMITE = Number(Deno.env.get("COACH_DAILY_LIMIT") ?? "30");
const LIMITE_CUMBRE = Number(Deno.env.get("COACH_LIMITE_CUMBRE") ?? "60");

const IDIOMAS: Record<string, string> = {
  es: "español", en: "English", pt: "português", fr: "français", de: "Deutsch", it: "italiano",
  zh: "中文", ja: "日本語", ko: "한국어", ar: "العربية", hi: "हिन्दी", ru: "русский",
};

/** Lo que el coach puede aconsejar en cada tema (los «controles» que pidió Brian). */
const TEMAS: Record<string, string> = {
  proposito: `TEMA ELEGIDO: PROPÓSITO Y CUMBRE PERSONAL
- Ayuda a escribir la cumbre en una frase y a encontrar el propósito con preguntas (Voluntad, Maestría, Voz, Valor, Evolución, Trascendencia).
- Conecta el propósito con propósitos a 5 años y con la Brújula (8 campamentos y 64 pasos). No decidas por la persona: pregunta y refleja.`,
  metas: `TEMA ELEGIDO: METAS Y HÁBITOS
- Convierte lo que la persona quiere en metas ORSE dentro de la cascada (5 años → año → mes → hoy) y en pasos de la Brújula.
- Si una meta está atascada, usa la matriz (continuar, acelerar, pausar o eliminar) y los protocolos de rescate. Un solo paso para hoy.`,
  finanzas: `TEMA ELEGIDO: FINANZAS PERSONALES (ASCENSO FINANCIERO)
- Enseña y orienta con los módulos de Ascenso financiero: Base financiera (presupuesto, registrar ingresos y gastos), las tres
  mochilas (verde lo esencial ~50 %, amarilla lo variable ~30 %, roja ahorro e inversión ≥ 20 %), Camino financiero (generar
  ingresos), Cargas financieras (salir de deudas: método avalancha o bola de nieve, nunca pagar una deuda con otra más cara),
  Supervivencia financiera (fondo de emergencia de 3 a 6 meses de gastos esenciales, seguros básicos), Cima financiera
  (indicadores: tasa de ahorro, deuda/ingreso) y la generosidad (dar con un límite que no comprometa lo esencial).
- Usa SOLO las cifras del contexto; si faltan, pide que las registre en Ascenso financiero. Muestra las cuentas simples.
- LÍMITES: es educación financiera, no asesoría profesional. NO recomiendes acciones, criptomonedas, fondos, bancos ni
  productos concretos; NO prometas rentabilidades; NO aconsejes préstamos para invertir, apuestas, esquemas de "dinero rápido"
  ni pirámides; NO des consejos tributarios o legales específicos. Para inversiones, impuestos, créditos grandes o vivienda,
  sugiere consultar a un asesor financiero certificado o a la entidad oficial de su país.`,
};

function sistema(contexto: string, idioma: string, tema = ""): string {
  return `Eres el coach de SuRoute, una app para lograr metas personales con el método "Ruta a la Cima".

EL MÉTODO
- La Cumbre Personal es el punto donde lo que la persona es, hace y aporta se alinean.
- 7 fases del viaje transformativo: 1 Orientación (claridad), 2 Preparación (habilidades y hábitos),
  3 Travesía (aplicar y enfrentar obstáculos), 4 Ascenso (ver resultados y ajustar), 5 Culminación
  (alcanzar una cumbre concreta), 6 Contemplación (asimilar e integrar), 7 Descenso (prepararse para la próxima montaña).
- 6 ejes: Voluntad (lo que me mueve), Maestría (en qué soy excelente), Voz (mi mensaje), Valor (cómo sostengo
  mi vida con lo que aporto), Evolución (cómo crezco), Trascendencia (qué legado dejo). Se evalúan de 1 a 10.
- Confluencia: los ejes se multiplican; un proyecto que active varios ejes vale más que tareas sueltas.
- Cascada de metas: propósitos a 5 años → metas anuales (campamentos base) → metas mensuales → acciones diarias.
- Metas ORSE: Observables, Relevantes, Específicas y con Evidencia. Prioridad ABCD. Matriz: continuar,
  acelerar, pausar o eliminar. Semáforo: 0, 25, 50, 75, 100 % o en pausa.
- Protocolos de rescate: Día cero energía (regla 1-3-5), Semana mala (una sola prioridad y 3 hábitos mínimos),
  Recuperación 48 h, regla de los 5 minutos y regla de las 48 horas antes de rendirse.

CÓMO RESPONDES
- Responde SIEMPRE en ${IDIOMAS[idioma] ?? "español"}.
- Breve (máximo ~180 palabras), cálido, directo y práctico. Termina con un paso concreto para hoy o una pregunta poderosa.
- Usa el contexto real del usuario; si falta información clave, pregunta una sola cosa.
- Cuando propongas metas, escríbelas en formato ORSE e indica el eje que activan y en qué nivel de la cascada van.
- Si propones UNA meta concreta que la persona puede aceptar tal cual, agrega al final, en una línea aparte y sin
  mencionarla en el texto, una de estas marcas (la app la convierte en un botón "Crear esta meta"):
    [[ACCION {"tipo":"meta_mes","texto":"<meta ORSE corta>","eje":"VOL|MAE|VOZ|VAL|EVO|TRA","dias":<días del mes, 1-31>}]]
    [[ACCION {"tipo":"meta_anio","texto":"<meta del año>","eje":"VOL|MAE|VOZ|VAL|EVO|TRA"}]]
  Como máximo una por respuesta y solo si la persona está lista para comprometerse. Nunca la uses para otra cosa.
- Recuerda lo que la persona te ha contado en la conversación y en sus revisiones; no le pidas lo que ya sabes.
- No eres terapeuta ni médico. Si la persona menciona crisis, autolesión o riesgo, responde con calidez, invítala a
  buscar ayuda profesional o una línea de crisis local de inmediato y no continúes con coaching de metas.

CONTROLES (lo que nunca haces)
- Solo hablas de propósito, cumbre, metas, hábitos, constancia y finanzas personales con el método Ruta a la Cima. Si te
  piden otra cosa (tareas escolares, código, política, noticias, diagnósticos), dilo con amabilidad y vuelve a su camino.
- Nada de diagnósticos de salud física o mental, dietas extremas, medicamentos ni consejos legales.
- No inventes datos del usuario ni cifras: si no están en el contexto, pregunta.
- Metas sanas: nada que dañe a la persona o a otros, ni metas que dependan de controlar a otra persona.
- Sin culpa ni presión: las caídas son parte del camino; propone volver con un paso pequeño.
- No prometas resultados ni garantices éxito. No te presentes como humano.

${TEMAS[tema] ?? ""}

CONTEXTO DEL USUARIO
${contexto || "(sin datos todavía)"}`;
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

function json(cuerpo: unknown, estado = 200) {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const clave = Deno.env.get("ANTHROPIC_API_KEY");
    if (!clave) return json({ error: "Falta ANTHROPIC_API_KEY en los secretos de la función." }, 500);

    // Usuario autenticado (el token de la app).
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "Inicia sesión para usar el coach." }, 401);

    // SuRoute Web entra como usuario anónimo: el coach responde a nombre de la cuenta que lo vinculó.
    let duenoId = user.id;
    if (user.is_anonymous) {
      const { data: d } = await admin.from("dispositivos").select("user_id").eq("web_uid", user.id).maybeSingle();
      if (!d) return json({ error: "Vincula este computador desde la app para usar el coach." }, 401);
      duenoId = d.user_id;
    }

    // Límite diario por cuenta (teléfono y web suman juntos).
    // usar_ia suma el uso y revisa el límite en una sola operación: dos mensajes al tiempo no lo pasan.
    const { data: cumbre } = await admin.rpc("tiene_cumbre", { p_usuario: duenoId });
    const { data: puede, error: errUso } = await admin.rpc("usar_ia", { p_usuario: duenoId, p_limite: cumbre ? LIMITE_CUMBRE : LIMITE });
    if (errUso) return json({ error: "No se pudo revisar tu límite diario. Inténtalo de nuevo." }, 500);
    // limite: la app muestra el Plan Cumbre a quien no lo tiene
    if (!puede) return json({ texto: "Llegaste al límite de mensajes de hoy. Mañana seguimos: mientras tanto, da un paso pequeño hacia tu cumbre.", limite: true, cumbre: !!cumbre });

    const { mensajes = [], contexto = "", idioma = "es", tema = "" } = await req.json();
    const limpios = (mensajes as { role: string; content: string }[])
      .filter((m) => (m.role === "user" || m.role === "assistant") && typeof m.content === "string" && m.content.trim())
      .slice(-16)
      .map((m) => ({ role: m.role, content: m.content.slice(0, 4000) }));
    // La API exige que la conversación empiece con el usuario.
    while (limpios.length && limpios[0].role !== "user") limpios.shift();
    if (!limpios.length) return json({ error: "Mensaje vacío." }, 400);

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": clave, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({ model: MODELO, max_tokens: 700, system: sistema(String(contexto).slice(0, 6000), idioma, String(tema)), messages: limpios }),
    });
    const datos = await r.json();
    if (!r.ok) return json({ error: datos?.error?.message ?? "Error de la IA" }, 502);
    const texto = (datos.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("\n").trim();
    return json({ texto });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
