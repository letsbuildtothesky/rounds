// LOCAL COMPONENT TEST ONLY. Not imported by any production route.
import React from 'react';
import {createRoot} from 'react-dom/client';
import {OperationsPickupIssues} from '../../src/v23/operations-pickup-issues';
import {PickupIssueDrawer} from '../../src/v23/pickup-issue-drawer';
import {DispatchWorkspace} from '../../src/v23/dispatch-workspace';
import {OperationsDeliveryBoard} from '../../src/v23/operations-delivery-board';
import {OperationsManualIntake} from '../../src/v23/operations-manual-intake';
import {reviewMapFactory} from './dispatch-map-review';
// Real legacy global styles are intentionally present to catch cross-route drift.
import '../../app/styles.css';
import '../../app/operations-v45.css';
import '../../app/capacity-v45.css';
import '../../src/v23/pickup-issue-drawer.css';
import '../../src/v23/dispatch-workspace.css';
import 'mapbox-gl/dist/mapbox-gl.css';
import '../../src/v23/dispatch-map.css';
import '../../src/v23/manual-intake-form.css';
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const key = 'rounds:component-test:login';
let loginId = sessionStorage.getItem(key);
if (!loginId) { loginId = crypto.randomUUID(); sessionStorage.setItem(key,loginId); }
const controller = new OperationsPickupIssues({baseUrl:location.origin,includeDisplay:true,
  scope:{principalId:id(1),tenantId:id(2),cityId:id(3),serviceDate:'2026-09-10',sessionEpoch:1},
  session:()=>({principalId:id(1),sessionEpoch:1,bearer:'component-test-only'}),
  recovery:{storage:sessionStorage,loginId,currentLoginId:()=>sessionStorage.getItem(key)}});
const board = new URLSearchParams(location.search).get('board') === '1';
const deliveries = new URLSearchParams(location.search).get('deliveries') === '1';
const mapTest = new URLSearchParams(location.search).get('map-test') === '1';
const intakeController=new URLSearchParams(location.search).get('intake-test')==='1'?new OperationsManualIntake({baseUrl:location.origin,scope:controller.scope,
  session:()=>({principalId:id(1),sessionEpoch:1,bearer:'component-test-only'}),recovery:{storage:sessionStorage,loginId,currentLoginId:()=>sessionStorage.getItem(key)}}):undefined;
const deliveryController = deliveries ? new OperationsDeliveryBoard({baseUrl:location.origin,scope:controller.scope,session:()=>({principalId:id(1),sessionEpoch:1,bearer:'component-test-only'}),includeNow:new URLSearchParams(location.search).get('now-test')==='1'}) : undefined;
createRoot(document.getElementById('root')!).render(<main className="component-test" style={{height:'100dvh',display:'grid',gridTemplateRows:'44px minmax(0,1fr)',background:'#f5f7fa'}}>
  <style>{'.component-test > .dispatch-v23 { height:100%; }'}</style>
  <div style={{font:'12px Arial',margin:0,padding:'8px 12px',display:'flex',gap:8,alignItems:'center',minWidth:0}}><span>SYNTHETIC TEST · No real sends</span>{deliveries && <select aria-label="Test delivery response" defaultValue="ready" onChange={async e=>{await fetch('/test-control?mode='+e.target.value);await deliveryController?.refresh();}}><option value="ready">Ready</option><option value="offline">Offline</option><option value="empty">Empty</option><option value="removed">Remove first order</option><option value="denied">Access denied</option></select>}</div>
  {board || deliveries ? <DispatchWorkspace controller={controller} deliveryController={deliveryController} mapboxToken={mapTest?'pk.synthetic.test_only':undefined} mapFactory={mapTest?reviewMapFactory:undefined} intakeController={intakeController}/> : <div style={{boxSizing:'border-box',width:'min(400px,100%)',marginLeft:'auto',minHeight:0,borderLeft:'1px solid #dce4ed'}}><PickupIssueDrawer controller={controller}/></div>}
</main>);
void controller.refresh();
void deliveryController?.refresh();
