import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import React from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {DispatchMapController,deliveryMapPoints,mapBounds,mapStyle,publicMapToken,type DispatchMapFactory,type DispatchMapPort,type MapCamera,type MapFactoryOptions,type MapPoint} from '../src/v23/dispatch-map-controller';
import {DispatchMapView} from '../src/v23/dispatch-map-view';
import {mapIconPaths} from '../src/v23/dispatch-map-icons';
import {operationsConnectionConfig} from '../src/v23/operations-connection-config';
import type {BoardDelivery} from '../src/v23/delivery-board-view';

const token='pk.synthetic.test_only',container={} as HTMLElement;
const p=(id='one',lng=100,lat=13):MapPoint=>({id,label:`${id} <safe>`,coordinate:[lng,lat],version:1});
const deferred=<T>()=>{let resolve!:(value:T)=>void;return {promise:new Promise<T>(r=>resolve=r),resolve:(v:T)=>resolve(v)};};
function fixture({delay=18000,failCreate=false}:{delay?:number;failCreate?:boolean}={}){
  const ports:{options:MapFactoryOptions;port:DispatchMapPort;destroyed:number;points:readonly MapPoint[];selected:string|null;visible:boolean;styles:string[];fits:unknown[];moves:Partial<MapCamera>[];resizes:number}[]=[];
  const selected:string[]=[];
  const factory:DispatchMapFactory=async options=>{
    if(failCreate)throw new Error('private-provider-error-not-exposed');
    const entry={options,destroyed:0,points:[] as readonly MapPoint[],selected:null as string|null,visible:true,styles:[] as string[],fits:[] as unknown[],moves:[] as Partial<MapCamera>[],resizes:0,port:{} as DispatchMapPort};
    entry.port={style:mode=>entry.styles.push(mode),points:(rows,id,visible)=>{entry.points=rows;entry.selected=id;entry.visible=visible;},fit:bounds=>entry.fits.push(bounds),move:camera=>{entry.moves.push(camera);options.cameraChanged({...options.camera,...camera});},resize:()=>{entry.resizes++;},destroy:()=>{entry.destroyed++;entry.points=[];}};
    ports.push(entry);return entry.port;
  };
  const controller=new DispatchMapController(token,factory,id=>selected.push(id),delay);
  return {controller,ports,selected};
}
test('Phase39 styles and every map icon path match original source, not v45 default',()=>{
  const source=readFileSync(new URL('../../../specs/source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html',import.meta.url),'utf8');
  assert.equal(mapStyle('operations').url,'mapbox://styles/mapbox/light-v11');assert.equal(mapStyle('operations').config,undefined);
  assert.equal(mapStyle('site').config?.basemap.show3dObjects,true);assert.equal(mapStyle('site').config?.basemap.lightPreset,'day');assert(mapStyle('satellite').url.endsWith('standard-satellite'));
  for(const path of Object.values(mapIconPaths))assert(source.includes(`d="${path}"`),path);
  const css=readFileSync(new URL('../src/v23/dispatch-map.css',import.meta.url),'utf8');assert(css.includes('width:352px'));assert(css.includes('top:204px'));assert(css.includes('width:40px; height:24px'));assert(!css.includes('rain-fill'));
});
test('only explicitly configured public Mapbox token is serialized; secrets/HTML tokens never fall back',()=>{
  for(const value of ['',undefined,'sk.secret.value',' pk.a.b','pk.a.b\n','pk.a.b?leak=1',{}])assert.equal(publicMapToken(value),'');
  assert.equal(publicMapToken(token),token);
  assert.equal(operationsConnectionConfig({ROUNDS_V23_OPERATIONS_UI:'1',NEXT_PUBLIC_MAPBOX_TOKEN:'sk.do-not.send'})?.mapboxToken,'');
  assert.equal(operationsConnectionConfig({ROUNDS_V23_OPERATIONS_UI:'1',NEXT_PUBLIC_MAPBOX_TOKEN:token})?.mapboxToken,token);
  assert.equal(operationsConnectionConfig({NEXT_PUBLIC_MAPBOX_TOKEN:token}),null);
});
test('projection keeps exact permitted zero coordinates/version and does not infer entrance or stop sequence',()=>{
  const row={id:'one',reference:'REF',recipient_name:'Name',destination_version:9,destination:{source:'delivery_destination',latitude:0,longitude:0},entrance_revision_id:'revision'} as BoardDelivery;
  const result=deliveryMapPoints([row]);assert.deepEqual(result,[{id:'one',label:'REF · Name',coordinate:[0,0],version:9}]);assert(Object.isFrozen(result[0].coordinate));assert(!JSON.stringify(result).includes('revision'));
  const bad=[null,{source:'google_route',latitude:1,longitude:1},{source:'delivery_destination',latitude:90,longitude:1},{source:'delivery_destination',latitude:NaN,longitude:1},{source:'delivery_destination',latitude:1,longitude:181}];
  assert.deepEqual(deliveryMapPoints(bad.map((destination,i)=>({...row,id:String(i),destination}) as BoardDelivery)),[]);
  assert.equal(deliveryMapPoints([row,row]).length,1);
});
test('bounds handle no points, zero coordinates and short dateline interval',()=>{
  assert.equal(mapBounds([]),null);assert.deepEqual(mapBounds([p('zero',0,0)]),[[0,0],[0,0]]);
  assert.deepEqual(mapBounds([p('a',179,10),p('b',-179,12)]),[[179,10],[181,12]]);
  assert.deepEqual(mapBounds([p('a',-2,-10),p('b',2,10)]),[[-2,-10],[2,10]]);
});
test('missing or secret token never calls provider factory',async()=>{
  for(const value of ['', 'sk.a.b']){let calls=0;const c=new DispatchMapController(value,async()=>{calls++;throw new Error();},()=>{});await c.attach(container);assert.equal(c.state.phase,'unconfigured');assert.equal(calls,0);c.dispose();}
});
test('initial load renders exact markers and fits once; ordinary refresh does not override user camera',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);const a=f.ports[0];assert.equal(f.controller.state.phase,'loading');a.options.ready();assert.equal(f.controller.state.phase,'ready');assert.equal(a.points[0].id,'one');assert.equal(a.selected,'one');assert.equal(a.fits.length,1);
  f.controller.update([p(),p('two')],'one');assert.equal(a.fits.length,1);f.controller.control('fit');assert.equal(a.fits.length,2);f.controller.dispose();
});
test('empty map does not fit to sample Bangkok; first later authorized points fit once',async()=>{
  const f=fixture();await f.controller.attach(container);const a=f.ports[0];assert.deepEqual(a.options.camera.center,[0,0]);assert.equal(a.options.camera.zoom,1);a.options.ready();assert.equal(a.fits.length,0);f.controller.update([p()],null);assert.equal(a.fits.length,1);f.controller.dispose();
});
test('style changes use source camera and retain selection/hidden pins without recreating provider',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);const a=f.ports[0];a.options.ready();f.controller.visibility(false);f.controller.setMode('site');assert.equal(f.controller.state.phase,'loading');assert.deepEqual(a.moves.at(-1),{center:[100,13],zoom:17.1,pitch:55});assert.deepEqual(a.styles,['site']);
  f.controller.setMode('satellite');assert.deepEqual(a.styles,['site']);a.options.ready();assert.equal(a.selected,'one');assert.equal(a.visible,false);assert.equal(f.ports.length,1);f.controller.setMode('operations');assert.deepEqual(a.moves.at(-1),{pitch:0,bearing:0});a.options.ready();f.controller.dispose();
});
test('3D Site without a selected authorized point cannot use fabricated fallback',async()=>{
  const f=fixture();await f.controller.attach(container);const a=f.ports[0];a.options.ready();f.controller.setMode('site');assert.equal(a.styles.length,0);assert.equal(a.moves.length,0);f.controller.dispose();
});
test('camera controls change geographic camera by20 degrees, North resets and selected focuses exact point',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);const a=f.ports[0];a.options.ready();f.controller.control('right');assert.equal(f.controller.state.camera.bearing,20);f.controller.control('left');assert.equal(f.controller.state.camera.bearing,0);f.controller.control('right');f.controller.control('north');assert.equal(f.controller.state.camera.bearing,0);f.controller.control('selected');assert.deepEqual(a.moves.at(-1),{center:[100,13],zoom:16});f.controller.resize();assert.equal(a.resizes,1);f.controller.dispose();
});
test('removed/unknown marker cannot select data; hidden layer updates local renderer only',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);const a=f.ports[0];a.options.ready();a.options.select('unknown');assert.deepEqual(f.selected,[]);a.options.select('one');assert.deepEqual(f.selected,['one']);f.controller.update([],null);assert.deepEqual(a.points,[]);a.options.select('one');assert.equal(f.selected.length,1);f.controller.dispose();
});
test('provider error clears rendered private points and requires explicit retry; old callbacks cannot resurrect',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);const a=f.ports[0];a.options.ready();a.options.error();assert.equal(f.controller.state.phase,'failed');assert.deepEqual(a.points,[]);assert.equal(a.destroyed,1);a.options.ready();assert.equal(f.controller.state.phase,'failed');f.controller.retry();await Promise.resolve();const b=f.ports[1];b.options.ready();assert.equal(f.controller.state.phase,'ready');assert.equal(b.points.length,1);a.options.error();assert.equal(f.controller.state.phase,'ready');f.controller.dispose();
});
test('initial/style timeouts cannot remain forever loading or auto-send/retry',async()=>{
  const f=fixture({delay:5});await f.controller.attach(container);await new Promise(r=>setTimeout(r,15));assert.equal(f.controller.state.phase,'failed');assert.equal(f.ports.length,1);f.controller.retry();await Promise.resolve();f.ports[1].options.ready();f.controller.setMode('satellite');await new Promise(r=>setTimeout(r,15));assert.equal(f.controller.state.phase,'failed');assert.equal(f.ports[1].destroyed,1);f.controller.dispose();
});
test('creation rejection becomes safe unavailable state without provider detail disclosure',async()=>{
  const f=fixture({failCreate:true});await f.controller.attach(container);assert.equal(f.controller.state.phase,'failed');assert(!JSON.stringify(f.controller.state).includes('private-provider'));f.controller.dispose();
});
test('revocation during async SDK load removes late map without publishing coordinates or IDs',async()=>{
  const d=deferred<DispatchMapPort>();let options!:MapFactoryOptions,destroyed=0;const c=new DispatchMapController(token,async o=>{options=o;return d.promise;},()=>assert.fail('late marker'));
  const load=c.attach(container);c.dispose();d.resolve({destroy:()=>{destroyed++;},style(){},points(){assert.fail('late points');},fit(){},move(){},resize(){}});await load;options.ready();options.cameraChanged({center:[100,13],zoom:17,pitch:55,bearing:20});options.select('one');assert.equal(c.state.phase,'closed');assert.deepEqual(c.state.camera.center,[0,0]);assert.equal(destroyed,1);
});
test('dispose is idempotent and blocks every subsequent control/update/retry',async()=>{
  const f=fixture();f.controller.update([p()],'one');await f.controller.attach(container);f.ports[0].options.ready();f.controller.dispose();f.controller.dispose();f.controller.update([p()],null);f.controller.visibility(true);f.controller.control('fit');f.controller.setMode('site');f.controller.retry();await f.controller.attach(container);assert.equal(f.ports.length,1);assert.equal(f.ports[0].destroyed,1);assert.deepEqual(f.ports[0].points,[]);
});
test('source map modal remains available without a provider; unsupported conditions/actions are explicit',()=>{
  const html=renderToStaticMarkup(React.createElement(DispatchMapView,{rows:[],selected:null,onSelect(){},focused:false,onFocus(){}}));
  for(const label of ['Map workspace','Satellite','3D Site','Rotate left 20 degrees','Rotate right 20 degrees','Fit workspace','Focus map','Street View connection','Traffic provider layer is not connected','Live weather provider is not connected'])assert(html.includes(label),label);
  assert(html.includes('aria-haspopup="dialog"'));assert(html.includes('0 stored delivery destinations'));assert(html.includes('Not verified entrances'));assert(!html.includes('sampleRain'));assert(!html.includes('https://www.google.com/maps'));
});
