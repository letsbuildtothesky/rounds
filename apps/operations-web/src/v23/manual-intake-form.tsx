'use client';
import React,{useEffect,useRef,useState} from 'react';
import {OperationsManualIntake} from './operations-manual-intake';
import type {Wire_delivery_draft} from '../../../../packages/contracts/src/v23/pickup-wire';

/** Phase39 parseIntakeItems grammar: independent product lines, not delivery
 * splitting. Preserve exact raw field in the tab journal; quantities are draft
 * proposals only. No coordinates, preparation fact or order is fabricated. */
export function intakeProducts(text:string):Wire_delivery_draft['manifest']{
  return text.split(/\n|\s*\+\s*|\s*;\s*/).map(x=>x.trim()).filter(Boolean).map((item,i)=>{
    const match=item.match(/^(\d{1,3})\s*[x×]?\s+(.+)$/)||item.match(/^(.+?)\s*[x×]\s*(\d{1,3})$/);
    const first=match&&/^\d+$/.test(match[1]!);
    return {line_key:'manual-'+(i+1),label:match?(first?match[2]!:match[1]!):item,quantity:match?Math.max(1,Number(first?match[1]:match[2])):1,unit:'item',handling_keys:[]};
  });
}
const tomorrow=(day:string)=>{const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+1);return d.toISOString().slice(0,10);};
const shortDay=(day:string)=>new Intl.DateTimeFormat('en-GB',{day:'numeric',month:'short',timeZone:'UTC'}).format(new Date(day+'T12:00:00Z'));
function Icon({kind}:{kind:'intake'|'chevron'|'image'|'close'|'map'|'settings'}){
  return <svg className="icon" viewBox="0 0 24 24" aria-hidden="true">{kind==='intake'?<path d="M12 3v12m-4-4 4 4 4-4M4 13v7h16v-7M4 4h3m10 0h3"/>:
    kind==='chevron'?<path d="m6 9 6 6 6-6"/>:kind==='close'?<path d="m6 6 12 12M6 18 18 6"/>:
    kind==='map'?<path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2V5Zm6-2v16m6-14v16"/>:
    kind==='image'?<><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 6-6 4 4 3-3 5 5"/></>:
    <><path d="M4 7h16M4 17h16"/><rect x="7" y="4" width="4" height="6" rx="1"/><rect x="14" y="14" width="4" height="6" rx="1"/></>}</svg>;
}
/** Exact source form grouping. Deferred bindings keep their source control and
 * truthful disabled state. In particular SaveDeliveryDraft is NOT Create. */
export function ManualIntakeForm({controller,open,onClose}:{controller:OperationsManualIntake;open:boolean;onClose:()=>void}){
  const dialog=useRef<HTMLDialogElement>(null),opener=useRef<HTMLElement|null>(null);
  const saveRequested=useRef(false);
  const [state,setState]=useState(()=>controller.state),[localError,setLocalError]=useState<string|null>(null);
  const [otherDay,setOtherDay]=useState(false);
  useEffect(()=>{const sync=()=>setState(controller.state);const off=controller.subscribe(sync);sync();return off;},[controller]);
  useEffect(()=>{
    // A blur/close during a slow save must retain the newer edit and flush it
    // after the original receipt, never overwrite the frozen pending request.
    if(saveRequested.current&&state.phase==='ready'&&!state.pending){
      saveRequested.current=false;if(state.dirty)void controller.save();
    }
  },[controller,state.phase,state.pending,state.dirty,state.draft]);
  useEffect(()=>{
    const d=dialog.current!;
    if(open){opener.current=document.activeElement instanceof HTMLElement?document.activeElement:null;if(!d.open)d.showModal();try{void controller.open();}catch{setLocalError('SESSION_CHANGED');}}
    else {if(d.open)d.close();opener.current?.focus();}
    return()=>{if(d.open)d.close();};
  },[open,controller]);
  const draft=state.draft,today=state.context?.city.current_service_date;
  const selectedOther=otherDay||!!draft&&(!draft.service_date||draft.service_date!==today&&draft.service_date!==(today?tomorrow(today):null));
  const recipient=draft?.contacts.find(x=>x.role==='recipient');
  const disabled=!draft||!state.context||['closed','loading','idle','failed'].includes(state.phase);
  const edit=(changes:Partial<Wire_delivery_draft>,productText?:string)=>{
    if(!draft)return;
    try{controller.edit({...draft,...changes},productText);setLocalError(null);}catch(e){setLocalError(e instanceof Error?e.message:'Draft could not be retained.');}
  };
  const contact=(changes:{name?:string;phone?:string})=>{
    if(!draft)return;
    const others=draft.contacts.filter(x=>x.role!=='recipient');
    edit({contacts:[...others,{role:'recipient',name:recipient?.name??'',...recipient,...changes}]});
  };
  const save=()=>{saveRequested.current=true;const s=controller.state;if(s.dirty&&!s.pending&&s.phase==='ready'){saveRequested.current=false;void controller.save();}};
  const close=()=>{save();onClose();};
  const code=localError??state.errorCode;
  const error=code==='STALE_VERSION'?'This draft changed elsewhere. Your edits remain on this tab; saving is paused to avoid overwriting another edit.':
    code?'Draft saving needs attention. Your edits are retained on this tab. Check the connection and try again.':null;
  return <dialog ref={dialog} className="rounds-manual-intake workspace-dialog add-dialog" aria-labelledby="manual-add-title"
    onCancel={e=>{e.preventDefault();close();}} onClick={e=>{if(e.target===e.currentTarget){const r=e.currentTarget.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)close();}}}>
    <header className="dialog-header"><h2 id="manual-add-title">Add delivery</h2><button type="button" className="dialog-close" aria-label="Close Add delivery" onClick={close}><Icon kind="close"/></button></header>
    <form noValidate onSubmit={e=>e.preventDefault()} onBlur={save}>
      <div className="dialog-body form-fields">
        <details className="add-autofill"><summary><Icon kind="intake"/><span>Autofill from message or screenshot</span><Icon kind="chevron"/></summary><div className="add-autofill-body">
          <textarea rows={3} aria-label="Paste message to autofill" placeholder="Paste the customer’s message here…" disabled/>
          <div className="add-autofill-actions"><button type="button" className="quiet-button" disabled><Icon kind="image"/>Add screenshot</button><button type="button" className="secondary-button" disabled>Autofill</button></div>
          <div className="add-reader-status">Autofill is not connected yet. Enter the delivery below.</div>
        </div></details>
        <div className="add-autofill-message" role="status">{!draft?'Draft is not open.':state.phase==='loading'?'Opening authorized draft…':state.phase==='saving'?'Saving draft…':state.pending?'Checking draft save is needed.':state.dirty?'Draft edits retained on this tab.':'Draft saved.'} Create delivery is not connected yet.</div>
        <fieldset className="add-form-fields" disabled={disabled}>
          <label>Recipient<input name="recipient" autoFocus required maxLength={100} placeholder="Customer name" value={recipient?.name??''} onChange={e=>contact({name:e.target.value})}/></label>
          <label>Delivery address<textarea name="address" required rows={2} maxLength={600} placeholder="Building, street, district, unit and floor" value={draft?.address_text??''} onChange={e=>edit({address_text:e.target.value,point:null})}/></label>
          <div className="add-address-tools"><span>Entrance can be confirmed after adding</span><button type="button" className="quiet-button" disabled title="Address review is not connected yet"><Icon kind="map"/>Check on map</button></div>
          <label>Product<input name="products" required maxLength={500} placeholder="Bouquet, cake or other item" value={state.productText} onChange={e=>edit({manifest:intakeProducts(e.target.value)},e.target.value)}/></label>
          <fieldset className="add-choice-field"><legend>Delivery day</legend><div className="choice-grid add-day-grid">
            {([['today','Today',today],['tomorrow','Tomorrow',today?tomorrow(today):undefined],['other','Another date',null]] as const).map(([id,label,date])=>
              <label key={id}><input type="radio" name="delivery-day" value={id} checked={id==='other'?selectedOther:!selectedOther&&draft?.service_date===date}
                onChange={()=>{setOtherDay(id==='other');if(date)edit({service_date:date,window:null,slot_occurrence_id:null});else edit({service_date:null,window:null,slot_occurrence_id:null});}}/>{label}{date?' · '+shortDay(date):''}</label>)}
          </div>{selectedOther&&<input type="date" aria-label="Delivery date" value={draft?.service_date??''} onChange={e=>edit({service_date:e.target.value||null,window:null,slot_occurrence_id:null})}/>}</fieldset>
          <fieldset className="add-choice-field" disabled><legend className="add-window-heading"><span>Delivery window</span><button type="button" className="quiet-button" disabled>Settings<Icon kind="settings"/></button></legend>
            <p className="form-help">Configured delivery windows are not connected yet.</p>
          </fieldset>
          <details className="add-extra"><summary>Phone &amp; delivery instructions</summary><div className="add-extra-body">
            <label>Phone <small>Optional</small><input name="phone" type="tel" maxLength={40} autoComplete="off" placeholder="Recipient’s number" value={recipient?.phone??''} onChange={e=>contact({phone:e.target.value})}/></label>
            <label>Instructions <small>Optional</small><input name="notes" maxLength={500} placeholder="Unit, floor or handoff notes" value={draft?.instructions??''} onChange={e=>edit({instructions:e.target.value})}/></label>
          </div></details>
          <label className="add-ready"><input type="checkbox" checked={draft?.preparation_state==='ready'} onChange={e=>edit({preparation_state:e.target.checked?'ready':'unknown'})}/>Ready for pickup</label>
        </fieldset>
        <p className="form-help">Confirm the entrance pin before dispatch.</p>
        {error&&<div className="form-error" role="alert">{error}{code!=='STALE_VERSION'&&state.phase!=='closed'&&<button type="button" onClick={()=>void (state.pending?controller.save():controller.open())}>Check draft save</button>}</div>}
      </div>
      <footer className="dialog-footer"><button type="button" className="button-secondary" onClick={close}>Cancel</button><button type="submit" className="button-primary" disabled title="CommitDelivery and address/window admission are not connected yet">Create delivery</button></footer>
    </form>
  </dialog>;
}
