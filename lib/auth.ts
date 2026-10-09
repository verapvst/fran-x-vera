import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import type { NextRequest } from "next/server";
import { query } from "./db";

export const COOKIE = "fxv_session";
const MAX_AGE = 60 * 60 * 24 * 10; // 10 dias
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem 0/O/1/I

export type Person = { id: string; name: string; role: "participant" | "admin"; in_portugal: boolean };

function secret(): string {
  const s = process.env.SESSION_SECRET;
  if (!s || s.length < 16) throw new Error("SESSION_SECRET em falta ou curto demais (mínimo 16 caracteres).");
  return s;
}

const sign = (payload: string) => createHmac("sha256", secret()).update(payload).digest("base64url");

export function makeSession(personId: string): string {
  const payload = `${personId}.${Math.floor(Date.now() / 1000) + MAX_AGE}`;
  return `${payload}.${sign(payload)}`;
}
export const sessionMaxAge = MAX_AGE;

export function newCode(): string {
  return Array.from({ length: 6 }, () => ALPHABET[randomInt(ALPHABET.length)]).join("");
}

export function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

/** Devolve a pessoa da sessão, ou null. */
export async function getUser(req: NextRequest): Promise<Person | null> {
  const raw = req.cookies.get(COOKIE)?.value;
  if (!raw) return null;
  const i = raw.lastIndexOf(".");
  if (i < 0) return null;
  const payload = raw.slice(0, i);
  if (!safeEqual(sign(payload), raw.slice(i + 1))) return null;
  const [id, exp] = payload.split(".");
  if (!id || Number(exp) < Date.now() / 1000) return null;
  const rows = await query<Person>("SELECT id, name, role, in_portugal FROM people WHERE id = $1", [id]);
  return rows[0] ?? null;
}

/** Códigos dos admins vêm de ADMIN_CODES="Fran=CODIGO1,Vera=CODIGO2", nunca do repositório. */
export function adminCodes(): Map<string, string> {
  const m = new Map<string, string>();
  for (const part of (process.env.ADMIN_CODES ?? "").split(",")) {
    const [n, c] = part.split("=");
    if (n?.trim() && c?.trim()) m.set(n.trim().toLowerCase(), c.trim().toUpperCase());
  }
  return m;
}
