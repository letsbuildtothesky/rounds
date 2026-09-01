import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'navigation_harness_screen.dart';
import 'pickup_confirmation_screen.dart';

class AssignedRoundScreen extends StatelessWidget {
  const AssignedRoundScreen({
    required this.controller,
    required this.enableNativeNavigation,
    this.session,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverSessionModel? session;

  static const _demoRound = DriverRoundModel(
    id: 'ROUND-DEMO',
    reference: 'ROUND-DEMO-001',
    serviceDate: '2026-09-01',
    state: 'active',
    version: 1,
    tenantName: 'UrbanFlowers',
    pickup: DriverPickupModel(
      displayName: 'UrbanFlowers · Sukhumvit 39',
      rawAddress: 'Sukhumvit 39, Bangkok',
      contactName: 'UrbanFlowers Dispatch',
      contactPhone: '+66000000000',
    ),
    stops: [
      DriverRoundStopModel(
        id: 'STOP-001',
        sequence: 1,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'MANIFEST-DEMO-001',
        manifestVersion: 1,
        deliveryReference: 'UF-DEMO-001',
        recipientName: 'Siriporn',
        recipientPhone: '+66999999999',
        rawAddress: 'Interchange 21, Sukhumvit Road, Bangkok',
        latitude: 13.7367,
        longitude: 100.5612,
        windowStart: '2026-09-01T02:00:00Z',
        windowEnd: '2026-09-01T04:00:00Z',
        manifestItems: [
          DriverManifestItemModel(
            lineNumber: 1,
            description: 'Flower bouquet',
            quantity: 1,
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    final round =
        session?.currentRound ??
        (controller.driverConfigured ? null : _demoRound);
    final firstStop = round?.stops.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rounds.',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (controller.driverConfigured)
            IconButton(
              tooltip: 'Refresh assigned work',
              onPressed: controller.refreshDriverSession,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: strings.chooseLanguage,
            onPressed: () => controller.selectLocale(
              controller.locale == HarnessLocale.thai
                  ? HarnessLocale.english
                  : HarnessLocale.thai,
            ),
            icon: const Icon(Icons.language),
          ),
          if (controller.driverConfigured)
            IconButton(
              tooltip: 'Sign out',
              onPressed: controller.signOutDriver,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: round == null
            ? _WaitingForRound(
                driverName: session?.userName,
                onRefresh: controller.driverConfigured
                    ? controller.refreshDriverSession
                    : null,
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        _LiveDot(),
                        SizedBox(width: 8),
                        Text(
                          'ROUND ASSIGNED',
                          style: TextStyle(
                            color: Color(0xFF26725C),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      firstStop == null ? 'Round ready' : 'Delivery next',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF15382F),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      round.reference,
                      style: const TextStyle(color: Color(0xFF69766F)),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      color: const Color(0xFF17453B),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_shipping_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TEAM ROUND',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    round.tenantName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${round.stops.length} stop${round.stops.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: round.stops.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _StopCard(stop: round.stops[index]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: Key(
                        round.state == 'active'
                            ? 'start-navigation'
                            : 'verify-pickup',
                      ),
                      onPressed: firstStop == null
                          ? null
                          : round.state == 'active'
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => NavigationHarnessScreen(
                                  controller: controller,
                                  enableNativeNavigation:
                                      enableNativeNavigation,
                                  stop: firstStop,
                                  stopCount: round.stops.length,
                                ),
                              ),
                            )
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PickupConfirmationScreen(
                                  controller: controller,
                                  round: round,
                                ),
                              ),
                            ),
                      icon: Icon(
                        round.state == 'active'
                            ? Icons.navigation_rounded
                            : Icons.inventory_2_outlined,
                      ),
                      label: Text(
                        firstStop == null
                            ? 'No Stops assigned'
                            : round.state == 'active'
                            ? 'Start route to Stop 1'
                            : 'Verify pickup manifest',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: const BoxDecoration(
      color: Color(0xFF27A87A),
      shape: BoxShape.circle,
    ),
  );
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final DriverRoundStopModel stop;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F0E8),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${stop.sequence}',
              style: const TextStyle(
                color: Color(0xFF17453B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.recipientName,
                  style: const TextStyle(
                    color: Color(0xFF15382F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stop.rawAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF69766F),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  stop.manifestItems
                      .map((item) => '${item.quantity}× ${item.description}')
                      .join(' · '),
                  style: const TextStyle(
                    color: Color(0xFF27705B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            stop.deliveryReference,
            style: const TextStyle(color: Color(0xFF87918C), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _WaitingForRound extends StatelessWidget {
  const _WaitingForRound({this.driverName, this.onRefresh});

  final String? driverName;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 58, color: Color(0xFF17453B)),
          const SizedBox(height: 18),
          Text(
            'Waiting for a Round',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${driverName ?? 'Driver'}, Operations has not assigned current work yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF69766F)),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for assigned work'),
            ),
          ],
        ],
      ),
    ),
  );
}
