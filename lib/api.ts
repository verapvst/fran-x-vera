import { NextResponse, type NextRequest } from "next/server";
import { getUser, type Person } from "./auth";
import { query } from "./db";

type EventRow = {
  id: string; day: string; start_time: string | null; end_time: string | null; all_day: boolean;
  title: string; place: string | null; note: string | null; rule_text: string | null; official: boolean;
};

/** Estado que o cliente pode ver. Participantes nunca recebem dados de admin. */
export async function buildState(me: Person | null) {
  const events = (await query<EventRow>("SELECT * FROM events ORDER BY sort_order, id")).map((e) => ({
    id: e.id, day: e.day, start: e.start_time ?? undefined, end: e.end_time ?? undefined, allDay: e.all_day,
    title: e.title, place: e.place ?? undefined, note: e.note ?? undefined, rule: e.rule_text ?? undefined,
    official: e.official,
  }));
  if (!me) return { me: null, events, myRsvp: [], challenges: [], people: [] };

  const myRsvp = (await query<{ event_id: string }>("SELECT event_id FROM attendance_intent WHERE person_id = $1", [me.id])).map((r) => r.event_id);
  const base = { me: { id: me.id, name: me.name, role: me.role, inPortugal: me.in_portugal }, events, myRsvp };
  if (me.role !== "admin") return { ...base, challenges: [], people: [] };

  const challenges = await query<{ id: string; text: string; points: number }>("SELECT id, text, points FROM challenges ORDER BY created_at, id");
  const people = await query<{ id: string; name: string; code: string; role: string; in_portugal: boolean; moments: number }>(
    `SELECT p.id, p.name, p.code, p.role, p.in_portugal, COUNT(a.event_id)::int AS moments
       FROM people p LEFT JOIN attendance_intent a ON a.person_id = p.id
      GROUP BY p.id ORDER BY p.created_at, p.name`,
  );
  return {
    ...base,
    challenges,
    people: people.map((p) => ({ id: p.id, name: p.name, code: p.code, role: p.role, inPortugal: p.in_portugal, moments: p.moments })),
  };
}

export const fail = (message: string, status = 400) => NextResponse.json({ error: message }, { status });

type Handler = (ctx: { req: NextRequest; me: Person; body: Record<string, unknown> }) => Promise<NextResponse | void>;

/** Verifica sessão (e admin, se pedido), corre o handler e devolve o estado atualizado. */
export function route(opts: { admin?: boolean }, fn: Handler) {
  return async (req: NextRequest) => {
    try {
      const me = await getUser(req);
      if (!me) return fail("Sem sessão.", 401);
      if (opts.admin && me.role !== "admin") return fail("Sem permissão.", 403);
      let body: Record<string, unknown> = {};
      if (req.method !== "GET" && req.method !== "DELETE") {
        try { body = await req.json(); } catch { return fail("Pedido inválido."); }
      }
      const out = await fn({ req, me, body });
      if (out) return out;
      const fresh = await getUser(req);
      return NextResponse.json(await buildState(fresh));
    } catch (e) {
      console.error(e);
      return fail("Erro no servidor.", 500);
    }
  };
}

export const str = (v: unknown, max: number): string | null =>
  typeof v === "string" && v.trim() && v.length <= max ? v.trim() : null;
export const optStr = (v: unknown, max: number): string | null | undefined =>
  v == null || v === "" ? null : typeof v === "string" && v.length <= max ? v.trim() : undefined;
export const timeOk = (v: unknown) => v == null || v === "" || (typeof v === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(v));
