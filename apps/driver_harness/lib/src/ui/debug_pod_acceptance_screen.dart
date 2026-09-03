import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/driver_design_system.dart';
import '../permissions/driver_permissions_screen.dart';
import '../debug/debug_acceptance_photo_store.dart';
import '../driver/driver_session.dart';

typedef DebugPhotoCapture = Future<XFile?> Function();

class DebugPodAcceptanceScreen extends StatefulWidget {
  const DebugPodAcceptanceScreen({
    required this.stop,
    this.store,
    this.capturePhoto,
    super.key,
  });

  final DriverRoundStopModel stop;
  final DebugAcceptancePhotoStore? store;
  final DebugPhotoCapture? capturePhoto;

  @override
  State<DebugPodAcceptanceScreen> createState() =>
      _DebugPodAcceptanceScreenState();
}

class _DebugPodAcceptanceScreenState extends State<DebugPodAcceptanceScreen> {
  DebugAcceptancePhotoStore? _store;
  DebugAcceptancePhoto? _photo;
  bool _loading = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode, 'Debug acceptance UI must never run in release mode.');
    _restore();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.canvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: RoundsColors.ink,
      title: const Text('Camera + restart test'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            key: const Key('debug-acceptance-warning'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D8),
              border: Border.all(color: const Color(0xFFF0A33A)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVELOPMENT ACCEPTANCE · NOT A DELIVERY',
                  style: TextStyle(
                    color: Color(0xFF9A4B00),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This test never confirms arrival, uploads evidence, or changes the round on the server.',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.stop.deliveryReference,
            style: const TextStyle(
              color: RoundsColors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Real camera check',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: RoundsColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take one photo, close the app completely, then reopen this screen. The same photo must still be here.',
            style: TextStyle(color: RoundsColors.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(
              height: 250,
              child: Center(
                child: Text(
                  'Checking retained photo…',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else if (_photo == null)
            Container(
              key: const Key('debug-acceptance-empty'),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: RoundsColors.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 54,
                    color: RoundsColors.muted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No acceptance photo saved',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ClipRRect(
              key: const Key('debug-acceptance-photo'),
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(_photo!.path),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('debug-acceptance-retained'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F7EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: RoundsColors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Restart-ready · photo retained on this phone',
                      style: TextStyle(
                        color: RoundsColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('debug-acceptance-error'),
              style: const TextStyle(
                color: RoundsColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('debug-capture-photo'),
            onPressed: _loading || _capturing ? null : _capture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _capturing
                  ? 'Saving photo…'
                  : _photo == null
                  ? 'Take acceptance photo'
                  : 'Retake acceptance photo',
            ),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              key: const Key('debug-clear-photo'),
              onPressed: _capturing ? null : _clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear local test photo'),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _restore() async {
    try {
      final store = widget.store ?? await DebugAcceptancePhotoStore.create();
      final photo = await store.restore();
      if (!mounted) return;
      setState(() {
        _store = store;
        _photo = photo;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The saved acceptance photo could not be checked.';
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
      if (captured == null || !mounted) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final retained = await _store!.retain(captured.path);
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
            ? 'Camera access is required for this test photo.'
            : 'The camera photo could not be retained. Please try again.';
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

  Future<void> _clear() async {
    await _store!.clear();
    if (!mounted) return;
    setState(() {
      _photo = null;
      _error = null;
    });
  }
}
