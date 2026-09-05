"use client";

import { createClient, type Session, type SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from "react";
import type {
  CreateDeliveryResult,
  OperationsSession,
  OperationsTenant,
} from "@rounds/contracts";
import {
  buildCreateDeliveryPayload,
  defaultDeliveryDraft,
  type DeliveryFormDraft,
} from "../src/delivery-form";
import { OperationsWorkstation } from "./operations-workstation";
import { OperationsMenuIcon, OperationsSectionSheet, type OperationsSectionKey } from "./operations-section-sheet";
import { DeliveryIntake, type SubmissionSuccess } from "./delivery-intake";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const supabasePublishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
const defaultOperationsEmail = process.env.NEXT_PUBLIC_OPERATIONS_LOGIN_EMAIL ?? "";
const developmentPreviewEnabled = process.env.NODE_ENV !== "production";
const developmentPreviewTenant: OperationsTenant = {
  id: "development-preview",
  displayName: "UrbanFlowers",
  timezone: "Asia/Bangkok",
  role: "dispatcher",
  locations: [],
};
const supabaseClient = supabaseUrl && supabasePublishableKey
  ? createClient(supabaseUrl, supabasePublishableKey)
  : null;

type ApiError = {
  error?: { code?: string; message?: string };
};

function messageFromResponse(body: unknown, fallback: string): string {
  if (body && typeof body === "object" && "error" in body) {
    const error = (body as ApiError).error;
    if (error?.message) return error.message;
  }
  return fallback;
}

function roleLabel(role: OperationsTenant["role"]): string {
  return role.split("_").map((word) => word[0]!.toUpperCase() + word.slice(1)).join(" ");
}

export default function OperationsPage() {
  const supabase = supabaseClient;
  const [authSession, setAuthSession] = useState<Session | null>(null);
  const [operationsSession, setOperationsSession] = useState<OperationsSession | null>(null);
  const [selectedTenantId, setSelectedTenantId] = useState("");
  const [draft, setDraft] = useState<DeliveryFormDraft>(() => defaultDeliveryDraft());
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [booting, setBooting] = useState(true);
  const [loadingProfile, setLoadingProfile] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState<SubmissionSuccess | null>(null);
  const [section, setSection] = useState<OperationsSectionKey>("action");
  const [communicationRequest, setCommunicationRequest] = useState<{ threadId: string; nonce: number; startVoice?: boolean }>({ threadId: "", nonce: 0 });
  const [developmentPreview, setDevelopmentPreview] = useState(false);
  const [sectionMenuOpen, setSectionMenuOpen] = useState(false);
  const [deliveryIntakeOpen, setDeliveryIntakeOpen] = useState(false);
  const [deliveryRevision, setDeliveryRevision] = useState(0);

  const selectedTenant = operationsSession?.tenants.find((tenant) => tenant.id === selectedTenantId)
    ?? operationsSession?.tenants[0];

  const loadOperationsSession = useCallback(async (session: Session) => {
    setLoadingProfile(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/session`, {
        headers: {
          authorization: `Bearer ${session.access_token}`,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsSession | ApiError;
      if (!response.ok) throw new Error(messageFromResponse(body, `Session HTTP ${response.status}`));
      const profile = body as OperationsSession;
      setOperationsSession(profile);
      const tenant = profile.tenants[0];
      setSelectedTenantId(tenant?.id ?? "");
      setDraft((current) => ({
        ...current,
        pickupLocationId: tenant?.locations[0]?.id ?? "",
      }));
    } catch (caught) {
      setOperationsSession(null);
      setError(caught instanceof Error ? caught.message : "Could not load Operations access");
    } finally {
      setLoadingProfile(false);
    }
  }, []);

  useEffect(() => {
    if (!supabase) {
      setError("Operations configuration is missing. Set the Supabase URL and publishable key.");
      setBooting(false);
      return;
    }
    void supabase.auth.getSession().then(({ data }) => {
      setAuthSession(data.session);
      if (data.session) void loadOperationsSession(data.session);
      setBooting(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthSession(session);
      if (session) {
        window.setTimeout(() => void loadOperationsSession(session), 0);
      } else {
        setOperationsSession(null);
        setSelectedTenantId("");
      }
    });
    return () => listener.subscription.unsubscribe();
  }, [loadOperationsSession, supabase]);

  async function signOut() {
    if (!supabase) return;
    await supabase.auth.signOut();
    setSuccess(null);
    setError("");
  }

  function openCommunicationThread(threadId = "", startVoice = false) {
    setCommunicationRequest((current) => ({ threadId, nonce: current.nonce + 1, ...(startVoice ? { startVoice: true } : {}) }));
  }

  function updateDraft<K extends keyof DeliveryFormDraft>(key: K, value: DeliveryFormDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  function chooseTenant(tenantId: string) {
    const tenant = operationsSession?.tenants.find((candidate) => candidate.id === tenantId);
    setSelectedTenantId(tenantId);
    setDraft((current) => ({ ...current, pickupLocationId: tenant?.locations[0]?.id ?? "" }));
  }

  function resetForm() {
    const next = defaultDeliveryDraft();
    next.pickupLocationId = selectedTenant?.locations[0]?.id ?? "";
    setDraft(next);
    setSuccess(null);
    setError("");
    setIdempotencyKey(crypto.randomUUID());
  }

  async function submitDelivery(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!authSession || !selectedTenant) return;
    setSubmitting(true);
    setError("");
    try {
      const payload = buildCreateDeliveryPayload(draft);
      const response = await fetch(`${roundsApiUrl}/v1/deliveries`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${authSession.access_token}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${idempotencyKey}`,
          "x-rounds-tenant-id": selectedTenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify(payload),
      });
      const result = await response.json() as CreateDeliveryResult | ApiError;
      if (!response.ok || !("status" in result) || result.status !== "committed") {
        throw new Error(messageFromResponse(result, `Delivery command HTTP ${response.status}`));
      }
      setSuccess({
        deliveryId: result.state.deliveryId,
        deliveryState: result.state.deliveryState,
        reference: draft.reference.trim(),
        deduplicated: result.deduplicated ?? false,
      });
      setDeliveryRevision((current) => current + 1);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Delivery could not be created");
    } finally {
      setSubmitting(false);
    }
  }

  if (booting) return <LoadingScreen label="Opening Operations" />;
  if (!authSession && developmentPreview) return <OperationsWorkstation accessToken="" tenant={developmentPreviewTenant} userName="Demo dispatcher" demoMode onAddDelivery={() => undefined} onHistory={() => undefined} onCommunications={() => undefined} onSignOut={() => setDevelopmentPreview(false)} />;
  if (!authSession) return <LoginScreen supabase={supabase} error={error} setError={setError} onPreview={developmentPreviewEnabled ? () => setDevelopmentPreview(true) : undefined} />;
  if (loadingProfile) return <LoadingScreen label="Checking merchant access" />;

  if (operationsSession && selectedTenant) {
    return <OperationsWorkstation
      accessToken={authSession.access_token}
      realtimeClient={supabase ?? undefined}
      tenant={selectedTenant}
      userName={operationsSession?.user.displayName ?? authSession.user.email ?? "Operations"}
      deliveryIntakeOpen={deliveryIntakeOpen}
      driversOpen={section === "drivers"}
      historyOpen={section === "history"}
      deliveryRefreshKey={deliveryRevision}
      communicationRequest={communicationRequest}
      onCloseDeliveryIntake={() => setDeliveryIntakeOpen(false)}
      onDrivers={() => { setDeliveryIntakeOpen(false); setSection("drivers"); }}
      onCloseDrivers={() => setSection("action")}
      onCloseHistory={() => setSection("action")}
      deliveryIntake={<DeliveryIntake
        operationsSession={operationsSession}
        selectedTenant={selectedTenant}
        draft={draft}
        submitting={submitting}
        error={error}
        success={success}
        onSubmit={(event) => void submitDelivery(event)}
        onUpdate={updateDraft}
        onChooseTenant={chooseTenant}
        onReset={resetForm}
        onCancel={() => setDeliveryIntakeOpen(false)}
      />}
      onAddDelivery={() => setDeliveryIntakeOpen(true)}
      onHistory={() => setSection("history")}
      onCommunications={(threadId, options) => {
        setDeliveryIntakeOpen(false);
        openCommunicationThread(threadId, options?.startVoice);
      }}
      onSignOut={() => void signOut()}
    />;
  }

  return (
    <div className="operations-shell">
      <header className="app-header">
        <div className="brand"><RoundsMark /><span>ROUNDS</span></div>
        <nav aria-label="Operations sections"><button type="button" className={section === "action" ? "active" : ""} onClick={() => setSection("action")}>Dispatch</button><button type="button" className={section === "drivers" ? "active" : ""} onClick={() => setSection("drivers")}>Drivers</button><button type="button" className={section === "history" ? "active" : ""} onClick={() => setSection("history")}>History</button></nav>
        <div className="account">
          <div><strong>{operationsSession?.user.displayName ?? authSession.user.email}</strong><small>{selectedTenant ? roleLabel(selectedTenant.role) : "No access"}</small></div>
          <button type="button" onClick={() => void signOut()}>Sign out</button>
        </div>
        <button className="app-mobile-nav" type="button" aria-haspopup="dialog" aria-expanded={sectionMenuOpen} onClick={() => setSectionMenuOpen(true)}><span>{section === "action" ? "Dispatch" : section[0]!.toUpperCase() + section.slice(1)}</span><OperationsMenuIcon /></button>
      </header>

      <OperationsSectionSheet
        open={sectionMenuOpen}
        current={section}
        onClose={() => setSectionMenuOpen(false)}
        onSelect={(nextSection) => setSection(nextSection)}
        onSignOut={() => void signOut()}
      />

      <main className="operations-main dispatch-main">
        <section className="empty-access"><LockIcon /><h2>No active Operations membership</h2><p>This authenticated account is not linked to an active merchant role.</p><button onClick={() => void loadOperationsSession(authSession)}>Check again</button></section>
      </main>
    </div>
  );
}

function LoginScreen({ supabase, error, setError, onPreview }: { supabase: SupabaseClient | null; error: string; setError: (message: string) => void; onPreview?: () => void }) {
  const [email, setEmail] = useState(defaultOperationsEmail);
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);

  async function signIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!supabase) return;
    setSubmitting(true);
    setError("");
    const { error: signInError } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: window.location.origin, shouldCreateUser: false },
    });
    if (signInError) setError(signInError.message);
    else setSent(true);
    setSubmitting(false);
  }

  return <main className="login-shell"><section className="login-brand"><div className="large-mark"><RoundsMark /></div><p className="eyebrow">ROUNDS OPERATIONS</p><h1>Delivery truth,<br />from order to handoff.</h1><p>Secure merchant access for Dispatch, planning and delivery execution.</p><div className="login-points"><span><ShieldIcon /> Tenant-isolated</span><span><PulseIcon /> Live operations</span><span><CheckIcon /> Audited commands</span></div></section><section className="login-panel"><div className="login-card"><p className="eyebrow">WELCOME BACK</p><h2>Sign in to Operations</h2><p>No password. Rounds sends one secure sign-in link to the approved Operations address.</p>{error && <div className="login-error" role="alert">{error}</div>}{sent ? <div className="login-link-sent" role="status"><CheckIcon /><div><strong>Check your email</strong><span>Open the Rounds sign-in link on this computer.</span></div></div> : <form onSubmit={(event) => void signIn(event)}>{!defaultOperationsEmail && <Field label="Work email"><input required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@business.com" /></Field>}<button className="login-button" disabled={submitting || !supabase || !email.trim()}>{submitting ? "Sending secure link…" : "Sign in"}<ArrowIcon /></button></form>}{onPreview && <button type="button" className="preview-board-button" onClick={onPreview}>Skip sign-in · Preview board</button>}<div className="security-note"><LockIcon /><span>The preview uses local demo data. Real Operations access still requires Supabase authentication.</span></div></div></section></main>;
}

function LoadingScreen({ label }: { label: string }) { return <main className="loading-screen"><RoundsMark /><div className="loading-bar"><span /></div><p>{label}…</p></main>; }
function Field({ label, optional, children }: { label: string; optional?: boolean; children: ReactNode }) { return <label className="field"><span>{label}{optional && <small>Optional</small>}</span>{children}</label>; }

function RoundsMark() { return <svg className="rounds-mark" viewBox="0 0 48 48" aria-hidden="true"><path d="M12 35V13h12.5c7.2 0 11.5 3.7 11.5 9.5 0 4.3-2.4 7.4-6.5 8.8L37 35h-8l-6.3-3.2H19V35h-7Zm7-9h5.2c3.1 0 4.8-1.1 4.8-3.3 0-2.1-1.7-3.2-4.8-3.2H19V26Z" /></svg>; }
function ShieldIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 5 6v5c0 4.6 2.9 8 7 10 4.1-2 7-5.4 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/></svg>; }
function LockIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>; }
function ArrowIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M14 7l5 5-5 5"/></svg>; }
function CheckIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>; }
function PulseIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12h4l2-6 4 12 2-6h6"/></svg>; }
