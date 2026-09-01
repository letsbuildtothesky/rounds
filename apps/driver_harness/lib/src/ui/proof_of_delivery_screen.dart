import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({
    required this.controller,
    required this.stop,
    super.key,
  });
  final HarnessAppController controller;
  final DriverRoundStopModel stop;

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _receiver = TextEditingController();
  final _relationship = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  String _handoffType = 'recipient';
  XFile? _photo;
  bool _submitting = false;
  bool _pendingSync = false;

  @override
  void initState() {
    super.initState();
    _receiver.text = widget.stop.recipientName;
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
            'Who received it?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm the same locked manifest, then add the required delivery photo.',
          ),
          const SizedBox(height: 16),
          ...[
            (
              'recipient',
              'Recipient',
              'Handed directly to the named recipient',
            ),
            (
              'someone_else',
              'Someone else',
              'Reception, security, family or staff',
            ),
            (
              'left_at_location',
              'Left at location',
              'An approved lobby, desk, door or other place',
            ),
          ].map(
            (choice) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _handoffType == choice.$1
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF17453B),
              ),
              title: Text(
                choice.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(choice.$3),
              onTap: _pendingSync
                  ? null
                  : () => setState(() {
                      _handoffType = choice.$1;
                      if (choice.$1 == 'recipient') {
                        _receiver.text = widget.stop.recipientName;
                      }
                    }),
            ),
          ),
          if (_handoffType != 'left_at_location')
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
            TextField(
              controller: _location,
              enabled: !_pendingSync,
              decoration: const InputDecoration(labelText: 'Approved location'),
              onChanged: (_) => setState(() {}),
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
          const SizedBox(height: 10),
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
            onPressed: _submitting || _pendingSync ? null : _capturePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _photo == null ? 'Take delivery photo' : 'Retake photo',
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
            onPressed: _submitting || _photo == null || !_handoffValid
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

  Future<void> _capturePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (!mounted || photo == null) return;
    setState(() => _photo = photo);
  }

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
