import { randomUUID } from "node:crypto";
import { fail, optStr, route, str, timeOk } from "@/lib/api";
import { query } from "@/lib/db";

const DAYS = ["qui", "sex", "sab", "dom"];

export const POST = route({ admin: true }, async ({ body }) => {
  const title = str(body.title, 80);
  const place = optStr(body.place, 80), note = optStr(body.note, 300), rule = optStr(body.rule, 120);
  if (!title || typeof body.day !== "string" || !DAYS.includes(body.day)) return fail("Dados do momento inválidos.");
  if (place === undefined || note === undefined || rule === undefined) return fail("Texto demasiado longo.");
  if (!timeOk(body.start) || !timeOk(body.end)) return fail("Hora inválida. Usa o formato 19:00.");
  const id = typeof body.id === "string" && body.id ? body.id : randomUUID().slice(0, 8);
  const allDay = body.allDay === true;
  const start = allDay ? null : (body.start || null), end = allDay ? null : (body.end || null);
  await query(
    `INSERT INTO events (id, day, start_time, end_time, all_day, title, place, note, rule_text, official, sort_order)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, (SELECT COALESCE(MAX(sort_order),0)+1 FROM events))
     ON CONFLICT (id) DO UPDATE SET day=$2, start_time=$3, end_time=$4, all_day=$5, title=$6, place=$7, note=$8, rule_text=$9, official=$10`,
    [id, body.day, start, end, allDay, title, place, note, rule, body.official !== false]);
});

export const DELETE = route({ admin: true }, async ({ req }) => {
  const id = req.nextUrl.searchParams.get("id");
  if (!id) return fail("Falta o id.");
  await query("DELETE FROM events WHERE id = $1", [id]);
});
