import { fail, route, str } from "@/lib/api";
import { query } from "@/lib/db";

export const POST = route({}, async ({ me, body }) => {
  const eventId = str(body.eventId, 40);
  if (!eventId) return fail("Momento inválido.");
  const ev = await query("SELECT 1 FROM events WHERE id = $1 AND official = TRUE", [eventId]);
  if (!ev.length) return fail("Momento inválido.");
  const del = await query("DELETE FROM attendance_intent WHERE person_id = $1 AND event_id = $2 RETURNING 1", [me.id, eventId]);
  if (!del.length) await query("INSERT INTO attendance_intent (person_id, event_id) VALUES ($1, $2)", [me.id, eventId]);
});
