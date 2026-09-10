import type {DispatchMapFactory,MapPoint} from './dispatch-map-controller';
import {mapStyle} from './dispatch-map-controller';
import {mapIconPaths} from './dispatch-map-icons';

/** Adapts the retained Mapbox SDK/camera primitives to v2.3 IDs. Deliberately
 * does not coerce these orders into historical Round/GPS/route contracts. */
export const createDispatchMap:DispatchMapFactory=async options=>{
  const {default:mapboxgl}=await import('mapbox-gl');
  const style=mapStyle(options.mode);
  const map=new mapboxgl.Map({container:options.container,accessToken:options.token,style:style.url,config:style.config,
    ...options.camera,minZoom:0,maxZoom:20,logoPosition:'bottom-left',attributionControl:true,hash:false});
  let removed=false;
  const markers=new Map<string,{marker:InstanceType<typeof mapboxgl.Marker>;element:HTMLButtonElement;label:HTMLSpanElement}>();
  const camera=()=>{if(!removed){const p=map.getCenter();options.cameraChanged({center:[p.lng,p.lat],zoom:map.getZoom(),bearing:map.getBearing(),pitch:map.getPitch()});}};
  const ready=()=>{if(!removed){camera();options.ready();}};
  const error=()=>{if(!removed)options.error();};
  let observer:ResizeObserver|undefined;
  const destroy=()=>{if(removed)return;removed=true;observer?.disconnect();map.off('style.load',ready);map.off('error',error);map.off('moveend',camera);for(const p of markers.values())p.marker.remove();markers.clear();map.remove();};
  try{
    map.on('style.load',ready);map.on('error',error);map.on('moveend',camera);
    observer=new ResizeObserver(()=>{if(!removed)map.resize();});observer.observe(options.container);
    map.addControl(new mapboxgl.NavigationControl({visualizePitch:true}),'top-right');
  }catch{destroy();throw new Error('MAP_SETUP_FAILED');}
  const duration=()=>window.matchMedia('(prefers-reduced-motion: reduce)').matches?0:300;
  function points(rows:readonly MapPoint[],selected:string|null,visible:boolean){
    const ids=new Set(rows.map(p=>p.id));
    for(const [id,entry]of markers)if(!ids.has(id)){entry.marker.remove();markers.delete(id);}
    for(const p of rows){
      let entry=markers.get(p.id);
      if(!entry){
        const element=document.createElement('button');element.type='button';element.className='dispatch-map-pin';
        // Pin artwork is the source i-pin path, not a fabricated stop number.
        const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('aria-hidden','true');
        const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',mapIconPaths.pin);
        const circle=document.createElementNS(svg.namespaceURI,'circle');circle.setAttribute('cx','12');circle.setAttribute('cy','10');circle.setAttribute('r','2.5');svg.append(path,circle);
        const label=document.createElement('span');label.className='marker-label';element.append(svg,label);
        element.addEventListener('click',()=>options.select(p.id));
        entry={element,label,marker:new mapboxgl.Marker({element}).setLngLat([...p.coordinate]).addTo(map)};markers.set(p.id,entry);
      }
      entry.element.setAttribute('aria-label',`${p.label} · Stored delivery destination, not verified entrance`);
      entry.element.setAttribute('aria-pressed',String(p.id===selected));entry.element.hidden=!visible;
      entry.label.textContent=p.label;entry.marker.setLngLat([...p.coordinate]);
    }
  }
  return {
    style:mode=>{const next=mapStyle(mode);map.setStyle(next.url,{config:next.config,localFontFamily:undefined,localIdeographFontFamily:'sans-serif'});},points,
    fit:bounds=>{const width=options.container.clientWidth,height=options.container.clientHeight;map.fitBounds(bounds,{padding:{top:Math.min(100,height/4),bottom:Math.min(80,height/4),left:Math.min(60,width/4),right:Math.min(85,width/4)},maxZoom:15,duration:duration()});},
    move:camera=>{map.easeTo({...camera,duration:duration()});},resize:()=>map.resize(),
    destroy,
  };
};
