"use client";

import type { OperationsSession, OperationsTenant } from "@rounds/contracts";
import type { FormEvent, ReactNode } from "react";
import type { DeliveryFormDraft } from "../src/delivery-form";

export type SubmissionSuccess = {
  deliveryId: string;
  deliveryState: string;
  reference: string;
  deduplicated: boolean;
};

type UpdateDraft = <K extends keyof DeliveryFormDraft>(key: K, value: DeliveryFormDraft[K]) => void;

type Props = {
  operationsSession: OperationsSession;
  selectedTenant: OperationsTenant;
  draft: DeliveryFormDraft;
  submitting: boolean;
  error: string;
  success: SubmissionSuccess | null;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onUpdate: UpdateDraft;
  onChooseTenant: (tenantId: string) => void;
  onReset: () => void;
};

function roleLabel(role: OperationsTenant["role"]): string {
  return role.split("_").map((word) => word[0]!.toUpperCase() + word.slice(1)).join(" ");
}

export function DeliveryIntake({ operationsSession, selectedTenant, draft, submitting, error, success, onSubmit, onUpdate, onChooseTenant, onReset }: Props) {
  const pickup = selectedTenant.locations.find((location) => location.id === draft.pickupLocationId);

  return <div className="v45-delivery-intake">
    <div className="v45-intake-truth"><ShieldIcon /><div><strong>Server-authoritative command</strong><span>Creates the Delivery, Stop, promise and physical manifest together.</span></div></div>
    {error && <div className="alert error" role="alert"><AlertIcon /><div><strong>Couldn&apos;t continue</strong><span>{error}</span></div></div>}
    {success ? <SuccessPanel success={success} onReset={onReset} /> : <form className="delivery-form" onSubmit={onSubmit}>
      <section className="form-card context-card">
        <CardTitle number="01" title="Merchant & pickup" detail="Pickup contact comes from the business profile." />
        <div className="field-grid two">
          <Field label="Business"><select value={selectedTenant.id} onChange={(event) => onChooseTenant(event.target.value)}>{operationsSession.tenants.map((tenant) => <option key={tenant.id} value={tenant.id}>{tenant.displayName}</option>)}</select></Field>
          <Field label="Pickup location"><select required value={draft.pickupLocationId} onChange={(event) => onUpdate("pickupLocationId", event.target.value)}><option value="">Choose pickup</option>{selectedTenant.locations.map((location) => <option key={location.id} value={location.id}>{location.displayName}</option>)}</select></Field>
        </div>
        {pickup && <div className="pickup-readout"><PinIcon /><div><strong>{pickup.rawAddress}</strong><span>{pickup.pickupContactName} · {pickup.pickupContactPhone}</span></div><small>PROFILE</small></div>}
      </section>

      <section className="form-card">
        <CardTitle number="02" title="Recipient" detail="Who receives the delivery and where it goes." />
        <div className="field-grid two"><Field label="Recipient name"><input required value={draft.recipientName} onChange={(event) => onUpdate("recipientName", event.target.value)} placeholder="Full name" /></Field><Field label="Recipient phone"><input required type="tel" value={draft.recipientPhone} onChange={(event) => onUpdate("recipientPhone", event.target.value)} placeholder="+66" /></Field></div>
        <Field label="Delivery address"><textarea required rows={3} value={draft.address} onChange={(event) => onUpdate("address", event.target.value)} placeholder="Building, street, district, Bangkok" /></Field>
        <div className="pin-fields"><div className="pin-copy"><PinIcon /><div><strong>Operational destination pin</strong><span>Use the confirmed map coordinate, not an approximate area.</span></div></div><div className="field-grid two compact"><Field label="Latitude"><input required inputMode="decimal" value={draft.latitude} onChange={(event) => onUpdate("latitude", event.target.value)} placeholder="13.7563" /></Field><Field label="Longitude"><input required inputMode="decimal" value={draft.longitude} onChange={(event) => onUpdate("longitude", event.target.value)} placeholder="100.5018" /></Field></div></div>
        <Field label="Access note" optional><input value={draft.accessNote} onChange={(event) => onUpdate("accessNote", event.target.value)} placeholder="Entrance, floor, reception, parking" /></Field>
        <div className="relationship-row"><div><strong>Ordered by</strong><span>Is the buyer also the recipient?</span></div><div className="segmented"><button type="button" className={draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => onUpdate("buyerSameAsRecipient", true)}>Same person</button><button type="button" className={!draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => onUpdate("buyerSameAsRecipient", false)}>Someone else</button></div></div>
        {!draft.buyerSameAsRecipient && <div className="field-grid two"><Field label="Buyer name"><input required value={draft.buyerName} onChange={(event) => onUpdate("buyerName", event.target.value)} /></Field><Field label="Buyer phone"><input required type="tel" value={draft.buyerPhone} onChange={(event) => onUpdate("buyerPhone", event.target.value)} placeholder="+66" /></Field></div>}
      </section>

      <section className="form-card">
        <CardTitle number="03" title="Order & promise" detail="The service date and committed delivery window." />
        <div className="field-grid two"><Field label="Order reference"><input required value={draft.reference} onChange={(event) => onUpdate("reference", event.target.value)} placeholder="UF-10452" /></Field><Field label="Service date"><input required type="date" value={draft.serviceDate} onChange={(event) => onUpdate("serviceDate", event.target.value)} /></Field></div>
        <div className="field-grid two"><Field label="Window starts"><input required type="datetime-local" value={draft.windowStart} onChange={(event) => onUpdate("windowStart", event.target.value)} /></Field><Field label="Window ends"><input required type="datetime-local" value={draft.windowEnd} onChange={(event) => onUpdate("windowEnd", event.target.value)} /></Field></div>
        <p className="timezone-note">Times are committed in {selectedTenant.timezone}.</p>
      </section>

      <section className="form-card">
        <CardTitle number="04" title="Items & handling" detail="Physical truth carried into pickup and POD." />
        <div className="manifest-list">{draft.items.map((item, index) => <div className="manifest-row" key={index}><span className="line-number">{String(index + 1).padStart(2, "0")}</span><Field label="Item"><input required value={item.description} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, description: event.target.value } : entry))} placeholder="Bouquet, cake, flower box…" /></Field><Field label="Qty"><input required min="1" type="number" value={item.quantity} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, quantity: event.target.value } : entry))} /></Field><Field label="Handling note" optional><input value={item.handlingNote} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, handlingNote: event.target.value } : entry))} placeholder="Fragile, keep upright" /></Field><button className="remove-line" type="button" disabled={draft.items.length === 1} onClick={() => onUpdate("items", draft.items.filter((_, itemIndex) => itemIndex !== index))} aria-label={`Remove item ${index + 1}`}>×</button></div>)}</div>
        <button className="add-line" type="button" onClick={() => onUpdate("items", [...draft.items, { description: "", quantity: "1", handlingNote: "" }])}>+ Add item</button>
        <Field label="Delivery instruction" optional><textarea rows={2} value={draft.note} onChange={(event) => onUpdate("note", event.target.value)} placeholder="Call before arrival, reception handoff…" /></Field>
        <label className="check-row"><input type="checkbox" checked={draft.isSurprise} onChange={(event) => onUpdate("isSurprise", event.target.checked)} /><span><strong>Surprise or gift delivery</strong><small>Protect buyer details from recipient-facing communication.</small></span></label>
      </section>

      <div className="form-actions"><div><ShieldIcon /><span>Authorized as <strong>{roleLabel(selectedTenant.role)}</strong></span></div><button className="primary-action" disabled={submitting || selectedTenant.role === "viewer"}>{submitting ? "Creating delivery…" : selectedTenant.role === "viewer" ? "Viewer cannot create" : "Add delivery"}<ArrowIcon /></button></div>
    </form>}
  </div>;
}

function SuccessPanel({ success, onReset }: { success: SubmissionSuccess; onReset: () => void }) {
  return <section className="success-panel"><div className="success-icon"><CheckIcon /></div><p className="eyebrow">COMMAND COMMITTED</p><h2>Delivery {success.reference} is ready for planning.</h2><p>The server created the Delivery, Stop, promise and physical manifest in one transaction.</p><dl><div><dt>Delivery ID</dt><dd>{success.deliveryId}</dd></div><div><dt>State</dt><dd>{success.deliveryState}</dd></div><div><dt>Request</dt><dd>{success.deduplicated ? "Safe retry · existing delivery returned" : "New delivery committed"}</dd></div></dl><button className="primary-action" onClick={onReset}>Add another delivery<ArrowIcon /></button></section>;
}

function Field({ label, optional, children }: { label: string; optional?: boolean; children: ReactNode }) { return <label className="field"><span>{label}{optional && <small>Optional</small>}</span>{children}</label>; }
function CardTitle({ number, title, detail }: { number: string; title: string; detail: string }) { return <div className="card-title"><div><span>{number}</span><div><h2>{title}</h2><p>{detail}</p></div></div></div>; }
function ShieldIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 5 6v5c0 4.6 2.9 8 7 10 4.1-2 7-5.4 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/></svg>; }
function PinIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>; }
function AlertIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v5M12 17h.01"/></svg>; }
function ArrowIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M14 7l5 5-5 5"/></svg>; }
function CheckIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>; }
