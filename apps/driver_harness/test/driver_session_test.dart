import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';

void main() {
  test(
    'assigned Round projection preserves Stop order and destination truth',
    () {
      final session = DriverSessionModel.fromJson({
        'user': {'id': 'auth-user', 'displayName': 'Demo Driver'},
        'driver': {'id': 'driver-1', 'preferredLocale': 'en'},
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
        },
      });

      expect(session.currentRound?.reference, 'ROUND-001');
      expect(session.currentRound?.pickup.id, 'pickup-1');
      expect(session.currentRound?.pickup.latitude, 13.7338);
      expect(session.currentRound?.pickup.longitude, 100.5766);
      expect(session.currentRound?.stops.single.sequence, 1);
      expect(session.currentRound?.stops.single.latitude, 13.7439);
      expect(
        session.currentRound?.stops.single.manifestItems.single.description,
        'Bouquet',
      );

      final cached = DriverSessionModel.fromJson(session.toJson());
      expect(cached.userName, session.userName);
      expect(cached.driverId, session.driverId);
      expect(cached.currentRound?.reference, 'ROUND-001');
      expect(cached.currentRound?.stops.single.recipientName, 'Siriporn');
      expect(cached.currentRound?.pickup.latitude, 13.7338);
    },
  );
}
