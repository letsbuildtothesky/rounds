// Explicitly labelled local map-port double. Does not draw substitute geography
// and is never imported by a production route. Browser UI checks are not SDK QA.
import type {DispatchMapFactory} from '../../src/v23/dispatch-map-controller';
export const reviewMapFactory:DispatchMapFactory=async options=>{
  const root=document.createElement('div');root.dataset.mapFixture='true';
  root.style.cssText='position:absolute;left:24px;top:100px;max-width:calc(100% - 120px);padding:12px;background:white;border:1px dashed #8692a3;font:12px Arial;';
  const title=document.createElement('p');title.textContent='SYNTHETIC MAP PORT · No basemap / provider requests';
  const camera=document.createElement('output');camera.setAttribute('aria-label','Test map camera');
  const list=document.createElement('div');const fail=document.createElement('button');fail.type='button';fail.textContent='Test map failure';fail.addEventListener('click',options.error);
  root.append(title,camera,list,fail);options.container.append(root);
  let current=options.camera,closed=false;
  const publish=()=>{camera.textContent=JSON.stringify(current);options.cameraChanged(current);};
  publish();queueMicrotask(options.ready);
  return {
    style:()=>queueMicrotask(()=>{if(!closed)options.ready();}),
    points:(points,selected,visible)=>{list.replaceChildren();list.hidden=!visible;for(const p of points.slice(0,3)){const b=document.createElement('button');b.type='button';b.textContent=p.label;b.setAttribute('aria-pressed',String(p.id===selected));b.addEventListener('click',()=>options.select(p.id));list.append(b);}},
    fit:bounds=>{root.dataset.bounds=JSON.stringify(bounds);},move:change=>{current={...current,...change};publish();},resize:()=>{},
    destroy:()=>{closed=true;root.remove();},
  };
};
