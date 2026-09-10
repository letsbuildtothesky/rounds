'use client';

import React,{useEffect,useMemo,useRef,useState} from 'react';
import type {BoardDelivery} from './delivery-board-view';
import {DispatchMapController,deliveryMapPoints,mapModeNames,type DispatchMapFactory,type MapMode,type MapState} from './dispatch-map-controller';
import {createDispatchMap} from './dispatch-mapbox';
import {mapIconPaths} from './dispatch-map-icons';

const emptyState:MapState={phase:'unconfigured',mode:'operations',camera:{center:[0,0],zoom:1,bearing:0,pitch:0},visible:true};
/** Phase39 map toolbar and modal. Only stored authorized destinations are drawn;
 * provider access does not imply routing, entrance review or tracking rights. */
export function DispatchMapView({rows,selected,onSelect,token='',active=true,lastKnown=false,focused,onFocus,factory=createDispatchMap}:{
  rows:readonly BoardDelivery[];selected:string|null;onSelect:(id:string)=>void;token?:string;active?:boolean;lastKnown?:boolean;
  focused:boolean;onFocus:(focus:boolean)=>void;factory?:DispatchMapFactory;
}){
  const points=useMemo(()=>deliveryMapPoints(rows),[rows]);
  const container=useRef<HTMLDivElement>(null),dialog=useRef<HTMLDialogElement>(null),trigger=useRef<HTMLButtonElement>(null),focusButton=useRef<HTMLButtonElement>(null);
  const controller=useRef<DispatchMapController|null>(null),latest=useRef({points,selected,onSelect});latest.current={points,selected,onSelect};
  const [state,setState]=useState<MapState>(emptyState),[open,setOpen]=useState(false);
  useEffect(()=>{
    const next=new DispatchMapController(token,factory,id=>latest.current.onSelect(id));controller.current=next;
    const off=next.subscribe(()=>setState(next.state));setState(next.state);next.update(latest.current.points,latest.current.selected);
    if(container.current)void next.attach(container.current);
    return()=>{off();next.dispose();controller.current=null;};
  },[token,factory]);
  useEffect(()=>{controller.current?.update(points,selected);},[points,selected]);
  useEffect(()=>{if(active)controller.current?.resize();else{dialog.current?.close();setOpen(false);}},[active,focused]);
  const ready=state.phase==='ready',target=points.find(p=>p.id===selected);
  const place=()=>{
    if(!trigger.current||!dialog.current)return;
    const rect=trigger.current.getBoundingClientRect(),width=Math.min(352,window.innerWidth-24),top=Math.max(12,Math.min(rect.bottom+12,window.innerHeight-160));
    Object.assign(dialog.current.style,{width:`${width}px`,left:`${Math.max(12,Math.min(rect.right-width,window.innerWidth-width-12))}px`,top:`${top}px`,maxHeight:`${Math.max(120,window.innerHeight-top-16)}px`});
  };
  useEffect(()=>{if(!open)return;window.addEventListener('resize',place);return()=>window.removeEventListener('resize',place);},[open]);
  const close=()=>{dialog.current?.close();setOpen(false);if(active)trigger.current?.focus();};
  const show=()=>{place();dialog.current?.showModal();setOpen(true);dialog.current?.querySelector<HTMLButtonElement>('[data-map-style][aria-pressed=true]:not(:disabled)')?.focus();};
  const mode=(value:MapMode)=>{close();controller.current?.setMode(value);};
  const focus=(value:boolean)=>{close();onFocus(value);requestAnimationFrame(()=>{controller.current?.resize();focusButton.current?.focus();});};
  const bearing=((state.camera.bearing%360)+360)%360;
  return <section className="dispatch-map-stage dispatch-map-connected" aria-label="Workspace map" onKeyDown={e=>{if(e.key==='Escape'&&focused&&!open){e.preventDefault();focus(false);}}}>
    <div className="dispatch-map-canvas" ref={container} aria-label="Mapbox workspace map"/>
    <div className="map-toolbar">
      <button className="map-inspect-trigger" disabled title="Entrance review and access notes are not connected yet" aria-label="Inspect entrance — not connected yet"><MapIcon kind="location"/><span>Inspect entrance</span></button>
      <button ref={trigger} className="map-display-trigger" aria-label={`Map view and layers, ${mapModeNames[state.mode]}`} aria-haspopup="dialog" aria-expanded={open} onClick={show}><MapIcon kind="layers"/><span>{mapModeNames[state.mode]}</span><MapIcon kind="chevron"/></button>
      <button className="map-tool-button map-fit" disabled={!ready||!points.length} aria-label="Fit workspace on map" title="Fit stored delivery destinations" onClick={()=>controller.current?.control('fit')}><MapIcon kind="fit"/></button>
      <button ref={focusButton} className="map-tool-button map-focus" aria-label={focused?'Show workspace':'Focus map'} aria-pressed={focused} onClick={()=>focus(!focused)}><MapIcon kind="expand"/></button>
    </div>
    <div className="map-camera-extra"><button disabled={!ready||state.camera.pitch<20&&!target} aria-label={state.camera.pitch>=20?'Return to 2D map':'Inspect selected destination in 3D'} title={target?'Change map tilt':'Select a delivery with a stored destination first'} aria-pressed={state.camera.pitch>=20} onClick={()=>mode(state.camera.pitch>=20?'operations':'site')}>{state.camera.pitch>=20?'2D':'3D'}</button></div>
    {focused && <button className="focus-return" onClick={()=>focus(false)}><MapIcon kind="back"/>Show workspace <kbd>Esc</kbd></button>}
    <span className="map-live-status" role="status">{state.phase==='ready'?'Map connected':state.phase==='loading'?`Loading ${mapModeNames[state.mode]} map…`:'Map unavailable'}</span>
    {state.phase!=='ready' && <div className="dispatch-map-unavailable" role="status"><b>{state.phase==='loading'?'Connecting map…':'The map is unavailable.'}</b><p>{state.phase==='unconfigured'?'A configured public Mapbox token is required. Your delivery board is still available.':state.phase==='loading'?'Your delivery board remains available while this map view loads.':'This map view did not load. Your delivery board is still available.'}</p>{state.phase==='failed'&&<button className="map-text-button" onClick={()=>controller.current?.retry()}>Retry map</button>}</div>}
    <div className="map-caption"><MapIcon kind="pin"/><span>{points.length} stored delivery {points.length===1?'destination':'destinations'}{rows.length>points.length?` · ${rows.length-points.length} not mapped`:''}{!state.visible?' · Hidden':''}{lastKnown?' · Last known':''}<small>Not verified entrances · Routes and driver GPS not connected</small></span></div>
    <dialog className="map-display-dialog" ref={dialog} aria-label="Map workspace" onCancel={e=>{e.stopPropagation();}} onClose={()=>{setOpen(false);if(active)trigger.current?.focus();}} onClick={e=>{if(e.target===e.currentTarget){const r=e.currentTarget.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)close();}}}>
      <header className="map-display-heading"><h2>Map workspace</h2><button className="map-tool-button" aria-label="Close map controls" onClick={close}><MapIcon kind="close"/></button></header>
      <div className="map-display-scroll">
        <div className="map-style-choices" role="group" aria-label="Map view">{(['operations','satellite','site'] as const).map(m=><button key={m} className="map-style-choice" data-map-style={m} aria-pressed={state.mode===m} disabled={!ready||m==='site'&&!target} onClick={()=>mode(m)} title={m==='site'&&!target?'Select a delivery with a stored destination first':undefined}><MapIcon kind={m==='operations'?'map':m==='satellite'?'layers':'city'}/><span><b>{mapModeNames[m]}</b><small>{m==='operations'?'Quiet streets and stored destinations':m==='satellite'?'Aerial imagery and road labels':'Inspect the selected destination'}</small></span><MapIcon kind="check"/></button>)}</div>
        <section className="map-settings-section"><h3>Visible on map</h3><Layer title="Deliveries" description="Stored destination points, not verified entrances" checked={state.visible} onChange={v=>controller.current?.visibility(v)}/><Layer title="Drivers" description="Driver location feed is not connected"/><Layer title="Routes" description="Authoritative route geometry is not connected"/><Layer title="Freelancer supply" description="Network supply is deferred"/></section>
        <section className="map-settings-section"><h3>Conditions</h3><Layer title="Traffic" description="Traffic provider layer is not connected"/><Layer title="Rain" description="Live weather provider is not connected"/><p className="map-setting-note">No ETA is calculated in this view. A basemap does not establish traffic or weather conditions.</p></section>
        <section className="map-settings-section"><div className="camera-heading"><h3>Camera</h3><span>{ready?`${Math.abs(state.camera.bearing)<.5?'North · ':''}${Math.round(bearing)}°`:'Unavailable'}</span></div><div className="camera-actions"><button className="secondary-button" disabled={!ready} aria-label="Rotate left 20 degrees" onClick={()=>controller.current?.control('left')}><MapIcon kind="left"/></button><button className="secondary-button" disabled={!ready} onClick={()=>controller.current?.control('north')}><MapIcon kind="north"/>North</button><button className="secondary-button" disabled={!ready} aria-label="Rotate right 20 degrees" onClick={()=>controller.current?.control('right')}><MapIcon kind="right"/></button></div><div className="map-utility-actions"><button className="secondary-button" disabled={!ready||!points.length} onClick={()=>{close();controller.current?.control('fit');}}><MapIcon kind="fit"/>Fit workspace</button><button className="secondary-button" onClick={()=>focus(!focused)}><MapIcon kind="expand"/>{focused?'Show workspace':'Focus map'}</button></div></section>
        <div className="map-settings-section"><button className="map-text-button" disabled title="Street View provider and entrance review are not connected yet">Street View connection</button></div>
      </div>
    </dialog>
  </section>;
}
function Layer({title,description,checked=false,onChange}:{title:string;description:string;checked?:boolean;onChange?:(value:boolean)=>void}){return <label className={`map-layer-setting${onChange?'':' unavailable'}`}><span><b>{title}</b><small>{description}</small></span><span className="switch"><input type="checkbox" role="switch" aria-label={`${title} layer`} checked={checked} disabled={!onChange} onChange={e=>onChange?.(e.target.checked)}/><span className="switch-track" aria-hidden="true"/></span></label>;}
function MapIcon({kind}:{kind:keyof typeof mapIconPaths}){return <svg className={`icon map-icon map-icon-${kind}`} viewBox="0 0 24 24" aria-hidden="true"><path d={mapIconPaths[kind]}/>{kind==='pin'&&<circle cx="12" cy="10" r="2.5"/>}</svg>;}
