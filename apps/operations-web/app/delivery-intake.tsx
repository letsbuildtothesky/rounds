"use client";

import type { OperationsSession, OperationsTenant } from "@rounds/contracts";
import type { FormEvent, ReactNode } from "react";
import { useState } from "react";
import type { DeliveryFormDraft } from "../src/delivery-form";
import { DestinationPinPicker, type DestinationCoordinate } from "./destination-pin-picker";

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
  onCancel: () => void;
};

const bangkokMapStart: DestinationCoordinate = { latitude: 13.7563, longitude: 100.5018 };

function draftCoordinate(draft: DeliveryFormDraft): DestinationCoordinate | null {
  const latitude = Number(draft.latitude);
  const longitude = Number(draft.longitude);
  if (!draft.latitude.trim() || !draft.longitude.trim()
    || !Number.isFinite(latitude) || latitude < -90 || latitude > 90
    || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) return null;
  return { latitude, longitude };
}

function roleLabel(role: OperationsTenant["role"]): string {
  return role.split("_").map((word) => word[0]!.toUpperCase() + word.slice(1)).join(" ");
}

export function DeliveryIntake({ operationsSession, selectedTenant, draft, submitting, error, success, onSubmit, onUpdate, onChooseTenant, onReset, onCancel }: Props) {
  const pickup = selectedTenant.locations.find((location) => location.id === draft.pickupLocationId);
  const selectedCoordinate = draftCoordinate(draft);
  const [pinPickerOpen, setPinPickerOpen] = useState(false);

  return <><div className="v45-delivery-intake">
    {error && <div className="alert error" role="alert"><AlertIcon /><div><strong>Couldn&apos;t continue</strong><span>{error}</span></div></div>}
    {success ? <SuccessPanel success={success} onReset={onReset} /> : <form className="delivery-form" onSubmit={onSubmit}>
      <div className="manual-intake-label">Delivery details</div>
      <section className="form-card">
        <SectionTitle>Recipient</SectionTitle>
        <div className="field-grid two"><Field label="Recipient name"><input required value={draft.recipientName} onChange={(event) => onUpdate("recipientName", event.target.value)} placeholder="Full name" /></Field><Field label="Recipient phone"><input required type="tel" value={draft.recipientPhone} onChange={(event) => onUpdate("recipientPhone", event.target.value)} placeholder="+66" /></Field></div>
        <Field label="Delivery address"><textarea required rows={3} value={draft.address} onChange={(event) => onUpdate("address", event.target.value)} placeholder="Building, street, district, Bangkok" /></Field>
        <div className={`intake-pin ${selectedCoordinate ? "selected" : "missing"}`}>
          <div className="intake-pin-copy"><PinIcon /><div><strong>Operational destination pin</strong><span id="intake-pin-help">Place the confirmed vehicle arrival or delivery point on the real map.</span></div></div>
          <button type="button" aria-describedby="intake-pin-help" onClick={() => setPinPickerOpen(true)}>{selectedCoordinate ? "Adjust pin" : "Set pin on map"}</button>
          <div className="intake-pin-state" role="status"><b>{selectedCoordinate ? "Pin selected" : "Required before adding delivery"}</b><span>{selectedCoordinate ? `${selectedCoordinate.latitude.toFixed(5)}, ${selectedCoordinate.longitude.toFixed(5)}` : "No destination pin selected"}</span></div>
        </div>
        <Field label="Entrance / access note" optional><input value={draft.accessNote} onChange={(event) => onUpdate("accessNote", event.target.value)} placeholder="Entrance, floor, reception, parking" /></Field>
        <div className="relationship-row"><div><strong>Ordered by</strong><span>Is the buyer also the recipient?</span></div><div className="segmented"><button type="button" className={draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => onUpdate("buyerSameAsRecipient", true)}>Same person</button><button type="button" className={!draft.buyerSameAsRecipient ? "selected" : ""} onClick={() => onUpdate("buyerSameAsRecipient", false)}>Someone else</button></div></div>
        {!draft.buyerSameAsRecipient && <div className="field-grid two"><Field label="Buyer name"><input required value={draft.buyerName} onChange={(event) => onUpdate("buyerName", event.target.value)} /></Field><Field label="Buyer phone"><input required type="tel" value={draft.buyerPhone} onChange={(event) => onUpdate("buyerPhone", event.target.value)} placeholder="+66" /></Field></div>}
      </section>

      <section className="form-card">
        <SectionTitle>Order &amp; promise</SectionTitle>
        <div className="field-grid two"><Field label="Order reference"><input required value={draft.reference} onChange={(event) => onUpdate("reference", event.target.value)} placeholder="UF-10452" /></Field><Field label="Service date"><input required type="date" value={draft.serviceDate} onChange={(event) => onUpdate("serviceDate", event.target.value)} /></Field></div>
        <div className="field-grid two"><Field label="Window starts"><input required type="datetime-local" value={draft.windowStart} onChange={(event) => onUpdate("windowStart", event.target.value)} /></Field><Field label="Window ends"><input required type="datetime-local" value={draft.windowEnd} onChange={(event) => onUpdate("windowEnd", event.target.value)} /></Field></div>
        <p className="timezone-note">Times are committed in {selectedTenant.timezone}.</p>
      </section>

      <section className="form-card">
        <SectionTitle>Items &amp; handling</SectionTitle>
        <div className="manifest-list">{draft.items.map((item, index) => <div className="manifest-row" key={index}><span className="line-number">{String(index + 1).padStart(2, "0")}</span><Field label="Item"><input required value={item.description} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, description: event.target.value } : entry))} placeholder="Bouquet, cake, flower box…" /></Field><Field label="Qty"><input required min="1" type="number" value={item.quantity} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, quantity: event.target.value } : entry))} /></Field><Field label="Handling note" optional><input value={item.handlingNote} onChange={(event) => onUpdate("items", draft.items.map((entry, itemIndex) => itemIndex === index ? { ...entry, handlingNote: event.target.value } : entry))} placeholder="Fragile, keep upright" /></Field><button className="remove-line" type="button" disabled={draft.items.length === 1} onClick={() => onUpdate("items", draft.items.filter((_, itemIndex) => itemIndex !== index))} aria-label={`Remove item ${index + 1}`}>×</button></div>)}</div>
        <button className="add-line" type="button" onClick={() => onUpdate("items", [...draft.items, { description: "", quantity: "1", handlingNote: "" }])}>+ Add item</button>
        <Field label="Delivery instruction" optional><textarea rows={2} value={draft.note} onChange={(event) => onUpdate("note", event.target.value)} placeholder="Call before arrival, reception handoff…" /></Field>
        <label className="check-row"><input type="checkbox" checked={draft.isSurprise} onChange={(event) => onUpdate("isSurprise", event.target.checked)} /><span><strong>Surprise or gift delivery</strong><small>Protect buyer details from recipient-facing communication.</small></span></label>
      </section>

      <section className="form-card context-card">
        <SectionTitle>Pickup</SectionTitle>
        <div className="field-grid two">
          <Field label="Business"><select value={selectedTenant.id} onChange={(event) => onChooseTenant(event.target.value)}>{operationsSession.tenants.map((tenant) => <option key={tenant.id} value={tenant.id}>{tenant.displayName}</option>)}</select></Field>
          <Field label="Pickup location"><select required value={draft.pickupLocationId} onChange={(event) => onUpdate("pickupLocationId", event.target.value)}><option value="">Choose pickup</option>{selectedTenant.locations.map((location) => <option key={location.id} value={location.id}>{location.displayName}</option>)}</select></Field>
        </div>
        {pickup && <div className="pickup-readout"><PinIcon /><div><small>PICKUP FROM BUSINESS PROFILE</small><strong>{pickup.displayName}</strong><span>{pickup.rawAddress}<br />{pickup.pickupContactName} · {pickup.pickupContactPhone}</span></div></div>}
      </section>

      <div className="form-actions"><button className="primary-action" disabled={submitting || selectedTenant.role === "viewer"}>{submitting ? "Creating delivery…" : selectedTenant.role === "viewer" ? `${roleLabel(selectedTenant.role)} cannot create` : "Add delivery"}</button><button className="secondary-action" type="button" disabled={submitting} onClick={onCancel}>Cancel</button></div>
    </form>}
  </div>{pinPickerOpen && <DestinationPinPicker mode="create" initial={selectedCoordinate ?? bangkokMapStart} onCancel={() => setPinPickerOpen(false)} onConfirm={(coordinate) => { onUpdate("latitude", String(coordinate.latitude)); onUpdate("longitude", String(coordinate.longitude)); setPinPickerOpen(false); }} />}</>;
}

function SuccessPanel({ success, onReset }: { success: SubmissionSuccess; onReset: () => void }) {
  return <section className="success-panel"><div className="success-icon"><CheckIcon /></div><p className="eyebrow">COMMAND COMMITTED</p><h2>Delivery {success.reference} is ready for planning.</h2><p>The server created the Delivery, Stop, promise and physical manifest in one transaction.</p><dl><div><dt>Delivery ID</dt><dd>{success.deliveryId}</dd></div><div><dt>State</dt><dd>{success.deliveryState}</dd></div><div><dt>Request</dt><dd>{success.deduplicated ? "Safe retry · existing delivery returned" : "New delivery committed"}</dd></div></dl><button className="primary-action" onClick={onReset}>Add another delivery</button></section>;
}

function Field({ label, optional, children }: { label: string; optional?: boolean; children: ReactNode }) { return <label className="field"><span>{label}{optional && <small>Optional</small>}</span>{children}</label>; }
function SectionTitle({ children }: { children: ReactNode }) { return <h3 className="intake-section-title">{children}</h3>; }
function PinIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>; }
function AlertIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v5M12 17h.01"/></svg>; }
function CheckIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>; }
