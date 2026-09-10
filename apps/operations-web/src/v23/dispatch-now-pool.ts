import type {Wire_OperationsDeliveryBoardQueryResult} from '../../../../packages/contracts/src/v23/pickup-wire.js';
import {planPoolRows} from './dispatch-plan-pool';
type Data=Wire_OperationsDeliveryBoardQueryResult['data'];
export type NowEntry=NonNullable<Data['now']>['entries'][number];
export type NowPool=NowEntry['bucket']|'all';
export const nowReasons:Record<NowEntry['reason'],{bucket:NowEntry['bucket'];label:string}>={
  issue:{bucket:'action',label:'Issue needs attention'},review_needed:{bucket:'action',label:'Address review needed'},
  held:{bucket:'action',label:'Delivery on hold'},awaiting_preparation:{bucket:'action',label:'Awaiting preparation'},
  awaiting_receipt:{bucket:'action',label:'Awaiting receipt'},discrepancy:{bucket:'action',label:'Receipt discrepancy'},
  blocked:{bucket:'action',label:'Departure blocked'},unresolved:{bucket:'action',label:'Outcome needs review'},
  evidence_disputed:{bucket:'action',label:'Evidence disputed'},execution_failed:{bucket:'action',label:'Delivery attempt needs attention'},
  assignment_declined:{bucket:'action',label:'Driver cannot comply'},
  collected:{bucket:'road',label:'On the road'},handed_over:{bucket:'road',label:'Handed over · Completion pending'},
  delivered:{bucket:'done',label:'Delivered'},returned:{bucket:'done',label:'Returned'},cancelled:{bucket:'done',label:'Cancelled'},rescheduled:{bucket:'done',label:'Rescheduled'},
  ready_to_assign:{bucket:'ready',label:'Ready to assign'},ready_for_pickup:{bucket:'ready',label:'Ready for pickup'},scheduled:{bucket:'planned',label:'Scheduled'},
};
/** Validate cross-field closure as well as the generated structural schema. */
export function validNowClosure(data:Data):boolean {
  const now=data.now;if(!now)return false;
  return now.entries.length===data.deliveries.length&&new Set(now.entries.map(e=>e.delivery_id)).size===now.entries.length&&
    now.entries.every(e=>data.deliveries.some(d=>d.id===e.delivery_id)&&nowReasons[e.reason]?.bucket===e.bucket);
}
export function nowPoolRows(rows:Data['deliveries'],entries:NowEntry[],query:string,brand:string,pool:NowPool){
  const all=planPoolRows(rows,query,brand,'all').rows;
  const byId=new Map(entries.map(e=>[e.delivery_id,e]));
  const counts={all:all.length,action:0,ready:0,road:0,done:0,planned:0};
  for(const d of all){const e=byId.get(d.id);if(e)counts[e.bucket]++;}
  return {counts,rows:all.filter(d=>pool==='all'||byId.get(d.id)?.bucket===pool)};
}
