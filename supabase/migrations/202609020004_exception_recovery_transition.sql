-- The audited Operations resolution command needs one explicit recovery edge.
-- No other exception exit is permitted by the delivery state guard.

create or replace function public.is_valid_delivery_transition(
  p_from public.delivery_state,
  p_to public.delivery_state
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_from = p_to or (p_from, p_to) in (
    ('draft'::public.delivery_state, 'unplanned'::public.delivery_state),
    ('draft'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'planned'::public.delivery_state),
    ('unplanned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('planned'::public.delivery_state, 'assigned'::public.delivery_state),
    ('planned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('assigned'::public.delivery_state, 'pickup_pending'::public.delivery_state),
    ('assigned'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'in_custody'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'exception'::public.delivery_state),
    ('pickup_pending'::public.delivery_state, 'cancelled'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'en_route'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'exception'::public.delivery_state),
    ('in_custody'::public.delivery_state, 'returned'::public.delivery_state),
    ('en_route'::public.delivery_state, 'arrived'::public.delivery_state),
    ('en_route'::public.delivery_state, 'exception'::public.delivery_state),
    ('en_route'::public.delivery_state, 'returned'::public.delivery_state),
    ('arrived'::public.delivery_state, 'delivered_pending_evidence'::public.delivery_state),
    ('arrived'::public.delivery_state, 'exception'::public.delivery_state),
    ('arrived'::public.delivery_state, 'returned'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'delivered'::public.delivery_state),
    ('delivered_pending_evidence'::public.delivery_state, 'exception'::public.delivery_state),
    ('exception'::public.delivery_state, 'assigned'::public.delivery_state)
  );
$$;

comment on function public.is_valid_delivery_transition(public.delivery_state, public.delivery_state) is
  'Canonical delivery state graph, including audited pickup-exception recovery to assigned.';
