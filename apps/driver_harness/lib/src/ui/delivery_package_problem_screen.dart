import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/driver_design_system.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import '../storage/delivery_problem_photo_store.dart';

typedef DamagePhotoCapture = Future<XFile?> Function();

class DeliveryPackageProblemScreen extends StatefulWidget {
  const DeliveryPackageProblemScreen({
    required this.controller,
    required this.stop,
    this.initialNote = '',
    this.photoStore,
    this.capturePhoto,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundStopModel stop;
  final String initialNote;
  final DeliveryProblemPhotoStore? photoStore;
  final DamagePhotoCapture? capturePhoto;

  @override
  State<DeliveryPackageProblemScreen> createState() =>
      _DeliveryPackageProblemScreenState();
}

class _DeliveryPackageProblemScreenState
    extends State<DeliveryPackageProblemScreen> {
  final _note = TextEditingController();
  DeliveryProblemPhotoStore? _photoStore;
  File? _photo;
  bool _restoring = true;
  bool _capturing = false;
  bool _submitting = false;
  bool _pendingSync = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restorePhoto();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.canvas,
    appBar: AppBar(
      backgroundColor: RoundsColors.canvas,
      title: const Text('Package problem'),
    ),
    body: SafeArea(
      child: _submitted
          ? _DamageReportWaiting(stop: widget.stop)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  widget.stop.deliveryReference,
                  style: const TextStyle(
                    color: RoundsColors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Damaged package',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Take one clear photo. The package stays with you and Operations receives a live action item after the evidence is verified.',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RoundsColors.surface,
                    borderRadius: BorderRadius.circular(RoundsRadii.surface),
                    border: Border.all(color: RoundsColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Damage evidence · required',
                        style: TextStyle(
                          color: RoundsColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Saved on this phone first. Upload can resume after a restart or lost connection.',
                        style: TextStyle(
                          color: RoundsColors.muted,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_restoring)
                        const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_photo != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            RoundsRadii.surface,
                          ),
                          child: Image.file(
                            _photo!,
                            height: 260,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: RoundsColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          key: const Key('capture-damage-photo'),
                          onPressed:
                              _restoring ||
                                  _capturing ||
                                  _submitting ||
                                  _pendingSync
                              ? null
                              : _capture,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _capturing
                                ? 'Saving photo…'
                                : _photo == null
                                ? 'Take damage photo'
                                : 'Retake photo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('damage-note'),
                  controller: _note,
                  enabled: !_pendingSync,
                  maxLength: 500,
                  maxLines: 3,
                  onChanged: (value) =>
                      _photoStore?.saveNote(widget.stop.id, value),
                  decoration: InputDecoration(
                    labelText: 'What is damaged? (optional)',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: RoundsColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RoundsRadii.surface),
                    ),
                  ),
                ),
                if (_pendingSync)
                  const Card(
                    color: Color(0xFFFFE2A8),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Photo and report are safe on this phone. Keep the package; the Stop is not marked complete. Retry when connected.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    key: const Key('submit-damage-report'),
                    onPressed:
                        _restoring ||
                            _capturing ||
                            _submitting ||
                            _photo == null
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.red,
                      disabledBackgroundColor: const Color(0xFFD9DFE5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RoundsRadii.surface,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: Text(
                      _submitting
                          ? 'Verifying and sending…'
                          : _pendingSync
                          ? 'Retry report sync'
                          : 'Send to Operations',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Do not hand over the damaged package. Wait for Operations instructions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    ),
  );

  Future<void> _restorePhoto() async {
    try {
      final store =
          widget.photoStore ?? await DeliveryProblemPhotoStore.create();
      final restored = await store.restore(widget.stop.id);
      final restoredNote = store.restoreNote(widget.stop.id);
      final note = restoredNote.isNotEmpty ? restoredNote : widget.initialNote;
      if (restoredNote.isEmpty && note.isNotEmpty) {
        await store.saveNote(widget.stop.id, note);
      }
      if (!mounted) return;
      _note.text = note;
      setState(() {
        _photoStore = store;
        _photo = restored;
        _restoring = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = 'The saved damage photo could not be checked.';
      });
    }
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
            ? 'Camera access is required for damage evidence.'
            : 'The damage photo could not be saved. Try again.';
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await widget.controller.reportDeliveryDamage(
      stop: widget.stop,
      capturedPhotoPath: _photo!.path,
      note: _note.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _pendingSync = outcome?.pendingSync ?? false;
      _error = outcome == null
          ? widget.controller.driverError ?? 'Report could not be sent'
          : null;
    });
    if (outcome?.committed ?? false) {
      await _photoStore?.clear(widget.stop.id);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _pendingSync = false;
        _photo = null;
      });
    }
  }
}

class _DamageReportWaiting extends StatelessWidget {
  const _DamageReportWaiting({required this.stop});

  final DriverRoundStopModel stop;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('damage-report-waiting'),
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
    children: [
      const Row(
        children: [
          Icon(Icons.circle, size: 10, color: RoundsColors.orange),
          SizedBox(width: 9),
          Text(
            'SENT TO OPERATIONS',
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Keep the package with you',
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: 34,
          height: 1.04,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Operations has the damaged-package report and verified photo evidence. Do not hand over or complete this Stop.',
        style: TextStyle(
          color: RoundsColors.muted,
          fontSize: 16,
          height: 1.42,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RoundsColors.surface,
          borderRadius: BorderRadius.circular(RoundsRadii.surface),
          border: Border.all(color: RoundsColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Package in custody',
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stop.manifestItems.firstOrNull?.description ??
                  stop.deliveryReference,
              style: const TextStyle(
                color: RoundsColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Damage reported · photo attached',
              style: TextStyle(
                color: RoundsColors.red,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Operations review',
        style: TextStyle(
          color: RoundsColors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Waiting for a decision',
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 60,
        child: FilledButton(
          key: const Key('waiting-for-operations'),
          onPressed: null,
          child: const Text('Waiting for Operations'),
        ),
      ),
    ],
  );
}
