import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
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
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final horizontalPadding = compact
        ? DriverD03D04Metrics.compactContentPaddingHorizontal
        : DriverD03D04Metrics.contentPaddingHorizontal;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Stack(
            children: [
              Column(
                children: [
                  _PickupTopBar(round: widget.round),
                  Expanded(
                    child: ListView(
                      key: const Key('pickup-content'),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        DriverD03D04Metrics.contentPaddingTop,
                        horizontalPadding,
                        DriverD03D04Metrics.contentPaddingBottom,
                      ),
                      children: [
                        _PickupHero(
                          confirmed: _confirmed.length,
                          lineCount: _lineCount,
                          unitCount: _unitCount,
                          compact: compact,
                        ),
                        SizedBox(height: DriverD03D04Metrics.manifestMarginTop),
                        _PickupManifest(
                          round: widget.round,
                          compact: compact,
                          confirmed: _confirmed,
                          itemKey: _key,
                          onToggle: (stop, item) => setState(() {
                            final key = _key(stop, item);
                            if (!_confirmed.add(key)) _confirmed.remove(key);
                          }),
                        ),
                        SizedBox(height: DriverD03D04Metrics.problemMarginTop),
                        _PickupProblemButton(
                          key: const Key('pickup-problem'),
                          onPressed: _submitting || _pendingSync
                              ? null
                              : _reportProblem,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                key: const Key('pickup-footer'),
                left: 0,
                right: 0,
                bottom: 0,
                height: DriverD03D04Metrics.footerHeight,
                child: _PickupFooter(
                  compact: compact,
                  pendingSync: _pendingSync,
                  submitting: _submitting,
                  onPressed: _ready && !_submitting && !_pendingSync
                      ? _confirm
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupTopBar extends StatelessWidget {
  const _PickupTopBar({required this.round});

  final DriverRoundModel round;

  @override
  Widget build(BuildContext context) {
    final deliveryCount = round.stops.length;
    return Container(
      key: const Key('pickup-topbar'),
      height: DriverD03D04Metrics.topBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: DriverD03D04Metrics.topBarPaddingHorizontal,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DriverD03D04Metrics.topButtonSize,
            height: DriverD03D04Metrics.topButtonSize,
            child: OutlinedButton(
              key: const Key('pickup-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: RoundsColors.ink,
                side: const BorderSide(color: RoundsColors.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverD03D04Metrics.topButtonRadius,
                  ),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: DriverD03D04Metrics.topIconSize,
              ),
            ),
          ),
          const SizedBox(width: DriverD03D04Metrics.topColumnGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AT PICKUP',
                  style: TextStyle(
                    color: RoundsColors.orange,
                    fontSize: DriverD03D04Metrics.topEyebrowSize,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontVariations: [
                      FontVariation(
                        'wght',
                        DriverD03D04Metrics.topEyebrowWeight,
                      ),
                    ],
                    letterSpacing: DriverD03D04Metrics.topEyebrowTracking,
                  ),
                ),
                const SizedBox(height: DriverD03D04Metrics.topNameGap),
                Text(
                  round.tenantName,
                  overflow: TextOverflow.ellipsis,
                  style: _pickupTextStyle(
                    color: RoundsColors.ink,
                    size: DriverD03D04Metrics.topNameSize,
                    height: 1,
                    weight: DriverD03D04Metrics.topNameWeight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DriverD03D04Metrics.topMetaGap),
          Text(
            '$deliveryCount ${deliveryCount == 1 ? 'delivery' : 'deliveries'}',
            style: _pickupTextStyle(
              color: RoundsColors.muted,
              size: DriverD03D04Metrics.topMetaSize,
              height: 1,
              weight: DriverD03D04Metrics.topMetaWeight,
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
    required this.compact,
  });

  final int confirmed;
  final int lineCount;
  final int unitCount;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pickup-hero'),
    padding: const EdgeInsets.only(
      bottom: DriverD03D04Metrics.heroPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Confirm pickup',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: _pickupTextStyle(
                  color: RoundsColors.ink,
                  size: compact
                      ? DriverD03D04Metrics.compactHeroTitleSize
                      : DriverD03D04Metrics.heroTitleSize,
                  height: DriverD03D04Metrics.heroTitleHeight,
                  weight: DriverD03D04Metrics.heroTitleWeight,
                  tracking: DriverD03D04Metrics.heroTitleTracking,
                ),
              ),
            ),
            const SizedBox(width: DriverD03D04Metrics.heroColumnGap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$confirmed / $lineCount',
                  key: const Key('pickup-progress'),
                  style: _pickupTextStyle(
                    color: RoundsColors.ink,
                    size: compact
                        ? DriverD03D04Metrics.compactProgressSize
                        : DriverD03D04Metrics.progressSize,
                    height: DriverD03D04Metrics.progressHeight,
                    weight: DriverD03D04Metrics.progressWeight,
                    tracking: DriverD03D04Metrics.progressTracking,
                  ),
                ),
                const SizedBox(height: DriverD03D04Metrics.progressLabelGap),
                const Text(
                  'confirmed',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverD03D04Metrics.progressLabelSize,
                    fontWeight: FontWeight.w700,
                    fontVariations: [
                      FontVariation(
                        'wght',
                        DriverD03D04Metrics.progressLabelWeight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: DriverD03D04Metrics.summaryGap),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$unitCount package${unitCount == 1 ? '' : 's'}',
                style: _pickupTextStyle(
                  color: RoundsColors.inkSecondary,
                  size: DriverD03D04Metrics.summarySize,
                  height: 1,
                  weight: DriverD03D04Metrics.summaryStrongWeight,
                ),
              ),
              const TextSpan(text: ' · physical manifest'),
            ],
          ),
          style: _pickupTextStyle(
            color: RoundsColors.muted,
            size: DriverD03D04Metrics.summarySize,
            height: 1,
            weight: DriverD03D04Metrics.summaryWeight,
          ),
        ),
      ],
    ),
  );
}

class _PickupManifest extends StatelessWidget {
  const _PickupManifest({
    required this.round,
    required this.compact,
    required this.confirmed,
    required this.itemKey,
    required this.onToggle,
  });

  final DriverRoundModel round;
  final bool compact;
  final Set<String> confirmed;
  final String Function(DriverRoundStopModel stop, DriverManifestItemModel item)
  itemKey;
  final void Function(DriverRoundStopModel stop, DriverManifestItemModel item)
  onToggle;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final stop in round.stops)
        for (final item in stop.manifestItems) (stop: stop, item: item),
    ];
    return Container(
      key: const Key('pickup-manifest'),
      decoration: BoxDecoration(
        border: Border.all(
          color: RoundsColors.line,
          width: DriverD03D04Metrics.manifestBorderWidth,
        ),
        borderRadius: BorderRadius.circular(DriverD03D04Metrics.manifestRadius),
      ),
      padding: const EdgeInsets.all(DriverD03D04Metrics.manifestBorderWidth),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            key: const Key('pickup-manifest-head'),
            height: DriverD03D04Metrics.manifestHeadHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: DriverD03D04Metrics.manifestHeadPaddingHorizontal,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFB),
              border: Border(bottom: BorderSide(color: RoundsColors.line)),
            ),
            child: Row(
              children: [
                Text(
                  'Collect',
                  style: _pickupTextStyle(
                    color: RoundsColors.ink,
                    size: DriverD03D04Metrics.manifestHeadTitleSize,
                    height: 1,
                    weight: DriverD03D04Metrics.manifestHeadTitleWeight,
                  ),
                ),
                const Spacer(),
                const SizedBox(
                  width: DriverD03D04Metrics.manifestHeadColumnGap,
                ),
                Text(
                  'Tap when physically present',
                  style: _pickupTextStyle(
                    color: RoundsColors.muted,
                    size: DriverD03D04Metrics.manifestHeadMetaSize,
                    height: 1,
                    weight: DriverD03D04Metrics.manifestHeadMetaWeight,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < entries.length; index++)
            _ManifestLine(
              key: Key(
                'manifest-${entries[index].stop.id}-'
                '${entries[index].item.lineNumber}',
              ),
              item: entries[index].item,
              reference: entries[index].stop.deliveryReference,
              recipient: entries[index].stop.recipientName,
              checked: confirmed.contains(
                itemKey(entries[index].stop, entries[index].item),
              ),
              compact: compact,
              isLast: index == entries.length - 1,
              onTap: () => onToggle(entries[index].stop, entries[index].item),
            ),
        ],
      ),
    );
  }
}

class _PickupProblemButton extends StatelessWidget {
  const _PickupProblemButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: DriverD03D04Metrics.problemHeight,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: DriverD03D04Metrics.problemPaddingHorizontal,
        ),
        alignment: Alignment.centerLeft,
        foregroundColor: RoundsColors.red,
        side: const BorderSide(color: Color(0xFFE6C8C8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            DriverD03D04Metrics.problemRadius,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pickup problem',
            style: _pickupTextStyle(
              color: RoundsColors.red,
              size: DriverD03D04Metrics.problemSize,
              height: 1,
              weight: DriverD03D04Metrics.problemWeight,
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: DriverD03D04Metrics.problemIconSize,
          ),
        ],
      ),
    ),
  );
}

class _PickupFooter extends StatelessWidget {
  const _PickupFooter({
    required this.compact,
    required this.pendingSync,
    required this.submitting,
    required this.onPressed,
  });

  final bool compact;
  final bool pendingSync;
  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverD03D04Metrics.compactFooterPaddingHorizontal
          : DriverD03D04Metrics.footerPaddingHorizontal,
      DriverD03D04Metrics.footerPaddingTop,
      compact
          ? DriverD03D04Metrics.compactFooterPaddingHorizontal
          : DriverD03D04Metrics.footerPaddingHorizontal,
      DriverD03D04Metrics.footerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: SizedBox(
      height: DriverD03D04Metrics.primaryHeight,
      child: FilledButton(
        key: const Key('confirm-pickup'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: RoundsColors.green,
          disabledBackgroundColor: const Color(0xFFD9DFE5),
          disabledForegroundColor: const Color(0xFF85909D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              DriverD03D04Metrics.primaryRadius,
            ),
          ),
        ),
        child: Text(
          pendingSync
              ? 'Pending sync — not confirmed'
              : submitting
              ? 'Sending to server…'
              : 'Confirm pickup',
          style: _pickupTextStyle(
            color: onPressed == null ? const Color(0xFF85909D) : Colors.white,
            size: DriverD03D04Metrics.primarySize,
            height: 1,
            weight: DriverD03D04Metrics.primaryWeight,
          ),
        ),
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
    required this.compact,
    required this.isLast,
    required this.onTap,
    super.key,
  });
  final DriverManifestItemModel item;
  final String reference;
  final String recipient;
  final bool checked;
  final bool compact;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lineHeight = compact
        ? DriverD03D04Metrics.compactManifestLineHeight
        : DriverD03D04Metrics.manifestLineHeight;
    final horizontalPadding = compact
        ? DriverD03D04Metrics.compactManifestLinePaddingHorizontal
        : DriverD03D04Metrics.manifestLinePaddingHorizontal;
    final columnGap = compact
        ? DriverD03D04Metrics.compactManifestLineColumnGap
        : DriverD03D04Metrics.manifestLineColumnGap;
    return Material(
      color: checked ? const Color(0xFFFBFEFC) : RoundsColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: lineHeight,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: DriverD03D04Metrics.manifestLinePaddingVertical,
          ),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFEDEFF2))),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: DriverD03D04Metrics.manifestCheckSize,
                height: DriverD03D04Metrics.manifestCheckSize,
                decoration: BoxDecoration(
                  color: checked ? RoundsColors.green : RoundsColors.surface,
                  border: Border.all(
                    color: checked
                        ? RoundsColors.green
                        : RoundsColors.lineStrong,
                    width: DriverD03D04Metrics.manifestCheckBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(
                    DriverD03D04Metrics.manifestCheckRadius,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check,
                        size: DriverD03D04Metrics.manifestCheckIconSize,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: columnGap),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.description,
                        style: _pickupTextStyle(
                          color: RoundsColors.ink,
                          size: compact
                              ? DriverD03D04Metrics.compactManifestTitleSize
                              : DriverD03D04Metrics.manifestTitleSize,
                          height: DriverD03D04Metrics.manifestTitleHeight,
                          weight: DriverD03D04Metrics.manifestTitleWeight,
                          tracking: DriverD03D04Metrics.manifestTitleTracking,
                        ),
                      ),
                      TextSpan(
                        text: '$reference · $recipient',
                        style: _pickupTextStyle(
                          color: RoundsColors.muted,
                          size: compact
                              ? DriverD03D04Metrics.compactManifestMetaSize
                              : DriverD03D04Metrics.manifestMetaSize,
                          height: DriverD03D04Metrics.manifestMetaHeight,
                          weight: 400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: columnGap),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: DriverD03D04Metrics.manifestSideMinWidth,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '×${item.quantity}',
                      style: _pickupTextStyle(
                        color: RoundsColors.ink,
                        size: DriverD03D04Metrics.manifestQuantitySize,
                        height: 1,
                        weight: DriverD03D04Metrics.manifestQuantityWeight,
                      ),
                    ),
                    if (item.handlingNote != null) ...[
                      const SizedBox(
                        height: DriverD03D04Metrics.manifestCareGap,
                      ),
                      Text(
                        item.handlingNote!,
                        style: _pickupTextStyle(
                          color:
                              item.handlingNote!.toLowerCase().contains('cool')
                              ? const Color(0xFF3269B7)
                              : RoundsColors.orange,
                          size: DriverD03D04Metrics.manifestCareSize,
                          height: 1,
                          weight: DriverD03D04Metrics.manifestCareWeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _pickupTextStyle({
  required Color color,
  required double size,
  required double height,
  required double weight,
  double tracking = 0,
}) => TextStyle(
  color: color,
  fontSize: size,
  height: height,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: tracking,
);
