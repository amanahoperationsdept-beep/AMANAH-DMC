import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  if (!code) {
    return NextResponse.redirect(new URL("/?auth=confirmation-failed", request.url));
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (!error) {
    // Email confirmation proves mailbox control, not distributor approval.
    await supabase.auth.signOut();
    return NextResponse.redirect(new URL("/?auth=pending", request.url));
  }

  return NextResponse.redirect(new URL("/?auth=confirmation-failed", request.url));
}
