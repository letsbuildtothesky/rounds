-- Attribute every new short-retention telemetry sample to its authenticated
-- operational context. Historical samples remain null and are never guessed
-- into a Round trail.

alter table public.driver_location_samples
  add column round_id uuid,
  add column stop_id uuid;

create index driver_location_samples_round_trail_idx
  on public.driver_location_samples (tenant_id, round_id, driver_id, captured_at)
  where round_id is not null;

create or replace function public.ingest_phase_zero_location_batch(p_batch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, realtime
as $$
declare
  v_tenant_id uuid := (p_batch ->> 'tenantId')::uuid;
  v_driver_id uuid := (p_batch ->> 'driverId')::uuid;
  v_device_id uuid := (p_batch ->> 'deviceId')::uuid;
  v_session_id uuid := (p_batch ->> 'sessionId')::uuid;
  v_trace_id uuid := (p_batch ->> 'traceId')::uuid;
  v_round_id uuid := nullif(p_batch ->> 'roundId', '')::uuid;
  v_stop_id uuid := nullif(p_batch ->> 'stopId', '')::uuid;
  v_sample_count integer := jsonb_array_length(p_batch -> 'samples');
  v_accepted integer := 0;
  v_previous_watermark bigint := 0;
  v_watermark bigint := 0;
  v_latest jsonb;
  v_payload jsonb;
begin
  if (p_batch ->> 'schemaVersion')::integer <> 1 then
    raise exception 'unsupported schema version';
  end if;
  if v_sample_count < 1 or v_sample_count > 200 then
    raise exception 'sample count must be between 1 and 200';
  end if;

  select coalesce(max(ingest_watermark), 0)
    into v_previous_watermark
    from public.driver_position_current
   where driver_id = v_driver_id;

  insert into public.driver_location_samples (
    tenant_id,
    driver_id,
    session_id,
    round_id,
    stop_id,
    sequence,
    source,
    position,
    captured_at,
    accuracy_meters,
    speed_meters_per_second,
    heading_degrees
  )
  select
    v_tenant_id,
    v_driver_id,
    v_session_id,
    v_round_id,
    v_stop_id,
    (sample ->> 'sequence')::bigint,
    (sample ->> 'source')::public.location_source,
    st_setsrid(
      st_makepoint(
        (sample ->> 'longitude')::double precision,
        (sample ->> 'latitude')::double precision
      ),
      4326
    )::extensions.geography,
    (sample ->> 'capturedAt')::timestamptz,
    (sample ->> 'accuracyMeters')::real,
    nullif(sample ->> 'speedMetersPerSecond', '')::real,
    nullif(sample ->> 'headingDegrees', '')::real
  from jsonb_array_elements(p_batch -> 'samples') as sample
  on conflict (driver_id, session_id, sequence) do nothing;

  get diagnostics v_accepted = row_count;

  with recursive contiguous(sequence) as (
    select v_previous_watermark
    union all
    select contiguous.sequence + 1
      from contiguous
     where exists (
       select 1
         from public.driver_location_samples samples
        where samples.driver_id = v_driver_id
          and samples.session_id = v_session_id
          and samples.sequence = contiguous.sequence + 1
     )
  )
  select max(sequence) into v_watermark from contiguous;

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
    v_watermark,
    now()
  )
  on conflict (driver_id) do update set
    tenant_id = excluded.tenant_id,
    device_id = excluded.device_id,
    session_id = excluded.session_id,
    round_id = excluded.round_id,
    stop_id = excluded.stop_id,
    source = excluded.source,
    position = excluded.position,
    captured_at = excluded.captured_at,
    accuracy_meters = excluded.accuracy_meters,
    speed_meters_per_second = excluded.speed_meters_per_second,
    heading_degrees = excluded.heading_degrees,
    ingest_watermark = excluded.ingest_watermark,
    received_at = now(),
    updated_at = now()
  where excluded.captured_at >= public.driver_position_current.captured_at;

  insert into public.phase_zero_ingest_requests (
    tenant_id,
    driver_id,
    session_id,
    trace_id,
    first_sequence,
    last_sequence,
    sample_count,
    accepted_samples,
    duplicate_samples,
    ingest_watermark
  ) values (
    v_tenant_id,
    v_driver_id,
    v_session_id,
    v_trace_id,
    (p_batch ->> 'firstSequence')::bigint,
    (p_batch ->> 'lastSequence')::bigint,
    v_sample_count,
    v_accepted,
    v_sample_count - v_accepted,
    v_watermark
  );

  v_payload := jsonb_build_object(
    'event', 'fleet.positions',
    'version', 1,
    'tenantId', v_tenant_id,
    'asOf', now(),
    'drivers', jsonb_build_array(jsonb_build_object(
      'driverId', v_driver_id,
      'latitude', (v_latest ->> 'latitude')::double precision,
      'longitude', (v_latest ->> 'longitude')::double precision,
      'sourceAt', (v_latest ->> 'capturedAt')::timestamptz,
      'receivedAt', now(),
      'accuracyMeters', (v_latest ->> 'accuracyMeters')::real,
      'source', v_latest ->> 'source',
      'ingestWatermark', v_watermark,
      'freshness', case
        when now() - (v_latest ->> 'capturedAt')::timestamptz <= interval '30 seconds' then 'live'
        when now() - (v_latest ->> 'capturedAt')::timestamptz <= interval '90 seconds' then 'aging'
        else 'stale'
      end
    ))
  );

  perform realtime.send(
    v_payload,
    'fleet.positions',
    'phase-zero-' || v_tenant_id::text,
    false
  );

  return jsonb_build_object(
    'ingestWatermark', v_watermark,
    'acceptedSamples', v_accepted,
    'duplicateSamples', v_sample_count - v_accepted,
    'broadcasts', 1
  );
end;
$$;

revoke all on function public.ingest_phase_zero_location_batch(jsonb) from public, anon, authenticated;
grant execute on function public.ingest_phase_zero_location_batch(jsonb) to service_role;

-- Migration 202609010003 kept the original implementation under this name so
-- the wrapper could initialize a first watermark. The replacement above no
-- longer delegates to it; leaving it executable would permit unscoped samples.
revoke all on function public.ingest_phase_zero_location_batch_v1(jsonb)
  from public, anon, authenticated, service_role;

comment on column public.driver_location_samples.round_id is
  'Exact Round context supplied by the authenticated Driver batch; null historical rows are never inferred into a Round trail.';
comment on column public.driver_location_samples.stop_id is
  'Exact Stop context supplied by the authenticated Driver batch; null means no Stop context was asserted.';
