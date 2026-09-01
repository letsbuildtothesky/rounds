import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:uuid/uuid.dart';

import '../storage/harness_database.dart';
import '../storage/harness_event_log.dart';
import '../storage/sqlite_navigation_intent_store.dart';
import '../telemetry/operational_location_recorder.dart';
import 'navigation_intent.dart';

class GoogleNavigationSurface extends StatefulWidget {
  const GoogleNavigationSurface({
    required this.onOperationalSample,
    required this.onStatus,
    required this.onArrival,
    super.key,
  });

  final void Function(DateTime capturedAt) onOperationalSample;
  final void Function(String status) onStatus;
  final VoidCallback onArrival;

  @override
  State<GoogleNavigationSurface> createState() =>
      _GoogleNavigationSurfaceState();
}

class _GoogleNavigationSurfaceState extends State<GoogleNavigationSurface>
    with WidgetsBindingObserver {
  static const _destination = LatLng(latitude: 13.7367, longitude: 100.5612);

  late final OperationalLocationRecorder _recorder;
  StreamSubscription<RoadSnappedLocationUpdatedEvent>? _roadLocation;
  StreamSubscription<void>? _rerouting;
  StreamSubscription<OnArrivalEvent>? _arrival;
  GoogleNavigationViewController? _viewController;
  HarnessDatabase? _database;
  HarnessEventLog? _events;
  NavigationIntent? _intent;
  bool _sessionReady = false;
  bool _routeRequested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = OperationalLocationRecorder(
      onSample: widget.onOperationalSample,
      onError: (error) => _setStatus('Telemetry error: $error'),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final database = await HarnessDatabase.open();
      _database = database;
      _events = HarnessEventLog(database);
      await _events?.record(
        'navigation_surface_opened',
        payload: {'stop_id': 'STOP-001', 'destination_version': 1},
      );

      widget.onStatus('Requesting precise location…');
      await _recorder.start();

      var accepted = await GoogleMapsNavigator.areTermsAccepted();
      if (!accepted) {
        accepted = await GoogleMapsNavigator.showTermsAndConditionsDialog(
          'Rounds navigation',
          'Rounds',
        );
      }
      if (!accepted) {
        throw StateError('Navigation terms were not accepted.');
      }

      await GoogleMapsNavigator.initializeNavigationSession(
        taskRemovedBehavior: TaskRemovedBehavior.continueService,
        notificationOptions: const NavigationNotificationOptions(
          notificationId: 7100,
          defaultMessage: 'Rounds navigation is active',
          resumeAppOnTap: true,
        ),
      );

      _rerouting = GoogleMapsNavigator.setOnReroutingListener(() {
        unawaited(
          _events?.record(
            'navigation_rerouted',
            payload: {'nav_session_id': _intent?.navSessionId},
          ),
        );
      });
      _arrival = GoogleMapsNavigator.setOnArrivalListener((event) {
        unawaited(
          _events?.record(
            'navigation_arrival_callback',
            payload: {
              'nav_session_id': _intent?.navSessionId,
              'waypoint': event.waypoint.title,
            },
          ),
        );
        widget.onArrival();
      });

      final guidanceRunning = await GoogleMapsNavigator.isGuidanceRunning();
      if (guidanceRunning) {
        _routeRequested = true;
        await _attachIntent();
        await _events?.record(
          'navigation_resumed',
          payload: {'nav_session_id': _intent?.navSessionId},
        );
      }

      _roadLocation =
          await GoogleMapsNavigator.setRoadSnappedLocationUpdatedListener((_) {
            if (!_routeRequested && _viewController != null) {
              unawaited(_setDestinationAndStart());
            }
          });

      if (!mounted) return;
      setState(() => _sessionReady = true);
      widget.onStatus(
        guidanceRunning
            ? 'TWO_WHEELER guidance resumed'
            : 'Waiting for a navigation location fix…',
      );
    } catch (error) {
      await _events?.record(
        'navigation_plugin_error',
        payload: {'error': error.toString()},
      );
      _setStatus('Navigation unavailable: $error', isError: true);
    }
  }

  Future<void> _onViewCreated(GoogleNavigationViewController controller) async {
    _viewController = controller;
    await controller.setMyLocationEnabled(true);
  }

  Future<void> _setDestinationAndStart() async {
    if (_routeRequested) return;
    _routeRequested = true;
    widget.onStatus('Calculating TWO_WHEELER route…');
    try {
      final attachment = await _attachIntent();
      await _events?.record(
        'destination_intent_requested',
        payload: {
          'stop_id': attachment.intent.stopId,
          'destination_version': attachment.intent.destinationVersion,
          'destination_fingerprint': attachment.intent.destinationFingerprint,
          'nav_session_id': attachment.intent.navSessionId,
          'request_kind': attachment.isNew ? 'new' : 'reattached',
        },
      );
      final status = await GoogleMapsNavigator.setDestinations(
        Destinations(
          waypoints: [
            NavigationWaypoint.withLatLngTarget(
              title: 'STOP-001 · Interchange 21',
              target: _destination,
            ),
          ],
          displayOptions: NavigationDisplayOptions(
            showDestinationMarkers: true,
          ),
          routingOptions: RoutingOptions(
            travelMode: NavigationTravelMode.twoWheeler,
          ),
        ),
      );
      if (status != NavigationRouteStatus.statusOk) {
        throw StateError('route status: ${status.name}');
      }
      await GoogleMapsNavigator.startGuidance();
      await _events?.record(
        'navigation_started',
        payload: {
          'nav_session_id': attachment.intent.navSessionId,
          'travel_mode': 'TWO_WHEELER',
        },
      );
      widget.onStatus('TWO_WHEELER guidance active');
    } catch (error) {
      await _events?.record(
        'route_request_error',
        payload: {
          'nav_session_id': _intent?.navSessionId,
          'error': error.toString(),
        },
      );
      _routeRequested = false;
      _setStatus('Route unavailable: $error', isError: true);
    }
  }

  Future<({NavigationIntent intent, bool isNew})> _attachIntent() async {
    final existing = _intent;
    if (existing != null) return (intent: existing, isNew: false);
    final database = _database;
    if (database == null) {
      throw StateError('Navigation event database is not ready.');
    }
    final attachment =
        await NavigationIntentLedger(
          SqliteNavigationIntentStore(database),
        ).attachOrCreate(
          stopId: 'STOP-001',
          destinationVersion: 1,
          destinationFingerprint:
              '${_destination.latitude},${_destination.longitude}',
          createSessionId: const Uuid().v4,
          now: DateTime.now().toUtc(),
        );
    _intent = attachment.intent;
    return attachment;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final eventType = switch (state) {
      AppLifecycleState.resumed => 'app_foregrounded',
      AppLifecycleState.inactive => 'app_inactive',
      AppLifecycleState.hidden => 'app_hidden',
      AppLifecycleState.paused => 'app_backgrounded',
      AppLifecycleState.detached => 'app_detached',
    };
    unawaited(
      _events?.record(
        eventType,
        payload: {'nav_session_id': _intent?.navSessionId},
      ),
    );
  }

  void _setStatus(String status, {bool isError = false}) {
    widget.onStatus(status);
    if (!mounted) return;
    setState(() => _error = isError ? status : null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    await _events?.record(
      'navigation_surface_closed',
      payload: {'nav_session_id': _intent?.navSessionId},
    );
    await _roadLocation?.cancel();
    await _rerouting?.cancel();
    await _arrival?.cancel();
    await _recorder.stop();
    if (_sessionReady) {
      // Keep active guidance alive in Android's foreground service. A later
      // screen can reinitialize and inspect the running guidance session.
      await GoogleMapsNavigator.cleanup(resetSession: false);
    }
    await _database?.database.close();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return ColoredBox(
        color: const Color(0xFFD7DDD7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!_sessionReady) {
      return const ColoredBox(
        color: Color(0xFFD7DDD7),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GoogleMapsNavigationView(
      onViewCreated: _onViewCreated,
      initialNavigationUIEnabledPreference:
          NavigationUIEnabledPreference.automatic,
      initialCameraPosition: const CameraPosition(
        target: _destination,
        zoom: 15,
      ),
    );
  }
}
