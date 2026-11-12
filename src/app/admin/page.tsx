import { signOutAction } from "@/app/actions/auth";
import { reviewDistributorAction } from "@/app/actions/members";
import { requireRole } from "@/lib/auth/require-role";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function AdminWorkspacePage() {
  const profile = await requireRole("admin");
  const supabase = await createSupabaseServerClient();
  const { data: pendingMembers, error: pendingError } = await supabase
    .from("profiles")
    .select("id, member_code, full_name, phone, joined_at")
    .eq("role", "distributor")
    .eq("status", "pending")
    .order("joined_at", { ascending: true });

  return (
    <main className="min-h-screen bg-[#f7f6f2] px-6 py-10 text-[#20251f]">
      <div className="mx-auto max-w-5xl">
        <header className="mb-10 flex flex-wrap items-start justify-between gap-5">
          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#9a743e]">
              AMANAH / Administrator
            </p>
            <h1 className="text-3xl font-semibold">Welcome, {profile.full_name}</h1>
            <p className="mt-2 text-sm text-stone-600">Your administrator session is authenticated.</p>
          </div>
          <form action={signOutAction}>
            <button className="rounded-full border border-stone-300 bg-white px-5 py-2.5 text-sm font-semibold hover:bg-stone-100">
              Sign out
            </button>
          </form>
        </header>

        <section className="rounded-2xl border border-stone-200 bg-white p-7 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-emerald-700">
            Access verified
          </p>
          <h2 className="mt-3 text-2xl font-semibold">Administrator workspace</h2>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-stone-600">
            Supabase Auth confirmed your session, and the server verified that your AMANAH profile
            is active and assigned the administrator role. Operational modules and live business
            records are not connected yet.
          </p>
          <dl className="mt-7 grid gap-4 border-t border-stone-100 pt-6 sm:grid-cols-2">
            <div>
              <dt className="text-xs uppercase tracking-wider text-stone-500">Member code</dt>
              <dd className="mt-1 font-semibold">{profile.member_code}</dd>
            </div>
            <div>
              <dt className="text-xs uppercase tracking-wider text-stone-500">Account role</dt>
              <dd className="mt-1 font-semibold">Administrator</dd>
            </div>
          </dl>
        </section>

        <section className="mt-7 rounded-2xl border border-stone-200 bg-white p-7 shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#9a743e]">Account governance</p>
              <h2 className="mt-2 text-2xl font-semibold">Distributor applications</h2>
              <p className="mt-2 text-sm text-stone-600">Review email-verified applications before activating distributor access.</p>
            </div>
            <span className="rounded-full bg-amber-50 px-3 py-1.5 text-sm font-semibold text-amber-800">
              {pendingMembers?.length ?? 0} pending
            </span>
          </div>

          {pendingError ? (
            <p role="status" className="mt-6 rounded-xl bg-rose-50 p-4 text-sm text-rose-800">
              The application queue could not be loaded. Confirm the database schema and administrator RLS policy are installed.
            </p>
          ) : pendingMembers && pendingMembers.length > 0 ? (
            <div className="mt-6 divide-y divide-stone-100">
              {pendingMembers.map((member) => (
                <article key={member.id} className="py-5 first:pt-0 last:pb-0">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h3 className="font-semibold">{member.full_name}</h3>
                      <p className="mt-1 text-xs text-stone-500">
                        {member.member_code} · Applied {new Date(member.joined_at).toLocaleDateString("en-PH")}
                      </p>
                      {member.phone && <p className="mt-1 text-sm text-stone-600">{member.phone}</p>}
                    </div>
                    <span className="rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-800">Pending review</span>
                  </div>
                  <form action={reviewDistributorAction} className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center">
                    <input type="hidden" name="member_id" value={member.id} />
                    <input name="note" maxLength={1000} aria-label={"Review note for " + member.full_name}
                      placeholder="Optional review note"
                      className="min-w-0 flex-1 rounded-xl border border-stone-300 px-3 py-2.5 text-sm outline-none focus:border-[#9a743e]" />
                    <div className="flex gap-2">
                      <button type="submit" name="decision" value="approve"
                        className="rounded-full bg-[#243c31] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#192d24]">
                        Approve
                      </button>
                      <button type="submit" name="decision" value="reject"
                        className="rounded-full border border-rose-200 px-4 py-2.5 text-sm font-semibold text-rose-700 hover:bg-rose-50">
                        Reject
                      </button>
                    </div>
                  </form>
                </article>
              ))}
            </div>
          ) : (
            <p className="mt-6 rounded-xl bg-stone-50 p-5 text-sm text-stone-600">
              No distributor applications are waiting for review.
            </p>
          )}
          <p className="mt-5 border-t border-stone-100 pt-4 text-xs leading-5 text-stone-500">
            Approval is enforced by a database function. An applicant must verify their email first.
            Rejected applications are closed and retained in the review history; no financial activity is created by approval.
          </p>
        </section>

        <p className="mt-6 text-xs leading-5 text-stone-500">
          Development workspace only. No commission calculation, wallet posting, or payout action is
          available from this page.
        </p>
      </div>
    </main>
  );
}
