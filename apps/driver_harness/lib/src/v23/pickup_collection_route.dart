import 'package:flutter/material.dart';

import '../ui/components/pickup_collection_view.dart';
import 'pickup_collection_controller.dart';

/// Staged route binding, NOT installed/main route cutover. Reuses D03/D04 as-is.
/// The owner must provide the approved problem/recovery destinations and Auth
/// gate; missing waiting/review artwork must not be invented by this adapter.
class PickupCollectionRoute extends StatefulWidget {
  const PickupCollectionRoute({
    required this.controller,
    required this.bearer,
    required this.onBack,
    required this.onProblem,
    required this.onCommitted,
    required this.onRecovery,
    super.key,
  });
  final PickupCollectionController controller;
  final String Function() bearer;
  final VoidCallback onBack, onProblem, onCommitted;
  final ValueChanged<PickupCollectionController> onRecovery;
  @override
  State<PickupCollectionRoute> createState() => _PickupCollectionRouteState();
}

class _PickupCollectionRouteState extends State<PickupCollectionRoute> {
  bool _acting = false;
  Future<void> _act(
    Future<void> Function() operation, {
    bool confirmation = false,
  }) async {
    final c = widget.controller;
    if (_acting || c.busy) return;
    _acting = true;
    try {
      await operation();
      if (!mounted || !identical(c, widget.controller)) return;
      c.requireCurrent();
      if (confirmation && c.committed) {
        widget.onCommitted();
      } else if (confirmation || c.errorCode != null) {
        widget.onRecovery(c);
      }
    } catch (_) {
      // The current-session/Auth gate owns lock/dispose handling. Never navigate
      // to success with a result from an old route, principal or session.
    } finally {
      _acting = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller, p = c.presentation;
      return PickupCollectionView(
        merchant: p.merchant,
        stopCount: p.stopCount,
        packages: p.packages,
        selected: c.selected,
        locked: c.busy || c.frozen,
        onToggle: (id) =>
            _act(() => c.setSelected(id, !c.selected.contains(id))),
        onBack: widget.onBack,
        onProblem: widget.onProblem,
        onConfirm: c.canConfirm
            ? () => _act(
                () => c.confirm(bearer: widget.bearer()),
                confirmation: true,
              )
            : null,
        actionLabel: c.committed ? 'Pickup confirmed' : null,
      );
    },
  );
}
