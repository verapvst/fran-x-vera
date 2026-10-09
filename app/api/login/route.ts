import { NextResponse, type NextRequest } from "next/server";
import { COOKIE, adminCodes, makeSession, safeEqual, sessionMaxAge, type Person } from "@/lib/auth";
import { buildState, fail } from "@/lib/api";
import { query } from "@/lib/db";

const MAX_FAILS = 10; // por IP, em 10 minutos

export async function POST(req: NextRequest) {
  try {
    const ip = req.headers.get("x-nf-client-connection-ip") ?? req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "local";
    const [{ n }] = await query<{ n: number }>(
      "SELECT COUNT(*)::int AS n FROM login_attempts WHERE ip = $1 AND at > NOW() - INTERVAL '10 minutes'", [ip]);
    if (n >= MAX_FAILS) return fail("Demasiadas tentativas. Espera uns minutos.", 429);

    let body: { name?: unknown; code?: unknown };
    try { body = await req.json(); } catch { return fail("Pedido inválido."); }
    const name = typeof body.name === "string" ? body.name.trim() : "";
    const code = typeof body.code === "string" ? body.code.trim().toUpperCase() : "";
    if (!name || !code || name.length > 60 || code.length > 20) return fail("Nome ou código errado.", 401);

    let person: Person | undefined;
    const adminCode = adminCodes().get(name.toLowerCase());
    if (adminCode && safeEqual(adminCode, code)) {
      const id = `admin-${name.toLowerCase()}`;
      await query(
        `INSERT INTO people (id, name, code, role) VALUES ($1, $2, $3, 'admin')
         ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code, role = 'admin'`,
        [id, name, adminCode]);
      person = (await query<Person>("SELECT id, name, role, in_portugal FROM people WHERE id = $1", [id]))[0];
    } else {
      person = (await query<Person>(
        "SELECT id, name, role, in_portugal FROM people WHERE lower(name) = lower($1) AND code = $2 AND role = 'participant'",
        [name, code]))[0];
    }
    if (!person) {
      await query("INSERT INTO login_attempts (ip) VALUES ($1)", [ip]);
      return fail("Nome ou código errado. Confirma com a Fran ou a Vera.", 401);
    }

    const res = NextResponse.json(await buildState(person));
    res.cookies.set(COOKIE, makeSession(person.id), {
      httpOnly: true, sameSite: "lax", secure: process.env.NODE_ENV === "production", path: "/", maxAge: sessionMaxAge,
    });
    return res;
  } catch (e) {
    console.error(e);
    return fail("Erro no servidor.", 500);
  }
}
