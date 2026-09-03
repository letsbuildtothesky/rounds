import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app/app_strings.dart';
import '../permissions/driver_permissions_screen.dart';
import '../permissions/location_access.dart';
import '../storage/harness_database.dart';
import '../storage/harness_event_log.dart';
import '../storage/sqlite_navigation_intent_store.dart';
import '../telemetry/operational_location_recorder.dart';
import '../telemetry/telemetry_uploader.dart';
import 'gps_signal_monitor.dart';
import 'navigation_intent.dart';
import 'route_attempt_gate.dart';

class NavigationRoadInstruction {
  const NavigationRoadInstruction({
    required this.maneuver,
    required this.text,
    this.distanceMeters,
  });

  final Maneuver maneuver;
  final String text;
  final int? distanceMeters;
}

class GoogleNavigationSurfaceController {
  _GoogleNavigationSurfaceState? _state;

  Future<void> retryGps() async => _state?._retryGps();

  void _attach(_GoogleNavigationSurfaceState state) => _state = state;

  void _detach(_GoogleNavigationSurfaceState state) {
    if (identical(_state, state)) _state = null;
  }
}

class GoogleNavigationSurface extends StatefulWidget {
  const GoogleNavigationSurface({
    required this.strings,
    required this.onOperationalSample,
    required this.onStatus,
    required this.onRemainingChanged,
    required this.onArrival,
    required this.stopId,
    required this.destinationVersion,
    required this.destinationTitle,
    required this.latitude,
    required this.longitude,
    required this.bottomOverlayInset,
    this.onInstruction,
    this.onGpsInterruptionChanged,
    this.controller,
    this.gpsSignalTimeout = const Duration(seconds: 30),
    this.showNativeNavigationUi = true,
    super.key,
  });

  final AppStrings strings;
  final void Function(DateTime capturedAt) onOperationalSample;
  final void Function(String status) onStatus;
  final void Function(int remainingSeconds, int remainingMeters)
  onRemainingChanged;
  final VoidCallback onArrival;
  final String stopId;
  final int destinationVersion;
  final String destinationTitle;
  final double latitude;
  final double longitude;
  final double bottomOverlayInset;
  final ValueChanged<NavigationRoadInstruction>? onInstruction;
  final ValueChanged<GpsNavigationInterruption?>? onGpsInterruptionChanged;
  final GoogleNavigationSurfaceController? controller;
  final Duration gpsSignalTimeout;
  final bool showNativeNavigationUi;

  @override
  State<GoogleNavigationSurface> createState() =>
      _GoogleNavigationSurfaceState();
}

class _GoogleNavigationSurfaceState extends State<GoogleNavigationSurface>
    with WidgetsBindingObserver {
  LatLng get _destination =>
      LatLng(latitude: widget.latitude, longitude: widget.longitude);

  late final OperationalLocationRecorder _recorder;
  late final GpsSignalMonitor _gpsSignalMonitor;
  late final TelemetryUploader _uploader;
  StreamSubscription<RoadSnappedLocationUpdatedEvent>? _roadLocation;
  StreamSubscription<void>? _rerouting;
  StreamSubscription<OnArrivalEvent>? _arrival;
  StreamSubscription<RemainingTimeOrDistanceChangedEvent>? _remaining;
  StreamSubscription<NavInfoEvent>? _navInfo;
  GoogleNavigationViewController? _viewController;
  HarnessDatabase? _database;
  HarnessEventLog? _events;
  NavigationIntent? _intent;
  final RouteAttemptGate _attemptGate = RouteAttemptGate();
  bool _sessionReady = false;
  bool _guidanceActive = false;
  String? _error;
  String? _diagnosticResult;
  DriverLocationAccessException? _locationFailure;
  bool _surfaceOpenedRecorded = false;
  bool _gpsUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _gpsSignalMonitor = GpsSignalMonitor(
      timeout: widget.gpsSignalTimeout,
      onUnavailableChanged: _handleGpsAvailabilityChanged,
    );
    _recorder = OperationalLocationRecorder(
      onPositionReceived: _handlePositionReceived,
      onSample: widget.onOperationalSample,
      onPersistenceError: (error) => _setStatus('Telemetry error: $error'),
      onLocationStreamError: (error) =>
          unawaited(_handleLocationStreamError(error)),
    );
    _uploader = TelemetryUploader(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final database = _database ?? await HarnessDatabase.open();
      _database ??= database;
      _events ??= HarnessEventLog(database);
      if (!_surfaceOpenedRecorded) {
        await _events?.record(
          'navigation_surface_opened',
          payload: {
            'stop_id': widget.stopId,
            'destination_version': widget.destinationVersion,
          },
        );
        _surfaceOpenedRecorded = true;
      }

      widget.onStatus('Requesting precise location…');
      await _recorder.start();
      if (mounted) setState(() => _locationFailure = null);
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
      _remaining =
          GoogleMapsNavigator.setOnRemainingTimeOrDistanceChangedListener(
            (event) => widget.onRemainingChanged(
              event.remainingTime.round(),
              event.remainingDistance.round(),
            ),
            remainingTimeThresholdSeconds: 10,
            remainingDistanceThresholdMeters: 25,
          );
      if (widget.onInstruction != null) {
        _navInfo = GoogleMapsNavigator.setNavInfoListener((event) {
          final step = event.navInfo.currentStep;
          if (step == null) return;
          final fullInstruction = step.fullInstructions?.trim();
          final roadName = step.fullRoadName?.trim();
          final instructionText =
              fullInstruction != null && fullInstruction.isNotEmpty
              ? fullInstruction
              : roadName != null && roadName.isNotEmpty
              ? roadName
              : 'Continue on the guided route';
          widget.onInstruction!(
            NavigationRoadInstruction(
              maneuver: step.maneuver,
              text: instructionText,
              distanceMeters: event.navInfo.distanceToCurrentStepMeters,
            ),
          );
        }, numNextStepsToPreview: 1);
      }

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
      _gpsSignalMonitor.start();
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
      if (error is DriverLocationAccessException && mounted) {
        _reportLocationAccessFailure(error);
      } else {
        _setStatus('Navigation unavailable: $error', isError: true);
      }
    }
  }

  void _handlePositionReceived(DateTime _) {
    _gpsSignalMonitor.markSample();
    if (_locationFailure != null && mounted) {
      setState(() => _locationFailure = null);
    }
  }

  Future<void> _handleLocationStreamError(Object error) async {
    final access = await const GeolocatorLocationAccessGateway().inspect();
    if (!mounted) return;
    if (!access.ready) {
      _reportLocationAccessFailure(DriverLocationAccessException(access.state));
      return;
    }
    _gpsSignalMonitor.start();
    _gpsSignalMonitor.markStreamError();
    await _events?.record(
      'gps_position_stream_error',
      payload: {
        'error': error.toString(),
        'nav_session_id': _intent?.navSessionId,
      },
    );
  }

  Future<void> _retryGps() async {
    final cachedRouteAvailable = _guidanceActive;
    final result = await probeGpsRecovery(
      cachedRouteAvailable: cachedRouteAvailable,
    );
    if (!mounted) return;
    if (result != null) {
      if (result.kind == GpsInterruptionKind.locationAccessOff) {
        final access = await const GeolocatorLocationAccessGateway().inspect();
        if (!mounted) return;
        _reportLocationAccessFailure(
          DriverLocationAccessException(access.state),
        );
      } else {
        widget.onGpsInterruptionChanged?.call(result);
      }
      return;
    }
    try {
      await _recorder.restartLocationStream();
      final wasUnavailable = _gpsUnavailable;
      _gpsSignalMonitor.start();
      _gpsSignalMonitor.markSample();
      if (!wasUnavailable) widget.onGpsInterruptionChanged?.call(null);
    } on DriverLocationAccessException catch (failure) {
      if (mounted) _reportLocationAccessFailure(failure);
    }
  }

  void _handleGpsAvailabilityChanged(bool unavailable) {
    if (unavailable) {
      unawaited(_classifyAndReportGpsInterruption());
      return;
    }
    if (!mounted || !_gpsUnavailable) return;
    _gpsUnavailable = false;
    widget.onStatus(
      _guidanceActive
          ? 'GPS restored · TWO_WHEELER guidance active'
          : 'GPS restored · calculating route',
    );
    unawaited(
      _events?.record(
        'gps_signal_restored',
        payload: {'nav_session_id': _intent?.navSessionId},
      ),
    );
    widget.onGpsInterruptionChanged?.call(null);
  }

  Future<void> _classifyAndReportGpsInterruption() async {
    final access = await const GeolocatorLocationAccessGateway().inspect();
    if (!mounted || !_gpsSignalMonitor.unavailable) return;
    if (!access.ready) {
      _reportLocationAccessFailure(DriverLocationAccessException(access.state));
      return;
    }
    if (_gpsUnavailable) return;
    _gpsUnavailable = true;
    widget.onStatus('GPS signal lost · live position paused');
    await _events?.record(
      'gps_signal_lost',
      payload: {
        'nav_session_id': _intent?.navSessionId,
        'cached_route_available': _guidanceActive,
      },
    );
    if (!mounted) return;
    widget.onGpsInterruptionChanged?.call(
      GpsNavigationInterruption(
        kind: GpsInterruptionKind.signalLost,
        cachedRouteAvailable: _guidanceActive,
      ),
    );
  }

  void _reportLocationAccessFailure(DriverLocationAccessException failure) {
    _gpsSignalMonitor.stop();
    _gpsUnavailable = false;
    setState(() => _locationFailure = failure);
    widget.onStatus('Navigation needs location access');
    widget.onGpsInterruptionChanged?.call(
      GpsNavigationInterruption(
        kind: GpsInterruptionKind.locationAccessOff,
        cachedRouteAvailable: _guidanceActive,
      ),
    );
  }

  Future<void> _reviewLocationAccess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DriverPermissionsScreen()),
    );
    if (!mounted) return;
    await _initialize();
  }

  Future<void> _onViewCreated(GoogleNavigationViewController controller) async {
    _viewController = controller;
    await controller.setMyLocationEnabled(true);
    await controller.setNavigationFooterEnabled(false);
    await controller.setPadding(
      EdgeInsets.only(bottom: widget.bottomOverlayInset),
    );
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
              title: widget.destinationTitle,
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
          stopId: widget.stopId,
          destinationVersion: widget.destinationVersion,
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
    widget.controller?._detach(this);
    _gpsSignalMonitor.stop();
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
    await _remaining?.cancel();
    await _navInfo?.cancel();
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
    final locationFailure = _locationFailure;
    if (locationFailure != null) {
      return ColoredBox(
        color: const Color(0xFFEEF1F4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 42,
                  color: Color(0xFFFF6420),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location access needed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF172238),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locationFailure.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF748094),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('navigation-location-recovery'),
                  onPressed: _reviewLocationAccess,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF172238),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('Review location access'),
                ),
              ],
            ),
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
    final diagnosticMessage = _diagnosticResult ?? _error;
    return Stack(
      children: [
        GoogleMapsNavigationView(
          onViewCreated: _onViewCreated,
          initialNavigationUIEnabledPreference: widget.showNativeNavigationUi
              ? NavigationUIEnabledPreference.automatic
              : NavigationUIEnabledPreference.disabled,
          initialPadding: EdgeInsets.only(bottom: widget.bottomOverlayInset),
          initialNavigationHeaderStylingOptions:
              const NavigationHeaderStylingOptions(
                primaryDayModeBackgroundColor: Color(0xFF172238),
                secondaryDayModeBackgroundColor: Color(0xFF172238),
                primaryNightModeBackgroundColor: Color(0xFF172238),
                secondaryNightModeBackgroundColor: Color(0xFF172238),
                largeManeuverIconColor: Color(0xFFFF6420),
                smallManeuverIconColor: Color(0xFFFF6420),
                nextStepTextColor: Color(0xBFFFFFFF),
                distanceValueTextColor: Colors.white,
                distanceUnitsTextColor: Color(0xBFFFFFFF),
                instructionsTextColor: Colors.white,
                guidanceRecommendedLaneColor: Color(0xFFFF6420),
              ),
          initialCameraPosition: CameraPosition(target: _destination, zoom: 15),
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
            bottom: widget.bottomOverlayInset + 12,
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
