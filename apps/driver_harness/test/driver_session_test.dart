import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';

void main() {
  test(
    'assigned Round projection preserves Stop order and destination truth',
    () {
      final session = DriverSessionModel.fromJson({
        'user': {'id': 'auth-user', 'displayName': 'Demo Driver'},
        'driver': {'id': 'driver-1', 'version': 7, 'preferredLocale': 'en'},
        'currentRound': {
          'id': 'round-1',
          'reference': 'ROUND-001',
          'serviceDate': '2026-09-02',
          'state': 'approved',
          'version': 1,
          'tenant': {
            'id': 'tenant-1',
            'displayName': 'UrbanFlowers',
            'timezone': 'Asia/Bangkok',
          },
          'pickup': {
            'id': 'pickup-1',
            'displayName': 'Sukhumvit 39',
            'rawAddress': 'Bangkok',
            'contactName': 'Dispatch',
            'contactPhone': '+66000000000',
            'latitude': 13.7338,
            'longitude': 100.5766,
          },
          'stops': [
            {
              'id': 'stop-1',
              'sequence': 1,
              'state': 'assigned',
              'version': 1,
              'destinationVersion': 1,
              'deliveryId': 'delivery-1',
              'deliveryReference': 'UF-001',
              'recipientName': 'Siriporn',
              'recipientPhone': '+66999999999',
              'deliveryNote': 'Leave the bouquet upright',
              'rawAddress': 'Wireless Road, Bangkok',
              'latitude': 13.7439,
              'longitude': 100.547,
              'isSurprise': true,
              'windowStart': '2026-09-02T02:00:00Z',
              'windowEnd': '2026-09-02T04:00:00Z',
              'manifestId': 'manifest-1',
              'manifestVersion': 1,
              'manifestItems': [
                {'lineNumber': 1, 'description': 'Bouquet', 'quantity': 1},
              ],
            },
          ],
          'routePlan': {
            'status': 'fits',
            'serviceDate': '2026-09-02',
            'driverId': 'driver-1',
            'stopIds': ['stop-1'],
            'calculatedAt': '2026-09-02T01:00:00Z',
            'departureAt': '2026-09-02T01:30:00Z',
            'finishAt': '2026-09-02T02:15:00Z',
            'distanceMeters': 4200,
            'durationSeconds': 2700,
            'provider': {
              'name': 'mapbox',
              'profile': 'driving-traffic',
              'freshness': 'current_snapshot',
            },
            'stops': [
              {
                'stopId': 'stop-1',
                'sequence': 1,
                'eta': '2026-09-02T02:00:00Z',
                'departureAt': '2026-09-02T02:10:00Z',
                'windowStart': '2026-09-02T02:00:00Z',
                'windowEnd': '2026-09-02T04:00:00Z',
                'promiseStatus': 'safe',
                'waitingSeconds': 0,
                'latenessSeconds': 0,
                'legDurationSeconds': 1800,
                'legDistanceMeters': 4200,
              },
            ],
            'blockingReasons': <String>[],
            'warnings': ['Bangkok traffic snapshot'],
            'capacity': {'fits': true},
          },
        },
        'pendingLiveChange': {
          'id': 'change-1',
          'changeVersion': 2,
          'roundId': 'round-1',
          'stopId': 'stop-1',
          'appliedAt': '2026-09-02T01:30:00Z',
          'before': {
            'sequence': 1,
            'rawAddress': 'Wireless Road, Bangkok',
            'latitude': 13.7439,
            'longitude': 100.547,
            'accessNote': 'Tower A lobby',
            'windowStart': '2026-09-02T02:00:00Z',
            'windowEnd': '2026-09-02T04:00:00Z',
          },
          'after': {
            'sequence': 1,
            'rawAddress': 'Wireless Road, Bangkok',
            'latitude': 13.7439,
            'longitude': 100.547,
            'accessNote': 'Gate B',
            'windowStart': '2026-09-02T02:00:00Z',
            'windowEnd': '2026-09-02T04:00:00Z',
          },
          'impact': {
            'distanceDeltaMeters': 0,
            'durationDeltaSeconds': 120,
            'downstreamStopCount': 0,
            'promiseStatus': 'safe',
            'shiftSafe': true,
          },
          'driverAckStatus': 'pending',
        },
      });

      expect(session.currentRound?.reference, 'ROUND-001');
      expect(session.userId, 'auth-user');
      expect(session.version, 7);
      expect(session.currentRound?.tenantId, 'tenant-1');
      expect(session.currentRound?.tenantTimezone, 'Asia/Bangkok');
      expect(session.currentRound?.pickup.id, 'pickup-1');
      expect(session.currentRound?.pickup.latitude, 13.7338);
      expect(session.currentRound?.pickup.longitude, 100.5766);
      expect(session.currentRound?.plannedDistanceMeters, 4200);
      expect(session.pendingLiveChange?.after.accessNote, 'Gate B');
      expect(session.pendingLiveChange?.changeVersion, 2);
      expect(session.currentRound?.stops.single.sequence, 1);
      expect(session.currentRound?.stops.single.deliveryId, 'delivery-1');
      expect(session.currentRound?.stops.single.isSurprise, isTrue);
      expect(
        session.currentRound?.stops.single.deliveryNote,
        'Leave the bouquet upright',
      );
      expect(session.currentRound?.stops.single.latitude, 13.7439);
      expect(
        session.currentRound?.stops.single.manifestItems.single.description,
        'Bouquet',
      );

      final cached = DriverSessionModel.fromJson(session.toJson());
      expect(cached.userName, session.userName);
      expect(cached.driverId, session.driverId);
      expect(cached.version, 7);
      expect(cached.userId, 'auth-user');
      expect(cached.currentRound?.reference, 'ROUND-001');
      expect(cached.currentRound?.tenantId, 'tenant-1');
      expect(cached.currentRound?.tenantTimezone, 'Asia/Bangkok');
      expect(cached.currentRound?.stops.single.recipientName, 'Siriporn');
      expect(cached.currentRound?.stops.single.deliveryId, 'delivery-1');
      expect(cached.currentRound?.stops.single.isSurprise, isTrue);
      expect(
        cached.currentRound?.stops.single.deliveryNote,
        'Leave the bouquet upright',
      );
      expect(cached.currentRound?.pickup.latitude, 13.7338);
      expect(
        (cached.currentRound?.routePlanSnapshot?['provider']
            as Map<String, dynamic>)['freshness'],
        'current_snapshot',
      );
      expect(cached.currentRound?.routePlanSnapshot?['warnings'], [
        'Bangkok traffic snapshot',
      ]);
      expect(cached.pendingLiveChange?.before.accessNote, 'Tower A lobby');
    },
  );
}
