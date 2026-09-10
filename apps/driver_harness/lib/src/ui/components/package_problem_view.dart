import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pickup_collection_view.dart';

abstract final class PackageProblemEnglish {
  static const choices = {
    'damaged': ('Damaged', 'Item or packaging is damaged'),
    'missing': ('Missing', 'Expected package is not here'),
    'wrong': ('Wrong package', 'Does not match this delivery'),
  };
  static String title(String? reason) => switch (reason) {
    'damaged' => 'Package damaged',
    'missing' => 'Package missing',
    'wrong' => 'Wrong package',
    _ => 'Package problem',
  };
}

/// Approved Refresh26 G03 choices + evidence states. Source CSS pixels map to
/// logical pixels; frame/statusbar are omitted. No simulated report/decision.
/// The host owns authenticated persistence, contact routes and recovery.
class PackageProblemView extends StatelessWidget {
  const PackageProblemView({
    required this.stopLabel,
    required this.recipient,
    required this.address,
    required this.packageLabel,
    required this.packageMeta,
    required this.problemLabel,
    required this.details,
    required this.reason,
    required this.showChoices,
    required this.onChoose,
    required this.onDetail,
    required this.onBack,
    required this.onMore,
    required this.onPhoto,
    required this.onSubmit,
    this.onCallRecipient,
    this.onMessageOperations,
    this.handling,
    this.photo,
    this.busy = false,
    this.locked = false,
    this.error,
    super.key,
  });
  final String stopLabel,
      recipient,
      address,
      packageLabel,
      packageMeta,
      problemLabel;
  final String? handling, reason, error;
  final TextEditingController details;
  final bool showChoices, busy, locked;
  final ImageProvider? photo;
  final ValueChanged<String> onChoose, onDetail;
  final VoidCallback onBack, onMore, onPhoto, onSubmit;
  final VoidCallback? onCallRecipient, onMessageOperations;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 350;
    final short = MediaQuery.sizeOf(context).height < 740;
    final inset = narrow ? 14.0 : 18.0;
    final needsPhoto = reason != 'missing';
    final enabled = !busy && !locked;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('g03-topbar'),
              constraints: const BoxConstraints(minHeight: 64),
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 10 : 14,
                vertical: 5.5,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: PickupReference.line)),
              ),
              child: Row(
                children: [
                  _square('Back', PickupIcon.back, onBack),
                  SizedBox(width: narrow ? 9 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stopLabel,
                          style: PickupReference.text(
                            13,
                            color: PickupReference.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipient,
                          style: PickupReference.text(
                            17,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: narrow ? 9 : 12),
                  _square('More stop actions', PickupIcon.more, onMore),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('g03-content'),
                child: Column(
                  children: [
                    Container(
                      key: const Key('g03-heading'),
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 10 : 14,
                        short ? 16 : 19,
                        inset,
                        short ? 16 : 20,
                      ),
                      decoration: const BoxDecoration(
                        color: PickupReference.soft,
                        border: Border(
                          left: BorderSide(
                            color: PickupReference.orange,
                            width: 4,
                          ),
                          bottom: BorderSide(color: Color(0xffcbdcf0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const PickupLineIcon(
                                PickupIcon.problem,
                                size: 18,
                                color: PickupReference.red,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  problemLabel,
                                  style: PickupReference.text(
                                    14,
                                    height: 1.25,
                                    weight: FontWeight.w600,
                                    color: PickupReference.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            PackageProblemEnglish.title(
                              showChoices ? null : reason,
                            ),
                            style: PickupReference.text(
                              narrow ? 28 : 30,
                              height: 1.12,
                              weight: FontWeight.w700,
                              tracking: -.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            address,
                            style: PickupReference.text(
                              narrow ? 15 : 16,
                              height: 1.35,
                              color: PickupReference.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: const Key('g03-package'),
                      constraints: const BoxConstraints(minHeight: 88),
                      padding: EdgeInsets.symmetric(
                        horizontal: inset,
                        vertical: short
                            ? 14
                            : narrow
                            ? 15
                            : 17,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PickupReference.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          const PickupLineIcon(
                            PickupIcon.package,
                            size: 28,
                            color: PickupReference.blue,
                          ),
                          SizedBox(width: narrow ? 10 : 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  packageLabel,
                                  style: PickupReference.text(
                                    narrow ? 16 : 17,
                                    weight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        packageMeta,
                                        style: PickupReference.text(
                                          14,
                                          height: 1.3,
                                          color: PickupReference.muted,
                                        ),
                                      ),
                                    ),
                                    if (handling != null) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            handling!,
                                            style: PickupReference.text(
                                              14,
                                              height: 1.3,
                                              weight: FontWeight.w600,
                                              color: const Color(0xff98400f),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showChoices)
                      Padding(
                        padding: EdgeInsets.fromLTRB(inset, 0, inset, 12),
                        child: Column(
                          children: [
                            for (final choice
                                in PackageProblemEnglish.choices.entries)
                              Semantics(
                                button: true,
                                enabled: enabled,
                                child: InkWell(
                                  onTap: enabled
                                      ? () => onChoose(choice.key)
                                      : null,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minHeight: short ? 82 : 88,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: short ? 13 : 16,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: PickupReference.line,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        PickupLineIcon(
                                          switch (choice.key) {
                                            'damaged' => PickupIcon.problem,
                                            'wrong' => PickupIcon.wrong,
                                            _ => PickupIcon.package,
                                          },
                                          size: 29,
                                          color: PickupReference.blue,
                                        ),
                                        SizedBox(width: narrow ? 12 : 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                choice.value.$1,
                                                style: PickupReference.text(
                                                  narrow ? 18 : 19,
                                                  weight: FontWeight.w600,
                                                  height: 1.25,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                choice.value.$2,
                                                style: PickupReference.text(
                                                  narrow ? 14 : 15,
                                                  height: 1.3,
                                                  color: PickupReference.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: narrow ? 12 : 14),
                                        const PickupLineIcon(
                                          PickupIcon.chevron,
                                          size: 19,
                                          color: PickupReference.blue,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          narrow ? 18 : 20,
                          inset,
                          narrow ? 22 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (needsPhoto) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reason == 'damaged'
                                          ? 'Damage photo'
                                          : 'Package photo',
                                      style: PickupReference.text(
                                        17,
                                        weight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    photo == null ? 'Required' : 'Added',
                                    style: PickupReference.text(
                                      14,
                                      color: photo == null
                                          ? PickupReference.red
                                          : PickupReference.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (photo == null)
                                SizedBox(
                                  width: double.infinity,
                                  child: CustomPaint(
                                    foregroundPainter: const _PhotoDashBorder(),
                                    child: OutlinedButton(
                                      key: const Key('g03-take-photo'),
                                      onPressed: enabled ? onPhoto : null,
                                      style:
                                          _buttonStyle(
                                            background: PickupReference.soft,
                                            minimum: narrow ? 196 : 212,
                                            border: const Color(0xff95afd0),
                                          ).copyWith(
                                            side: const WidgetStatePropertyAll(
                                              BorderSide.none,
                                            ),
                                          ),
                                      child: Column(
                                        children: [
                                          const PickupLineIcon(
                                            PickupIcon.camera,
                                            size: 42,
                                            color: PickupReference.blue,
                                          ),
                                          const SizedBox(height: 17),
                                          Text(
                                            reason == 'damaged'
                                                ? 'Photograph the damage'
                                                : 'Photograph the package label',
                                            textAlign: TextAlign.center,
                                            style: PickupReference.text(
                                              narrow ? 19 : 20,
                                              weight: FontWeight.w600,
                                              height: 1.25,
                                              color: PickupReference.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xffe9eef4),
                                    border: Border.all(
                                      color: const Color(0xffbfd0e0),
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      Image(
                                        image: photo!,
                                        height: narrow ? 196 : 212,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        semanticLabel:
                                            'Selected package evidence',
                                        gaplessPlayback: false,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          13,
                                          6,
                                          8,
                                          6,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: PickupReference.line,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const PickupLineIcon(
                                              PickupIcon.check,
                                              size: 20,
                                              color: PickupReference.green,
                                            ),
                                            const SizedBox(width: 7),
                                            Expanded(
                                              child: Text(
                                                'Photo added',
                                                style: PickupReference.text(
                                                  15,
                                                  weight: FontWeight.w600,
                                                  color: PickupReference.green,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            OutlinedButton(
                                              onPressed: enabled
                                                  ? onPhoto
                                                  : null,
                                              style: _buttonStyle(
                                                minimum: 52,
                                                background:
                                                    PickupReference.soft,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const PickupLineIcon(
                                                    PickupIcon.camera,
                                                    size: 20,
                                                    color: PickupReference.blue,
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Text(
                                                    'Retake',
                                                    style: PickupReference.text(
                                                      16,
                                                      weight: FontWeight.w600,
                                                      color:
                                                          PickupReference.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  17,
                                  0,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    const PickupLineIcon(
                                      PickupIcon.package,
                                      size: 28,
                                      color: PickupReference.blue,
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Text(
                                        'No photo required for a missing package.',
                                        style: PickupReference.text(
                                          16,
                                          height: 1.4,
                                          color: PickupReference.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Text(
                                  'Details',
                                  style: PickupReference.text(
                                    16,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Optional',
                                  style: PickupReference.text(
                                    14,
                                    color: PickupReference.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            SizedBox(
                              height: math.max(
                                90,
                                MediaQuery.textScalerOf(context).scale(16) *
                                        1.45 *
                                        2 +
                                    26,
                              ),
                              child: TextField(
                                key: const Key('g03-details'),
                                controller: details,
                                onChanged: onDetail,
                                readOnly: !enabled,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                maxLines: null,
                                inputFormatters: [_NoteLimit()],
                                style: PickupReference.text(16, height: 1.45),
                                decoration: InputDecoration(
                                  hintText: 'Add a useful detail',
                                  hintStyle: PickupReference.text(
                                    16,
                                    color: PickupReference.muted,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    minHeight: 90,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(7),
                                    borderSide: const BorderSide(
                                      color: Color(0xffa8bbd1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(7),
                                    borderSide: const BorderSide(
                                      color: PickupReference.orange,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error!,
                                    style: PickupReference.text(
                                      14,
                                      height: 1.4,
                                      color: PickupReference.red,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              key: const Key('g03-footer'),
              padding: EdgeInsets.fromLTRB(inset, short ? 12 : 14, inset, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: PickupReference.line)),
              ),
              child: Column(
                children: [
                  if (!showChoices) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: enabled && (!needsPhoto || photo != null)
                            ? onSubmit
                            : null,
                        style:
                            _buttonStyle(
                              minimum: 64,
                              background: PickupReference.blue,
                            ).copyWith(
                              side: const WidgetStatePropertyAll(
                                BorderSide.none,
                              ),
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (s) => s.contains(WidgetState.disabled)
                                    ? const Color(0xffe2e8ee)
                                    : PickupReference.blue,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (s) => s.contains(WidgetState.disabled)
                                    ? const Color(0xff566477)
                                    : Colors.white,
                              ),
                            ),
                        child: Text(
                          busy ? 'Saving report…' : 'Request instructions',
                          style: PickupReference.text(
                            narrow ? 17 : 18,
                            weight: FontWeight.w600,
                            color: enabled && (!needsPhoto || photo != null)
                                ? Colors.white
                                : const Color(0xff566477),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _contact(
                          'Call recipient',
                          PickupIcon.call,
                          onCallRecipient,
                          narrow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _contact(
                          'Message Ops',
                          PickupIcon.message,
                          onMessageOperations,
                          narrow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _buttonStyle({
  double minimum = 60,
  Color background = Colors.white,
  Color border = const Color(0xffbfd1e7),
}) => OutlinedButton.styleFrom(
  minimumSize: Size(0, minimum),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  backgroundColor: background,
  foregroundColor: PickupReference.blue,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  side: BorderSide(color: border),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
Widget _square(String label, PickupIcon icon, VoidCallback action) => SizedBox(
  width: 52,
  height: 52,
  child: IconButton(
    tooltip: label,
    onPressed: action,
    style: IconButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      side: const BorderSide(color: PickupReference.line),
    ),
    icon: PickupLineIcon(icon),
  ),
);
Widget _contact(
  String text,
  PickupIcon icon,
  VoidCallback? action,
  bool narrow,
) => OutlinedButton(
  onPressed: action,
  style: _buttonStyle(background: PickupReference.soft).copyWith(
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    ),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PickupLineIcon(
        icon,
        size: narrow ? 19 : 22,
        color: action == null ? PickupReference.muted : PickupReference.blue,
      ),
      SizedBox(width: narrow ? 6 : 8),
      Flexible(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: PickupReference.text(
            narrow ? 15 : 16,
            weight: FontWeight.w600,
            color: action == null
                ? PickupReference.muted
                : PickupReference.blue,
          ),
        ),
      ),
    ],
  ),
);

class _NoteLimit extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.text.runes.length <= 240 ? newValue : oldValue;
}

class _PhotoDashBorder extends CustomPainter {
  const _PhotoDashBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(7),
        ),
      );
    final paint = Paint()
      ..color = const Color(0xff95afd0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 9) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PhotoDashBorder oldDelegate) => false;
}
