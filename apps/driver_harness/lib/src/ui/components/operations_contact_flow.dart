import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/driver_design_system.dart';
import '../../app/harness_app_controller.dart';
import '../../driver/driver_session.dart';
import '../call_contact_screen.dart';
import 'rounds_action_drawer.dart';

typedef RoundsExternalLauncher = Future<bool> Function(Uri uri);
typedef RoundsOperationsMessageAction = Future<void> Function();

Future<void> openOperationsContactFlow(
  BuildContext context, {
  required DriverRoundModel round,
  required DriverRoundStopModel stop,
  HarnessAppController? controller,
  RoundsOperationsMessageAction? onMessage,
  RoundsExternalLauncher launcher = _launchExternal,
}) async {
  final action = await showRoundsActionDrawer(
    context,
    title: 'Contact Operations',
    actions: [
      RoundsDrawerAction(
        value: 'call',
        label: 'Call ${round.pickup.contactName}',
        icon: Icons.call_outlined,
      ),
      RoundsDrawerAction(
        value: 'message',
        label: 'Message ${round.pickup.contactName}',
        icon: Icons.chat_bubble_outline,
      ),
    ],
  );
  if (action == null || !context.mounted) return;

  if (action == 'message' && onMessage != null) {
    await onMessage();
    return;
  }

  if (action == 'call' && controller != null) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CallContactScreen(
          controller: controller,
          round: round,
          stop: stop,
          target: CallContactTarget.operations,
          onMessageOperations: onMessage,
          launcher: launcher,
        ),
      ),
    );
    return;
  }

  final phone = round.pickup.contactPhone.trim();
  final uri = action == 'call'
      ? Uri(scheme: 'tel', path: phone)
      : Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': _operationsMessage(round: round, stop: stop)},
        );
  final opened = phone.isNotEmpty && await launcher(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('operations-contact-launch-error'),
        content: Text(
          action == 'call'
              ? 'The phone app could not be opened.'
              : 'The message app could not be opened.',
        ),
      ),
    );
  }
}

String _operationsMessage({
  required DriverRoundModel round,
  required DriverRoundStopModel stop,
}) =>
    'Rounds driver update\n'
    'Round: ${round.reference}\n'
    'Stop ${stop.sequence}: ${stop.deliveryReference}\n'
    'Recipient: ${stop.recipientName}\n'
    'I need help with this stop.';

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class OperationsContactContextCard extends StatelessWidget {
  const OperationsContactContextCard({
    required this.round,
    required this.stop,
    super.key,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel stop;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RoundsSpace.md),
    decoration: BoxDecoration(
      color: RoundsColors.canvas,
      border: Border.all(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(RoundsRadii.surface),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${round.reference} · Stop ${stop.sequence} of ${round.stops.length}',
          style: const TextStyle(
            color: RoundsColors.orange,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${stop.recipientName} · ${stop.deliveryReference}',
          style: const TextStyle(
            color: RoundsColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          stop.rawAddress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
