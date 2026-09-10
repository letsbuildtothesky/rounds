import {publicMapToken} from './dispatch-map-controller';
export type OperationsConnectionConfig = Readonly<{apiOrigin: string; principalId: string; tenantId: string; cityId: string; serviceDate: string; authOrigin: string; publishableKey: string;mapboxToken?:string}>;

/** Server-callable allowlist. Never serialize process.env or a service key. */
export function operationsConnectionConfig(env: Record<string, string | undefined>): OperationsConnectionConfig | null {
  if (env.ROUNDS_V23_OPERATIONS_UI !== '1') return null;
  return Object.freeze({
    apiOrigin: env.ROUNDS_V23_OPERATIONS_API_ORIGIN ?? '',
    principalId: env.ROUNDS_V23_OPERATIONS_PRINCIPAL_ID ?? '',
    tenantId: env.ROUNDS_V23_OPERATIONS_TENANT_ID ?? '',
    cityId: env.ROUNDS_V23_OPERATIONS_CITY_ID ?? '',
    serviceDate: env.ROUNDS_V23_OPERATIONS_SERVICE_DATE ?? '',
    authOrigin: env.NEXT_PUBLIC_SUPABASE_URL ?? '',
    publishableKey: env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '',
    mapboxToken:publicMapToken(env.NEXT_PUBLIC_MAPBOX_TOKEN),
  });
}
