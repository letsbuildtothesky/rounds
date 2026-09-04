import 'package:geolocator/geolocator.dart';

import '../permissions/location_access.dart';
import 'driver_operations_thread.dart';

abstract interface class DriverChatLocationGateway {
  Future<DriverMessageAttachmentModel> captureCurrentLocation();
}

class GeolocatorDriverChatLocationGateway implements DriverChatLocationGateway {
  const GeolocatorDriverChatLocationGateway();

  @override
  Future<DriverMessageAttachmentModel> captureCurrentLocation() async {
    await requireOperationalLocationAccess();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return DriverMessageAttachmentModel.location(
      label: 'Current location',
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }
}
