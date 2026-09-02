-- Slice 1 Operations communications subset: authorized tenant staff can append
-- durable replies to existing Team-driver threads through the server boundary.

create or replace function public.send_operations_message_command(
  p_command jsonb,
  p_actor_person_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_command_type constant text := 'thread.send_operations_message';
  v_tenant_id uuid;
  v_thread_id uuid;
  v_command_id uuid;
  v_trace_id uuid;
  v_expected_version bigint;
  v_idempotency_key text;
  v_payload jsonb;
  v_payload_hash text;
  v_existing public.command_idempotency%rowtype;
  v_thread public.operations_threads%rowtype;
  v_actor_role public.tenant_role;
  v_body text;
  v_message_id uuid := gen_random_uuid();
  v_event_id uuid := gen_random_uuid();
  v_occurred_at timestamptz := now();
  v_thread_version bigint;
  v_message jsonb;
  v_event jsonb;
  v_state jsonb;
  v_result jsonb;
begin
  if p_command is null or coalesce((p_command ->> 'schemaVersion')::integer, 0) <> 1
    or p_command ->> 'commandType' <> v_command_type then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Unsupported command envelope'));
  end if;
  begin
    v_tenant_id := (p_command ->> 'tenantId')::uuid;
    v_thread_id := (p_command ->> 'aggregateId')::uuid;
    v_command_id := (p_command ->> 'commandId')::uuid;
    v_trace_id := (p_command ->> 'traceId')::uuid;
    v_expected_version := (p_command ->> 'expectedVersion')::bigint;
  exception when others then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message identifiers or version are invalid'));
  end;
  v_idempotency_key := btrim(coalesce(p_command ->> 'idempotencyKey', ''));
  v_payload := p_command -> 'payload';
  v_body := btrim(coalesce(v_payload ->> 'body', ''));
  if v_expected_version < 1 or v_idempotency_key = '' or length(v_idempotency_key) > 200
    or length(v_body) < 1 or length(v_body) > 2000 then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'VALIDATION_FAILED', 'message', 'Message payload is invalid'));
  end if;

  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_tenant_id::text || ':' || v_command_type || ':' || v_idempotency_key, 0));
  select * into v_existing from public.command_idempotency
   where tenant_id = v_tenant_id and command_type = v_command_type and idempotency_key = v_idempotency_key;
  if found then
    if v_existing.payload_hash <> v_payload_hash then
      return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
        'code', 'IDEMPOTENCY_CONFLICT', 'message', 'Idempotency key was already used with different payload'));
    end if;
    return v_existing.result || jsonb_build_object('deduplicated', true);
  end if;

  select membership.role into v_actor_role
    from public.tenant_memberships membership
   where membership.tenant_id = v_tenant_id and membership.person_id = p_actor_person_id
     and membership.status = 'active'
     and membership.role in ('tenant_owner', 'operations_admin', 'dispatcher')
   limit 1;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations reply is not permitted for this thread'));
  end if;

  select thread.* into v_thread
    from public.operations_threads thread
    join public.rounds round_record
      on round_record.tenant_id = thread.tenant_id and round_record.id = thread.round_id
    join public.driver_tenant_relationships relationship
      on relationship.driver_id = thread.driver_id and relationship.tenant_id = thread.tenant_id
   where thread.id = v_thread_id and thread.tenant_id = v_tenant_id
     and relationship.relationship_kind = 'team' and relationship.status = 'active'
     and relationship.deleted_at is null
     and round_record.state in ('approved', 'loading', 'active') and round_record.deleted_at is null
   for update of thread;
  if not found then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'NOT_AUTHORIZED', 'message', 'Operations reply is not permitted for this thread'));
  end if;
  if v_thread.version <> v_expected_version then
    return jsonb_build_object('status', 'rejected', 'error', jsonb_build_object(
      'code', 'STALE_VERSION', 'message', 'Thread changed; refresh before sending another message'));
  end if;

  insert into public.operations_messages (
    id, tenant_id, thread_id, sender, sender_person_id, body, sent_at, command_id
  ) values (
    v_message_id, v_tenant_id, v_thread_id, 'operations', p_actor_person_id, v_body,
    v_occurred_at, v_command_id
  );
  update public.operations_threads
     set version = version + 1, updated_at = v_occurred_at
   where id = v_thread_id returning version into v_thread_version;

  v_message := jsonb_build_object(
    'id', v_message_id, 'sender', 'operations', 'body', v_body, 'sentAt', v_occurred_at);
  v_state := jsonb_build_object('threadId', v_thread_id, 'message', v_message);
  v_event := jsonb_build_object(
    'event', 'thread.message_sent', 'version', 1, 'eventId', v_event_id,
    'traceId', v_trace_id, 'tenantId', v_tenant_id, 'aggregateType', 'operations_thread',
    'aggregateId', v_thread_id, 'aggregateVersion', v_thread_version, 'occurredAt', v_occurred_at,
    'payload', v_state);
  insert into public.audit_events (
    tenant_id, actor_person_id, actor_role, action, aggregate_type, aggregate_id,
    aggregate_version, command_id, trace_id, semantic_change
  ) values (
    v_tenant_id, p_actor_person_id, v_actor_role, 'thread.message_sent', 'operations_thread',
    v_thread_id, v_thread_version, v_command_id, v_trace_id,
    jsonb_build_object('messageId', v_message_id, 'sender', 'operations'));
  insert into public.domain_event_outbox (
    id, tenant_id, event_name, event_version, aggregate_type, aggregate_id,
    aggregate_version, trace_id, payload, occurred_at
  ) values (
    v_event_id, v_tenant_id, 'thread.message_sent', 1, 'operations_thread', v_thread_id,
    v_thread_version, v_trace_id, v_event, v_occurred_at);
  v_result := jsonb_build_object(
    'status', 'committed', 'aggregateVersion', v_thread_version,
    'state', v_state, 'events', jsonb_build_array(v_event));
  insert into public.command_idempotency (
    tenant_id, command_type, idempotency_key, command_id, aggregate_id,
    payload_hash, status, result, trace_id, actor_person_id
  ) values (
    v_tenant_id, v_command_type, v_idempotency_key, v_command_id, v_thread_id,
    v_payload_hash, 'committed', v_result, v_trace_id, p_actor_person_id);
  return v_result;
end;
$$;

revoke all on function public.send_operations_message_command(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.send_operations_message_command(jsonb, uuid) to service_role;

comment on function public.send_operations_message_command(jsonb, uuid) is
  'Server-only versioned and idempotent Operations reply command for an active Team-driver thread.';
