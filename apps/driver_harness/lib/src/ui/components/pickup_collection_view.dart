import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Refresh02 D03/D04, carried unchanged in the approved Refresh26 pack.
/// CSS px == logical px. No legacy Inter/900-weight or width-ratio scaling.
/// Arial/Helvetica availability and Android fallback need visual approval.
abstract final class PickupReference {
  static const ink = Color(0xff17283f);
  static const blue = Color(0xff1754a6);
  static const soft = Color(0xffedf4fd);
  static const muted = Color(0xff526278);
  static const line = Color(0xffdce4ed);
  static const green = Color(0xff167344);
  static const red = Color(0xffa22f2f);
  static const orange = Color(0xffff6420);

  static TextStyle text(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
    double tracking = 0,
  }) => TextStyle(
    // Explicit provisional Android system fallback. Not an approved Arial
    // substitution: source/phone typography comparison remains required.
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['Arial', 'Helvetica'],
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking,
    color: color,
  );
}

/// Display identity is not command authority. The caller owns original IDs,
/// full-order validation, submission/recovery and storage compatibility.
class PickupPackage {
  const PickupPackage({
    required this.key,
    required this.title,
    required this.reference,
    required this.recipient,
    this.piece,
    this.handling,
    this.keepCool = false,
  });
  final String key, title, reference, recipient;
  final String? piece, handling;
  final bool keepCool;
}

enum PickupProblemAction { missing, wrong, damaged, message }

abstract final class PickupEnglish {
  static const heading = 'Collect packages';
  static const confirm = 'Confirm pickup';
  static String collected(int value, int total) => '$value of $total';
  static String stops(int count) => '$count ${count == 1 ? 'stop' : 'stops'}';
  static String confirmCount(int count) =>
      'Confirm $count ${count == 1 ? 'package' : 'packages'}';
  static String problem(PickupProblemAction action) => switch (action) {
    PickupProblemAction.missing => 'Missing package',
    PickupProblemAction.wrong => 'Wrong package',
    PickupProblemAction.damaged => 'Damaged package',
    PickupProblemAction.message => 'Message Operations',
  };
}

class PickupCollectionView extends StatelessWidget {
  const PickupCollectionView({
    required this.merchant,
    required this.stopCount,
    required this.packages,
    required this.selected,
    required this.onToggle,
    required this.onBack,
    required this.onProblem,
    required this.onConfirm,
    this.locked = false,
    this.actionLabel,
    super.key,
  });
  final String merchant;
  final int stopCount;
  final List<PickupPackage> packages;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onBack, onProblem;
  final VoidCallback? onConfirm;
  final bool locked;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 350;
    final short = MediaQuery.sizeOf(context).height < 740;
    final inset = narrow ? 14.0 : 18.0;
    final count = packages.where((p) => selected.contains(p.key)).length;
    final all = packages.isNotEmpty && count == packages.length;
    final enabled = all && !locked && onConfirm != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('pickup-topbar'),
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
                  _Square(
                    key: const Key('pickup-back'),
                    label: 'Back to pickup',
                    icon: PickupIcon.back,
                    onPressed: onBack,
                  ),
                  SizedBox(width: narrow ? 9 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'At pickup',
                          style: PickupReference.text(
                            13,
                            color: PickupReference.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          merchant,
                          style: PickupReference.text(
                            17,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: narrow ? 9 : 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      PickupEnglish.stops(stopCount),
                      style: PickupReference.text(
                        narrow ? 13 : 14,
                        color: PickupReference.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              key: const Key('pickup-hero'),
              constraints: const BoxConstraints(minHeight: 92),
              padding: EdgeInsets.fromLTRB(
                inset,
                short ? 15 : 20,
                inset,
                short ? 15 : 18,
              ),
              decoration: const BoxDecoration(
                color: PickupReference.soft,
                border: Border(
                  left: BorderSide(color: PickupReference.orange, width: 4),
                  bottom: BorderSide(color: Color(0xffcbdcf0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      PickupEnglish.heading,
                      style: PickupReference.text(
                        narrow ? 25 : 27,
                        weight: FontWeight.w700,
                        height: 1.12,
                        tracking: -.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    liveRegion: true,
                    label: '$count of ${packages.length} collected',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PickupEnglish.collected(count, packages.length),
                          key: const Key('pickup-progress'),
                          style: PickupReference.text(
                            narrow ? 23 : 25,
                            color: PickupReference.blue,
                            weight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'collected',
                          style: PickupReference.text(
                            13,
                            color: PickupReference.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('pickup-content'),
                padding: EdgeInsets.zero,
                children: [
                  for (final package in packages)
                    _PackageRow(
                      package: package,
                      checked: selected.contains(package.key),
                      narrow: narrow,
                      short: short,
                      onTap: locked ? null : () => onToggle(package.key),
                    ),
                ],
              ),
            ),
            Container(
              key: const Key('pickup-footer'),
              padding: EdgeInsets.fromLTRB(
                inset,
                short ? 10 : 12,
                inset,
                short ? 12 : 17,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: PickupReference.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      maxWidth: 64,
                      minHeight: 68,
                    ),
                    child: OutlinedButton(
                      key: const Key('pickup-problem'),
                      onPressed: locked ? null : onProblem,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(64, 68),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xfffff9f8),
                        foregroundColor: PickupReference.red,
                        side: const BorderSide(color: Color(0xffe3c2c2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PickupLineIcon(
                            PickupIcon.problem,
                            color: PickupReference.red,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Problem',
                            style: PickupReference.text(
                              13,
                              color: PickupReference.red,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('confirm-pickup'),
                      onPressed: enabled ? onConfirm : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 68),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        backgroundColor: PickupReference.green,
                        disabledBackgroundColor: const Color(0xffe2e8ee),
                        disabledForegroundColor: const Color(0xff566477),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: Text(
                        actionLabel ??
                            (all
                                ? PickupEnglish.confirmCount(packages.length)
                                : PickupEnglish.confirm),
                        textAlign: TextAlign.center,
                        style: PickupReference.text(
                          narrow ? 17 : 18,
                          color: enabled
                              ? Colors.white
                              : const Color(0xff566477),
                          weight: FontWeight.w600,
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
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.package,
    required this.checked,
    required this.narrow,
    required this.short,
    required this.onTap,
  });
  final PickupPackage package;
  final bool checked, narrow, short;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: checked ? PickupReference.soft : Colors.white,
    child: Semantics(
      button: true,
      toggled: checked,
      enabled: onTap != null,
      label:
          '${package.title}${package.piece == null ? '' : ', ${package.piece}'}, ${package.reference}, ${package.recipient}${package.handling == null ? '' : ', ${package.handling}'}',
      child: InkWell(
        key: Key(package.key),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            constraints: BoxConstraints(minHeight: short ? 88 : 92),
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 14 : 18,
              vertical: 14,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PickupReference.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: checked ? PickupReference.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      width: 2,
                      color: checked
                          ? PickupReference.blue
                          : const Color(0xffa8bacd),
                    ),
                  ),
                  child: checked
                      ? const Center(
                          child: PickupLineIcon(
                            PickupIcon.check,
                            color: Colors.white,
                            size: 22,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: narrow ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: package.title),
                            if (package.piece != null)
                              TextSpan(
                                text: '  ${package.piece}',
                                style: PickupReference.text(
                                  13,
                                  color: PickupReference.muted,
                                ),
                              ),
                          ],
                        ),
                        style: PickupReference.text(
                          17,
                          weight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final meta = Text(
                            '${package.reference} · ${package.recipient}',
                            style: PickupReference.text(
                              14,
                              color: PickupReference.muted,
                              height: 1.3,
                            ),
                          );
                          if (package.handling == null) return meta;
                          final care = Text(
                            package.handling!,
                            style: PickupReference.text(
                              13,
                              color: package.keepCool
                                  ? PickupReference.blue
                                  : const Color(0xffa74313),
                              weight: FontWeight.w600,
                            ),
                          );
                          // CSS flex-wrap: retain complete text at narrow/enlarged sizes.
                          final metaPainter = TextPainter(
                            text: TextSpan(
                              text:
                                  '${package.reference} · ${package.recipient}',
                              style: PickupReference.text(14, height: 1.3),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          final carePainter = TextPainter(
                            text: TextSpan(
                              text: package.handling!,
                              style: PickupReference.text(
                                13,
                                weight: FontWeight.w600,
                              ),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          final fits =
                              metaPainter.width + carePainter.width + 8 <=
                              constraints.maxWidth;
                          metaPainter.dispose();
                          carePainter.dispose();
                          return fits
                              ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [meta, care],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    meta,
                                    const SizedBox(height: 4),
                                    care,
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<PickupProblemAction?> showPickupProblemActions(
  BuildContext context,
) => showModalBottomSheet<PickupProblemAction>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x55132c4f),
  elevation: 0,
  builder: (context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
    },
    child: Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            Navigator.pop(context);
            return null;
          },
        ),
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            key: const Key('pickup-action-sheet'),
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  36,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: PickupReference.line),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pickup problem',
                            style: PickupReference.text(
                              23,
                              weight: FontWeight.w700,
                              tracking: -.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Square(
                          label: 'Close',
                          icon: PickupIcon.close,
                          border: false,
                          autofocus: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  for (final action in PickupProblemAction.values)
                    Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, action),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 68),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: PickupReference.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              PickupLineIcon(
                                action == PickupProblemAction.message
                                    ? PickupIcon.message
                                    : PickupIcon.problem,
                                color: action == PickupProblemAction.message
                                    ? PickupReference.ink
                                    : PickupReference.red,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  PickupEnglish.problem(action),
                                  style: PickupReference.text(
                                    17,
                                    color: action == PickupProblemAction.message
                                        ? PickupReference.ink
                                        : PickupReference.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PickupLineIcon(
                                PickupIcon.chevron,
                                size: 18,
                                color: action == PickupProblemAction.message
                                    ? PickupReference.ink
                                    : PickupReference.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

class _Square extends StatelessWidget {
  const _Square({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.border = true,
    this.autofocus = false,
    super.key,
  });
  final String label;
  final PickupIcon icon;
  final VoidCallback onPressed;
  final bool border, autofocus;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 52,
    child: IconButton(
      onPressed: onPressed,
      tooltip: label,
      autofocus: autofocus,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        side: border
            ? const BorderSide(color: PickupReference.line)
            : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      icon: PickupLineIcon(icon),
    ),
  );
}

enum PickupIcon {
  back,
  close,
  problem,
  message,
  chevron,
  check,
  package,
  wrong,
  camera,
  call,
  more,
}

/// Paths transcribed from the selected HTML's inline SVG, not Material glyphs.
class PickupLineIcon extends StatelessWidget {
  const PickupLineIcon(
    this.icon, {
    this.color = PickupReference.ink,
    this.size = 24,
    super.key,
  });
  final PickupIcon icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(icon, color));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);
  final PickupIcon icon;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Path();
    switch (icon) {
      case PickupIcon.package:
        p
          ..moveTo(3, 7)
          ..lineTo(12, 2)
          ..lineTo(21, 7)
          ..lineTo(21, 17)
          ..lineTo(12, 22)
          ..lineTo(3, 17)
          ..close()
          ..moveTo(3, 7)
          ..lineTo(12, 12)
          ..lineTo(21, 7)
          ..moveTo(12, 12)
          ..lineTo(12, 22)
          ..moveTo(7, 5)
          ..lineTo(17, 10);
      case PickupIcon.wrong:
        p
          ..addRect(const Rect.fromLTWH(4, 5, 16, 16))
          ..moveTo(8, 10)
          ..lineTo(16, 17)
          ..moveTo(16, 10)
          ..lineTo(8, 17);
      case PickupIcon.camera:
        p
          ..moveTo(3, 7)
          ..lineTo(7, 7)
          ..lineTo(9, 4)
          ..lineTo(15, 4)
          ..lineTo(17, 7)
          ..lineTo(21, 7)
          ..lineTo(21, 20)
          ..lineTo(3, 20)
          ..close()
          ..addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 4));
      case PickupIcon.call:
        p
          ..moveTo(5, 3)
          ..lineTo(9, 4)
          ..lineTo(10, 9)
          ..lineTo(7, 11)
          ..arcToPoint(
            const Offset(13, 17),
            radius: const Radius.circular(15),
            clockwise: false,
          )
          ..lineTo(15, 14)
          ..lineTo(20, 15)
          ..lineTo(21, 19)
          ..cubicTo(20, 23, 14, 21, 10, 18)
          ..cubicTo(6, 15, 1, 7, 5, 3)
          ..close();
      case PickupIcon.more:
        for (final x in [5.0, 12.0, 19.0]) {
          p.addOval(Rect.fromCircle(center: Offset(x, 12), radius: 1));
        }
      case PickupIcon.back:
        p
          ..moveTo(19, 12)
          ..lineTo(5, 12)
          ..moveTo(12, 5)
          ..lineTo(5, 12)
          ..lineTo(12, 19);
      case PickupIcon.close:
        p
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(6, 18)
          ..lineTo(18, 6);
      case PickupIcon.problem:
        p
          ..moveTo(12, 3)
          ..lineTo(22, 21)
          ..lineTo(2, 21)
          ..close()
          ..moveTo(12, 9)
          ..lineTo(12, 14)
          ..moveTo(12, 17)
          ..lineTo(12, 17.1);
      case PickupIcon.message:
        p
          ..moveTo(21, 15)
          ..arcToPoint(const Offset(18, 18), radius: const Radius.circular(3))
          ..lineTo(9, 18)
          ..lineTo(3, 22)
          ..lineTo(3, 6)
          ..arcToPoint(const Offset(6, 3), radius: const Radius.circular(3))
          ..lineTo(18, 3)
          ..arcToPoint(const Offset(21, 6), radius: const Radius.circular(3))
          ..close();
      case PickupIcon.chevron:
        p
          ..moveTo(9, 5)
          ..lineTo(16, 12)
          ..lineTo(9, 19);
      case PickupIcon.check:
        p
          ..moveTo(5, 12)
          ..lineTo(9, 16)
          ..lineTo(19, 6);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = icon == PickupIcon.check ? 2.6 : 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      icon != old.icon || color != old.color;
}
