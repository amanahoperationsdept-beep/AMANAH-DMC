"use server";

import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type SignInResult = { error: string };

export async function signInAction(formData: FormData): Promise<SignInResult | void> {
  const role = formData.get("role");
  const emailValue = formData.get("email");
  const passwordValue = formData.get("password");

  if (role !== "admin" && role !== "distributor") {
    return { error: "Choose a valid AMANAH sign-in portal." };
  }

  if (
    typeof emailValue !== "string" ||
    typeof passwordValue !== "string" ||
    !emailValue.trim() ||
    !passwordValue
  ) {
    return { error: "Enter your email address and password." };
  }

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    return {
      error: "Secure sign-in is not configured yet. Add the Supabase project URL and anon key, then try again.",
    };
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: emailValue.trim(),
    password: passwordValue,
  });

  if (error || !data.user) {
    return { error: "Unable to sign in. Check your credentials or contact AMANAH support." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role, status")
    .eq("id", data.user.id)
    .maybeSingle();

  if (profileError || !profile || profile.role !== role) {
    await supabase.auth.signOut();
    return {
      error: "This account is not active for the selected portal. Contact an AMANAH administrator.",
    };
  }

  if (profile.status !== "active") {
    await supabase.auth.signOut();
    if (profile.status === "pending" && role === "distributor") {
      return { error: "Your email and application are received. Your distributor account is awaiting administrator approval." };
    }
    if (profile.status === "closed" && role === "distributor") {
      return { error: "Your distributor application is closed. Contact AMANAH support if you need assistance." };
    }
    return { error: "This account is not active. Contact an AMANAH administrator." };
  }

  redirect(role === "admin" ? "/admin" : "/distributor");
}

export async function signOutAction(): Promise<void> {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect("/");
}
