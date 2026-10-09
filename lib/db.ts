import { getDatabase } from "@netlify/database";

export async function query<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
  const db = getDatabase();
  const res = await db.pool.query(text, params);
  return res.rows as T[];
}
