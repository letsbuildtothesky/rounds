-- PostgreSQL correctly flags `version` as ambiguous in UPDATE ... FROM when
-- both Delivery and Stop expose that column. Keep migration 006 immutable and
-- qualify every aggregate version source in the stored command definition.

do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.plan_and_approve_round_command(jsonb,uuid)'::regprocedure
  ) into v_definition;

  v_definition := replace(
    v_definition,
    $old$update public.deliveries delivery
     set state = 'planned', version = version + 1, updated_at = v_occurred_at$old$,
    $new$update public.deliveries delivery
     set state = 'planned', version = delivery.version + 1, updated_at = v_occurred_at$new$
  );
  v_definition := replace(
    v_definition,
    $old$update public.deliveries delivery
     set state = 'assigned', version = version + 1, updated_at = v_occurred_at$old$,
    $new$update public.deliveries delivery
     set state = 'assigned', version = delivery.version + 1, updated_at = v_occurred_at$new$
  );
  v_definition := replace(
    v_definition,
    $old$update public.delivery_stops
     set state = 'assigned', version = version + 1, updated_at = v_occurred_at$old$,
    $new$update public.delivery_stops stop_update
     set state = 'assigned', version = stop_update.version + 1, updated_at = v_occurred_at$new$
  );

  if v_definition like '%version = version + 1%' then
    raise exception 'Round command version qualification patch was incomplete';
  end if;

  execute v_definition;
end;
$migration$;
