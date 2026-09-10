'use client';

import React, {useEffect, useRef, useState} from 'react';
import {OperationsPickupIssues} from './operations-pickup-issues';
import {PickupIssueDrawer} from './pickup-issue-drawer';
import {OperationsDeliveryBoard} from './operations-delivery-board';
import {DeliveryBoardView, useDeliveryBoard} from './delivery-board-view';
import type {DispatchMapFactory} from './dispatch-map-controller';
import {pickupActionReports} from './dispatch-pickup-action';
import {OperationsManualIntake} from './operations-manual-intake';
import {ManualIntakeForm} from './manual-intake-form';

/** The supplied Phase39 shell, not a second data/controller implementation.
 * Delivery reads and pickup reports have separate authority. No workspace,
 * positions, promises or reply permissions are inferred from a report list. */
export function DispatchWorkspace({controller, deliveryController,mapboxToken,mapFactory,intakeController}: {controller: OperationsPickupIssues; deliveryController?: OperationsDeliveryBoard;mapboxToken?:string;mapFactory?:DispatchMapFactory;intakeController?:OperationsManualIntake}) {
  // Keep the previous report-only fixture/entry compatible. The configured
  // board supplies both controllers, with identical identity but separate grants.
  if (deliveryController) return <ConnectedDispatchWorkspace controller={controller} deliveryController={deliveryController} mapboxToken={mapboxToken} mapFactory={mapFactory} intakeController={intakeController}/>;
  return <DispatchShell serviceDate={controller.scope.serviceDate}><PickupIssueDrawer controller={controller} layout="board"/></DispatchShell>;
}
function ConnectedDispatchWorkspace({controller,deliveryController,mapboxToken,mapFactory,intakeController}: {controller:OperationsPickupIssues;deliveryController:OperationsDeliveryBoard;mapboxToken?:string;mapFactory?:DispatchMapFactory;intakeController?:OperationsManualIntake}) {
  const [intakeOpen,setIntakeOpen]=useState(false);
  const sameIntakeScope=!intakeController||(['principalId','tenantId','cityId','sessionEpoch'] as const).every(k=>intakeController.scope[k]===deliveryController.scope[k]);
  const [dateReader,setDateReader]=useState<OperationsDeliveryBoard|null>(null);
  const ownedDateReader=useRef<OperationsDeliveryBoard|null>(null);
  const planDate=useRef(deliveryController.scope.serviceDate);
  const activeBoard=dateReader??deliveryController;
  const currentBoard=useRef(activeBoard);currentBoard.current=activeBoard;
  const board = useDeliveryBoard(activeBoard);
  const [reports,setReports] = useState(false);
  const [reportDelivery,setReportDelivery] = useState<string|null>(null);
  const [deliveryMode,setDeliveryMode]=useState<'plan'|'now'>('plan');
  const [reportState,setReportState] = useState(() => controller.state);
  const sameScope = ['principalId','tenantId','cityId','serviceDate','sessionEpoch'].every(k => controller.scope[k as keyof typeof controller.scope] === deliveryController.scope[k as keyof typeof deliveryController.scope]);
  useEffect(() => {
    let pending=controller.state.pendingCommandId;
    const sync=()=>{
      const next=controller.state;
      const recorded=!!pending&&!next.pendingCommandId&&!next.draft&&next.phase!=='closed';
      pending=next.pendingCommandId;setReportState(next);
      // Observe the controller even when its drawer has been closed. Only a
      // committed receipt clears both pending and draft; rejection keeps draft.
      if(recorded)void currentBoard.current.refresh().catch(()=>{/* No optimistic state change. */});
    };
    const off=controller.subscribe(sync);sync();return off;
  },[controller]);
  useEffect(()=>()=>{ownedDateReader.current?.dispose();ownedDateReader.current=null;},[deliveryController]);
  const selectDate=(date:string)=>{
    if(date===activeBoard.scope.serviceDate)return;
    // Validate/create before dropping the current read. Never mutate the issue
    // controller, its original date, draft, receipt or pending command bytes.
    const next=deliveryController.forServiceDate(date);
    ownedDateReader.current?.dispose();ownedDateReader.current=next;setDateReader(next);
    void next.refresh().catch(()=>{/* Closed authority is rendered by the reader. */});
  };
  const selectMode=(mode:'plan'|'now')=>{
    const date=mode==='now'?board.snapshot?.data.now?.current_service_date:planDate.current;
    if(!date)return;
    selectDate(date);setDeliveryMode(mode);
  };
  useEffect(() => {
    const warn=(e:BeforeUnloadEvent)=>{if(controller.state.hasUnsavedWork||intakeController?.state.dirty||intakeController?.state.pending){e.preventDefault();e.returnValue='';}};
    window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);
  },[controller,intakeController]);
  if (!sameScope||!sameIntakeScope) return <section role="alert">The delivery and pickup-report scopes do not match. Reopen this connection.</section>;
  const context=board.snapshot?.data;
  const pickupActions=pickupActionReports(activeBoard,controller);
  const openPickupAction=(deliveryId:string)=>{
    // Recheck at click time: a stale rendered link never selects foreign work.
    if(!pickupActionReports(activeBoard,controller).has(deliveryId))return;
    setReportDelivery(deliveryId);setReports(true);
  };
  return <DispatchShell serviceDate={reports?controller.scope.serviceDate:activeBoard.scope.serviceDate} workspace={context?.workspace.name ?? undefined} city={context?.city.name ?? undefined} deliveryMode lastKnown={board.lastKnown}>
    <div className="dispatch-connected-content">
      <div className="dispatch-surface" hidden={reports}><DeliveryBoardView key={activeBoard.scope.serviceDate} controller={activeBoard} mode={deliveryMode} onMode={selectMode} onServiceDate={date=>{selectDate(date);planDate.current=date;}} focusDate={!!dateReader&&deliveryMode==='plan'} reportDate={controller.scope.serviceDate} reportsAvailable={reportState.phase !== 'closed'} active={!reports} onReports={()=>{setReportDelivery(null);setReports(true);}} pickupActions={pickupActions} onPickupAction={openPickupAction} mapboxToken={mapboxToken} mapFactory={mapFactory} onAddDelivery={intakeController?()=>setIntakeOpen(true):undefined}/></div>
      {reports && <div className="dispatch-surface"><PickupIssueDrawer controller={controller} layout="board" entryDeliveryId={reportDelivery} onDeliveries={()=>setReports(false)}/></div>}
      {intakeController&&<ManualIntakeForm controller={intakeController} open={intakeOpen} onClose={()=>setIntakeOpen(false)}/>}
    </div>
  </DispatchShell>;
}
function DispatchShell({children,serviceDate,workspace,city,deliveryMode=false,lastKnown=false}:{children:React.ReactNode;serviceDate:string;workspace?:string;city?:string;deliveryMode?:boolean;lastKnown?:boolean}) {
  return <div className="dispatch-v23" aria-label="Rounds Dispatch">
    <header className="dispatch-app-header">
      <div className="dispatch-identity">
        <div className="dispatch-brand" aria-label="Rounds"><span className="dispatch-brand-word">Rounds</span><span className="dispatch-brand-dot" aria-hidden="true"/></div>
        <div className="dispatch-business"><strong title={workspace}>{workspace ?? 'Current workspace'}</strong><span>{deliveryMode ? (lastKnown ? 'Workspace · Last known' : 'Business workspace') : 'Pickup issues only'}</span></div>
      </div>
      <nav className="dispatch-app-nav" aria-label="Application">
        <span aria-current="page"><DispatchIcon kind="dispatch"/>Dispatch</span>
        <button disabled title="Driver management is not connected in this v2.3 workspace yet"><DispatchIcon kind="drivers"/>Drivers</button>
        <button disabled title="History is not connected in this v2.3 workspace yet"><DispatchIcon kind="history"/>History</button>
      </nav>
      <div className="dispatch-header-tools">
        <span className="dispatch-scope-label">{deliveryMode ? 'City deliveries' : 'Own-team pickup reports'}</span>
        <button disabled className="dispatch-icon-button" aria-label="Messages — not connected yet" title="Messages are not connected in this workspace yet"><DispatchIcon kind="message"/></button>
        <button disabled className="dispatch-icon-button" aria-label="Settings — not connected yet" title="Settings are not connected in this workspace yet"><DispatchIcon kind="settings"/></button>
      </div>
    </header>
    <header className="dispatch-board-header">
      <div className="dispatch-board-context">
        <div className="dispatch-board-modes" aria-label="Dispatch workspace">
          <span className="dispatch-board-mode" aria-current="true"><DispatchIcon kind="city"/>City</span>
          <button className="dispatch-board-mode" disabled title="Intercity execution is deferred"><DispatchIcon kind="network"/>Intercity</button>
        </div>
        <h1 className="dispatch-location" title={city ?? 'City display name is not available in this read'}>{city ?? 'Current city'}</h1>
      </div>
      <span className="dispatch-date">Service date · {serviceDate}</span>
    </header>
    {children}
  </div>;
}

// Exact inline icon paths from Phase39's symbol definitions. No external sprite,
// prototype script, asset token or new logo artwork is shipped.
export function DispatchIcon({kind}: {kind: 'dispatch' | 'city' | 'network' | 'drivers' | 'history' | 'message' | 'settings' | 'search'}) {
  return <svg className="dispatch-icon" viewBox="0 0 24 24" aria-hidden="true">{
    kind === 'dispatch' ? <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 17h7m-3-3 3 3-3 3"/></> :
    kind === 'city' ? <path d="M3 21h18M5 21V5l8-2v18m0-11h6v11M8 8h2m-2 4h2m-2 4h2m6-2h1m-1 3h1"/> :
    kind === 'network' ? <><rect x="9" y="2" width="6" height="6" rx="1"/><rect x="2" y="16" width="6" height="6" rx="1"/><rect x="16" y="16" width="6" height="6" rx="1"/><path d="M12 8v4M5 16v-4h14v4"/></> :
    kind === 'drivers' ? <><circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3m1-16a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 4v3"/></> :
    kind === 'history' ? <path d="M3 10a9 9 0 1 1 1 8M3 4v6h6m3-3v6l4 2"/> :
    kind === 'message' ? <path d="M4 4h16v13H9l-5 4V4Z M8 8h8M8 12h5"/> :
    kind === 'settings' ? <><path d="M4 7h16M4 17h16"/><rect x="7" y="4" width="4" height="6" rx="1"/><rect x="14" y="14" width="4" height="6" rx="1"/></> :
    <><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></>
  }</svg>;
}
