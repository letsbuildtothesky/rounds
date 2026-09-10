import 'package:image_picker/image_picker.dart';

/// Same native camera/options used by the existing proof screen. No gallery,
/// automatic lost-data adoption, plaintext export or metadata collection.
Future<XFile?> openDeliveryEvidenceCamera() => ImagePicker().pickImage(
  source: ImageSource.camera,
  maxWidth: 1600,
  imageQuality: 75,
  requestFullMetadata: false,
);
