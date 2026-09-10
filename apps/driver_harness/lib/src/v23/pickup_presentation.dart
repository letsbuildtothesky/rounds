import '../ui/components/pickup_collection_view.dart';
import 'execution_query.dart';

/// Adapts current authorized data to the approved D03/D04 parcel component.
/// No quantity-to-parcel expansion, demo labels, pickup state or command fence.
class PickupPresentation {
  PickupPresentation._(this.merchant, this.site, this.stopCount, this.packages);

  factory PickupPresentation.fromSnapshot(DriverPickupSnapshot snapshot) {
    final data = snapshot.toJson()['data'] as Map<String, dynamic>;
    final orders = data['orders'] as List;
    final packages = <PickupPackage>[];
    for (final order in orders) {
      final parcels = order['packages'] as List;
      if (parcels.isEmpty) {
        // Optional packaging is valid domain data. It cannot be displayed by
        // the parcel checklist without an approved unpacked-order UI state.
        throw const PickupPresentationException(
          'PICKUP_PACKAGE_DISPLAY_UNAVAILABLE',
        );
      }
      for (final parcel in parcels) {
        final lineIds = (parcel['contents'] as List)
            .map((c) => c['line_id'])
            .toSet();
        final handling = <String>{};
        for (final line in order['lines'] as List) {
          if (lineIds.contains(line['line_id'])) {
            handling.addAll((line['handling_keys'] as List).cast<String>());
          }
        }
        // Labels are existing data, not newly invented temperature behaviour.
        packages.add(
          PickupPackage(
            key: parcel['package_id'] as String,
            title: parcel['label'] as String,
            reference: order['reference'] as String,
            recipient: order['recipient_name'] as String,
            handling: handling.isEmpty ? null : handling.join(' · '),
          ),
        );
      }
    }
    return PickupPresentation._(
      data['merchant'] as String,
      data['pickup_site_name'] as String,
      orders.length,
      List.unmodifiable(packages),
    );
  }

  final String merchant, site;
  final int stopCount;
  final List<PickupPackage> packages;

  @override
  String toString() => 'PickupPresentation(redacted)';
}

class PickupPresentationException implements Exception {
  const PickupPresentationException(this.code);
  final String code;
  @override
  String toString() => 'PickupPresentationException($code)';
}
