'use client';

import React, {useEffect, useRef, useState, type ReactNode} from 'react';
import {OperationsPickupIssues} from './operations-pickup-issues';
import {blockedReason, canSubmitReply, issueErrorText, issueTitle, replyActions} from './pickup-issue-view';
import {filterPickupIssues} from './pickup-issue-search';
import {reportsForDelivery} from './dispatch-pickup-action';

/** Phase39 detail/issue-panel/action-dialog port. No sample job, permission,
 * map or customer contact is invented to fill fields absent from this query. */
export function PickupIssueDrawer({controller, layout = 'drawer', onDeliveries, entryDeliveryId=null}: {controller: OperationsPickupIssues; layout?: 'drawer' | 'board'; onDeliveries?: () => void; entryDeliveryId?:string|null}) {
  const [state, setState] = useState(() => controller.state);
  // A sole exact match may open for review; multiple reports require selection.
  // This initializer runs only on entry, never reopens a drawer after closing.
  const [selected, setSelected] = useState<string | null>(()=>{
    if(!entryDeliveryId||controller.state.phase!=='ready')return null;
    const matches=reportsForDelivery(controller.state.snapshot?.data.issues??[],entryDeliveryId);
    return matches.length===1?matches[0]!.issue_id:null;
  });
  const [deliveryFilter,setDeliveryFilter]=useState(entryDeliveryId);
  const [editing, setEditing] = useState(false);
  const [reviewClose, setReviewClose] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);
  const opener = useRef<HTMLButtonElement | null>(null);
  const heading = useRef<HTMLHeadingElement | null>(null);
  const pendingBefore = useRef<string | null>(null);
  const [confirmed, setConfirmed] = useState(false);
  const [query, setQuery] = useState('');
  const [mobileMap, setMobileMap] = useState(false);
  const search = useRef<HTMLInputElement | null>(null);
  const board = layout === 'board';
  const returnToList = () => {
    const row = opener.current;
    if (row?.isConnected && row.getClientRects().length) row.focus();
    else search.current?.focus();
  };
  useEffect(() => {
    const sync = () => {
      const next = controller.state;
      const recorded=!!pendingBefore.current && !next.pendingCommandId && !next.draft && next.phase !== 'closed';
      pendingBefore.current = next.pendingCommandId;
      setState(next);
      if(recorded)setConfirmed(true);
    };
    const unsubscribe = controller.subscribe(sync); sync();
    const warn = (e: BeforeUnloadEvent) => { if (controller.state.hasUnsavedWork) { e.preventDefault(); e.returnValue = ''; } };
    window.addEventListener('beforeunload', warn);
    const shortcut = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (board && e.key === '/' && !e.ctrlKey && !e.metaKey && !e.altKey && !e.isComposing &&
        !target?.closest('input,textarea,select,[contenteditable=true],dialog') && !selected && !mobileMap) {
        e.preventDefault(); search.current?.focus();
      }
    };
    window.addEventListener('keydown', shortcut);
    return () => { unsubscribe(); window.removeEventListener('beforeunload', warn); window.removeEventListener('keydown', shortcut); };
  }, [controller, board, selected, mobileMap]);
  useEffect(() => {
    if (selected) heading.current?.focus();
    else if (opener.current) returnToList();
  }, [selected, confirmed]);
  const issue = state.snapshot?.data.issues.find(i => i.issue_id === selected);
  const draft = state.draft;
  const run = async (fn: () => void | Promise<void>) => {
    setLocalError(null);
    try { await fn(); } catch (e) { setLocalError(e instanceof Error ? e.message : 'SOURCE_UNAVAILABLE'); }
  };
  const refresh = () => void run(() => controller.refresh());
  const close = () => {
    if (state.hasUnsavedWork) { setReviewClose(true); return; }
    setSelected(null);
  };
  const openDraft = () => { if (draft) { setSelected(draft.issueId); setEditing(true); } };
  const error = issueErrorText(localError ?? state.errorCode ?? state.recoveryError);
  const locked = state.phase !== 'ready' || state.sending || !!state.pendingCommandId || state.draftNeedsReview || !!state.recoveryError;
  const issues = state.snapshot?.data.issues ?? [];
  const scopedIssues=reportsForDelivery(issues,deliveryFilter);
  const visible = filterPickupIssues(scopedIssues, query);
  // Revocation removes identifiers, selected detail, search text and dialogs,
  // not merely the row data. The verified host will require a new controller.
  if (state.phase === 'closed') return <section className="pickup-issues" aria-label="Pickup issues"><Status state="closed" lastKnown={false} error={null}/>{onDeliveries && <button className="secondary-button" onClick={onDeliveries}>Back to deliveries</button>}</section>;
  return <section className={`pickup-issues${board ? ' pickup-board' : ''}`} data-detail={!!selected} data-mobile-map={mobileMap} aria-label="Pickup issues">
    {board && <nav className="dispatch-tablet-controls" aria-label="Workspace surface"><button aria-pressed={!mobileMap} onClick={() => setMobileMap(false)}>Pickup issues</button><button aria-pressed={mobileMap} onClick={() => setMobileMap(true)}>Map</button></nav>}
    <div className="issue-list-panel" hidden={!board && selected !== null}>
      {board ? <header className="dispatch-delivery-head">
        {onDeliveries && <button className="back-button" onClick={onDeliveries}><Arrow back/>Deliveries</button>}
        <div className="dispatch-panel-title"><h2>Pickup issues{state.snapshot && <span className="dispatch-soft-count" aria-label={`${issues.length} pickup reports${state.lastKnown ? ', last known' : ''}`}>{issues.length}</span>}</h2><button className="secondary-button" onClick={refresh} disabled={state.phase === 'loading'}>Refresh</button></div>
        <p className="dispatch-queue-scope">Own-team reports · Not the full delivery board</p>
        {deliveryFilter&&<p className="form-help">Reports for the selected delivery. <button className="dispatch-quiet-button" onClick={()=>{setDeliveryFilter(null);setQuery('');}}>Show all pickup reports</button></p>}
        <label className="dispatch-search"><svg className="icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg><input ref={search} type="search" aria-label="Search pickup reports" placeholder="Search pickup reports" maxLength={200} value={query} onChange={e => setQuery(e.target.value)}/><kbd aria-hidden="true">/</kbd></label>
      </header> : <header className="detail-top"><h1>Pickup issues</h1><button className="secondary-button" onClick={refresh} disabled={state.phase === 'loading'}>Refresh</button></header>}
      <div className="detail-scroll">
        <p className="form-help">{controller.scope.serviceDate} · Own-team pickup</p>
        <Status state={state.phase} lastKnown={state.lastKnown} error={error}/>
        {state.hasUnsavedWork && <button className="dialog-choice" onClick={openDraft}><span className="choice-copy"><b>{state.pendingCommandId ? 'Check pending reply' : 'Review saved draft'}</b><small>No reply is sent automatically.</small></span><Arrow/></button>}
        {state.phase === 'ready' && state.snapshot?.data.issues.length === 0 && <div className="empty-state"><b>No pickup issues</b><p>No own-team pickup reports were returned for this date.</p></div>}
        {board && state.snapshot && issues.length > 0 && visible.length === 0 && <div className="empty-state"><b>No matching pickup reports</b><p>Search only covers the reports loaded for this date{deliveryFilter?' and selected delivery':''}.</p><button className="secondary-button" onClick={() => { setQuery(''); search.current?.focus(); }}>Clear search</button></div>}
        {visible.map(i => <button key={i.issue_id} className="delivery-card issue-row" aria-pressed={selected === i.issue_id} onClick={e => { opener.current = e.currentTarget; setSelected(i.issue_id); setMobileMap(false); setConfirmed(false); }}>
          <span className="card-top">{i.display?.delivery_reference ?? (i.delivery_id ? 'Delivery reference unavailable' : 'Round-only report')}</span>
          <span className="card-name">{i.display?.recipient_name ?? issueTitle(i)}</span>
          {i.display?.destination_address && <span className="card-address">{i.display.destination_address}</span>}
          <span className="card-meta"><span className="card-status issue">{issueTitle(i)}</span></span>
          <span className="card-next"><span>Review pickup report</span><Arrow/></span>
        </button>)}
      </div>
      {board && <footer className="dispatch-delivery-footer" aria-live="polite">{state.snapshot ? `${visible.length} of ${issues.length} pickup reports${state.lastKnown ? ' · Last known' : ''}` : 'Waiting for authorized pickup reports'}</footer>}
    </div>
    {board && <section className="dispatch-map-stage" aria-label="Workspace map">
      <div className="dispatch-map-unavailable"><b>The map is not connected.</b><p>This pickup-report query does not supply map positions or routes. No sample map, driver location or rain is shown.</p></div>
    </section>}
    {selected && <aside className="delivery-detail" aria-labelledby="pickup-issue-heading" onKeyDown={e => { if (e.key === 'Escape' && !editing && !reviewClose) { e.stopPropagation(); close(); } }}>
      <header className="detail-top"><button className="back-button" onClick={close}><Arrow back/>Pickup issues</button><span>{issue?.display?.delivery_reference ?? issue?.state ?? 'Review required'}</span></header>
      <div className="detail-scroll">
        <div className="detail-kicker"><span>{controller.scope.serviceDate}</span><span>Own-team pickup</span></div>
        <h2 className="detail-heading" id="pickup-issue-heading" ref={heading} tabIndex={-1}>{issue?.display?.recipient_name ?? (issue ? issueTitle(issue) : 'Saved reply')}</h2>
        {issue?.display?.destination_address && <p className="detail-address">{issue.display.destination_address}</p>}
        <Status state={state.phase} lastKnown={state.lastKnown} error={error}/>
        {confirmed && <p className="reply-confirmed" role="status">Reply recorded. This does not confirm pickup or release the driver.</p>}
        <div className="issue-panel"><b>{issue ? issueTitle(issue) : 'Driver report'}</b><p className="exact-text">{issue?.report.detail ?? (issue ? issue.report.reason_code : 'This issue is not in the current result. Review the original saved reply below.')}</p></div>
        {issue?.display && <>
          <section className="detail-section"><h3 className="section-label">Pickup site</h3><p className="detail-address">{issue.display.pickup_site_name ?? 'Pickup site name unavailable'}</p></section>
          <section className="detail-section"><h3 className="section-label">Reported by</h3><div className="assignment"><span className="driver-avatar" aria-hidden="true"><svg className="icon" viewBox="0 0 24 24"><circle cx="12" cy="7" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/></svg></span><div><b>{issue.display.reported_driver_name ?? 'Driver name unavailable'}</b><small>Original pickup report</small></div></div></section>
          <p className="form-help">Names and address are current details, not a change to the original assignment.</p>
        </>}
        <section className="detail-section"><h3 className="section-label">Original work</h3><dl className="issue-identities"><dt>Issue</dt><dd>{selected}</dd><dt>Round</dt><dd>{issue?.round_id ?? draft?.roundId}</dd><dt>Assignment</dt><dd>{issue?.assignment_id ?? draft?.assignmentId}</dd><dt>Delivery</dt><dd>{issue?.delivery_id ?? draft?.deliveryId ?? 'Round-only report'}</dd></dl></section>
        {!!issue?.report.asset_ids.length && <section className="detail-section"><h3 className="section-label">Evidence</h3><p className="form-help">{issue.report.asset_ids.length} photo attached to the original report. Secure photo viewing is not connected in this drawer yet.</p></section>}
        {issue?.decisions.map(decision => <section className="detail-section" key={decision.id}><h3 className="section-label">Latest instruction{state.lastKnown ? ' · Last known' : ''}</h3><p className="exact-text">{decision.instructions}</p><p className="form-help">{decision.decided_at}</p></section>)}
        {issue && blockedReason(issue) && <p className="form-error">{blockedReason(issue)}</p>}
        {state.draftNeedsReview && !state.pendingCommandId && <p className="form-error">Refresh and review the original saved reply before sending. It may no longer match the current issue.</p>}
        {state.snapshot && <p className="form-help">Last checked: {state.snapshot.as_of}</p>}
      </div>
      <footer className="detail-actions">
        <button className="primary-button" disabled={!draft && (!issue?.allowed_actions.length || state.phase !== 'ready')} onClick={() => {
          if (draft && draft.issueId !== selected) { openDraft(); return; }
          void run(() => { if (!draft && issue) controller.saveDraft(issue.issue_id, issue.allowed_actions[0]!, '', ''); setEditing(true); setConfirmed(false); });
        }}>{draft ? (state.pendingCommandId ? 'Check pending reply' : 'Review saved draft') : 'Reply to driver'}<Arrow/></button>
        <p>Instructions only · No pickup, readiness or release change.</p>
      </footer>
    </aside>}
    {editing && draft && <Modal title="Reply to driver" onClose={() => { if (state.hasUnsavedWork) setReviewClose(true); else setEditing(false); }}>
      <form onSubmit={e => { e.preventDefault(); void run(() => controller.submitDraft()); }}>
        <div className="dialog-body">
          <p className="action-intro">Give instructions for the original pickup report. The internal reason is not shown to the driver.</p>
          {error && <p className="form-error" role="alert">{error}</p>}
          {state.draftNeedsReview && !state.pendingCommandId && <p className="form-error">Refresh and review this draft. If its original version has changed, discard it explicitly before starting a new reply.</p>}
          {state.pendingCommandId && <div className="issue-panel" role="status"><b>{state.sending ? 'Checking reply…' : 'Reply result not confirmed'}</b><p>Keep the original reply. Check its status to recover the result; do not create a replacement.</p></div>}
          <fieldset disabled={locked} className="form-fields">
            <legend>Action</legend><div className="action-stack">{replyActions.map(action => <button type="button" key={action.id} className="dialog-choice" aria-pressed={draft.action === action.id} disabled={locked || !issue?.allowed_actions.includes(action.id)} onClick={() => void run(() => controller.saveDraft(draft.issueId, action.id, draft.instructions, draft.reason))}><span className="choice-copy"><b>{action.label}</b></span>{draft.action === action.id && <span aria-hidden="true">✓</span>}</button>)}</div>
            <label>Driver instructions<textarea value={draft.instructions} rows={4} onChange={e => void run(() => controller.saveDraft(draft.issueId, draft.action, e.target.value, draft.reason))} aria-describedby="instruction-help"/></label>
            <p id="instruction-help" className="form-help">Sent exactly as written · {[...draft.instructions].length}/4,000</p>
            <label>Internal reason<textarea value={draft.reason} rows={3} onChange={e => void run(() => controller.saveDraft(draft.issueId, draft.action, draft.instructions, e.target.value))}/></label>
            <p className="form-help">Operations only · {[...draft.reason].length}/4,000</p>
          </fieldset>
        </div>
        <footer className="dialog-footer">
          <button type="button" className="secondary-button" onClick={() => setReviewClose(true)}>Close</button>
          {state.pendingCommandId ? <button type="button" className="primary-button" disabled={state.sending || !!state.recoveryError} onClick={() => void run(() => controller.retry())}>{state.sending ? 'Checking…' : 'Check reply status'}</button> : <button type="submit" className="primary-button" disabled={!canSubmitReply(state)}>Send instructions</button>}
        </footer>
      </form>
    </Modal>}
    {reviewClose && <Modal title={state.pendingCommandId ? 'Keep pending reply?' : 'Keep this draft?'} onClose={() => setReviewClose(false)}>
      <div className="dialog-body"><p className="action-intro">{state.pendingCommandId ? 'The result is not confirmed. The original reply must remain available for a status check.' : 'Keep your draft in this tab, or explicitly discard it. Closing does not send it.'}</p>{state.recoveryError && <p className="form-error">Recovery is unavailable. Keep this tab open; closing may lose unsaved text.</p>}</div>
      <footer className="dialog-footer">
        <button className="secondary-button" onClick={() => setReviewClose(false)}>Continue reviewing</button>
        {!state.pendingCommandId && <button className="secondary-button" disabled={state.sending || !!state.recoveryError} onClick={() => void run(() => { controller.discardDraft(); setReviewClose(false); setEditing(false); setSelected(null); opener.current?.focus(); })}>Discard draft</button>}
        <button className="primary-button" disabled={!!state.recoveryError || !state.reloadRecovery} onClick={() => { setReviewClose(false); setEditing(false); setSelected(null); opener.current?.focus(); }}>Keep and close</button>
      </footer>
    </Modal>}
  </section>;
}

function Status({state, lastKnown, error}: {state: string; lastKnown: boolean; error: string | null}) {
  return <div aria-live="polite">{state === 'loading' && <p className="form-help">Refreshing issues…{lastKnown ? ' Previous information is last known.' : ''}</p>}{state === 'closed' && <p className="form-error">This session is closed. Sign in again to continue.</p>}{error && <p className="form-error" role="alert">{error}</p>}</div>;
}
function Arrow({back = false}: {back?: boolean}) {
  return <svg className="icon" viewBox="0 0 24 24" aria-hidden="true"><path d={back ? 'm10 5-7 7 7 7M3 12h18' : 'm9 5 7 7-7 7'}/></svg>;
}
function Modal({title, onClose, children}: {title: string; onClose: () => void; children: ReactNode}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const latestClose = useRef(onClose); latestClose.current = onClose;
  useEffect(() => {
    const node = dialog.current!;
    const previous = document.activeElement as HTMLElement | null;
    node.showModal();
    return () => { node.close(); if (previous?.isConnected) previous.focus(); };
  }, []);
  return <dialog className="issue-action-dialog" ref={dialog} aria-label={title} onCancel={e => { e.preventDefault(); latestClose.current(); }}>
    <header className="dialog-header"><h2>{title}</h2><button type="button" className="close-button" aria-label="Close dialog" onClick={onClose}>×</button></header>{children}
  </dialog>;
}
