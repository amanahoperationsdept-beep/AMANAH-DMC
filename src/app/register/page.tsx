"use client";

import Link from "next/link";
import { useActionState } from "react";
import { registerDistributorAction } from "@/app/actions/members";

type RegistrationState = {
  status: "idle" | "error" | "success";
  message: string;
};
const initialState: RegistrationState = { status: "idle", message: "" };

export default function RegisterPage() {
  const [state, formAction, isPending] = useActionState(registerDistributorAction, initialState);

  return (
    <main className="min-h-screen bg-[#f7f6f2] px-5 py-10 text-[#20251f] sm:px-8">
      <div className="mx-auto max-w-xl">
        <Link href="/" className="text-sm font-semibold text-[#8b6738] hover:underline">← Back to AMANAH</Link>
        <section className="mt-8 rounded-3xl border border-stone-200 bg-white p-6 shadow-sm sm:p-9">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#9a743e]">AMANAH / Distributor onboarding</p>
          <h1 className="mt-3 text-3xl font-semibold">Apply for a distributor account</h1>
          <p className="mt-3 text-sm leading-6 text-stone-600">
            Submit your details and active sponsor code. Your application starts as pending.
            Verify your email, then wait for an administrator to approve your account.
          </p>

          <form action={formAction} className="mt-8 space-y-5">
            <div>
              <label htmlFor="full_name" className="mb-2 block text-sm font-semibold">Full name</label>
              <input id="full_name" name="full_name" required minLength={2} maxLength={120}
                autoComplete="name" className="w-full rounded-xl border border-stone-300 px-4 py-3 outline-none focus:border-[#9a743e]"
                placeholder="Your complete name" />
            </div>
            <div>
              <label htmlFor="email" className="mb-2 block text-sm font-semibold">Email address</label>
              <input id="email" name="email" type="email" required maxLength={254}
                autoComplete="email" className="w-full rounded-xl border border-stone-300 px-4 py-3 outline-none focus:border-[#9a743e]"
                placeholder="you@example.com" />
            </div>
            <div>
              <label htmlFor="phone" className="mb-2 block text-sm font-semibold">Phone number <span className="font-normal text-stone-500">(optional)</span></label>
              <input id="phone" name="phone" type="tel" maxLength={40}
                autoComplete="tel" className="w-full rounded-xl border border-stone-300 px-4 py-3 outline-none focus:border-[#9a743e]"
                placeholder="09xx xxx xxxx" />
            </div>
            <div>
              <label htmlFor="sponsor_code" className="mb-2 block text-sm font-semibold">Sponsor member code</label>
              <input id="sponsor_code" name="sponsor_code" required minLength={1} maxLength={32}
                autoCapitalize="characters" className="w-full rounded-xl border border-stone-300 px-4 py-3 uppercase outline-none focus:border-[#9a743e]"
                placeholder="Enter your active sponsor's code" />
              <p className="mt-2 text-xs leading-5 text-stone-500">Your sponsor must be an active AMANAH distributor. Ask your sponsor for their exact member code.</p>
            </div>
            <div>
              <label htmlFor="password" className="mb-2 block text-sm font-semibold">Password</label>
              <input id="password" name="password" type="password" required minLength={8} maxLength={128}
                autoComplete="new-password" className="w-full rounded-xl border border-stone-300 px-4 py-3 outline-none focus:border-[#9a743e]"
                placeholder="At least 8 characters" />
            </div>

            {state.message && (
              <div role="status" aria-live="polite"
                className={state.status === "success"
                  ? "rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900"
                  : "rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-900"}>
                {state.message}
              </div>
            )}

            <button type="submit" disabled={isPending || state.status === "success"}
              className="flex w-full items-center justify-center rounded-full bg-[#243c31] px-6 py-3.5 text-sm font-semibold text-white transition hover:bg-[#192d24] disabled:cursor-not-allowed disabled:opacity-60">
              {isPending ? "Submitting application..." : "Submit distributor application"}
            </button>
            <p className="text-center text-sm text-stone-600">
              Already registered? <Link href="/?portal=distributor" className="font-semibold text-[#8b6738] hover:underline">Sign in</Link>
            </p>
          </form>
        </section>
        <p className="mt-6 text-center text-xs leading-5 text-stone-500">
          Registration is for distributor accounts only. Administrator accounts are provisioned separately by AMANAH.
        </p>
      </div>
    </main>
  );
}
