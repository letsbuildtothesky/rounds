import 'package:flutter/material.dart';

import '../ui/components/package_problem_view.dart';
import 'pickup_issue_form_controller.dart';

/// Staged G03 route. Explicit callbacks keep contact/hold/recovery navigation
/// truthful; this cannot manufacture custody or Operations instructions.
class PickupIssueFormRoute extends StatefulWidget {
  const PickupIssueFormRoute({
    required this.controller,
    required this.onBack,
    required this.onMore,
    required this.onRecovery,
    required this.onReported,
    this.onCallRecipient,
    this.onMessageOperations,
    super.key,
  });
  final PickupIssueFormController controller;
  final VoidCallback onBack, onMore;
  final VoidCallback? onCallRecipient, onMessageOperations;
  final ValueChanged<PickupIssueFormController> onRecovery, onReported;
  @override
  State<PickupIssueFormRoute> createState() => _PickupIssueFormRouteState();
}

class _PickupIssueFormRouteState extends State<PickupIssueFormRoute> {
  late final TextEditingController _details;
  late bool _choices;
  MemoryImage? _image;
  PickupIssueFormController? _reportedController;
  @override
  void initState() {
    super.initState();
    _details = TextEditingController(text: widget.controller.form.detail);
    _choices = widget.controller.form.reason == null;
    _resume(widget.controller);
  }

  void _resume(PickupIssueFormController c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(c, widget.controller) || !c.form.frozen) {
        return;
      }
      try {
        c.requireCurrent();
      } catch (_) {
        return;
      }
      // Reopening a frozen report must reach recovery, not an uneditable form
      // with a disabled primary button and no way forward.
      if (c.committed) {
        _reported(c);
      } else {
        widget.onRecovery(c);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PickupIssueFormRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _image?.evict();
    _image = null;
    _details.text = widget.controller.form.detail;
    _choices = widget.controller.form.reason == null;
    _reportedController = null;
    _resume(widget.controller);
  }

  void _back() {
    if (!_choices && !widget.controller.form.frozen) {
      setState(() => _choices = true);
    } else {
      widget.onBack();
    }
  }

  void _reported(PickupIssueFormController c) {
    // A failed reply read does not undo a committed report or resend it. The
    // approved host gets waiting/instructions/last-known/failure separately.
    try {
      if (!mounted || !identical(c, widget.controller)) return;
      c.requireCurrent();
      if (identical(_reportedController, c)) return;
      _reportedController = c;
      // Navigate immediately with a loading state, not after a slow network
      // round trip. The host retains this controller and listens for replies.
      c.refreshInstructions().catchError((Object _) {
        // Network failures become recovery state. Auth/dispose throws only
        // after clearing private state; the Auth host owns removal.
      });
      if (!mounted || !identical(c, widget.controller)) return;
      c.requireCurrent();
    } catch (_) {
      // Auth invalidation owns screen removal; never expose another session.
      return;
    }
    widget.onReported(c);
  }

  Future<void> _action(
    Future<void> Function() action, {
    bool submit = false,
    bool choose = false,
  }) async {
    final c = widget.controller;
    try {
      await action();
    } catch (_) {
      // Session/Auth removal is owned by the host. Never navigate a late
      // result into another principal's screen.
      if (!mounted || !identical(c, widget.controller)) return;
      try {
        c.requireCurrent();
      } catch (_) {
        return;
      }
      widget.onRecovery(c);
      return;
    }
    if (!mounted || !identical(c, widget.controller)) return;
    try {
      c.requireCurrent();
    } catch (_) {
      return;
    }
    if (submit && c.committed) {
      _reported(c);
    } else if (c.errorCode != null || submit) {
      widget.onRecovery(c);
    } else if (choose) {
      _details.text = c.form.detail;
      setState(() => _choices = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller, form = c.form;
      final data = form.snapshot.toJson()['data'] as Map<String, dynamic>;
      final order =
          (data['orders'] as List).singleWhere(
                (o) => o['delivery_id'] == form.deliveryId,
              )
              as Map;
      final parcels = order['packages'] as List;
      // No copied sample person/address/stop count or inferred package units.
      final label = parcels.isEmpty
          ? (order['lines'] as List).map((l) => l['label']).join(' + ')
          : parcels.map((p) => p['label']).join(' + ');
      if (!identical(_image?.bytes, c.preview)) {
        _image?.evict();
        _image = c.preview == null ? null : MemoryImage(c.preview!);
      }
      return PopScope(
        canPop: _choices || form.frozen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: PackageProblemView(
          stopLabel: 'Pickup · ${order['reference']}',
          recipient: order['recipient_name'] as String,
          address: data['pickup_site_name'] as String,
          problemLabel: 'Pickup problem',
          packageLabel: label,
          packageMeta:
              '${order['reference']} · ${parcels.length} ${parcels.length == 1 ? 'package' : 'packages'}',
          reason: form.reason,
          showChoices: _choices,
          details: _details,
          photo: _image,
          busy: c.busy,
          locked: form.frozen,
          onBack: _back,
          onMore: widget.onMore,
          onChoose: (reason) => _action(() => c.choose(reason), choose: true),
          onDetail: (value) => c.editDetail(value),
          onPhoto: () => _action(() => c.capture()),
          onSubmit: () => _action(c.submit, submit: true),
          onCallRecipient: widget.onCallRecipient,
          onMessageOperations: widget.onMessageOperations,
          error: c.errorCode == null
              ? null
              : 'Draft could not be saved. Keep this screen open.',
        ),
      );
    },
  );
  @override
  void dispose() {
    _image?.evict();
    _details.dispose();
    super.dispose();
  }
}
