import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/harness_app_controller.dart';
import '../driver/driver_handoff_selection.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import '../storage/pod_draft_photo_store.dart';

typedef DeliveryPhotoCapture = Future<XFile?> Function();

class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({
    required this.controller,
    required this.stop,
    this.handoff = const DriverHandoffSelection.recipient(),
    this.photoStore,
    this.capturePhoto,
    super.key,
  });
  final HarnessAppController controller;
  final DriverRoundStopModel stop;
  final DriverHandoffSelection handoff;
  final PodDraftPhotoStore? photoStore;
  final DeliveryPhotoCapture? capturePhoto;

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _receiver = TextEditingController();
  final _relationship = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  late final String _handoffType;
  PodDraftPhotoStore? _photoStore;
  XFile? _photo;
  bool _restoringPhoto = true;
  bool _capturingPhoto = false;
  bool _submitting = false;
  bool _pendingSync = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    _handoffType = widget.handoff.handoffType;
    _receiver.text = widget.stop.recipientName;
    _location.text = widget.handoff.leftAtLocation ?? '';
    _restorePhoto();
  }

  @override
  void dispose() {
    _receiver.dispose();
    _relationship.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _handoffValid => switch (_handoffType) {
    'recipient' => _receiver.text.trim().isNotEmpty,
    'someone_else' =>
      _receiver.text.trim().isNotEmpty && _relationship.text.trim().isNotEmpty,
    'left_at_location' => _location.text.trim().isNotEmpty,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete delivery')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.stop.deliveryReference,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            'Proof of delivery',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(_handoffSummary),
          const SizedBox(height: 16),
          if (_handoffType == 'recipient')
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Receiver'),
              child: Text(
                widget.stop.recipientName,
                key: const Key('pod-named-recipient'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (_handoffType == 'someone_else')
            TextField(
              controller: _receiver,
              enabled: !_pendingSync,
              decoration: const InputDecoration(labelText: 'Receiver name'),
              onChanged: (_) => setState(() {}),
            ),
          if (_handoffType == 'someone_else')
            TextField(
              controller: _relationship,
              enabled: !_pendingSync,
              decoration: const InputDecoration(
                labelText: 'Relationship or role',
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (_handoffType == 'left_at_location')
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Approved location'),
              child: Text(
                _location.text,
                key: const Key('pod-approved-location'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Locked manifest · v${widget.stop.manifestVersion}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...widget.stop.manifestItems.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Color(0xFF17453B)),
              title: Text('${item.quantity}× ${item.description}'),
              subtitle: item.handlingNote == null
                  ? null
                  : Text(item.handlingNote!),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Delivery photo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Text(
            'Required. The photo is saved on this phone first and uploaded resumably.',
          ),
          if (_photoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _photoError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 10),
          if (_restoringPhoto)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_photo!.path),
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('capture-delivery-photo'),
            onPressed:
                _submitting ||
                    _pendingSync ||
                    _restoringPhoto ||
                    _capturingPhoto
                ? null
                : _capturePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _restoringPhoto
                  ? 'Checking saved photo…'
                  : _capturingPhoto
                  ? 'Saving photo…'
                  : _photo == null
                  ? 'Take delivery photo'
                  : 'Retake photo',
            ),
          ),
          TextField(
            controller: _note,
            enabled: !_pendingSync,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Delivery note (optional)',
            ),
          ),
          if (_pendingSync)
            const Card(
              color: Color(0xFFFFE2A8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Evidence is safe on this phone and pending sync. This delivery is not marked Delivered yet.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('complete-delivery'),
            onPressed:
                _submitting ||
                    _restoringPhoto ||
                    _capturingPhoto ||
                    _photo == null ||
                    !_handoffValid
                ? null
                : _complete,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              _submitting
                  ? 'Verifying evidence…'
                  : _pendingSync
                  ? 'Retry evidence sync'
                  : 'Complete delivery',
            ),
          ),
        ],
      ),
    ),
  );

  String get _handoffSummary => switch (_handoffType) {
    'recipient' => 'Handed directly to ${widget.stop.recipientName}',
    'someone_else' => 'Received by someone else',
    'left_at_location' => 'Left at ${_location.text}',
    _ => 'Delivery handoff',
  };

  Future<void> _restorePhoto() async {
    try {
      final store = widget.photoStore ?? await PodDraftPhotoStore.create();
      final restored = await store.restore(widget.stop.id);
      if (!mounted) return;
      setState(() {
        _photoStore = store;
        _photo = restored == null ? null : XFile(restored.path);
        _restoringPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoringPhoto = false;
        _photoError = 'The saved delivery photo could not be checked.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _capturingPhoto = true;
      _photoError = null;
    });
    try {
      final photo = await (widget.capturePhoto ?? _openCamera)();
      if (photo == null || !mounted) {
        if (mounted) setState(() => _capturingPhoto = false);
        return;
      }
      final retained = await _photoStore!.retain(widget.stop.id, photo.path);
      if (!mounted) return;
      setState(() {
        _photo = XFile(retained.path);
        _capturingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturingPhoto = false;
        _photoError = isCameraPermissionError(error)
            ? 'Camera access is required for delivery evidence.'
            : 'The delivery photo could not be retained. Try again.';
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
    setState(() => _submitting = true);
    final outcome = await widget.controller.completePod(
      stop: widget.stop,
      capturedPhotoPath: _photo!.path,
      handoffType: _handoffType,
      receiverName: _handoffType == 'left_at_location'
          ? null
          : _receiver.text.trim(),
      receiverRelationship: _handoffType == 'someone_else'
          ? _relationship.text.trim()
          : null,
      leftAtLocation: _handoffType == 'left_at_location'
          ? _location.text.trim()
          : null,
      note: _note.text.trim(),
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
            widget.controller.driverError ?? 'Delivery could not be completed',
          ),
        ),
      );
    }
  }
}
