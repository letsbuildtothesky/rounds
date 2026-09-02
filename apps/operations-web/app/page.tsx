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
import { HistoryPanel } from "./history-panel";
import { CommunicationsPanel } from "./communications-panel";
import { OperationsWorkstation } from "./operations-workstation";
import { OperationsMenuIcon, OperationsSectionSheet, type OperationsSectionKey } from "./operations-section-sheet";

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

type SubmissionSuccess = {
  deliveryId: string;
  deliveryState: string;
  reference: string;
  deduplicated: boolean;
};

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
  const [communicationThreadId, setCommunicationThreadId] = useState("");
  const [developmentPreview, setDevelopmentPreview] = useState(false);
  const [sectionMenuOpen, setSectionMenuOpen] = useState(false);

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

  function openCommunicationThread(threadId: string) {
    setCommunicationThreadId(threadId);
    setSection("communications");
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

  if (selectedTenant && section === "action") {
    return <OperationsWorkstation
      accessToken={authSession.access_token}
      tenant={selectedTenant}
      userName={operationsSession?.user.displayName ?? authSession.user.email ?? "Operations"}
      onAddDelivery={() => setSection("deliveries")}
      onHistory={() => setSection("history")}
      onCommunications={(threadId) => {
        if (threadId) setCommunicationThreadId(threadId);
        setSection("communications");
      }}
      onSignOut={() => void signOut()}
    />;
  }

  return (
    <div className="operations-shell">
      <header className="app-header">
        <div className="brand"><RoundsMark /><span>ROUNDS</span></div>
        <nav aria-label="Operations sections"><button type="button" className={section === "action" ? "active" : ""} onClick={() => setSection("action")}>Dispatch</button><button type="button" className={section === "deliveries" ? "active" : ""} onClick={() => setSection("deliveries")}>Deliveries</button><button type="button" className={section === "communications" ? "active" : ""} onClick={() => setSection("communications")}>Communications</button><button type="button" className={section === "history" ? "active" : ""} onClick={() => setSection("history")}>History</button></nav>
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

      <main className={`operations-main ${section !== "deliveries" ? "dispatch-main" : ""}`}>
        {section === "communications" && selectedTenant ? <CommunicationsPanel accessToken={authSession.access_token} tenant={selectedTenant} initialThreadId={communicationThreadId} /> : section === "history" && selectedTenant ? <HistoryPanel accessToken={authSession.access_token} tenant={selectedTenant} /> : <>
        <section className="page-heading">
          <div><p className="eyebrow">MANUAL INTAKE</p><h1>Add delivery</h1><p>Create one canonical delivery for the unplanned pool.</p></div>
          <div className="secure-badge"><ShieldIcon /> Server-authoritative command</div>
        </section>

        {error && <div className="alert error" role="alert"><AlertIcon /><div><strong>Couldn&apos;t continue</strong><span>{error}</span></div></div>}

        {!operationsSession || !selectedTenant ? (
          <section className="empty-access"><LockIcon /><h2>No active Operations membership</h2><p>This authenticated account is not linked to an active merchant role.</p><button onClick={() => void loadOperationsSession(authSession)}>Check again</button></section>
        ) : success ? (
          <SuccessPanel success={success} onReset={resetForm} />
        ) : (
          <form className="delivery-form" onSubmit={(event) => void submitDelivery(event)}>
            <section className="form-card context-card">
              <div className="card-title"><div><span>01</span><div><h2>Merchant & pickup</h2><p>Pickup contact comes from the business profile.</p></div></div></div>
              <div className="field-grid two">
                <Field label="Business">
                  <select value={selectedTenant.id} onChange={(event) => chooseTenant(event.target.value)}>
                    {operationsSession.tenants.map((tenant) => <option key={tenant.id} value={tenant.id}>{tenant.displayName}</option>)}
                  </select>
                </Field>
                <Field label="Pickup location">
                  <select required value={draft.pickupLocationId} onChange={(event) => updateDraft("pickupLocationId", event.target.value)}>
                    <option value="">Choose pickup</option>
                    {selectedTenant.locations.map((location) => <option key={location.id} value={location.id}>{location.displayName}</option>)}
                  </select>
                </Field>
              </div>
              {selectedTenant.locations.find((location) => location.id === draft.pickupLocationId) && (
                <div className="pickup-readout"><PinIcon /><div><strong>{selectedTenant.locations.find((location) => location.id === draft.pickupLocationId)!.rawAddress}</strong><span>{selectedTenant.locations.find((location) => location.id === draft.pickupLocationId)!.pickupContactName} · {selectedTenant.locations.find((location) => location.id === draft.pickupLocationId)!.pickupContactPhone}</span></div><small>PROFILE</small></div>
              )}
            </section>

            <section className="form-card">
              <CardTitle number="02" title="Recipient" detail="Who receives the delivery and where it goes." />
              <div className="field-grid two">
                <Field label="Recipient name"><input required value={draft.recipientName} onChange={(event) => updateDraft("recipientName", event.target.value)} placeholder="Full name" /></Field>
                <Field label="Recipient phone"><input required type="tel" value={draft.recipientPhone} onChange={(event) => updateDraft("recipientPhone", event.target.value)} placeholder="+66" /></Field>
              </div>
              <Field label="Delivery address"><textarea required rows={3} value={draft.address} onChange={(event) => updateDraft("address", event.target.value)} placeholder="Building, street, district, Bangkok" /></Field>
              <div className="pin-fields">
                <div className="pin-copy"><PinIcon /><div><strong>Operational destination pin</strong><span>Use the confirmed map coordinate, not an approximate area.</span></div></div>
                <div className="field-grid two compact">
                  <Field label="Latitude"><input required inputMode="decimal" value={draft.latitude} onChange={(event) => updateDraft("latitude", event.target.value)} placeholder="13.7563" /></Field>
                  <Field label="Longitude"><input required inputMode="decimal" value={draft.longitude} onChange={(event) => updateDraft("longitude", event.target.value)} placeholder="100.5018" /></Field>
                </div>
              </div>
              <Field label="Access note" optional><input value={draft.accessNote} onChange={(event) => updateDraft("accessNote", event.target.value)} placeholder="Entrance, floor, reception, parking" /></Field>
              <div className="relationship-row">
                <div><strong>Ordered by</strong><span>Is the buyer also the recipient?</span></div>
                <div className="segmented"><button type="button" className={draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => updateDraft("buyerSameAsRecipient", true)}>Same person</button><button type="button" className={!draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => updateDraft("buyerSameAsRecipient", false)}>Someone else</button></div>
              </div>
              {!draft.buyerSameAsRecipient && <div className="field-grid two"><Field label="Buyer name"><input required value={draft.buyerName} onChange={(event) => updateDraft("buyerName", event.target.value)} /></Field><Field label="Buyer phone"><input required type="tel" value={draft.buyerPhone} onChange={(event) => updateDraft("buyerPhone", event.target.value)} placeholder="+66" /></Field></div>}
            </section>

            <section className="form-card">
              <CardTitle number="03" title="Order & promise" detail="The service date and committed delivery window." />
              <div className="field-grid two">
                <Field label="Order reference"><input required value={draft.reference} onChange={(event) => updateDraft("reference", event.target.value)} placeholder="UF-10452" /></Field>
                <Field label="Service date"><input required type="date" value={draft.serviceDate} onChange={(event) => updateDraft("serviceDate", event.target.value)} /></Field>
              </div>
              <div className="field-grid two">
                <Field label="Window starts"><input required type="datetime-local" value={draft.windowStart} onChange={(event) => updateDraft("windowStart", event.target.value)} /></Field>
                <Field label="Window ends"><input required type="datetime-local" value={draft.windowEnd} onChange={(event) => updateDraft("windowEnd", event.target.value)} /></Field>
              </div>
              <p className="timezone-note">Times are committed in Asia/Bangkok.</p>
            </section>

            <section className="form-card">
              <CardTitle number="04" title="Items & handling" detail="Physical truth carried into pickup and POD." />
              <div className="manifest-list">
                {draft.items.map((item, index) => (
                  <div className="manifest-row" key={index}>
                    <span className="line-number">{String(index + 1).padStart(2, "0")}</span>
                    <Field label="Item"><input required value={item.description} onChange={(event) => updateDraft("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, description: event.target.value } : entry))} placeholder="Bouquet, cake, flower box…" /></Field>
                    <Field label="Qty"><input required min="1" type="number" value={item.quantity} onChange={(event) => updateDraft("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, quantity: event.target.value } : entry))} /></Field>
                    <Field label="Handling note" optional><input value={item.handlingNote} onChange={(event) => updateDraft("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, handlingNote: event.target.value } : entry))} placeholder="Fragile, keep upright" /></Field>
                    <button className="remove-line" type="button" disabled={draft.items.length === 1} onClick={() => updateDraft("items", draft.items.filter((_, itemIndex) => itemIndex !== index))} aria-label={`Remove item ${index + 1}`}>×</button>
                  </div>
                ))}
              </div>
              <button className="add-line" type="button" onClick={() => updateDraft("items", [...draft.items, { description: "", quantity: "1", handlingNote: "" }])}>+ Add item</button>
              <Field label="Delivery instruction" optional><textarea rows={2} value={draft.note} onChange={(event) => updateDraft("note", event.target.value)} placeholder="Call before arrival, reception handoff…" /></Field>
              <label className="check-row"><input type="checkbox" checked={draft.isSurprise} onChange={(event) => updateDraft("isSurprise", event.target.checked)} /><span><strong>Surprise or gift delivery</strong><small>Protect buyer details from recipient-facing communication.</small></span></label>
            </section>

            <div className="form-actions"><div><ShieldIcon /><span>Authorized as <strong>{roleLabel(selectedTenant.role)}</strong></span></div><button className="primary-action" disabled={submitting || selectedTenant.role === "viewer"}>{submitting ? "Creating delivery…" : selectedTenant.role === "viewer" ? "Viewer cannot create" : "Add delivery"}<ArrowIcon /></button></div>
          </form>
        )}
        </>}
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

function SuccessPanel({ success, onReset }: { success: SubmissionSuccess; onReset: () => void }) {
  return <section className="success-panel"><div className="success-icon"><CheckIcon /></div><p className="eyebrow">COMMAND COMMITTED</p><h2>Delivery {success.reference} is ready for planning.</h2><p>The server created the Delivery, Stop, promise and physical manifest in one transaction.</p><dl><div><dt>Delivery ID</dt><dd>{success.deliveryId}</dd></div><div><dt>State</dt><dd>{success.deliveryState}</dd></div><div><dt>Request</dt><dd>{success.deduplicated ? "Safe retry · existing delivery returned" : "New delivery committed"}</dd></div></dl><button className="primary-action" onClick={onReset}>Add another delivery<ArrowIcon /></button></section>;
}

function LoadingScreen({ label }: { label: string }) { return <main className="loading-screen"><RoundsMark /><div className="loading-bar"><span /></div><p>{label}…</p></main>; }
function Field({ label, optional, children }: { label: string; optional?: boolean; children: ReactNode }) { return <label className="field"><span>{label}{optional && <small>Optional</small>}</span>{children}</label>; }
function CardTitle({ number, title, detail }: { number: string; title: string; detail: string }) { return <div className="card-title"><div><span>{number}</span><div><h2>{title}</h2><p>{detail}</p></div></div></div>; }

function RoundsMark() { return <svg className="rounds-mark" viewBox="0 0 48 48" aria-hidden="true"><path d="M12 35V13h12.5c7.2 0 11.5 3.7 11.5 9.5 0 4.3-2.4 7.4-6.5 8.8L37 35h-8l-6.3-3.2H19V35h-7Zm7-9h5.2c3.1 0 4.8-1.1 4.8-3.3 0-2.1-1.7-3.2-4.8-3.2H19V26Z" /></svg>; }
function ShieldIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 5 6v5c0 4.6 2.9 8 7 10 4.1-2 7-5.4 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/></svg>; }
function LockIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>; }
function PinIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>; }
function AlertIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v5M12 17h.01"/></svg>; }
function ArrowIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M14 7l5 5-5 5"/></svg>; }
function CheckIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>; }
function PulseIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12h4l2-6 4 12 2-6h6"/></svg>; }
