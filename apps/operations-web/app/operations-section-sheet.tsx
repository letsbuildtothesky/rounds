"use client";

export type OperationsSectionKey = "action" | "deliveries" | "drivers" | "history";

const sectionLabels: Record<OperationsSectionKey, { label: string; detail: string }> = {
  action: { label: "Dispatch", detail: "Live work, planning and exceptions" },
  deliveries: { label: "Deliveries", detail: "Search and inspect canonical delivery truth" },
  drivers: { label: "Drivers", detail: "Own-team capacity, shifts and current work" },
  history: { label: "History", detail: "Committed handoffs and POD evidence" },
};

type Props = {
  open: boolean;
  current: OperationsSectionKey;
  onClose: () => void;
  onSelect: (section: OperationsSectionKey) => void;
  onSignOut: () => void;
};

export function OperationsSectionSheet({ open, current, onClose, onSelect, onSignOut }: Props) {
  if (!open) return null;

  return <div className="operations-section-scrim" onClick={onClose}>
    <section className="operations-section-sheet" role="dialog" aria-modal="true" aria-labelledby="operations-section-title" onClick={(event) => event.stopPropagation()}>
      <header>
        <div><small>ROUNDS OPERATIONS</small><h2 id="operations-section-title">Where do you want to work?</h2></div>
        <button type="button" onClick={onClose} aria-label="Close Operations navigation"><CloseIcon /></button>
      </header>
      <nav aria-label="Operations destinations">
        {(Object.keys(sectionLabels) as OperationsSectionKey[]).map((section) => {
          const item = sectionLabels[section];
          return <button key={section} type="button" className={current === section ? "active" : ""} aria-current={current === section ? "page" : undefined} onClick={() => { onSelect(section); onClose(); }}>
            <span><b>{item.label}</b><small>{item.detail}</small></span><ArrowIcon />
          </button>;
        })}
      </nav>
      <button className="operations-section-signout" type="button" onClick={onSignOut}>Sign out</button>
    </section>
  </div>;
}

export function OperationsMenuIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>;
}

function ArrowIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M14 7l5 5-5 5" /></svg>;
}

function CloseIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg>;
}
