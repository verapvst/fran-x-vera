import { fail, route } from "@/lib/api";
import { query } from "@/lib/db";

export const POST = route({}, async ({ me, body }) => {
  if (typeof body.inPortugal !== "boolean") return fail("Valor inválido.");
  await query("UPDATE people SET in_portugal = $1 WHERE id = $2", [body.inPortugal, me.id]);
});
