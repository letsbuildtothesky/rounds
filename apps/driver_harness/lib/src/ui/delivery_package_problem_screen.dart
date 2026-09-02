import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/driver_design_system.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../storage/delivery_problem_photo_store.dart';

typedef DamagePhotoCapture = Future<XFile?> Function();

class DeliveryPackageProblemScreen extends StatefulWidget {
  const DeliveryPackageProblemScreen({
    required this.controller,
    required this.stop,
    this.photoStore,
    this.capturePhoto,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundStopModel stop;
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
      child: ListView(
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
                    borderRadius: BorderRadius.circular(RoundsRadii.surface),
                    child: Image.file(_photo!, height: 260, fit: BoxFit.cover),
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
                        _restoring || _capturing || _submitting || _pendingSync
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
                  _restoring || _capturing || _submitting || _photo == null
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: RoundsColors.red,
                disabledBackgroundColor: const Color(0xFFD9DFE5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RoundsRadii.surface),
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
      if (!mounted) return;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'The damage photo could not be saved. Try again.';
      });
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
      Navigator.of(context).pop(true);
    }
  }
}
