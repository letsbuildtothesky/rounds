import 'package:flutter/material.dart';

import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';

class PickupConfirmationScreen extends StatefulWidget {
  const PickupConfirmationScreen({
    required this.controller,
    required this.round,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;

  @override
  State<PickupConfirmationScreen> createState() =>
      _PickupConfirmationScreenState();
}

class _PickupConfirmationScreenState extends State<PickupConfirmationScreen> {
  final Set<String> _confirmed = {};
  bool _submitting = false;
  bool _pendingSync = false;

  int get _lineCount => widget.round.stops.fold(
    0,
    (count, stop) => count + stop.manifestItems.length,
  );
  int get _unitCount => widget.round.stops.fold(
    0,
    (count, stop) =>
        count +
        stop.manifestItems.fold(0, (units, item) => units + item.quantity),
  );
  bool get _ready => _lineCount > 0 && _confirmed.length == _lineCount;

  String _key(DriverRoundStopModel stop, DriverManifestItemModel item) =>
      '${stop.id}:${item.lineNumber}';

  Future<void> _confirm() async {
    if (!_ready || _submitting) return;
    setState(() => _submitting = true);
    final outcome = await widget.controller.confirmPickup(widget.round);
    if (!mounted) return;
    if (outcome?.committed ?? false) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _submitting = false);
    if (outcome?.pendingSync ?? false) {
      setState(() => _pendingSync = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pickup saved on this phone. Pending sync — custody is not confirmed yet.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.driverError ?? 'Pickup could not be confirmed',
        ),
      ),
    );
  }

  Future<void> _reportProblem() async {
    if (_submitting || _pendingSync) return;
    final draft = await showModalBottomSheet<_PickupProblemDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PickupProblemSheet(stops: widget.round.stops),
    );
    if (draft == null || !mounted) return;
    setState(() => _submitting = true);
    final outcome = await widget.controller.reportPickupProblem(
      stop: draft.stop,
      category: draft.category,
      note: draft.note,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome?.committed ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup problem sent to Operations. Pickup stopped.'),
        ),
      );
      Navigator.of(context).pop(false);
      return;
    }
    if (outcome?.pendingSync ?? false) {
      setState(() => _pendingSync = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Problem saved on this phone. Pending sync — do not confirm pickup.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.driverError ?? 'Pickup problem could not be sent',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          _PickupTopBar(round: widget.round),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
              children: [
                _PickupHero(
                  confirmed: _confirmed.length,
                  lineCount: _lineCount,
                  unitCount: _unitCount,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE1E6EA)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 54),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        color: const Color(0xFFFAFBFB),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Collect',
                              style: TextStyle(
                                color: Color(0xFF172238),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Tap when physically present',
                              style: TextStyle(
                                color: Color(0xFF748094),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final stop in widget.round.stops)
                        for (final item in stop.manifestItems)
                          _ManifestLine(
                            key: Key('manifest-${stop.id}-${item.lineNumber}'),
                            item: item,
                            reference: stop.deliveryReference,
                            recipient: stop.recipientName,
                            checked: _confirmed.contains(_key(stop, item)),
                            onTap: () => setState(() {
                              final key = _key(stop, item);
                              if (!_confirmed.add(key)) _confirmed.remove(key);
                            }),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _PickupProblemButton(
                  key: const Key('pickup-problem'),
                  onPressed: _submitting || _pendingSync
                      ? null
                      : _reportProblem,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE1E6EA))),
            ),
            child: SizedBox(
              height: 64,
              child: FilledButton(
                key: const Key('confirm-pickup'),
                onPressed: _ready && !_submitting && !_pendingSync
                    ? _confirm
                    : null,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF168B50),
                  disabledBackgroundColor: const Color(0xFFD9DFE5),
                  disabledForegroundColor: const Color(0xFF85909D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(
                  _pendingSync
                      ? 'Pending sync — not confirmed'
                      : _submitting
                      ? 'Sending to server…'
                      : 'Confirm pickup',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PickupTopBar extends StatelessWidget {
  const _PickupTopBar({required this.round});

  final DriverRoundModel round;

  @override
  Widget build(BuildContext context) {
    final deliveryCount = round.stops.length;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E6EA))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: OutlinedButton(
              key: const Key('pickup-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFF172238),
                side: const BorderSide(color: Color(0xFFCBD4DC)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Icon(Icons.arrow_back, size: 21),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AT PICKUP',
                  style: TextStyle(
                    color: Color(0xFFFF6420),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .88,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  round.tenantName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172238),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$deliveryCount ${deliveryCount == 1 ? 'delivery' : 'deliveries'}',
            style: const TextStyle(
              color: Color(0xFF748094),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupHero extends StatelessWidget {
  const _PickupHero({
    required this.confirmed,
    required this.lineCount,
    required this.unitCount,
  });

  final int confirmed;
  final int lineCount;
  final int unitCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 22),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E6EA))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Confirm pickup',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: Color(0xFF172238),
                  fontSize: 31,
                  height: .98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.7,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$confirmed / $lineCount',
                  key: const Key('pickup-progress'),
                  style: const TextStyle(
                    color: Color(0xFF172238),
                    fontSize: 27,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'confirmed',
                  style: TextStyle(
                    color: Color(0xFF748094),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$unitCount package${unitCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF3D4A5D),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(text: ' · physical manifest'),
            ],
          ),
          style: const TextStyle(
            color: Color(0xFF748094),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PickupProblemButton extends StatelessWidget {
  const _PickupProblemButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        foregroundColor: const Color(0xFFBF4A4A),
        side: const BorderSide(color: Color(0xFFE6C8C8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pickup problem',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          Icon(Icons.chevron_right, size: 22),
        ],
      ),
    ),
  );
}

class _PickupProblemDraft {
  const _PickupProblemDraft(this.stop, this.category, this.note);
  final DriverRoundStopModel stop;
  final String category;
  final String note;
}

class _PickupProblemSheet extends StatefulWidget {
  const _PickupProblemSheet({required this.stops});
  final List<DriverRoundStopModel> stops;

  @override
  State<_PickupProblemSheet> createState() => _PickupProblemSheetState();
}

class _PickupProblemSheetState extends State<_PickupProblemSheet> {
  late DriverRoundStopModel _stop = widget.stops.first;
  String? _category;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      18,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pickup problem',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the exact delivery and problem. Ordinary pickup will stop until Operations resolves it.',
            style: TextStyle(color: Color(0xFF748094)),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<DriverRoundStopModel>(
            initialValue: _stop,
            decoration: const InputDecoration(
              labelText: 'Delivery',
              border: OutlineInputBorder(),
            ),
            items: widget.stops
                .map(
                  (stop) => DropdownMenuItem(
                    value: stop,
                    child: Text(
                      '${stop.deliveryReference} · ${stop.recipientName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (stop) {
              if (stop != null) setState(() => _stop = stop);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'What is wrong?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          RadioGroup<String>(
            groupValue: _category,
            onChanged: (value) => setState(() => _category = value),
            child: const Column(
              children: [
                RadioListTile(
                  value: 'missing_item',
                  title: Text('Missing item'),
                  subtitle: Text('An expected package or item is not here'),
                ),
                RadioListTile(
                  value: 'wrong_item',
                  title: Text('Wrong item'),
                  subtitle: Text('The package does not match this delivery'),
                ),
                RadioListTile(
                  value: 'damaged_item',
                  title: Text('Damaged item'),
                  subtitle: Text('The package or item is damaged'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note for Operations (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('send-pickup-problem'),
            onPressed: _category == null
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(_PickupProblemDraft(_stop, _category!, _note.text)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB43F3F),
            ),
            child: const Text('Send to Operations'),
          ),
        ],
      ),
    ),
  );
}

class _ManifestLine extends StatelessWidget {
  const _ManifestLine({
    required this.item,
    required this.reference,
    required this.recipient,
    required this.checked,
    required this.onTap,
    super.key,
  });
  final DriverManifestItemModel item;
  final String reference;
  final String recipient;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFFBFEFC) : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEDEFF2))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: checked ? const Color(0xFF168B50) : Colors.white,
              border: Border.all(
                color: checked
                    ? const Color(0xFF168B50)
                    : const Color(0xFFCBD4DC),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: checked
                ? const Icon(Icons.check, size: 19, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFF172238),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$reference · $recipient',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF748094),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '×${item.quantity}',
                style: const TextStyle(
                  color: Color(0xFF172238),
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.handlingNote != null)
                Text(
                  item.handlingNote!,
                  style: TextStyle(
                    color: item.handlingNote!.toLowerCase().contains('cool')
                        ? const Color(0xFF3269B7)
                        : const Color(0xFFFF6420),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
