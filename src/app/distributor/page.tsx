import { signOutAction } from "@/app/actions/auth";
import { requireRole } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";

export default async function DistributorWorkspacePage() {
  const profile = await requireRole("distributor");

  return (
    <main className="min-h-screen bg-[#f7f6f2] px-6 py-10 text-[#20251f]">
      <div className="mx-auto max-w-5xl">
        <header className="mb-10 flex flex-wrap items-start justify-between gap-5">
          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#9a743e]">
              AMANAH / Distributor
            </p>
            <h1 className="text-3xl font-semibold">Welcome, ${profile.full_name}</h1>
            <p className="mt-2 text-sm text-stone-600">Your distributor session is authenticated.</p>
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
          <h2 className="mt-3 text-2xl font-semibold">Distributor workspace</h2>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-stone-600">
            Supabase Auth confirmed your session, and the server verified that your AMANAH profile
            is active and assigned the distributor role. Personal PV, group PV, orders, genealogy,
            commissions, and wallet data will be connected in later increments.
          </p>
          <dl className="mt-7 grid gap-4 border-t border-stone-100 pt-6 sm:grid-cols-2">
            <div>
              <dt className="text-xs uppercase tracking-wider text-stone-500">Member code</dt>
              <dd className="mt-1 font-semibold">${profile.member_code}</dd>
            </div>
            <div>
              <dt className="text-xs uppercase tracking-wider text-stone-500">Account role</dt>
              <dd className="mt-1 font-semibold">Distributor</dd>
            </div>
          </dl>
        </section>

        <p className="mt-6 text-xs leading-5 text-stone-500">
          Development workspace only. Figures are not live, and no commission or payout is
          calculated or issued here.
        </p>
      </div>
    </main>
  );
}
