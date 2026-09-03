import 'package:geolocator/geolocator.dart';

enum DriverLocationAccessState {
  serviceDisabled,
  denied,
  deniedForever,
  whileInUse,
  always,
}

class DriverLocationAccessSnapshot {
  const DriverLocationAccessSnapshot(this.state);

  final DriverLocationAccessState state;

  bool get ready =>
      state == DriverLocationAccessState.whileInUse ||
      state == DriverLocationAccessState.always;
}

class DriverLocationAccessException implements Exception {
  const DriverLocationAccessException(this.state);

  final DriverLocationAccessState state;

  @override
  String toString() => switch (state) {
    DriverLocationAccessState.serviceDisabled =>
      'Location services are disabled.',
    DriverLocationAccessState.denied =>
      'Location access was not granted. You can try again.',
    DriverLocationAccessState.deniedForever =>
      'Location access is blocked in device settings.',
    DriverLocationAccessState.whileInUse ||
    DriverLocationAccessState.always => 'Location access is ready.',
  };
}

abstract interface class DriverLocationAccessGateway {
  Future<DriverLocationAccessSnapshot> inspect();

  Future<DriverLocationAccessSnapshot> request();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorLocationAccessGateway implements DriverLocationAccessGateway {
  const GeolocatorLocationAccessGateway();

  @override
  Future<DriverLocationAccessSnapshot> inspect() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const DriverLocationAccessSnapshot(
        DriverLocationAccessState.serviceDisabled,
      );
    }
    return DriverLocationAccessSnapshot(
      _mapPermission(await Geolocator.checkPermission()),
    );
  }

  @override
  Future<DriverLocationAccessSnapshot> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const DriverLocationAccessSnapshot(
        DriverLocationAccessState.serviceDisabled,
      );
    }
    return DriverLocationAccessSnapshot(
      _mapPermission(await Geolocator.requestPermission()),
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  DriverLocationAccessState _mapPermission(
    LocationPermission permission,
  ) => switch (permission) {
    LocationPermission.denied => DriverLocationAccessState.denied,
    LocationPermission.deniedForever => DriverLocationAccessState.deniedForever,
    LocationPermission.whileInUse => DriverLocationAccessState.whileInUse,
    LocationPermission.always => DriverLocationAccessState.always,
    LocationPermission.unableToDetermine => DriverLocationAccessState.denied,
  };
}

Future<void> requireOperationalLocationAccess({
  DriverLocationAccessGateway gateway = const GeolocatorLocationAccessGateway(),
}) async {
  var snapshot = await gateway.inspect();
  if (snapshot.state == DriverLocationAccessState.denied) {
    snapshot = await gateway.request();
  }
  if (!snapshot.ready) {
    throw DriverLocationAccessException(snapshot.state);
  }
}
