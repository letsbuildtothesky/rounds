import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import '../storage/delivery_problem_photo_store.dart';
import 'components/rounds_action_drawer.dart';
import 'driver_emergency_screen.dart';
import 'operations_chat_screen.dart';

typedef DamagePhotoCapture = Future<XFile?> Function();

enum DeliveryPackageProblemCategory {
  damaged('damaged_item'),
  missing('missing_item'),
  wrong('wrong_item');

  const DeliveryPackageProblemCategory(this.apiValue);
  final String apiValue;
  bool get requiresPhoto => this != DeliveryPackageProblemCategory.missing;

  static DeliveryPackageProblemCategory? fromApiValue(String? value) {
    for (final category in values) {
      if (category.apiValue == value) return category;
    }
    return null;
  }
}

class DeliveryPackageProblemScreen extends StatefulWidget {
  const DeliveryPackageProblemScreen({
    required this.controller,
    required this.round,
    required this.stop,
    this.initialCategory,
    this.initialNote = '',
    this.photoStore,
    this.capturePhoto,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final DeliveryPackageProblemCategory? initialCategory;
  final String initialNote;
  final DeliveryProblemPhotoStore? photoStore;
  final DamagePhotoCapture? capturePhoto;

  @override
  State<DeliveryPackageProblemScreen> createState() =>
      _DeliveryPackageProblemScreenState();
}

class _DeliveryPackageProblemScreenState
    extends State<DeliveryPackageProblemScreen> {
  DeliveryProblemPhotoStore? _photoStore;
  DeliveryPackageProblemCategory? _category;
  File? _photo;
  bool _restoring = true;
  bool _capturing = false;
  bool _submitting = false;
  bool _pendingSync = false;
  bool _submitted = false;
  String? _error;

  AppStrings get _copy => widget.controller.strings;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  Widget build(BuildContext context) {
    final contentBottom = _copy.isThai ? 80.0 : 112.0;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: DriverG03Metrics.topBarHeight,
              child: _ProblemTopBar(
                copy: _copy,
                sequence: widget.stop.sequence,
                stopCount: widget.round.stops.length,
                recipientName: widget.stop.recipientName,
                onMore: _openMoreActions,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: DriverG03Metrics.topBarHeight,
              bottom: contentBottom,
              child: _restoring
                  ? const Center(child: CircularProgressIndicator())
                  : _submitted
                  ? _WaitingState(
                      copy: _copy,
                      stop: widget.stop,
                      stopCount: widget.round.stops.length,
                      category: _category!,
                      pendingSync: _pendingSync,
                    )
                  : _category == null
                  ? _InitialState(
                      copy: _copy,
                      stop: widget.stop,
                      onChoose: _chooseCategory,
                    )
                  : _EvidenceState(
                      copy: _copy,
                      stop: widget.stop,
                      category: _category!,
                      photo: _photo,
                      capturing: _capturing,
                      error: _error,
                      onCapture: _capture,
                    ),
            ),
            if (!_restoring)
              Positioned(left: 0, right: 0, bottom: 0, child: _footer()),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    if (_submitted) {
      return _ProblemFooter(
        copy: _copy,
        mode: _ProblemFooterMode.waiting,
        pendingSync: _pendingSync,
      );
    }
    if (_category == null) {
      return _ProblemFooter(
        copy: _copy,
        mode: _ProblemFooterMode.initial,
        onSecondary: _openMoreActions,
      );
    }
    return _ProblemFooter(
      copy: _copy,
      mode: _ProblemFooterMode.evidence,
      submitting: _submitting,
      needsPhoto: _category!.requiresPhoto && _photo == null,
      category: _category,
      onPrimary: _submit,
      onSecondary: _changeProblem,
    );
  }

  Future<void> _restoreDraft() async {
    try {
      final store =
          widget.photoStore ?? await DeliveryProblemPhotoStore.create();
      final restoredPhoto = await store.restore(widget.stop.id);
      var restoredCategory = DeliveryPackageProblemCategory.fromApiValue(
        store.restoreCategory(widget.stop.id),
      );
      restoredCategory ??= widget.initialCategory;
      if (restoredCategory == null && restoredPhoto != null) {
        restoredCategory = DeliveryPackageProblemCategory.damaged;
      }
      if (restoredCategory != null) {
        await store.saveCategory(widget.stop.id, restoredCategory.apiValue);
      }
      if (widget.initialNote.trim().isNotEmpty &&
          store.restoreNote(widget.stop.id).isEmpty) {
        await store.saveNote(widget.stop.id, widget.initialNote.trim());
      }
      if (!mounted) return;
      setState(() {
        _photoStore = store;
        _photo = restoredPhoto;
        _category = restoredCategory;
        _restoring = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = _copy.isThai
            ? 'ไม่สามารถตรวจสอบร่างที่บันทึกไว้ได้'
            : 'The saved package-problem draft could not be checked.';
      });
    }
  }

  Future<void> _chooseCategory(DeliveryPackageProblemCategory category) async {
    await _photoStore?.saveCategory(widget.stop.id, category.apiValue);
    if (!category.requiresPhoto && _photo != null) {
      await _photoStore?.clearPhoto(widget.stop.id);
    }
    if (!mounted) return;
    setState(() {
      _category = category;
      if (!category.requiresPhoto) _photo = null;
      _pendingSync = false;
      _error = null;
    });
  }

  Future<void> _changeProblem() async {
    await _photoStore?.clearPhoto(widget.stop.id);
    await _photoStore?.saveCategory(widget.stop.id, null);
    if (!mounted) return;
    setState(() {
      _category = null;
      _photo = null;
      _pendingSync = false;
      _error = null;
    });
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final captured = await (widget.capturePhoto ?? _openCamera)();
      if (captured == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final retained = await _photoStore!.retain(widget.stop.id, captured.path);
      if (!mounted) return;
      setState(() {
        _photo = retained;
        _capturing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = isCameraPermissionError(error)
            ? (_copy.isThai
                  ? 'ต้องอนุญาตการใช้กล้องเพื่อถ่ายหลักฐาน'
                  : 'Camera access is required for photo evidence.')
            : (_copy.isThai
                  ? 'บันทึกรูปไม่สำเร็จ ลองอีกครั้ง'
                  : 'The photo could not be saved. Try again.');
      });
      if (isCameraPermissionError(error)) {
        await showCameraPermissionRecovery(
          context,
          locale: widget.controller.locale,
        );
      }
    }
  }

  Future<XFile?> _openCamera() => ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 75,
    requestFullMetadata: false,
  );

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await widget.controller.reportDeliveryProblem(
      stop: widget.stop,
      category: _category!.apiValue,
      capturedPhotoPath: _photo?.path,
      note: _photoStore?.restoreNote(widget.stop.id),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _pendingSync = outcome?.pendingSync ?? false;
      _submitted = outcome != null;
      _error = outcome == null
          ? widget.controller.driverError ??
                (_copy.isThai
                    ? 'ส่งปัญหาไม่สำเร็จ'
                    : 'Package problem could not be sent')
          : null;
    });
    if (outcome?.committed ?? false) {
      await _photoStore?.clear(widget.stop.id);
      if (mounted) setState(() => _photo = null);
    }
  }

  Future<void> _openMoreActions() async {
    final action = await showRoundsActionDrawer(
      context,
      title: _copy.packageProblem,
      showCancel: false,
      showChevrons: false,
      inset: true,
      actions: [
        RoundsDrawerAction(
          value: 'message',
          label: _copy.messageOperations,
          icon: Icons.chat_bubble_outline,
        ),
        RoundsDrawerAction(
          value: 'handoff',
          label: _copy.isThai ? 'กลับไปส่งมอบ' : 'Return to handoff',
          icon: Icons.arrow_back,
        ),
        RoundsDrawerAction(
          value: 'emergency',
          label: _copy.isThai ? 'ฉุกเฉิน' : 'Emergency',
          icon: Icons.warning_amber_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'message':
        await _openOperationsChat();
        return;
      case 'handoff':
        if (mounted) Navigator.of(context).pop();
        return;
      case 'emergency':
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => DriverEmergencyScreen(
              controller: widget.controller,
              round: widget.round,
              stop: widget.stop,
            ),
          ),
        );
        return;
    }
  }

  Future<void> _openOperationsChat() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OperationsChatScreen(
        controller: widget.controller,
        round: widget.round,
        stop: widget.stop,
      ),
    ),
  );
}

class _ProblemTopBar extends StatelessWidget {
  const _ProblemTopBar({
    required this.copy,
    required this.sequence,
    required this.stopCount,
    required this.recipientName,
    required this.onMore,
  });

  final AppStrings copy;
  final int sequence;
  final int stopCount;
  final String recipientName;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return Container(
      key: const Key('package-problem-topbar'),
      padding: const EdgeInsets.symmetric(
        horizontal: DriverG03Metrics.topBarPaddingHorizontal,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: DriverG03Metrics.topButtonSize,
            child: IconButton(
              key: const Key('package-problem-back'),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                size: DriverG03Metrics.topIconSize,
              ),
            ),
          ),
          const SizedBox(width: DriverG03Metrics.topColumnGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thai
                      ? copy.stopProgress(sequence, stopCount)
                      : copy.stopProgress(sequence, stopCount).toUpperCase(),
                  style: TextStyle(
                    color: RoundsColors.orange,
                    fontSize: thai
                        ? DriverG03Metrics.thaiTopEyebrowSize
                        : DriverG03Metrics.englishTopEyebrowSize,
                    height: thai ? DriverG03Metrics.thaiTopEyebrowHeight : 1,
                    fontWeight: thai ? FontWeight.w700 : FontWeight.w900,
                    letterSpacing: thai
                        ? 0
                        : DriverG03Metrics.englishTopEyebrowTracking,
                  ),
                ),
                SizedBox(
                  height: thai
                      ? DriverG03Metrics.thaiTopTitleGap
                      : DriverG03Metrics.englishTopTitleGap,
                ),
                Text(
                  recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverG03Metrics.topTitleSize,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.425,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DriverG03Metrics.topColumnGap),
          SizedBox.square(
            dimension: DriverG03Metrics.topButtonSize,
            child: IconButton(
              key: const Key('package-problem-more'),
              onPressed: onMore,
              padding: const EdgeInsets.only(bottom: 5),
              icon: const Icon(Icons.more_horiz, size: 25),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState({
    required this.copy,
    required this.stop,
    required this.onChoose,
  });

  final AppStrings copy;
  final DriverRoundStopModel stop;
  final ValueChanged<DeliveryPackageProblemCategory> onChoose;

  @override
  Widget build(BuildContext context) => _ProblemContent(
    key: const Key('package-problem-initial'),
    copy: copy,
    children: [
      _Kicker(copy: copy, text: copy.deliveryProblem, color: RoundsColors.red),
      _Hero(copy: copy, text: copy.packageProblem),
      _Location(copy: copy, text: stop.rawAddress),
      _PackageRecord(
        copy: copy,
        stop: stop,
        eyebrow: copy.packageInCustody,
        note: _handlingNote(copy, stop),
      ),
      _CustodyLine(copy: copy, text: copy.pickupVerified),
      _ProblemChoices(copy: copy, onChoose: onChoose),
    ],
  );
}

class _EvidenceState extends StatelessWidget {
  const _EvidenceState({
    required this.copy,
    required this.stop,
    required this.category,
    required this.photo,
    required this.capturing,
    required this.error,
    required this.onCapture,
  });

  final AppStrings copy;
  final DriverRoundStopModel stop;
  final DeliveryPackageProblemCategory category;
  final File? photo;
  final bool capturing;
  final String? error;
  final VoidCallback onCapture;

  String get title => switch (category) {
    DeliveryPackageProblemCategory.damaged =>
      copy.isThai ? 'ของเสียหาย' : 'Package damaged',
    DeliveryPackageProblemCategory.missing =>
      copy.isThai ? 'ของไม่ครบ' : 'Package missing',
    DeliveryPackageProblemCategory.wrong => copy.packageWrong,
  };

  String get summary => switch (category) {
    DeliveryPackageProblemCategory.damaged => copy.packageDamaged,
    DeliveryPackageProblemCategory.missing => copy.packageMissing,
    DeliveryPackageProblemCategory.wrong => copy.packageWrong,
  };

  @override
  Widget build(BuildContext context) => _ProblemContent(
    key: const Key('package-problem-evidence'),
    copy: copy,
    children: [
      _Kicker(copy: copy, text: copy.packageProblem, color: RoundsColors.red),
      _Hero(copy: copy, text: title),
      _Location(copy: copy, text: stop.rawAddress),
      _PackageRecord(
        copy: copy,
        stop: stop,
        eyebrow: copy.custodyRecord,
        note: _handlingNote(copy, stop),
      ),
      _CustodyLine(copy: copy, text: copy.custodyUnchanged),
      if (category.requiresPhoto)
        _PhotoBlock(
          copy: copy,
          category: category,
          photo: photo,
          capturing: capturing,
          onCapture: onCapture,
        ),
      _ReportSummary(copy: copy, stop: stop, problem: summary),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            error!,
            key: const Key('package-problem-error'),
            style: const TextStyle(
              color: RoundsColors.red,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
}

class _WaitingState extends StatelessWidget {
  const _WaitingState({
    required this.copy,
    required this.stop,
    required this.stopCount,
    required this.category,
    required this.pendingSync,
  });

  final AppStrings copy;
  final DriverRoundStopModel stop;
  final int stopCount;
  final DeliveryPackageProblemCategory category;
  final bool pendingSync;

  String get summary => switch (category) {
    DeliveryPackageProblemCategory.damaged =>
      copy.isThai
          ? 'แจ้งของเสียหาย · แนบรูปแล้ว'
          : 'Damage reported · photo attached',
    DeliveryPackageProblemCategory.missing =>
      copy.isThai ? 'แจ้งของไม่ครบ' : 'Missing package reported',
    DeliveryPackageProblemCategory.wrong =>
      copy.isThai
          ? 'แจ้งของไม่ตรง · แนบรูปแล้ว'
          : 'Wrong package reported · photo attached',
  };

  @override
  Widget build(BuildContext context) => _ProblemContent(
    key: const Key('package-problem-waiting'),
    copy: copy,
    children: [
      _Kicker(
        copy: copy,
        text: copy.sentToOperations,
        color: RoundsColors.orange,
      ),
      _Hero(copy: copy, text: copy.waitingForDecision),
      _Location(
        copy: copy,
        text:
            '${stop.recipientName} · ${copy.stopProgress(stop.sequence, stopCount)}',
      ),
      _PackageRecord(
        copy: copy,
        stop: stop,
        eyebrow: copy.packageInCustody,
        note: summary,
      ),
      _WaitingCopy(copy: copy, pendingSync: pendingSync, category: category),
    ],
  );
}

class _ProblemContent extends StatelessWidget {
  const _ProblemContent({
    required this.copy,
    required this.children,
    super.key,
  });

  final AppStrings copy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return ListView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        DriverG03Metrics.contentPaddingHorizontal,
        thai
            ? DriverG03Metrics.thaiContentPaddingTop
            : DriverG03Metrics.englishContentPaddingTop,
        DriverG03Metrics.contentPaddingHorizontal,
        thai
            ? DriverG03Metrics.thaiContentPaddingBottom
            : DriverG03Metrics.englishContentPaddingBottom,
      ),
      children: children,
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.copy, required this.text, required this.color});

  final AppStrings copy;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return Row(
      children: [
        Icon(Icons.circle, size: DriverG03Metrics.dotSize, color: color),
        const SizedBox(width: DriverG03Metrics.kickerGap),
        Text(
          thai ? text : text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: thai
                ? DriverG03Metrics.thaiKickerSize
                : DriverG03Metrics.englishKickerSize,
            height: thai ? DriverG03Metrics.thaiKickerHeight : 1,
            fontWeight: thai ? FontWeight.w700 : FontWeight.w900,
            letterSpacing: thai ? 0 : DriverG03Metrics.englishKickerTracking,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.copy, required this.text});

  final AppStrings copy;
  final String text;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiHeroGap
            : DriverG03Metrics.englishHeroGap,
      ),
      child: Text(
        text,
        maxLines: thai ? 1 : null,
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: thai
              ? DriverG03Metrics.thaiHeroSize
              : DriverG03Metrics.englishHeroSize,
          height: thai
              ? DriverG03Metrics.thaiHeroHeight
              : DriverG03Metrics.englishHeroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: thai ? 0 : DriverG03Metrics.englishHeroTracking,
        ),
      ),
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({required this.copy, required this.text});

  final AppStrings copy;
  final String text;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiLocationGap
            : DriverG03Metrics.englishLocationGap,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: RoundsColors.muted,
          fontSize: thai
              ? DriverG03Metrics.thaiLocationSize
              : DriverG03Metrics.englishLocationSize,
          height: thai
              ? DriverG03Metrics.thaiLocationHeight
              : DriverG03Metrics.englishLocationHeight,
          fontWeight: thai ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _PackageRecord extends StatelessWidget {
  const _PackageRecord({
    required this.copy,
    required this.stop,
    required this.eyebrow,
    required this.note,
  });

  final AppStrings copy;
  final DriverRoundStopModel stop;
  final String eyebrow;
  final String note;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    final item = stop.manifestItems.firstOrNull;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiPackageMarginTop
            : DriverG03Metrics.englishPackageMarginTop,
      ),
      child: Container(
        key: const Key('package-problem-record'),
        padding: EdgeInsets.only(
          top: thai
              ? DriverG03Metrics.thaiPackagePaddingTop
              : DriverG03Metrics.englishPackagePaddingTop,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RoundsColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: thai
                          ? DriverG03Metrics.thaiPackageEyebrowSize
                          : DriverG03Metrics.englishPackageEyebrowSize,
                      height: thai
                          ? DriverG03Metrics.thaiPackageEyebrowHeight
                          : 1,
                      fontWeight: thai ? FontWeight.w600 : FontWeight.w900,
                      letterSpacing: thai
                          ? 0
                          : DriverG03Metrics.englishPackageEyebrowTracking,
                    ),
                  ),
                  SizedBox(
                    height: thai
                        ? DriverG03Metrics.thaiPackageNameGap
                        : DriverG03Metrics.englishPackageNameGap,
                  ),
                  Text(
                    item?.description ?? stop.deliveryReference,
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: thai
                          ? DriverG03Metrics.thaiPackageNameSize
                          : DriverG03Metrics.englishPackageNameSize,
                      height: thai
                          ? DriverG03Metrics.thaiPackageNameHeight
                          : DriverG03Metrics.englishPackageNameHeight,
                      fontWeight: FontWeight.w900,
                      letterSpacing: thai
                          ? 0
                          : DriverG03Metrics.englishPackageNameTracking,
                    ),
                  ),
                  SizedBox(
                    height: thai
                        ? DriverG03Metrics.thaiPackageNoteGap
                        : DriverG03Metrics.englishPackageNoteGap,
                  ),
                  Text(
                    note,
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: thai
                          ? DriverG03Metrics.thaiPackageNoteSize
                          : DriverG03Metrics.englishPackageNoteSize,
                      height: thai
                          ? DriverG03Metrics.thaiPackageNoteHeight
                          : DriverG03Metrics.englishPackageNoteHeight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: thai
                  ? DriverG03Metrics.thaiPackageColumnGap
                  : DriverG03Metrics.englishPackageColumnGap,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: thai
                    ? DriverG03Metrics.thaiQuantityPaddingTop
                    : DriverG03Metrics.englishQuantityPaddingTop,
              ),
              child: Text(
                '×${item?.quantity ?? 1}',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: thai
                      ? DriverG03Metrics.thaiQuantitySize
                      : DriverG03Metrics.englishQuantitySize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustodyLine extends StatelessWidget {
  const _CustodyLine({required this.copy, required this.text});

  final AppStrings copy;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: copy.isThai
          ? DriverG03Metrics.thaiCustodyGap
          : DriverG03Metrics.englishCustodyGap,
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check,
          color: RoundsColors.green,
          size: DriverG03Metrics.custodyIconSize,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: RoundsColors.green,
              fontSize: DriverG03Metrics.custodyTextSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProblemChoices extends StatelessWidget {
  const _ProblemChoices({required this.copy, required this.onChoose});

  final AppStrings copy;
  final ValueChanged<DeliveryPackageProblemCategory> onChoose;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiChoiceSectionGap
            : DriverG03Metrics.englishChoiceSectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.packageWhatIsWrong,
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: thai
                  ? DriverG03Metrics.thaiChoiceTitleSize
                  : DriverG03Metrics.englishChoiceTitleSize,
              height: thai ? DriverG03Metrics.thaiChoiceTitleHeight : 1,
              fontWeight: FontWeight.w800,
              letterSpacing: thai
                  ? 0
                  : DriverG03Metrics.englishChoiceTitleTracking,
            ),
          ),
          SizedBox(
            height: thai
                ? DriverG03Metrics.thaiChoiceTitleBottom
                : DriverG03Metrics.englishChoiceTitleBottom,
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: RoundsColors.line)),
            ),
            child: Column(
              children: [
                _ProblemChoice(
                  key: const Key('package-problem-damaged'),
                  copy: copy,
                  icon: Icons.warning_amber_rounded,
                  title: copy.packageDamaged,
                  subtitle: copy.packageDamagedHelp,
                  onTap: () => onChoose(DeliveryPackageProblemCategory.damaged),
                ),
                _ProblemChoice(
                  key: const Key('package-problem-missing'),
                  copy: copy,
                  icon: Icons.inventory_2_outlined,
                  title: copy.packageMissing,
                  subtitle: copy.packageMissingHelp,
                  onTap: () => onChoose(DeliveryPackageProblemCategory.missing),
                ),
                _ProblemChoice(
                  key: const Key('package-problem-wrong'),
                  copy: copy,
                  icon: Icons.disabled_by_default_outlined,
                  title: copy.packageWrong,
                  subtitle: copy.packageWrongHelp,
                  onTap: () => onChoose(DeliveryPackageProblemCategory.wrong),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemChoice extends StatelessWidget {
  const _ProblemChoice({
    required this.copy,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final AppStrings copy;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return SizedBox(
      height: thai
          ? DriverG03Metrics.thaiChoiceRowHeight
          : DriverG03Metrics.englishChoiceRowHeight,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: RoundsColors.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: thai
                    ? DriverG03Metrics.thaiChoiceIconColumnWidth
                    : DriverG03Metrics.englishChoiceIconColumnWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    icon,
                    color: RoundsColors.inkSecondary,
                    size: thai
                        ? DriverG03Metrics.thaiChoiceIconSize
                        : DriverG03Metrics.englishChoiceIconSize,
                  ),
                ),
              ),
              SizedBox(
                width: thai
                    ? DriverG03Metrics.thaiChoiceColumnGap
                    : DriverG03Metrics.englishChoiceColumnGap,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: RoundsColors.ink,
                        fontSize: thai
                            ? DriverG03Metrics.thaiChoiceNameSize
                            : DriverG03Metrics.englishChoiceNameSize,
                        height: thai
                            ? DriverG03Metrics.thaiChoiceNameHeight
                            : DriverG03Metrics.englishChoiceNameHeight,
                        fontWeight: FontWeight.w800,
                        letterSpacing: thai ? 0 : -.24,
                      ),
                    ),
                    SizedBox(
                      height: thai
                          ? DriverG03Metrics.thaiChoiceDetailGap
                          : DriverG03Metrics.englishChoiceDetailGap,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RoundsColors.muted,
                        fontSize: thai
                            ? DriverG03Metrics.thaiChoiceDetailSize
                            : DriverG03Metrics.englishChoiceDetailSize,
                        height: thai
                            ? DriverG03Metrics.thaiChoiceDetailHeight
                            : 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: DriverG03Metrics.choiceArrowColumnWidth,
                child: Icon(
                  Icons.chevron_right,
                  color: RoundsColors.muted,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.copy,
    required this.category,
    required this.photo,
    required this.capturing,
    required this.onCapture,
  });

  final AppStrings copy;
  final DeliveryPackageProblemCategory category;
  final File? photo;
  final bool capturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    final damage = category == DeliveryPackageProblemCategory.damaged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: thai
                ? DriverG03Metrics.thaiPhotoLabelTop
                : DriverG03Metrics.englishPhotoLabelTop,
            bottom: thai
                ? DriverG03Metrics.thaiPhotoLabelBottom
                : DriverG03Metrics.englishPhotoLabelBottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  damage ? copy.damagePhoto : copy.packagePhoto,
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: thai
                        ? DriverG03Metrics.thaiPhotoLabelSize
                        : DriverG03Metrics.englishPhotoLabelSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: thai ? 0 : .91,
                  ),
                ),
              ),
              Text(
                photo == null ? copy.required : copy.added,
                style: TextStyle(
                  color: photo == null ? RoundsColors.red : RoundsColors.green,
                  fontSize: thai
                      ? DriverG03Metrics.thaiPhotoStateSize
                      : DriverG03Metrics.englishPhotoStateSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _PhotoEvidence(
          copy: copy,
          photo: photo,
          capturing: capturing,
          title: damage ? copy.photographDamage : copy.photographPackage,
          onTap: onCapture,
        ),
      ],
    );
  }
}

class _PhotoEvidence extends StatelessWidget {
  const _PhotoEvidence({
    required this.copy,
    required this.photo,
    required this.capturing,
    required this.title,
    required this.onTap,
  });

  final AppStrings copy;
  final File? photo;
  final bool capturing;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return SizedBox(
      key: const Key('package-problem-photo'),
      height: thai
          ? DriverG03Metrics.thaiPhotoHeight
          : DriverG03Metrics.englishPhotoHeight,
      child: Material(
        color: RoundsColors.canvas,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.circular(DriverG03Metrics.photoRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('capture-package-problem-photo'),
          onTap: capturing ? null : onTap,
          child: photo == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: DriverG03Metrics.cameraBoxSize,
                      height: DriverG03Metrics.cameraBoxSize,
                      decoration: BoxDecoration(
                        color: RoundsColors.surface,
                        border: Border.all(color: RoundsColors.line),
                        borderRadius: BorderRadius.circular(
                          DriverG03Metrics.photoRadius,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: RoundsColors.red,
                        size: DriverG03Metrics.cameraIconSize,
                      ),
                    ),
                    SizedBox(
                      height: thai
                          ? DriverG03Metrics.thaiPhotoInnerGap
                          : DriverG03Metrics.englishPhotoInnerGap,
                    ),
                    Text(
                      capturing
                          ? (thai ? 'กำลังบันทึกรูป…' : 'Saving photo…')
                          : title,
                      style: TextStyle(
                        color: RoundsColors.ink,
                        fontSize: thai
                            ? DriverG03Metrics.thaiPhotoActionSize
                            : DriverG03Metrics.englishPhotoActionSize,
                        height: thai
                            ? DriverG03Metrics.thaiPhotoActionHeight
                            : 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(
                      height: thai
                          ? DriverG03Metrics.thaiPhotoInnerGap
                          : DriverG03Metrics.englishPhotoInnerGap,
                    ),
                    Text(
                      copy.tapToCapture,
                      style: TextStyle(
                        color: RoundsColors.muted,
                        fontSize: thai
                            ? DriverG03Metrics.thaiPhotoHelpSize
                            : DriverG03Metrics.englishPhotoHelpSize,
                        height: thai ? DriverG03Metrics.thaiPhotoHelpHeight : 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(photo!, fit: BoxFit.cover),
                    Positioned(
                      left: DriverG03Metrics.photoBadgeLeft,
                      bottom: DriverG03Metrics.photoBadgeBottom,
                      child: Container(
                        height: DriverG03Metrics.photoBadgeHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: RoundsColors.surface,
                          border: Border.all(color: const Color(0xffc7ded0)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: RoundsColors.green,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              copy.photoAdded,
                              style: const TextStyle(
                                color: RoundsColors.green,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({
    required this.copy,
    required this.stop,
    required this.problem,
  });

  final AppStrings copy;
  final DriverRoundStopModel stop;
  final String problem;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    final item = stop.manifestItems.firstOrNull;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiReportMarginTop
            : DriverG03Metrics.englishReportMarginTop,
      ),
      child: Container(
        key: const Key('package-problem-summary'),
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: RoundsColors.line),
          ),
        ),
        child: Column(
          children: [
            _ReportRow(
              copy: copy,
              label: thai ? 'ปัญหา' : 'Problem',
              value: problem,
            ),
            const Divider(height: 1, color: RoundsColors.line),
            _ReportRow(
              copy: copy,
              label: thai ? 'ของ' : 'Package',
              value:
                  '${item?.description ?? stop.deliveryReference} ×${item?.quantity ?? 1}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.copy,
    required this.label,
    required this.value,
  });

  final AppStrings copy;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    return SizedBox(
      height: thai
          ? DriverG03Metrics.thaiReportRowHeight
          : DriverG03Metrics.englishReportRowHeight,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: thai
                  ? DriverG03Metrics.thaiReportLabelSize
                  : DriverG03Metrics.englishReportLabelSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: thai
                    ? DriverG03Metrics.thaiReportValueSize
                    : DriverG03Metrics.englishReportValueSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCopy extends StatelessWidget {
  const _WaitingCopy({
    required this.copy,
    required this.pendingSync,
    required this.category,
  });

  final AppStrings copy;
  final bool pendingSync;
  final DeliveryPackageProblemCategory category;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    final body = pendingSync
        ? copy.savedLocally
        : category.requiresPhoto
        ? copy.operationsHasIssue
        : copy.operationsHasIssueNoPhoto;
    return Padding(
      padding: EdgeInsets.only(
        top: thai
            ? DriverG03Metrics.thaiWaitingGap
            : DriverG03Metrics.englishWaitingGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            thai ? copy.operationsReview : copy.operationsReview.toUpperCase(),
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: thai
                  ? DriverG03Metrics.thaiWaitingEyebrowSize
                  : DriverG03Metrics.englishWaitingEyebrowSize,
              height: thai ? DriverG03Metrics.thaiWaitingEyebrowHeight : 1,
              fontWeight: FontWeight.w800,
              letterSpacing: thai
                  ? 0
                  : DriverG03Metrics.englishWaitingEyebrowTracking,
            ),
          ),
          SizedBox(
            height: thai
                ? DriverG03Metrics.thaiWaitingTitleGap
                : DriverG03Metrics.englishWaitingTitleGap,
          ),
          Text(
            copy.keepPackage,
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: thai
                  ? DriverG03Metrics.thaiWaitingTitleSize
                  : DriverG03Metrics.englishWaitingTitleSize,
              height: thai
                  ? DriverG03Metrics.thaiWaitingTitleHeight
                  : DriverG03Metrics.englishWaitingTitleHeight,
              fontWeight: FontWeight.w900,
              letterSpacing: thai
                  ? 0
                  : DriverG03Metrics.englishWaitingTitleTracking,
            ),
          ),
          SizedBox(
            height: thai
                ? DriverG03Metrics.thaiWaitingBodyGap
                : DriverG03Metrics.englishWaitingBodyGap,
          ),
          Text(
            body,
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: thai
                  ? DriverG03Metrics.thaiWaitingBodySize
                  : DriverG03Metrics.englishWaitingBodySize,
              height: thai
                  ? DriverG03Metrics.thaiWaitingBodyHeight
                  : DriverG03Metrics.englishWaitingBodyHeight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProblemFooterMode { initial, evidence, waiting }

class _ProblemFooter extends StatelessWidget {
  const _ProblemFooter({
    required this.copy,
    required this.mode,
    this.pendingSync = false,
    this.submitting = false,
    this.needsPhoto = false,
    this.category,
    this.onPrimary,
    this.onSecondary,
  });

  final AppStrings copy;
  final _ProblemFooterMode mode;
  final bool pendingSync;
  final bool submitting;
  final bool needsPhoto;
  final DeliveryPackageProblemCategory? category;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final thai = copy.isThai;
    final initial = mode == _ProblemFooterMode.initial;
    return Container(
      key: const Key('package-problem-footer'),
      padding: EdgeInsets.fromLTRB(
        DriverG03Metrics.footerPaddingHorizontal,
        thai && initial
            ? DriverG03Metrics.thaiInitialFooterPaddingTop
            : DriverG03Metrics.englishFooterPaddingTop,
        DriverG03Metrics.footerPaddingHorizontal,
        thai && initial
            ? DriverG03Metrics.thaiInitialFooterPaddingBottom
            : DriverG03Metrics.englishFooterPaddingBottom,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: initial
          ? SizedBox(
              height: thai
                  ? DriverG03Metrics.thaiInitialSecondaryHeight
                  : DriverG03Metrics.englishSecondaryHeight,
              child: OutlinedButton(
                key: const Key('message-operations'),
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  side: thai
                      ? const BorderSide(color: RoundsColors.lineStrong)
                      : BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverG03Metrics.primaryRadius,
                    ),
                  ),
                ),
                child: Text(
                  copy.messageOperations,
                  style: TextStyle(
                    fontSize: thai
                        ? DriverG03Metrics.thaiSecondarySize
                        : DriverG03Metrics.englishSecondarySize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : mode == _ProblemFooterMode.waiting
          ? SizedBox(
              height: DriverG03Metrics.primaryHeight,
              child: FilledButton(
                key: const Key('waiting-for-operations'),
                onPressed: null,
                child: Text(
                  pendingSync ? copy.waitingToSync : copy.waitingForOperations,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: DriverG03Metrics.primaryHeight,
                  child: FilledButton(
                    key: const Key('submit-package-problem'),
                    onPressed: submitting || needsPhoto ? null : onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DriverG03Metrics.primaryRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      submitting
                          ? (thai ? 'กำลังส่ง…' : 'Sending…')
                          : needsPhoto
                          ? (category == DeliveryPackageProblemCategory.damaged
                                ? copy.addDamagePhoto
                                : copy.addPackagePhoto)
                          : copy.sendToOperations,
                      style: TextStyle(
                        fontSize: thai
                            ? DriverG03Metrics.thaiPrimarySize
                            : DriverG03Metrics.englishPrimarySize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DriverG03Metrics.secondaryGap),
                SizedBox(
                  width: double.infinity,
                  height: DriverG03Metrics.englishSecondaryHeight,
                  child: TextButton(
                    key: const Key('change-package-problem'),
                    onPressed: submitting ? null : onSecondary,
                    child: Text(copy.changeProblem),
                  ),
                ),
              ],
            ),
    );
  }
}

String _handlingNote(AppStrings copy, DriverRoundStopModel stop) {
  final note = stop.manifestItems.firstOrNull?.handlingNote;
  if (note == null || note.trim().isEmpty) {
    return copy.isThai ? 'ระวังแตก' : 'Fragile';
  }
  if (copy.isThai && note.toLowerCase().contains('fragile')) return 'ระวังแตก';
  return copy.pickupHandlingNote(note);
}
