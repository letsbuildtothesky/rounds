import { CommandRejection } from './transaction-runner.js';

/** Immutable supersession, never inferred from timestamp or UUID ordering. */
export function currentIssueDecision<T extends {id:string; supersedes_id:string|null}>(rows:readonly T[], state:string):T|undefined {
  if(rows.length>200)throw new CommandRejection('FEATURE_NOT_ENABLED');
  if(!['open','investigating','decided','resolved'].includes(state) ||
     ['decided','resolved'].includes(state)!==(rows.length>0))throw new CommandRejection('SOURCE_STALE');
  if(!rows.length)return undefined;
  const roots=rows.filter(r=>r.supersedes_id===null);
  if(roots.length!==1)throw new CommandRejection('SOURCE_STALE');
  let tip=roots[0]!;const seen=new Set<string>();
  for(;;){
    if(seen.has(tip.id))throw new CommandRejection('SOURCE_STALE');
    seen.add(tip.id);
    const next=rows.filter(r=>r.supersedes_id===tip.id);
    if(next.length>1)throw new CommandRejection('SOURCE_STALE');
    if(!next.length)break;
    tip=next[0]!;
  }
  if(seen.size!==rows.length)throw new CommandRejection('SOURCE_STALE');
  return tip;
}
