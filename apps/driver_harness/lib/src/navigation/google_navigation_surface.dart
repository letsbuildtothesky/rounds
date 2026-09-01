import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app/app_strings.dart';
import '../storage/harness_database.dart';
import '../storage/harness_event_log.dart';
import '../storage/sqlite_navigation_intent_store.dart';
import '../telemetry/operational_location_recorder.dart';
import '../telemetry/telemetry_uploader.dart';
import 'navigation_intent.dart';
import 'route_attempt_gate.dart';

class GoogleNavigationSurface extends StatefulWidget {
  const GoogleNavigationSurface({
    required this.strings,
    required this.onOperationalSample,
    required this.onStatus,
    required this.onArrival,
    super.key,
  });

  final AppStrings strings;
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
  late final TelemetryUploader _uploader;
  StreamSubscription<RoadSnappedLocationUpdatedEvent>? _roadLocation;
  StreamSubscription<void>? _rerouting;
  StreamSubscription<OnArrivalEvent>? _arrival;
  GoogleNavigationViewController? _viewController;
  HarnessDatabase? _database;
  HarnessEventLog? _events;
  NavigationIntent? _intent;
  final RouteAttemptGate _attemptGate = RouteAttemptGate();
  bool _sessionReady = false;
  bool _guidanceActive = false;
  String? _error;
  String? _diagnosticResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = OperationalLocationRecorder(
      onSample: widget.onOperationalSample,
      onError: (error) => _setStatus('Telemetry error: $error'),
    );
    _uploader = TelemetryUploader(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
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
      await _uploader.start();

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
        _guidanceActive = true;
        _attemptGate.restoreActiveNavigation();
        await _attachIntent();
        await _events?.record(
          'navigation_resumed',
          payload: {'nav_session_id': _intent?.navSessionId},
        );
      }

      _roadLocation =
          await GoogleMapsNavigator.setRoadSnappedLocationUpdatedListener((_) {
            if (!_guidanceActive && _viewController != null) {
              unawaited(
                _attemptRoute(
                  NavigationTravelMode.twoWheeler,
                  RouteAttemptTrigger.automatic,
                ),
              );
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

  Future<void> _attemptRoute(
    NavigationTravelMode travelMode,
    RouteAttemptTrigger trigger,
  ) async {
    if (_guidanceActive) return;
    final claim = trigger == RouteAttemptTrigger.automatic
        ? _attemptGate.claimAutomatic()
        : _attemptGate.claimManual(trigger);
    if (claim == null) return;

    final modeName = _modeName(travelMode);
    if (mounted) {
      setState(() {
        _error = null;
        _diagnosticResult = null;
      });
    }
    widget.onStatus('Calculating $modeName route…');
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
          'attempt_number': claim.number,
          'attempt_trigger': claim.trigger.name,
          'travel_mode': modeName,
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
          routingOptions: RoutingOptions(travelMode: travelMode),
        ),
      );
      if (status != NavigationRouteStatus.statusOk) {
        throw StateError('route status: ${status.name}');
      }
      if (travelMode == NavigationTravelMode.twoWheeler) {
        await GoogleMapsNavigator.startGuidance();
        _guidanceActive = true;
        await _events?.record(
          'navigation_started',
          payload: {
            'nav_session_id': attachment.intent.navSessionId,
            'travel_mode': modeName,
            'attempt_number': claim.number,
          },
        );
        widget.onStatus('TWO_WHEELER guidance active');
      } else {
        const result =
            'DRIVING route works. The failure is isolated to TWO_WHEELER.';
        await _events?.record(
          'driving_diagnostic_route_available',
          payload: {
            'nav_session_id': attachment.intent.navSessionId,
            'attempt_number': claim.number,
          },
        );
        if (mounted) setState(() => _diagnosticResult = result);
        widget.onStatus(result);
      }
    } catch (error) {
      await _events?.record(
        'route_request_error',
        payload: {
          'nav_session_id': _intent?.navSessionId,
          'attempt_number': claim.number,
          'attempt_trigger': claim.trigger.name,
          'travel_mode': modeName,
          'error': error.toString(),
        },
      );
      _setStatus('$modeName route unavailable: $error', isError: true);
    } finally {
      _attemptGate.complete();
      if (mounted) setState(() {});
    }
  }

  String _modeName(NavigationTravelMode travelMode) =>
      travelMode == NavigationTravelMode.twoWheeler ? 'TWO_WHEELER' : 'DRIVING';

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
    await _uploader.stop();
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
    if (!_sessionReady) {
      return const ColoredBox(
        color: Color(0xFFD7DDD7),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final diagnosticMessage = _diagnosticResult ?? _error;
    return Stack(
      children: [
        GoogleMapsNavigationView(
          onViewCreated: _onViewCreated,
          initialNavigationUIEnabledPreference:
              NavigationUIEnabledPreference.automatic,
          initialCameraPosition: const CameraPosition(
            target: _destination,
            zoom: 15,
          ),
        ),
        if (_attemptGate.inFlight)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
        if (!_guidanceActive && diagnosticMessage != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              color: _error == null
                  ? const Color(0xFFE1F2E8)
                  : const Color(0xFFFFE8DF),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      diagnosticMessage,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.strings.routeDiagnosticHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      key: const Key('retry-two-wheeler'),
                      onPressed: _attemptGate.inFlight
                          ? null
                          : () => unawaited(
                              _attemptRoute(
                                NavigationTravelMode.twoWheeler,
                                RouteAttemptTrigger.manualTwoWheeler,
                              ),
                            ),
                      child: Text(widget.strings.retryTwoWheeler),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      key: const Key('test-driving-route'),
                      onPressed: _attemptGate.inFlight
                          ? null
                          : () => unawaited(
                              _attemptRoute(
                                NavigationTravelMode.driving,
                                RouteAttemptTrigger.drivingDiagnostic,
                              ),
                            ),
                      child: Text(widget.strings.testDrivingRoute),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
