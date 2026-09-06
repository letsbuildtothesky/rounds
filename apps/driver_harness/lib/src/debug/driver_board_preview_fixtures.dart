import '../driver/driver_session.dart';

/// Explicit debug-only data used to compare Flutter against the canonical
/// English B00/B01/B01B HTML boards. Production routes never read this file.
abstract final class DriverBoardPreviewFixtures {
  static final startShift = _session(attendance: false);
  static final waiting = _session(attendance: true);
  static final assigned = _session(attendance: true, round: assignedRound);

  static final startShiftNow = DateTime.parse('2026-09-03T00:52:00.000Z');
  static final waitingNow = DateTime.parse('2026-09-03T02:41:00.000Z');

  static DriverSessionModel _session({
    required bool attendance,
    DriverRoundModel? round,
  }) => DriverSessionModel(
    userName: 'Johannes',
    driverId: 'preview-driver',
    preferredLocale: 'en',
    teamName: 'UrbanFlowers',
    currentRound: round,
    shift: DriverShiftModel(
      effective: DriverEffectiveShiftModel(
        serviceDate: '2026-09-03',
        timezone: 'Asia/Bangkok',
        source: 'preview_fixture',
        startAt: DateTime.parse('2026-09-03T01:00:00.000Z'),
        endAt: DateTime.parse('2026-09-03T10:00:00.000Z'),
        startLocal: '08:00',
        endLocal: '17:00',
        crossesMidnight: false,
      ),
      attendance: attendance
          ? DriverShiftAttendanceModel(
              id: 'preview-attendance',
              version: 1,
              serviceDate: '2026-09-03',
              startedAt: DateTime.parse('2026-09-03T01:00:00.000Z'),
            )
          : null,
    ),
  );

  static const assignedRound = DriverRoundModel(
    id: 'preview-round',
    reference: 'ROUND-001',
    serviceDate: '2026-09-03',
    state: 'approved',
    version: 3,
    tenantName: 'UrbanFlowers',
    plannedDistanceMeters: 18600,
    plannedDurationSeconds: 3480,
    pickup: DriverPickupModel(
      id: 'preview-pickup',
      displayName: 'UrbanFlowers',
      rawAddress: 'Sukhumvit 39, Bangkok',
      contactName: 'UrbanFlowers Dispatch',
      contactPhone: '+66000000000',
      latitude: 13.7338,
      longitude: 100.5766,
    ),
    stops: [
      DriverRoundStopModel(
        id: 'preview-stop-1',
        sequence: 1,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'preview-manifest-1',
        manifestVersion: 1,
        deliveryReference: 'UF-001',
        recipientName: 'Siriporn',
        recipientPhone: '+66999999999',
        rawAddress: 'Wireless Road, Bangkok',
        latitude: 13.7439,
        longitude: 100.547,
        windowStart: '2026-09-03T05:00:00Z',
        windowEnd: '2026-09-03T10:00:00Z',
        manifestItems: [
          DriverManifestItemModel(
            lineNumber: 1,
            description: 'Flowers',
            quantity: 1,
          ),
          DriverManifestItemModel(
            lineNumber: 2,
            description: 'Cake',
            quantity: 1,
          ),
        ],
      ),
      DriverRoundStopModel(
        id: 'preview-stop-2',
        sequence: 2,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'preview-manifest-2',
        manifestVersion: 1,
        deliveryReference: 'UF-002',
        recipientName: 'Anong',
        recipientPhone: '+66999999998',
        rawAddress: 'Sathorn Road, Bangkok',
        latitude: 13.7200,
        longitude: 100.5300,
        windowStart: '2026-09-03T06:00:00Z',
        windowEnd: '2026-09-03T11:00:00Z',
        manifestItems: [],
      ),
      DriverRoundStopModel(
        id: 'preview-stop-3',
        sequence: 3,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'preview-manifest-3',
        manifestVersion: 1,
        deliveryReference: 'UF-003',
        recipientName: 'Mali',
        recipientPhone: '+66999999997',
        rawAddress: 'Silom Road, Bangkok',
        latitude: 13.7300,
        longitude: 100.5200,
        windowStart: '2026-09-03T07:00:00Z',
        windowEnd: '2026-09-03T12:00:00Z',
        manifestItems: [],
      ),
      DriverRoundStopModel(
        id: 'preview-stop-4',
        sequence: 4,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'preview-manifest-4',
        manifestVersion: 1,
        deliveryReference: 'UF-004',
        recipientName: 'Nok',
        recipientPhone: '+66999999996',
        rawAddress: 'Rama IV Road, Bangkok',
        latitude: 13.7400,
        longitude: 100.5100,
        windowStart: '2026-09-03T08:00:00Z',
        windowEnd: '2026-09-03T13:00:00Z',
        manifestItems: [],
      ),
    ],
  );
}
