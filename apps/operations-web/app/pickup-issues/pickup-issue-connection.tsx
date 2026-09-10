'use client';

import {createClient, type Session} from '@supabase/supabase-js';
import {useEffect, useState} from 'react';
import {OperationsPickupIssues} from '../../src/v23/operations-pickup-issues';
import {OperationsDeliveryBoard} from '../../src/v23/operations-delivery-board';
import {OperationsManualIntake} from '../../src/v23/operations-manual-intake';
import {OperationsIssueLogin, verifiedIssueLogin} from '../../src/v23/operations-issue-login';
import {PickupIssueDrawer} from '../../src/v23/pickup-issue-drawer';
import {DispatchWorkspace} from '../../src/v23/dispatch-workspace';
import type {OperationsConnectionConfig} from '../../src/v23/operations-connection-config';

type Config = OperationsConnectionConfig;
const authClients = new Map<string, ReturnType<typeof createClient>>();
function authClient(config: Config) {
  const key = JSON.stringify([config.authOrigin, config.publishableKey]);
  let client = authClients.get(key);
  if (!client) { client = createClient(config.authOrigin, config.publishableKey); authClients.set(key, client); }
  return client;
}
export function PickupIssueConnection({config, layout = 'drawer'}: {config: Config | null; layout?: 'drawer' | 'board'}) {
  const [controller, setController] = useState<OperationsPickupIssues | null>(null);
  const [deliveryController, setDeliveryController] = useState<OperationsDeliveryBoard | null>(null);
  const [intakeController,setIntakeController]=useState<OperationsManualIntake|null>(null);
  const [status, setStatus] = useState('Checking connection…');
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    if (!config) { setStatus('The v2.3 pickup issue connection is not enabled. The existing board and phone are unchanged.'); return; }
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (![config.principalId, config.tenantId, config.cityId].every(id => uuid.test(id)) || !/^\d{4}-\d{2}-\d{2}$/.test(config.serviceDate) || !config.authOrigin || !config.publishableKey) {
      setStatus('The isolated API, account, city and date must be configured before this connection can open. No demo records are substituted.'); return;
    }
    let stopped = false, generation = 0, active: OperationsPickupIssues | null = null;
    let activeDelivery: OperationsDeliveryBoard | null = null;
    let activeIntake:OperationsManualIntake|null=null;
    const clear = () => { active?.dispose(); active=null; activeDelivery?.dispose(); activeDelivery=null;activeIntake?.dispose();activeIntake=null; setController(null); setDeliveryController(null);setIntakeController(null); };
    let sessionValue: {principalId: string; sessionEpoch: number; bearer: string} | null = null;
    let currentLoginId: string | null = null;
    let login: OperationsIssueLogin;
    let storage: Storage;
    let auth: ReturnType<typeof createClient>;
    try {
      const api = new URL(config.apiOrigin), origin = new URL(config.authOrigin);
      if (api.origin !== config.apiOrigin || origin.origin !== config.authOrigin ||
        api.protocol !== 'https:' && !(['localhost', '127.0.0.1', '[::1]'].includes(api.hostname) && api.protocol === 'http:') ||
        origin.protocol !== 'https:') throw new Error();
      storage = window.sessionStorage;
      login = new OperationsIssueLogin(storage, origin.origin, api.origin);
      auth = authClient(config);
    } catch { setStatus('Secure connection or browser recovery storage is unavailable. Nothing has been sent.'); return; }
    const accept = async (candidate: Session | null) => {
      const epoch = ++generation;
      // Synchronously hide old private content even when Auth verification is slow.
      sessionValue = null; currentLoginId = null; clear();
      if (!candidate) {
        try { login.clear(); setStatus('Sign in through the existing Operations sign-in, then reopen this connection.'); }
        catch { setStatus('Sign-in is closed, but this browser could not erase the departing login’s draft. Keep this tab open and resolve browser storage before continuing.'); }
        return;
      }
      setStatus('Verifying Operations sign-in…');
      try {
        // getSession alone is not trusted. Verify the exact bearer with Auth.
        const result = await auth.auth.getUser(candidate.access_token);
        if (stopped || epoch !== generation) return;
        if (result.error || !result.data.user) throw new Error('AUTH_REQUIRED');
        const verified = verifiedIssueLogin(candidate.access_token, result.data.user.id);
        currentLoginId = login.bind(verified);
        sessionValue = {principalId: config.principalId, sessionEpoch: epoch, bearer: verified.bearer};
        const next = new OperationsPickupIssues({baseUrl: config.apiOrigin, includeDisplay: true,
          scope: {principalId: config.principalId, tenantId: config.tenantId, cityId: config.cityId, serviceDate: config.serviceDate, sessionEpoch: epoch},
          session: () => sessionValue,
          recovery: {storage, loginId: currentLoginId, currentLoginId: () => currentLoginId}});
        active = next; setController(next);
        if (layout === 'board') {
          const delivery = new OperationsDeliveryBoard({baseUrl:config.apiOrigin,scope:next.scope,session:()=>sessionValue,includeNow:true});
          activeDelivery=delivery;setDeliveryController(delivery);
          const intake=new OperationsManualIntake({baseUrl:config.apiOrigin,scope:next.scope,session:()=>sessionValue,
            recovery:{storage,loginId:currentLoginId,currentLoginId:()=>currentLoginId}});
          activeIntake=intake;setIntakeController(intake);
          // A refused issue grant must not prevent a board.read result (or vice
          // versa). Each reader owns its failure state; Auth owns both lifetimes.
          await Promise.allSettled([delivery.refresh(),next.refresh()]);
        } else await next.refresh();
      } catch (e) {
        if (stopped || epoch !== generation) return;
        sessionValue = null; currentLoginId = null; clear();
        setStatus(e instanceof Error && e.message.startsWith('RECOVERY_') ? 'Browser draft recovery is unavailable. Sending is blocked; do not clear browser data.' : 'The sign-in could not be verified. No pickup issues or saved text have been opened.');
      }
    };
    // Subscribe first: INITIAL_SESSION provides the persisted candidate and the
    // same path handles renewal, sign-out and account changes. Do not call Auth
    // recursively from inside its synchronous event callback.
    const {data} = auth.auth.onAuthStateChange((_event, candidate) => {
      if (stopped) return;
      ++generation; sessionValue = null; currentLoginId = null; clear();
      const scheduled = generation;
      queueMicrotask(() => { if (!stopped && generation === scheduled) void accept(candidate); });
    });
    return () => { stopped = true; ++generation; sessionValue = null; currentLoginId = null; active?.dispose(); activeDelivery?.dispose();activeIntake?.dispose(); data.subscription.unsubscribe(); };
  }, [config, retry, layout]);
  if (controller && layout === 'board') return <main><DispatchWorkspace key={JSON.stringify(controller.scope)} controller={controller} deliveryController={deliveryController ?? undefined} mapboxToken={config?.mapboxToken} intakeController={intakeController??undefined}/></main>;
  return <main className="pickup-issue-entry">{controller ? <PickupIssueDrawer key={JSON.stringify(controller.scope)} controller={controller}/> : <section className="connection-panel" aria-live="polite"><h1>{layout === 'board' ? 'Rounds Dispatch' : 'Pickup issues'}</h1><p>{status}</p>{config && <button className="primary-button" onClick={() => setRetry(n => n + 1)}>Check connection</button>}</section>}</main>;
}
