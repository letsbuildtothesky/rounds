'use client';

import React, {useEffect, useRef, useState} from 'react';
import type {Wire_OperationsDeliveryBoardQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire';
import {OperationsDeliveryBoard} from './operations-delivery-board';
import {DispatchMapView} from './dispatch-map-view';
import type {DispatchMapFactory} from './dispatch-map-controller';
import {planBrands,planPoolRows,searchDeliveryRows,type PlanPool} from './dispatch-plan-pool';
import {nowPoolRows,nowReasons,type NowPool} from './dispatch-now-pool';

export type BoardDelivery = Wire_OperationsDeliveryBoardQueryResult['data']['deliveries'][number];
export const filterBoardDeliveries=searchDeliveryRows;
export function deliveryWindow(d: BoardDelivery) {
  const format = new Intl.DateTimeFormat('en-GB', {timeZone:d.window.timezone,hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
  const day = new Intl.DateTimeFormat('en-CA', {timeZone:d.window.timezone,year:'numeric',month:'2-digit',day:'2-digit'});
  const start = new Date(d.window.starts_at), end = new Date(d.window.ends_at);
  return day.format(start) === day.format(end) ? `${format.format(start)}–${format.format(end)}` : `${day.format(start)} ${format.format(start)}–${day.format(end)} ${format.format(end)}`;
}
const words = (value: string) => value.replaceAll('_',' ');
export function useDeliveryBoard(controller: OperationsDeliveryBoard) {
  const [state,setState] = useState(() => controller.state);
  useEffect(() => { const sync = () => setState(controller.state); const off = controller.subscribe(sync); sync(); return () => {off();}; }, [controller]);
  return state;
}

/** Phase39's Now/Plan list primitives over an authorized delivery read.
 * Server-derived categories are not planning proposals or command authority. */
export function DeliveryBoardView({controller,onReports,reportsAvailable,active = true,mapboxToken='',mapFactory,onServiceDate,reportDate,focusDate=false,mode='plan',onMode,pickupActions,onPickupAction,onAddDelivery}: {
  controller: OperationsDeliveryBoard; onReports: () => void; reportsAvailable: boolean; active?: boolean;
  mapboxToken?:string;mapFactory?:DispatchMapFactory;
  onServiceDate?:(date:string)=>void;reportDate?:string;focusDate?:boolean;
  mode?:'plan'|'now';onMode?:(mode:'plan'|'now')=>void;
  pickupActions?:ReadonlyMap<string,readonly string[]>;onPickupAction?:(deliveryId:string)=>void;
  onAddDelivery?:()=>void;
}) {
  const state = useDeliveryBoard(controller);
  const [query,setQuery] = useState('');
  const [pool,setPool]=useState<PlanPool>('all');
  const [nowPool,setNowPool]=useState<NowPool>('action');
  const [brand,setBrand]=useState('');
  const [dateError,setDateError]=useState(false);
  const [selected,setSelected] = useState<string|null>(null);
  const [mobileMap,setMobileMap] = useState(false);
  const [mapFocus,setMapFocus] = useState(false);
  const search = useRef<HTMLInputElement>(null), heading = useRef<HTMLHeadingElement>(null);
  const opener = useRef<HTMLButtonElement|null>(null);
  const nowTab=useRef<HTMLButtonElement>(null);
  const nowFocusDone=useRef(false);
  const rows = state.snapshot?.data.deliveries ?? [];
  const now=state.snapshot?.data.now;
  const currentNow=!!now&&now.current_service_date===controller.scope.serviceDate;
  const filtered=mode==='now'?nowPoolRows(rows,now?.entries??[],query,brand,nowPool):planPoolRows(rows,query,brand,pool);
  const visible=mode==='now'&&!currentNow?[]:filtered.rows;
  const nowCounts=nowPoolRows(rows,now?.entries??[],query,brand,nowPool).counts;
  const brands=planBrands(rows);
  const delivery = rows.find(d => d.id === selected);
  const pickupCount=(id:string)=>state.phase==='ready'&&currentNow&&onPickupAction ? pickupActions?.get(id)?.length??0 : 0;
  const pickupLabel=(id:string)=>pickupCount(id)===1?'Review pickup report':'Review pickup reports';
  const close = () => setSelected(null);
  useEffect(()=>{
    if(mode!=='now'||!active){nowFocusDone.current=false;return;}
    if(state.phase==='ready'&&!nowFocusDone.current){nowTab.current?.focus();nowFocusDone.current=true;}
  },[mode,active,state.phase]);
  useEffect(() => {
    if (state.phase === 'closed') { setQuery(''); setBrand(''); setPool('all'); setNowPool('action'); setSelected(null); setMobileMap(false); setMapFocus(false); opener.current=null; }
    // A successful read can remove an archived/order-out-of-scope selection.
    if (selected && state.phase === 'ready' && !delivery) close();
  }, [state.phase,delivery,selected]);
  useEffect(() => {
    if (!active || mobileMap || mapFocus) return;
    if (selected) heading.current?.focus();
    else if (opener.current) {
      // Wait until React has made the replacement rail visible on tablets.
      if (opener.current.isConnected && opener.current.getClientRects().length) opener.current.focus();
      else search.current?.focus();
    }
  }, [selected,active,mobileMap,mapFocus]);
  useEffect(() => {
    const shortcut = (e: KeyboardEvent) => {
      if (active && !selected && !mobileMap && !mapFocus && e.key === '/' && !e.ctrlKey && !e.metaKey && !e.altKey && !e.isComposing &&
        !(e.target as HTMLElement|null)?.closest('input,textarea,select,[contenteditable=true],dialog')) { e.preventDefault(); search.current?.focus(); }
    };
    window.addEventListener('keydown',shortcut); return () => window.removeEventListener('keydown',shortcut);
  }, [active,selected,mobileMap,mapFocus]);
  const refresh = () => { void controller.refresh().catch(() => { /* Closed session is rendered below. */ }); };
  if (state.phase === 'closed') return <section className="pickup-issues dispatch-read-closed" aria-label="Deliveries"><p role="status">Delivery access is unavailable. Recheck your sign-in and city access.</p>{reportsAvailable && <button className="secondary-button" onClick={onReports}>Pickup issues</button>}</section>;
  return <section className="pickup-issues pickup-board delivery-board" aria-label="Deliveries" data-detail={!!delivery} data-mobile-map={mobileMap} data-map-focus={mapFocus}>
    <nav className="dispatch-tablet-controls" aria-label="Workspace surface"><button aria-pressed={!mobileMap&&!mapFocus} onClick={() => {setMobileMap(false);setMapFocus(false);}}>Deliveries</button><button aria-pressed={mobileMap||mapFocus} onClick={() => setMobileMap(true)}>Map</button></nav>
    <aside className="issue-list-panel" aria-labelledby="deliveries-heading">
      <header className="dispatch-delivery-head">
        <div className="dispatch-panel-title"><h2 id="deliveries-heading">Deliveries{state.snapshot && <span className="dispatch-soft-count" aria-label={`${rows.length} deliveries${state.lastKnown ? ', last known' : ''}`}>{rows.length}</span>}</h2><button className="dispatch-add-delivery" disabled={!onAddDelivery} onClick={onAddDelivery} aria-label={onAddDelivery?'Add delivery':'Add delivery — not connected yet'} title={onAddDelivery?'Open Add delivery · Draft saving only':'Creating deliveries is not connected in this v2.3 view yet'}>+</button></div>
        <div className="dispatch-delivery-context">
          <div className="dispatch-delivery-tabs" role="tablist" aria-label="Delivery view" onKeyDown={e=>{
            if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)&&onMode){
              const next=e.key==='Home'?'now':e.key==='End'?'plan':mode==='plan'?'now':'plan';
              if(next==='now'&&(!now||state.phase!=='ready'))return;
              e.preventDefault();onMode(next);
            }
          }}>
            <button id="dispatch-now-tab" ref={nowTab} role="tab" aria-selected={mode==='now'} aria-controls="dispatch-now-results" disabled={!now||!onMode||state.phase!=='ready'} title={now?'Open the current city service day':'Now categories require the authoritative action projection'} onClick={()=>onMode?.('now')}>Now</button>
            <button id="dispatch-plan-tab" role="tab" aria-selected={mode==='plan'} aria-controls="dispatch-plan-results" onClick={()=>onMode?.('plan')}>Plan{state.snapshot && <span>{rows.length}</span>}</button>
          </div><span>{mode==='plan'?'Read-only plan list':'Current city day · Read-only'}</span>
        </div>
        {mode==='plan'&&<label className="dispatch-service-date"><span>Delivery date</span><input type="date" aria-label="Planned delivery date" autoFocus={focusDate} value={controller.scope.serviceDate} disabled={!onServiceDate} aria-invalid={dateError} aria-describedby={dateError?'dispatch-date-error':undefined} onChange={e=>{
          const value=e.target.value;
          try{if(!value||!e.target.validity.valid)throw new Error();onServiceDate?.(value);setDateError(false);}catch{setDateError(true);}
        }}/></label>}
        {dateError&&<p className="form-error" id="dispatch-date-error">Choose a valid delivery date. The current date has not changed.</p>}
        <label className="dispatch-search"><SearchIcon/><input ref={search} type="search" aria-label="Search deliveries" placeholder="Search deliveries" maxLength={200} value={query} onChange={e => setQuery(e.target.value)}/><kbd aria-hidden="true">/</kbd></label>
        {mode==='now'&&<div className="dispatch-status-tabs" role="group" aria-label="Delivery status">
          {([['action','Action'],['ready','Ready'],['road','On road'],['done','Done']] as const).map(([value,label])=><button key={value} type="button" data-status={value} aria-pressed={nowPool===value} disabled={!currentNow} onClick={()=>setNowPool(value)}>{label}{currentNow&&<span>{nowCounts[value]}</span>}</button>)}
        </div>}
        <div className="dispatch-delivery-tools"><span>By delivery time</span><button className="dispatch-quiet-button" onClick={refresh} disabled={state.phase === 'loading'}>Refresh deliveries</button></div>
        <div className="dispatch-plan-queue-tools">{mode==='plan'&&<div className="dispatch-plan-queue-tabs" role="group" aria-label="Plan deliveries">
          {(['unplanned','all'] as const).map(value=><button key={value} type="button" aria-pressed={pool===value} disabled={!state.snapshot} onClick={()=>setPool(value)}>{value==='unplanned'?'Unplanned':'All deliveries'}{state.snapshot&&<span>{planPoolRows(rows,query,brand,pool).counts[value]}</span>}</button>)}
        </div>}
        <label className="dispatch-plan-brand"><span>Brand</span><select aria-label="Filter deliveries by brand" value={brand} disabled={!state.snapshot} onChange={e=>setBrand(e.target.value)}>
          <option value="">All brands</option>{brands.map(b=><option key={b.id} value={b.id}>{b.name??'Brand name unavailable'}</option>)}
          {brand&&!brands.some(b=>b.id===brand)&&<option value={brand}>Brand no longer in this date</option>}
        </select></label></div>
      </header>
      <div id={`dispatch-${mode}-results`} role="tabpanel" aria-labelledby={`dispatch-${mode}-tab`} className="detail-scroll" aria-busy={state.phase === 'loading'}>
        <BoardStatus phase={state.phase} lastKnown={state.lastKnown} error={state.errorCode}/>
        {mode==='now'&&state.snapshot&&!currentNow&&<p className="form-help" role="status">The current city day has changed. Select Now to load its deliveries.</p>}
        {state.phase === 'ready' && rows.length === 0 && <div className="empty-state"><b>No deliveries scheduled</b><p>No deliveries were returned for this city and date.</p></div>}
        {!!rows.length && visible.length === 0 && (mode==='plan'||currentNow) && <div className="empty-state"><b>{mode==='plan'&&pool==='unplanned'&&!query&&!brand?'No unplanned deliveries':'No deliveries in this view'}</b><p>{mode==='plan'?'Filters cover only this date. Unplanned means an open order with no current Round; it does not mean ready for pickup.':'Try another status, brand or search. Scheduled work remains in Show all deliveries.'}</p><button className="secondary-button" onClick={() => {setQuery('');setBrand('');setPool('all');setNowPool('all');search.current?.focus();}}>{mode==='now'?'Show all deliveries':'Clear filters'}</button></div>}
        {visible.map(d => <button key={d.id} className="delivery-card" aria-pressed={d.id === selected} onClick={e => {opener.current=e.currentTarget;setSelected(d.id);setMobileMap(false);}}>
          <span className="card-top"><span>{d.reference ?? 'Reference unavailable'}</span><span className="card-window">{deliveryWindow(d)}</span></span>
          <span className="card-name">{d.recipient_name ?? 'Recipient name unavailable'}</span>
          <span className="card-address">{d.address_text ?? 'Address unavailable'}</span>
          <span className="card-meta"><span className={`card-status ${mode==='now'&&now?.entries.find(e=>e.delivery_id===d.id)?.bucket==='action'?'issue':''}`}>{mode==='now'?nowReasons[now!.entries.find(e=>e.delivery_id===d.id)!.reason].label:d.outcome === 'open' ? `Readiness: ${words(d.readiness)}` : `Outcome: ${words(d.outcome)}`}</span></span>
          <span className="card-next"><span>{pickupCount(d.id)?pickupLabel(d.id):'View delivery details'}</span><Arrow/></span>
        </button>)}
      </div>
      <footer className="dispatch-delivery-footer"><span aria-live="polite">{state.snapshot ? `${visible.length} of ${rows.length} deliveries${state.lastKnown ? ' · Last known' : ''}` : 'Waiting for authorized deliveries'}</span>{mode==='now'&&nowPool!=='all'&&<button className="dispatch-quiet-button" onClick={()=>setNowPool('all')}>Show all deliveries</button>}<button className="dispatch-quiet-button" disabled={!reportsAvailable} title={reportsAvailable ? 'Open separately authorized own-team pickup reports' : 'Pickup report access is unavailable'} onClick={onReports}>Pickup issues{reportDate&&reportDate!==controller.scope.serviceDate?` · ${reportDate}`:''}<Arrow/></button></footer>
    </aside>
    <DispatchMapView rows={mode==='now'&&!currentNow?[]:rows} selected={selected} onSelect={id=>{opener.current=document.activeElement instanceof HTMLButtonElement?document.activeElement:null;setSelected(id);setMobileMap(false);setMapFocus(false);}} token={mapboxToken} factory={mapFactory} active={active} lastKnown={state.lastKnown} focused={mapFocus} onFocus={value=>{setMapFocus(value);if(value)setMobileMap(true);else setMobileMap(false);}}/>
    {delivery && <aside className="delivery-detail" aria-labelledby="delivery-heading" onKeyDown={e => {if(e.key === 'Escape'){e.stopPropagation();close();}}}>
      <header className="detail-top"><button className="back-button" onClick={close}><Arrow back/>Deliveries</button><span>{delivery.reference ?? 'Reference unavailable'}</span></header>
      <div className="detail-scroll">
        <div className="detail-kicker"><span>{controller.scope.serviceDate}</span><span>Delivery details</span></div>
        <h2 id="delivery-heading" className="detail-heading" tabIndex={-1} ref={heading}>{delivery.recipient_name ?? 'Recipient name unavailable'}</h2>
        <p className="detail-address">{delivery.address_text ?? 'Address unavailable'}</p>
        <BoardStatus phase={state.phase} lastKnown={state.lastKnown} error={state.errorCode}/>
        {now&&<section className="detail-section"><h3 className="section-label">Operational status{state.lastKnown?' · Last known':''}</h3><p className="detail-address">{nowReasons[now.entries.find(e=>e.delivery_id===delivery.id)!.reason].label}</p><p className="form-help">Status is not permission to collect, release or complete. Those actions require their own checks.</p></section>}
        <section className="detail-section"><h3 className="section-label">Delivery window</h3><p className="detail-address">{deliveryWindow(delivery)} · {delivery.window.timezone}</p></section>
        <section className="detail-section"><h3 className="section-label">Pickup site</h3><p className="detail-address">{delivery.pickup_site.name ?? 'Pickup site name unavailable'}</p>{delivery.brand && <p className="form-help">{delivery.brand.name ?? 'Brand name unavailable'}</p>}</section>
        <section className="detail-section"><h3 className="section-label">Recorded state{state.lastKnown ? ' · Last known' : ''}</h3><dl className="dispatch-delivery-facts"><dt>Readiness</dt><dd>{words(delivery.readiness)}</dd><dt>Preparation</dt><dd>{words(delivery.preparation_state)}</dd><dt>Outcome</dt><dd>{words(delivery.outcome)}</dd><dt>Evidence</dt><dd>{words(delivery.evidence_state)}</dd>{delivery.planning && <><dt>Round state</dt><dd>{words(delivery.planning.round_state)}</dd><dt>Departure gate</dt><dd>{words(delivery.planning.departure_gate)}</dd></>}</dl></section>
        <p className="form-help">Read-only details. Planning, pickup and release are not changed here.</p>
      </div>
      {!!pickupCount(delivery.id)&&<footer className="detail-actions"><button className="primary-button" onClick={()=>onPickupAction?.(delivery.id)}>{pickupLabel(delivery.id)}<Arrow/></button><p>Review the original report before replying. No pickup or release change.</p></footer>}
    </aside>}
  </section>;
}
function BoardStatus({phase,lastKnown,error}:{phase:string;lastKnown:boolean;error:string|null}) {
  return <div className="dispatch-read-status" role="status">{(phase === 'idle' || phase === 'loading') && <p className="form-help">{lastKnown ? 'Refreshing · Previous information is last known.' : 'Loading deliveries…'}</p>}{phase === 'failed' && <p className="form-error">{error === 'FEATURE_NOT_ENABLED' ? 'This delivery scope is not supported yet.' : 'Could not refresh deliveries. Try Refresh deliveries.'}{lastKnown ? ' Showing last-known information.' : ' No delivery count is available.'}</p>}</div>;
}
function SearchIcon(){return <svg className="icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg>;}
function Arrow({back=false}:{back?:boolean}){return <svg className="icon" viewBox="0 0 24 24" aria-hidden="true"><path d={back?'m10 5-7 7 7 7M3 12h18':'m9 5 7 7-7 7'}/></svg>;}
