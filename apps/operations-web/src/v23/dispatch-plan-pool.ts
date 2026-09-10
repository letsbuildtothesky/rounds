import type {Wire_OperationsDeliveryBoardQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire';

type Delivery=Wire_OperationsDeliveryBoardQueryResult['data']['deliveries'][number];
export type PlanPool='all'|'unplanned';

/** A read-only view, not an eligibility or departure decision. The server
 * already guarantees one current-manifest planning reference or explicit null.
 * Closed/historical orders remain in All, never the unplanned work queue. */
export const isUnplannedDelivery=(delivery:Delivery)=>delivery.outcome==='open'&&delivery.planning===null;

export function searchDeliveryRows(rows:readonly Delivery[],query:string){
  const terms=query.trim().toLocaleLowerCase('en').split(/\s+/).filter(Boolean);
  if(!terms.length)return rows;
  return rows.filter(d=>{
    const text=[d.reference,d.recipient_name,d.address_text,d.brand?.name,d.pickup_site.name].filter(Boolean).join(' ').toLocaleLowerCase('en');
    return terms.every(term=>text.includes(term));
  });
}

export function planPoolRows(rows:readonly Delivery[],query:string,brandId:string,pool:PlanPool){
  const matching=searchDeliveryRows(rows,query).filter(d=>!brandId||d.brand?.id===brandId);
  const unplanned=matching.filter(isUnplannedDelivery);
  return {rows:pool==='unplanned'?unplanned:matching,counts:{all:matching.length,unplanned:unplanned.length}};
}

export function planBrands(rows:readonly Delivery[]){
  return [...new Map(rows.flatMap(d=>d.brand?[[d.brand.id,d.brand] as const]:[])).values()]
    .sort((a,b)=>(a.name??'').localeCompare(b.name??'','en')||a.id.localeCompare(b.id));
}
