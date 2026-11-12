"use server";

import { revalidatePath } from "next/cache";
import { requireRole } from "@/lib/auth/require-role";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type RegistrationState = {
  status: "idle" | "error" | "success";
  message: string;
};

export async function registerDistributorAction(
  _previousState: RegistrationState,
  formData: FormData,
): Promise<RegistrationState> {
  const fullNameValue = formData.get("full_name");
  const emailValue = formData.get("email");
  const phoneValue = formData.get("phone");
  const sponsorCodeValue = formData.get("sponsor_code");
  const passwordValue = formData.get("password");

  if (
    typeof fullNameValue !== "string" ||
    typeof emailValue !== "string" ||
    typeof phoneValue !== "string" ||
    typeof sponsorCodeValue !== "string" ||
    typeof passwordValue !== "string"
  ) {
    return { status: "error", message: "Complete all required fields." };
  }

  const fullName = fullNameValue.trim();
  const email = emailValue.trim().toLowerCase();
  const phone = phoneValue.trim();
  const sponsorCode = sponsorCodeValue.trim().toUpperCase();
  const password = passwordValue;

  if (fullName.length < 2 || fullName.length > 120) {
    return { status: "error", message: "Enter a name between 2 and 120 characters." };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return { status: "error", message: "Enter a valid email address." };
  }
  if (phone.length > 40) {
    return { status: "error", message: "Phone number must be 40 characters or fewer." };
  }
  if (sponsorCode.length < 1 || sponsorCode.length > 32) {
    return { status: "error", message: "Enter your active distributor sponsor code." };
  }
  if (password.length < 8 || password.length > 128) {
    return { status: "error", message: "Password must be between 8 and 128 characters." };
  }

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    return { status: "error", message: "Distributor registration is not configured yet." };
  }

  const supabase = await createSupabaseServerClient();
  const { data: sponsorData, error: sponsorError } = await supabase.rpc(
    "resolve_active_sponsor",
    { p_member_code: sponsorCode },
  );
  const sponsors = Array.isArray(sponsorData) ? sponsorData : [];

  if (sponsorError || sponsors.length !== 1) {
    return {
      status: "error",
      message: "That sponsor code is not valid for an active distributor. Check the code with your sponsor.",
    };
  }

  const configuredSiteUrl = process.env.NEXT_PUBLIC_SITE_URL;
  if (!configuredSiteUrl) {
    return { status: "error", message: "The email-confirmation website URL is not configured. Contact AMANAH support." };
  }

  let emailRedirectTo: string;
  try {
    const siteOrigin = new URL(configuredSiteUrl);
    const isLocalDevelopment = siteOrigin.hostname === "localhost" || siteOrigin.hostname === "127.0.0.1";
    if (siteOrigin.protocol !== "https:" && !isLocalDevelopment) {
      return { status: "error", message: "The email-confirmation website URL must use HTTPS." };
    }
    emailRedirectTo = new URL("/auth/callback", siteOrigin).toString();
  } catch {
    return { status: "error", message: "The email-confirmation website URL is invalid." };
  }

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo,
      data: {
        amanah_distributor_signup: true,
        full_name: fullName,
        phone: phone || null,
        sponsor_code: sponsorCode,
      },
    },
  });

  if (error || !data.user || (data.user.identities && data.user.identities.length === 0)) {
    return {
      status: "error",
      message: "We could not create this account. Check the details or contact AMANAH support.",
    };
  }

  if (data.session) await supabase.auth.signOut();

  return {
    status: "success",
    message: "Application received. Check your email for verification. An administrator must approve your distributor account before you can sign in.",
  };
}

export async function reviewDistributorAction(formData: FormData): Promise<void> {
  await requireRole("admin");

  const memberId = formData.get("member_id");
  const decision = formData.get("decision");
  const noteValue = formData.get("note");

  if (typeof memberId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(memberId)) {
    throw new Error("Invalid distributor application.");
  }
  if (decision !== "approve" && decision !== "reject") {
    throw new Error("Choose approve or reject.");
  }
  if (noteValue !== null && typeof noteValue !== "string") {
    throw new Error("Invalid review note.");
  }

  const note = typeof noteValue === "string" ? noteValue.trim() : "";
  if (note.length > 1000) throw new Error("Review note must be 1,000 characters or fewer.");

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("review_member_application", {
    p_member_id: memberId,
    p_decision: decision,
    p_note: note || null,
  });

  if (error) {
    throw new Error(
      "The review could not be saved. Confirm migration 0003 is applied and, for approval, the applicant has verified their email.",
    );
  }

  revalidatePath("/admin");
}
