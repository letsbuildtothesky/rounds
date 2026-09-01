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
    final committed = await widget.controller.confirmPickup(widget.round);
    if (!mounted) return;
    if (committed) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.driverError ?? 'Pickup could not be confirmed',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AT PICKUP',
            style: TextStyle(
              color: Color(0xFFFF6420),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            widget.round.pickup.displayName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Center(
            child: Text(
              '${widget.round.stops.length} deliveries',
              style: const TextStyle(
                color: Color(0xFF748094),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Confirm\npickup',
                      style: TextStyle(
                        color: Color(0xFF172238),
                        fontSize: 34,
                        height: .95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_confirmed.length} / $_lineCount',
                          key: const Key('pickup-progress'),
                          style: const TextStyle(
                            color: Color(0xFF172238),
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'confirmed',
                          style: TextStyle(
                            color: Color(0xFF748094),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$_unitCount package unit${_unitCount == 1 ? '' : 's'} · physical manifest',
                  style: const TextStyle(
                    color: Color(0xFF748094),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE1E6EA)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Collect',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Tap when physically present',
                              style: TextStyle(
                                color: Color(0xFF748094),
                                fontSize: 12,
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
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pickup problem saved for structured exception follow-up.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Pickup problem'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBF4A4A),
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE1E6EA))),
            ),
            child: FilledButton(
              key: const Key('confirm-pickup'),
              onPressed: _ready && !_submitting ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF168B50),
                disabledBackgroundColor: const Color(0xFFD9DFE5),
              ),
              child: Text(
                _submitting ? 'Confirming with server…' : 'Confirm pickup',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAEDEF))),
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
                  style: const TextStyle(
                    color: Color(0xFFFF6420),
                    fontSize: 10,
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
