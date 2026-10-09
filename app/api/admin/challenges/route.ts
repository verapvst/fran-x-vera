import { randomUUID } from "node:crypto";
import { fail, route, str } from "@/lib/api";
import { query } from "@/lib/db";

export const POST = route({ admin: true }, async ({ body }) => {
  const text = str(body.text, 300);
  const points = Number(body.points);
  if (!text || !Number.isInteger(points) || points < 0 || points > 10000) return fail("Challenge inválido.");
  const id = typeof body.id === "string" && body.id ? body.id : randomUUID().slice(0, 8);
  await query(
    `INSERT INTO challenges (id, text, points) VALUES ($1,$2,$3)
     ON CONFLICT (id) DO UPDATE SET text = $2, points = $3`, [id, text, points]);
});

export const DELETE = route({ admin: true }, async ({ req }) => {
  const id = req.nextUrl.searchParams.get("id");
  if (!id) return fail("Falta o id.");
  await query("DELETE FROM challenges WHERE id = $1", [id]);
});
