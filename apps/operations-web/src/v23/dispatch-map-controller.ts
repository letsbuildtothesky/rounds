import type {Wire_OperationsDeliveryBoardQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire';

export type MapMode = 'operations' | 'satellite' | 'site';
export type MapCamera = {center: [number,number]; zoom:number; bearing:number; pitch:number};
export type MapPoint = Readonly<{id:string; label:string; coordinate:readonly [number,number]; version:number}>;
type Delivery = Wire_OperationsDeliveryBoardQueryResult['data']['deliveries'][number];
export const mapModeNames = {operations:'Operations',satellite:'Satellite',site:'3D Site'} as const;
// Phase39 mapStyleURL/mapStyleOptions, not the historical v45 Standard default.
export function mapStyle(mode:MapMode) {
  return {url:mode==='operations'?'mapbox://styles/mapbox/light-v11':mode==='satellite'?'mapbox://styles/mapbox/standard-satellite':'mapbox://styles/mapbox/standard',
    config:mode==='operations'?undefined:{basemap:{lightPreset:'day',showPointOfInterestLabels:false,showTransitLabels:false,...(mode==='site'?{theme:'faded',show3dObjects:true}:{})}}};
}
export function publicMapToken(value:unknown):string {
  return typeof value==='string' && value.length<=4096 && /^pk\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value)?value:'';
}
/** Stored delivery destinations only. No geocoding, entrance approval, route,
 * stop ordinal or tracking authority is inferred. Mercator cannot show poles. */
export function deliveryMapPoints(rows:readonly Delivery[]):readonly MapPoint[] {
  const ids=new Set<string>();
  return Object.freeze(rows.flatMap(d=>{
    const p=d.destination;
    if(ids.has(d.id)||!p||p.source!=='delivery_destination'||!Number.isFinite(p.latitude)||!Number.isFinite(p.longitude)||Math.abs(p.latitude)>85.051129||Math.abs(p.longitude)>180)return [];
    ids.add(d.id);
    return [Object.freeze({id:d.id,label:[d.reference,d.recipient_name].filter(Boolean).join(' · ')||'Delivery destination',coordinate:Object.freeze([p.longitude,p.latitude] as const),version:d.destination_version})];
  }));
}
/** Smallest longitude interval, including legitimate 0,0 and dateline pairs. */
export function mapBounds(points:readonly MapPoint[]):[[number,number],[number,number]]|null {
  if(!points.length)return null;
  const xs=points.map(p=>(p.coordinate[0]+360)%360).sort((a,b)=>a-b);
  let gap=-1,start=0;
  for(let i=0;i<xs.length;i++){const next=i===xs.length-1?xs[0]+360:xs[i+1];if(next-xs[i]>gap){gap=next-xs[i];start=(i+1)%xs.length;}}
  const west=xs[start]>180?xs[start]-360:xs[start],east=west+360-gap;
  const ys=points.map(p=>p.coordinate[1]);
  return [[west,Math.min(...ys)],[east,Math.max(...ys)]];
}
export interface DispatchMapPort {
  style(mode:MapMode):void;
  points(points:readonly MapPoint[],selected:string|null,visible:boolean):void;
  fit(bounds:[[number,number],[number,number]]):void;
  move(camera:Partial<MapCamera>):void;
  resize():void;
  destroy():void;
}
export type MapFactoryOptions = {container:HTMLElement;token:string;mode:MapMode;camera:MapCamera;ready:()=>void;error:()=>void;cameraChanged:(camera:MapCamera)=>void;select:(id:string)=>void};
export type DispatchMapFactory = (options:MapFactoryOptions)=>Promise<DispatchMapPort>;
export type MapState = Readonly<{phase:'unconfigured'|'loading'|'ready'|'failed'|'closed';mode:MapMode;camera:MapCamera;visible:boolean}>;
const world=():MapCamera=>({center:[0,0],zoom:1,bearing:0,pitch:0});

/** Client-local camera state only; no persistence, writes or authority cache. */
export class DispatchMapController {
  state:MapState;
  private port:DispatchMapPort|null=null;
  private generation=0;
  private timer:ReturnType<typeof setTimeout>|undefined;
  private listeners=new Set<()=>void>();
  private rows:readonly MapPoint[]=[];
  private selected:string|null=null;
  private initialFit=true;
  private container:HTMLElement|null=null;
  constructor(private token:string,private factory:DispatchMapFactory,private onSelect:(id:string)=>void,private timeoutMs=18000){
    this.token=publicMapToken(token);
    this.state={phase:this.token?'loading':'unconfigured',mode:'operations',camera:world(),visible:true};
  }
  subscribe(fn:()=>void){this.listeners.add(fn);return()=>{this.listeners.delete(fn);};}
  private publish(patch:Partial<MapState>){this.state=Object.freeze({...this.state,...patch});for(const fn of this.listeners)fn();}
  private stop(){clearTimeout(this.timer);this.timer=undefined;const port=this.port;this.port=null;port?.destroy();}
  private fail(epoch:number){if(epoch!==this.generation||this.state.phase==='closed')return;++this.generation;this.stop();this.publish({phase:'failed'});}
  private deadline(epoch:number){clearTimeout(this.timer);this.timer=setTimeout(()=>this.fail(epoch),this.timeoutMs);}
  async attach(container:HTMLElement){
    if(this.state.phase==='closed'||!this.token)return;
    this.container=container;const epoch=++this.generation;this.stop();this.publish({phase:'loading'});this.deadline(epoch);
    let loaded=false;
    const ready=()=>{loaded=true;if(epoch===this.generation&&this.port)this.finish();};
    try{
      const port=await this.factory({container,token:this.token,mode:this.state.mode,camera:this.state.camera,ready,error:()=>this.fail(epoch),
        cameraChanged:camera=>{if(epoch===this.generation)this.publish({camera});},
        select:id=>{if(epoch===this.generation&&this.state.phase==='ready'&&this.rows.some(p=>p.id===id))this.onSelect(id);}});
      if(epoch!==this.generation){port.destroy();return;}
      this.port=port;if(loaded)this.finish();
    }catch{this.fail(epoch);}
  }
  private finish(){
    clearTimeout(this.timer);
    this.publish({phase:'ready'});
    try{this.render();if(this.initialFit&&this.rows.length){this.fit();this.initialFit=false;}}
    catch{this.fail(this.generation);}
  }
  private render(){this.port?.points(this.rows,this.selected,this.state.visible);}
  update(points:readonly MapPoint[],selected:string|null){
    if(this.state.phase==='closed')return;
    this.rows=points;this.selected=points.some(p=>p.id===selected)?selected:null;
    if(this.state.phase==='ready'){
      try{this.render();if(this.initialFit&&points.length){this.fit();this.initialFit=false;}}
      catch{this.fail(this.generation);}
    }
  }
  retry(){if(this.container&&this.state.phase==='failed')void this.attach(this.container);}
  setMode(mode:MapMode){
    if(this.state.phase!=='ready'||!['operations','satellite','site'].includes(mode))return;
    const target=this.rows.find(p=>p.id===this.selected);
    if(mode==='site'&&!target)return;
    try{
      const camera:Partial<MapCamera>=mode==='site'?{center:[...target!.coordinate],zoom:17.1,pitch:55}:{pitch:0,bearing:0};
      this.port?.move(camera);
      if(mode===this.state.mode)return;
      this.publish({mode,phase:'loading'});this.deadline(this.generation);this.port?.style(mode);
    }catch{this.fail(this.generation);}
  }
  control(action:'left'|'right'|'north'|'fit'|'selected'){
    if(this.state.phase!=='ready')return;
    try{
      if(action==='fit'){this.fit();return;}
      if(action==='selected'){const p=this.rows.find(p=>p.id===this.selected);if(p)this.port?.move({center:[...p.coordinate],zoom:16});return;}
      this.port?.move({bearing:action==='north'?0:this.state.camera.bearing+(action==='left'?-20:20)});
    }catch{this.fail(this.generation);}
  }
  private fit(){const bounds=mapBounds(this.rows);if(bounds)this.port?.fit(bounds);}
  visibility(visible:boolean){if(this.state.phase==='closed')return;this.publish({visible});try{this.render();}catch{this.fail(this.generation);}}
  resize(){if(this.state.phase==='closed')return;try{this.port?.resize();}catch{this.fail(this.generation);}}
  dispose(){++this.generation;this.stop();this.rows=[];this.selected=null;this.container=null;this.token='';this.publish({phase:'closed',camera:world()});this.listeners.clear();}
}
