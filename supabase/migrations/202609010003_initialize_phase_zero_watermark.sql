alter function public.ingest_phase_zero_location_batch(jsonb)
  rename to ingest_phase_zero_location_batch_v1;

revoke all on function public.ingest_phase_zero_location_batch_v1(jsonb)
  from public;
grant execute on function public.ingest_phase_zero_location_batch_v1(jsonb)
  to service_role;

create or replace function public.ingest_phase_zero_location_batch(p_batch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid := (p_batch ->> 'tenantId')::uuid;
  v_driver_id uuid := (p_batch ->> 'driverId')::uuid;
  v_device_id uuid := (p_batch ->> 'deviceId')::uuid;
  v_session_id uuid := (p_batch ->> 'sessionId')::uuid;
  v_round_id uuid := nullif(p_batch ->> 'roundId', '')::uuid;
  v_stop_id uuid := nullif(p_batch ->> 'stopId', '')::uuid;
  v_latest jsonb;
begin
  select sample
    into v_latest
    from jsonb_array_elements(p_batch -> 'samples') as sample
   order by (sample ->> 'sequence')::bigint desc
   limit 1;

  insert into public.driver_position_current (
    tenant_id,
    driver_id,
    device_id,
    session_id,
    round_id,
    stop_id,
    source,
    position,
    captured_at,
    accuracy_meters,
    speed_meters_per_second,
    heading_degrees,
    ingest_watermark,
    updated_at
  ) values (
    v_tenant_id,
    v_driver_id,
    v_device_id,
    v_session_id,
    v_round_id,
    v_stop_id,
    (v_latest ->> 'source')::public.location_source,
    st_setsrid(
      st_makepoint(
        (v_latest ->> 'longitude')::double precision,
        (v_latest ->> 'latitude')::double precision
      ),
      4326
    )::extensions.geography,
    (v_latest ->> 'capturedAt')::timestamptz,
    (v_latest ->> 'accuracyMeters')::real,
    nullif(v_latest ->> 'speedMetersPerSecond', '')::real,
    nullif(v_latest ->> 'headingDegrees', '')::real,
    0,
    now()
  )
  on conflict (driver_id) do nothing;

  return public.ingest_phase_zero_location_batch_v1(p_batch);
end;
$$;

revoke all on function public.ingest_phase_zero_location_batch(jsonb)
  from public;
grant execute on function public.ingest_phase_zero_location_batch(jsonb)
  to service_role;
