import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_handoff_selection.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import '../storage/pod_draft_photo_store.dart';
import 'delivery_package_problem_screen.dart';

typedef DeliveryPhotoCapture = Future<XFile?> Function();

class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({
    required this.controller,
    required this.stop,
    this.stopCount = 1,
    this.handoff = const DriverHandoffSelection.recipient(),
    this.photoStore,
    this.capturePhoto,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundStopModel stop;
  final int stopCount;
  final DriverHandoffSelection handoff;
  final PodDraftPhotoStore? photoStore;
  final DeliveryPhotoCapture? capturePhoto;

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _receiverName = TextEditingController();
  final Set<int> _confirmedLines = <int>{};
  PodDraftPhotoStore? _photoStore;
  XFile? _photo;
  _ReceiverRole? _receiverRole;
  bool _restoring = true;
  bool _capturing = false;
  bool _submitting = false;
  bool _pendingSync = false;
  String? _photoError;

  bool get _thai => widget.controller.strings.isThai;
  String get _handoffType => widget.handoff.handoffType;
  bool get _requiresReceiver => _handoffType == 'someone_else';
  bool get _manifestDone =>
      widget.stop.manifestItems.isNotEmpty &&
      widget.stop.manifestItems.every(
        (item) => _confirmedLines.contains(item.lineNumber),
      );
  bool get _receiverDone =>
      !_requiresReceiver ||
      (_receiverRole != null && _receiverName.text.trim().isNotEmpty);
  int get _totalRequired => 2 + (_requiresReceiver ? 1 : 0);
  int get _doneRequired =>
      (_manifestDone ? 1 : 0) +
      (_photo != null ? 1 : 0) +
      (_requiresReceiver && _receiverDone ? 1 : 0);
  bool get _ready => _manifestDone && _photo != null && _receiverDone;

  @override
  void initState() {
    super.initState();
    if (_handoffType == 'recipient') {
      _receiverName.text = widget.stop.recipientName;
    }
    _restorePhoto();
  }

  @override
  void dispose() {
    _receiverName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < DriverReferenceViewport.compactBreakpoint;
    final horizontal = compact
        ? (_thai
              ? DriverF03F04Metrics.compactThaiContentPaddingHorizontal
              : DriverF03F04Metrics.compactEnglishContentPaddingHorizontal)
        : DriverF03F04Metrics.contentPaddingHorizontal;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _PodTopBar(
                  thai: _thai,
                  compact: compact,
                  sequence: widget.stop.sequence,
                  stopCount: widget.stopCount,
                  recipientName: widget.stop.recipientName,
                ),
                Expanded(
                  child: ListView(
                    key: const Key('pod-content'),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      compact && _thai
                          ? DriverF03F04Metrics.compactThaiContentPaddingTop
                          : DriverF03F04Metrics.contentPaddingTop,
                      horizontal,
                      compact && _thai
                          ? DriverF03F04Metrics.compactThaiFooterReserve
                          : DriverF03F04Metrics.footerReserve,
                    ),
                    children: [
                      _PodHero(
                        thai: _thai,
                        compact: compact,
                        done: _doneRequired,
                        total: _totalRequired,
                        handoff: widget.handoff,
                        recipientName: widget.stop.recipientName,
                      ),
                      _PodSection(
                        thai: _thai,
                        compact: compact,
                        title: _thai ? 'แพ็กเกจ' : 'Package',
                        done: _manifestDone,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PodManifest(
                              stop: widget.stop,
                              thai: _thai,
                              compact: compact,
                              confirmedLines: _confirmedLines,
                              disabled: _pendingSync || _submitting,
                              onToggle: (line) => setState(() {
                                if (!_confirmedLines.add(line)) {
                                  _confirmedLines.remove(line);
                                }
                              }),
                            ),
                            InkWell(
                              key: const Key('pod-package-problem'),
                              onTap: _submitting
                                  ? null
                                  : () => Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DeliveryPackageProblemScreen(
                                              controller: widget.controller,
                                              stop: widget.stop,
                                            ),
                                      ),
                                    ),
                              child: SizedBox(
                                height: compact && _thai
                                    ? DriverF03F04Metrics
                                          .compactThaiProblemHeight
                                    : _thai
                                    ? DriverF03F04Metrics.thaiProblemHeight
                                    : DriverF03F04Metrics.englishProblemHeight,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      _thai
                                          ? 'มีปัญหากับแพ็กเกจ'
                                          : 'Package problem',
                                      style: TextStyle(
                                        color: RoundsColors.red,
                                        fontSize: 12.8,
                                        height: _thai ? 1.4 : 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_requiresReceiver)
                        _PodSection(
                          thai: _thai,
                          compact: compact,
                          title: _thai ? 'ผู้รับของ' : 'Received by',
                          done: _receiverDone,
                          child: Column(
                            children: [
                              _ReceiverRow(
                                thai: _thai,
                                selected: _receiverRole,
                                onTap: _pendingSync || _submitting
                                    ? null
                                    : _chooseReceiver,
                              ),
                              if (_receiverRole != null) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  key: const Key('pod-receiver-name'),
                                  controller: _receiverName,
                                  enabled: !_pendingSync && !_submitting,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: _thai
                                        ? 'ชื่อผู้รับของ'
                                        : 'Receiver name',
                                    hintText: _thai
                                        ? 'ใส่ชื่อผู้รับจริง'
                                        : 'Enter the person’s name',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      _PodSection(
                        thai: _thai,
                        compact: compact,
                        title: _thai ? 'รูปยืนยันการส่ง' : 'Delivery photo',
                        done: _photo != null,
                        child: _PhotoSurface(
                          thai: _thai,
                          compact: compact,
                          leftAtLocation: _handoffType == 'left_at_location',
                          photo: _photo,
                          restoring: _restoring,
                          capturing: _capturing,
                          disabled: _submitting || _pendingSync,
                          onCapture: _capturePhoto,
                        ),
                      ),
                      if (_photoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _photoError!,
                            style: const TextStyle(
                              color: RoundsColors.red,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      _AutomaticRow(thai: _thai),
                      if (_pendingSync) _PendingSync(thai: _thai),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _PodFooter(
                thai: _thai,
                compact: compact,
                sequence: widget.stop.sequence,
                submitting: _submitting,
                pendingSync: _pendingSync,
                ready: _ready && !_restoring && !_capturing,
                onPressed: _complete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseReceiver() async {
    final selected = await showModalBottomSheet<_ReceiverRole>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .32),
      builder: (_) => _ReceiverSheet(thai: _thai),
    );
    if (selected != null && mounted) {
      setState(() => _receiverRole = selected);
    }
  }

  Future<void> _restorePhoto() async {
    try {
      final store = widget.photoStore ?? await PodDraftPhotoStore.create();
      final restored = await store.restore(widget.stop.id);
      if (!mounted) return;
      setState(() {
        _photoStore = store;
        _photo = restored == null ? null : XFile(restored.path);
        _restoring = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _photoError = _thai
            ? 'ตรวจสอบรูปยืนยันที่บันทึกไว้ไม่ได้'
            : 'The saved delivery photo could not be checked.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_restoring || _capturing || _submitting || _pendingSync) return;
    setState(() {
      _capturing = true;
      _photoError = null;
    });
    try {
      final photo = await (widget.capturePhoto ?? _openCamera)();
      if (photo == null || !mounted) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final retained = await _photoStore!.retain(widget.stop.id, photo.path);
      if (!mounted) return;
      setState(() {
        _photo = XFile(retained.path);
        _capturing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _photoError = isCameraPermissionError(error)
            ? (_thai
                  ? 'ต้องอนุญาตให้ใช้กล้องเพื่อเก็บหลักฐานการส่ง'
                  : 'Camera access is required for delivery evidence.')
            : (_thai
                  ? 'บันทึกรูปยืนยันไม่ได้ โปรดลองอีกครั้ง'
                  : 'The delivery photo could not be retained. Try again.');
      });
      if (isCameraPermissionError(error)) {
        await showCameraPermissionRecovery(context);
      }
    }
  }

  Future<XFile?> _openCamera() => ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 75,
    requestFullMetadata: false,
  );

  Future<void> _complete() async {
    if (!_ready || _submitting) return;
    setState(() => _submitting = true);
    final confirmed = _confirmedLines.toList()..sort();
    final outcome = await widget.controller.completePod(
      stop: widget.stop,
      capturedPhotoPath: _photo!.path,
      confirmedLineNumbers: confirmed,
      handoffType: _handoffType,
      receiverName: _handoffType == 'left_at_location'
          ? null
          : _receiverName.text.trim(),
      receiverRelationship: _requiresReceiver
          ? _receiverRole!.contractValue
          : null,
      leftAtLocation: _handoffType == 'left_at_location'
          ? widget.handoff.leftAtLocation?.trim()
          : null,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _pendingSync = outcome?.pendingSync ?? false;
    });
    if (outcome?.committed ?? false) {
      await _photoStore?.clear(widget.stop.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ??
                (_thai
                    ? 'ยืนยันการส่งไม่ได้'
                    : 'Delivery could not be completed'),
          ),
        ),
      );
    }
  }
}

class _PodTopBar extends StatelessWidget {
  const _PodTopBar({
    required this.thai,
    required this.compact,
    required this.sequence,
    required this.stopCount,
    required this.recipientName,
  });

  final bool thai;
  final bool compact;
  final int sequence;
  final int stopCount;
  final String recipientName;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pod-top-bar'),
    height: DriverF03F04Metrics.topBarHeight,
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? DriverF03F04Metrics.compactTopBarPaddingHorizontal
          : DriverF03F04Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: DriverF03F04Metrics.topButtonSize,
          child: OutlinedButton(
            key: const Key('pod-back'),
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: RoundsColors.ink,
              side: const BorderSide(color: RoundsColors.lineStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RoundsRadii.small),
              ),
            ),
            child: const Icon(Icons.arrow_back, size: 21),
          ),
        ),
        SizedBox(width: DriverF03F04Metrics.topGap),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thai ? 'จุด $sequence' : 'Stop $sequence',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: thai ? 11.8 : 11.5,
                  height: thai ? 1.4 : 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: thai ? 2 : 3),
              Text(
                recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontFamily: 'Inter',
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          thai ? '$sequence จาก $stopCount' : '$sequence of $stopCount',
          style: TextStyle(
            color: RoundsColors.inkSecondary,
            fontSize: 12.5,
            height: thai ? 1.4 : 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PodHero extends StatelessWidget {
  const _PodHero({
    required this.thai,
    required this.compact,
    required this.done,
    required this.total,
    required this.handoff,
    required this.recipientName,
  });

  final bool thai;
  final bool compact;
  final int done;
  final int total;
  final DriverHandoffSelection handoff;
  final String recipientName;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact
        ? (thai
              ? DriverF03F04Metrics.compactThaiHeroSize
              : DriverF03F04Metrics.compactEnglishHeroSize)
        : (thai
              ? DriverF03F04Metrics.thaiHeroSize
              : DriverF03F04Metrics.englishHeroSize);
    final progressSize = compact
        ? (thai
              ? DriverF03F04Metrics.compactThaiProgressSize
              : DriverF03F04Metrics.compactProgressSize)
        : (thai
              ? DriverF03F04Metrics.thaiProgressSize
              : DriverF03F04Metrics.progressSize);
    final (label, detail) = switch (handoff.handoffType) {
      'recipient' => (thai ? 'ผู้รับ' : 'Recipient', recipientName),
      'someone_else' => (
        thai ? 'คนอื่นรับแทน' : 'Someone else',
        thai ? 'ต้องระบุผู้รับ' : 'receiver required',
      ),
      'left_at_location' => (
        thai ? 'วางไว้ที่จุดส่ง' : 'Left at location',
        handoff.leftAtLocation ?? (thai ? 'จุดที่อนุมัติ' : 'Approved place'),
      ),
      _ => (thai ? 'การส่งมอบ' : 'Delivery handoff', ''),
    };
    return Container(
      key: const Key('pod-hero'),
      padding: EdgeInsets.only(
        bottom: thai
            ? DriverF03F04Metrics.thaiHeroPaddingBottom
            : DriverF03F04Metrics.englishHeroPaddingBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  thai ? 'หลักฐานการส่ง' : 'Proof of delivery',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: titleSize,
                    height: thai ? 1.18 : 1.02,
                    fontWeight: thai ? FontWeight.w800 : FontWeight.w900,
                    letterSpacing: thai ? 0 : -1.55,
                  ),
                ),
              ),
              SizedBox(
                width: compact && thai
                    ? DriverF03F04Metrics.compactThaiHeroRowGap
                    : thai
                    ? DriverF03F04Metrics.thaiHeroRowGap
                    : DriverF03F04Metrics.heroRowGap,
              ),
              Padding(
                padding: EdgeInsets.only(top: thai ? 4 : 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$done / $total',
                      key: const Key('pod-progress'),
                      style: TextStyle(
                        color: RoundsColors.ink,
                        fontFamily: 'Inter',
                        fontSize: progressSize,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    SizedBox(height: thai ? 4 : 5),
                    Text(
                      thai ? 'ต้องทำ' : 'required',
                      style: TextStyle(
                        color: RoundsColors.muted,
                        fontSize: thai ? 11.8 : 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: thai
                ? DriverF03F04Metrics.thaiHandoffGap
                : DriverF03F04Metrics.englishHandoffGap,
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.isNotEmpty) TextSpan(text: ' · $detail'),
              ],
            ),
            style: TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: 13.5,
              height: thai ? 1.45 : 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodSection extends StatelessWidget {
  const _PodSection({
    required this.thai,
    required this.compact,
    required this.title,
    required this.done,
    required this.child,
  });

  final bool thai;
  final bool compact;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: compact && thai
          ? DriverF03F04Metrics.compactThaiSectionMarginTop
          : thai
          ? DriverF03F04Metrics.thaiSectionMarginTop
          : DriverF03F04Metrics.englishSectionMarginTop,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: thai
                ? DriverF03F04Metrics.thaiSectionHeadBottom
                : DriverF03F04Metrics.englishSectionHeadBottom,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: thai ? 13.5 : 13,
                  height: thai ? 1.4 : 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                done
                    ? (thai ? 'ยืนยันแล้ว' : 'Verified')
                    : (thai ? 'ต้องทำ' : 'Required'),
                style: TextStyle(
                  color: done ? RoundsColors.green : RoundsColors.muted,
                  fontSize: thai ? 11.8 : 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

class _PodManifest extends StatelessWidget {
  const _PodManifest({
    required this.stop,
    required this.thai,
    required this.compact,
    required this.confirmedLines,
    required this.disabled,
    required this.onToggle,
  });

  final DriverRoundStopModel stop;
  final bool thai;
  final bool compact;
  final Set<int> confirmedLines;
  final bool disabled;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pod-manifest'),
    decoration: BoxDecoration(
      border: Border.all(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stop.manifestItems.length; i++)
          _ManifestLine(
            item: stop.manifestItems[i],
            deliveryReference: stop.deliveryReference,
            thai: thai,
            compact: compact,
            checked: confirmedLines.contains(stop.manifestItems[i].lineNumber),
            showDivider: i != stop.manifestItems.length - 1,
            onTap: disabled
                ? null
                : () => onToggle(stop.manifestItems[i].lineNumber),
          ),
      ],
    ),
  );
}

class _ManifestLine extends StatelessWidget {
  const _ManifestLine({
    required this.item,
    required this.deliveryReference,
    required this.thai,
    required this.compact,
    required this.checked,
    required this.showDivider,
    required this.onTap,
  });

  final DriverManifestItemModel item;
  final String deliveryReference;
  final bool thai;
  final bool compact;
  final bool checked;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: checked ? const Color(0xFFFBFEFC) : RoundsColors.surface,
    child: InkWell(
      key: Key('pod-manifest-line-${item.lineNumber}'),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minHeight: compact && thai
              ? DriverF03F04Metrics.compactThaiManifestMinHeight
              : thai
              ? DriverF03F04Metrics.thaiManifestMinHeight
              : DriverF03F04Metrics.englishManifestMinHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact && thai
              ? DriverF03F04Metrics.compactThaiManifestPaddingHorizontal
              : DriverF03F04Metrics.manifestPaddingHorizontal,
          vertical: thai ? 11 : 12,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: RoundsColors.line))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: compact
                  ? DriverF03F04Metrics.compactManifestCheckColumn
                  : DriverF03F04Metrics.manifestCheckColumn,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  width: DriverF03F04Metrics.manifestCheckSize,
                  height: DriverF03F04Metrics.manifestCheckSize,
                  decoration: BoxDecoration(
                    color: checked ? RoundsColors.green : RoundsColors.surface,
                    border: Border.all(
                      color: checked
                          ? RoundsColors.green
                          : RoundsColors.lineStrong,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: checked
                      ? const Icon(Icons.check, size: 17, color: Colors.white)
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: compact && thai
                  ? DriverF03F04Metrics.compactThaiManifestGap
                  : thai
                  ? DriverF03F04Metrics.thaiManifestGap
                  : DriverF03F04Metrics.manifestGap,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: compact && thai
                          ? 12.8
                          : thai
                          ? 13.8
                          : 14,
                      height: thai ? 1.4 : 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '#$deliveryReference · ${thai ? 'ยืนยันตอนรับของแล้ว' : 'pickup verified'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: compact && thai ? 10.8 : 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '×${item.quantity}',
                  style: const TextStyle(
                    color: RoundsColors.inkSecondary,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.handlingNote?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.handlingNote!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RoundsColors.orange,
                      fontSize: compact && thai ? 10.8 : 11.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReceiverRow extends StatelessWidget {
  const _ReceiverRow({
    required this.thai,
    required this.selected,
    required this.onTap,
  });

  final bool thai;
  final _ReceiverRole? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: RoundsColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(RoundsRadii.small),
    ),
    child: InkWell(
      key: const Key('pod-receiver-role'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(RoundsRadii.small),
      child: Container(
        constraints: BoxConstraints(
          minHeight: thai
              ? DriverF03F04Metrics.thaiReceiverMinHeight
              : DriverF03F04Metrics.englishReceiverMinHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thai ? 'ใครรับของ?' : 'Who received it?',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: thai ? 14 : 13.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: thai ? 2 : 4),
                  Text(
                    thai ? 'เลือกผู้รับ' : 'Choose one',
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              selected == null
                  ? (thai ? 'เลือก' : 'Choose')
                  : selected!.label(thai),
              style: const TextStyle(
                color: RoundsColors.orange,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoSurface extends StatelessWidget {
  const _PhotoSurface({
    required this.thai,
    required this.compact,
    required this.leftAtLocation,
    required this.photo,
    required this.restoring,
    required this.capturing,
    required this.disabled,
    required this.onCapture,
  });

  final bool thai;
  final bool compact;
  final bool leftAtLocation;
  final XFile? photo;
  final bool restoring;
  final bool capturing;
  final bool disabled;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? (thai
              ? DriverF03F04Metrics.compactThaiPhotoMinHeight
              : DriverF03F04Metrics.compactEnglishPhotoMinHeight)
        : (thai
              ? DriverF03F04Metrics.thaiPhotoMinHeight
              : DriverF03F04Metrics.englishPhotoMinHeight);
    return Semantics(
      button: true,
      label: thai ? 'ถ่ายรูปยืนยันการส่ง' : 'Take delivery photo',
      child: Material(
        color: photo == null
            ? const Color(0xFFF7F9FA)
            : const Color(0xFFEEF5F1),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: photo == null
                ? const Color(0xFFAEB9C4)
                : const Color(0xFFBFDACB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('capture-delivery-photo'),
          onTap: disabled || restoring || capturing ? null : onCapture,
          child: SizedBox(
            height: height,
            child: photo == null
                ? Center(
                    child: restoring || capturing
                        ? _PhotoBusy(thai: thai, restoring: restoring)
                        : _PhotoEmpty(
                            thai: thai,
                            leftAtLocation: leftAtLocation,
                          ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(photo!.path), fit: BoxFit.cover),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PhotoBadge(
                              text: thai ? '✓ เพิ่มรูปแล้ว' : '✓ Photo added',
                              color: RoundsColors.green,
                            ),
                            _PhotoBadge(
                              text: thai ? 'ถ่ายใหม่' : 'Retake',
                              color: RoundsColors.inkSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBusy extends StatelessWidget {
  const _PhotoBusy({required this.thai, required this.restoring});
  final bool thai;
  final bool restoring;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      const SizedBox(height: 10),
      Text(
        restoring
            ? (thai ? 'กำลังตรวจสอบรูปที่บันทึกไว้…' : 'Checking saved photo…')
            : (thai ? 'กำลังบันทึกรูป…' : 'Saving photo…'),
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: 12.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PhotoEmpty extends StatelessWidget {
  const _PhotoEmpty({required this.thai, required this.leftAtLocation});
  final bool thai;
  final bool leftAtLocation;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: DriverF03F04Metrics.cameraSize,
        height: DriverF03F04Metrics.cameraSize,
        decoration: BoxDecoration(
          color: RoundsColors.surface,
          border: Border.all(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(
          Icons.camera_alt_outlined,
          size: 25,
          color: RoundsColors.orange,
        ),
      ),
      SizedBox(height: thai ? 10 : 12),
      Text(
        leftAtLocation
            ? (thai ? 'ถ่ายรูปจุดที่วางของ' : 'Photograph where it was left')
            : (thai ? 'ถ่ายรูปส่งของ' : 'Take delivery photo'),
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: 14.5,
          height: thai ? 1.4 : 1,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: thai ? 3 : 5),
      Text(
        thai ? 'แตะเพื่อถ่าย' : 'Tap to capture',
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: 12.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      border: Border.all(color: RoundsColors.ink.withValues(alpha: .12)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11.8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AutomaticRow extends StatelessWidget {
  const _AutomaticRow({required this.thai});
  final bool thai;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pod-server-time'),
    constraints: const BoxConstraints(
      minHeight: DriverF03F04Metrics.automaticMinHeight,
    ),
    margin: EdgeInsets.only(
      top: thai
          ? DriverF03F04Metrics.thaiAutomaticMarginTop
          : DriverF03F04Metrics.englishAutomaticMarginTop,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: RoundsColors.line),
        bottom: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          thai ? 'เวลาส่ง' : 'Delivery time',
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          thai ? 'บันทึกโดยเซิร์ฟเวอร์' : 'Server recorded',
          style: const TextStyle(
            color: RoundsColors.green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PendingSync extends StatelessWidget {
  const _PendingSync({required this.thai});
  final bool thai;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      key: const Key('pod-pending-sync'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        border: Border.all(color: const Color(0xFFE8CF94)),
        borderRadius: BorderRadius.circular(RoundsRadii.small),
      ),
      child: Text(
        thai
            ? 'หลักฐานถูกเก็บไว้ในโทรศัพท์แล้ว รอเชื่อมต่อเพื่อส่งข้อมูล จุดนี้ยังไม่ถูกทำเครื่องหมายว่าส่งสำเร็จ'
            : 'Evidence is safe on this phone and waiting to sync. This stop is not marked delivered yet.',
        style: const TextStyle(
          color: RoundsColors.inkSecondary,
          fontSize: 12.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _PodFooter extends StatelessWidget {
  const _PodFooter({
    required this.thai,
    required this.compact,
    required this.sequence,
    required this.submitting,
    required this.pendingSync,
    required this.ready,
    required this.onPressed,
  });

  final bool thai;
  final bool compact;
  final int sequence;
  final bool submitting;
  final bool pendingSync;
  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact
        ? (thai
              ? DriverF03F04Metrics.compactThaiFooterPaddingHorizontal
              : DriverF03F04Metrics.compactEnglishFooterPaddingHorizontal)
        : DriverF03F04Metrics.footerPaddingHorizontal;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        DriverF03F04Metrics.footerPaddingTop,
        horizontal,
        DriverF03F04Metrics.footerPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: RoundsColors.surface.withValues(alpha: .985),
        border: const Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: SizedBox(
        height: compact && thai
            ? DriverF03F04Metrics.compactThaiPrimaryHeight
            : DriverF03F04Metrics.primaryHeight,
        child: FilledButton(
          key: const Key('complete-delivery'),
          onPressed: ready && !submitting ? onPressed : null,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: const Color(0xFFD9DFE5),
            disabledForegroundColor: const Color(0xFF85909D),
            backgroundColor: RoundsColors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DriverF03F04Metrics.primaryRadius,
              ),
            ),
          ),
          child: Text(
            submitting
                ? (thai ? 'กำลังตรวจสอบหลักฐาน…' : 'Verifying evidence…')
                : pendingSync
                ? (thai ? 'ลองส่งหลักฐานอีกครั้ง' : 'Retry evidence sync')
                : thai
                ? 'ยืนยันส่งจุด $sequence'
                : 'Complete Stop $sequence',
            style: TextStyle(
              fontSize: thai ? 16.5 : 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReceiverRole {
  reception('reception'),
  security('security'),
  family('family'),
  staff('staff_or_colleague'),
  other('other');

  const _ReceiverRole(this.contractValue);
  final String contractValue;

  String label(bool thai) => switch (this) {
    _ReceiverRole.reception => thai ? 'รีเซปชัน' : 'Reception',
    _ReceiverRole.security => thai ? 'รปภ.' : 'Security',
    _ReceiverRole.family => thai ? 'ครอบครัว' : 'Family',
    _ReceiverRole.staff =>
      thai ? 'พนักงาน / เพื่อนร่วมงาน' : 'Staff / colleague',
    _ReceiverRole.other => thai ? 'อื่นๆ' : 'Other',
  };
}

class _ReceiverSheet extends StatelessWidget {
  const _ReceiverSheet({required this.thai});
  final bool thai;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      DriverF03F04Metrics.sheetPaddingHorizontal,
      DriverF03F04Metrics.sheetPaddingTop,
      DriverF03F04Metrics.sheetPaddingHorizontal,
      DriverF03F04Metrics.sheetPaddingBottom,
    ),
    decoration: BoxDecoration(
      color: RoundsColors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DriverF03F04Metrics.sheetRadius),
      ),
      border: const Border(top: BorderSide(color: RoundsColors.lineStrong)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: DriverF03F04Metrics.sheetHandleWidth,
            height: DriverF03F04Metrics.sheetHandleHeight,
            margin: const EdgeInsets.only(top: 1, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD3DA),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Text(
          thai ? 'ใครรับของ?' : 'Received by',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: thai
                ? DriverF03F04Metrics.thaiSheetTitleSize
                : DriverF03F04Metrics.sheetTitleSize,
            height: thai ? 1.35 : 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: thai ? 0 : -.75,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: RoundsColors.line)),
          ),
          child: Column(
            children: [
              for (final role in _ReceiverRole.values)
                SizedBox(
                  height: thai
                      ? DriverF03F04Metrics.thaiSheetRowHeight
                      : DriverF03F04Metrics.sheetRowHeight,
                  child: InkWell(
                    key: Key('pod-receiver-${role.name}'),
                    onTap: () => Navigator.of(context).pop(role),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: RoundsColors.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              role.label(thai),
                              style: const TextStyle(
                                color: RoundsColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(
                            '›',
                            style: TextStyle(
                              color: RoundsColors.muted,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: DriverF03F04Metrics.sheetCancelHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: RoundsColors.inkSecondary,
              side: const BorderSide(color: RoundsColors.lineStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RoundsRadii.small),
              ),
            ),
            child: Text(
              thai ? 'ยกเลิก' : 'Cancel',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
