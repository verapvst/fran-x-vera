import { randomUUID } from "node:crypto";
import { newCode } from "@/lib/auth";
import { fail, route, str } from "@/lib/api";
import { query } from "@/lib/db";

export const POST = route({ admin: true }, async ({ body }) => {
  const name = str(body.name, 60);
  if (!name) return fail("Nome inválido.");
  for (let i = 0; i < 5; i++) {
    try {
      await query("INSERT INTO people (id, name, code) VALUES ($1,$2,$3)", [randomUUID().slice(0, 8), name, newCode()]);
      return;
    } catch (e) {
      if ((e as { code?: string }).code !== "23505") throw e; // código repetido: tenta outro
    }
  }
  return fail("Não consegui gerar um código. Tenta outra vez.", 500);
});

export const DELETE = route({ admin: true }, async ({ req }) => {
  const id = req.nextUrl.searchParams.get("id");
  if (!id) return fail("Falta o id.");
  await query("DELETE FROM people WHERE id = $1 AND role = 'participant'", [id]);
});
