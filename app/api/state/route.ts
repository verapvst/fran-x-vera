import { NextResponse, type NextRequest } from "next/server";
import { getUser } from "@/lib/auth";
import { buildState, fail } from "@/lib/api";

export async function GET(req: NextRequest) {
  try {
    return NextResponse.json(await buildState(await getUser(req)));
  } catch (e) {
    console.error(e);
    return fail("Erro no servidor.", 500);
  }
}
