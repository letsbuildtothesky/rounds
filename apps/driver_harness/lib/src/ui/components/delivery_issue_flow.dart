import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/driver_design_system.dart';
import '../../driver/driver_session.dart';
import 'operations_contact_flow.dart';

class DeliveryIssueDraft {
  const DeliveryIssueDraft({required this.category, required this.note});

  final String category;
  final String note;
}

Future<void> openDeliveryIssueFlow(
  BuildContext context, {
  required DriverRoundModel round,
  required DriverRoundStopModel stop,
  RoundsExternalLauncher launcher = _launchExternal,
}) async {
  final draft = await showModalBottomSheet<DeliveryIssueDraft>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (context) => _DeliveryIssueSheet(round: round, stop: stop),
  );
  if (draft == null || !context.mounted) return;

  final phone = round.pickup.contactPhone.trim();
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: {
      'body': _issueMessage(round: round, stop: stop, draft: draft),
    },
  );
  final opened = phone.isNotEmpty && await launcher(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('delivery-issue-launch-error'),
        content: Text('The message app could not be opened.'),
      ),
    );
  }
}

String _issueMessage({
  required DriverRoundModel round,
  required DriverRoundStopModel stop,
  required DeliveryIssueDraft draft,
}) =>
    'ROUNDS EXCEPTION\n'
    'Round: ${round.reference}\n'
    'Stop ${stop.sequence}: ${stop.deliveryReference}\n'
    'Recipient: ${stop.recipientName}\n'
    'Issue: ${draft.category}'
    '${draft.note.trim().isEmpty ? '' : '\nNote: ${draft.note.trim()}'}';

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class _DeliveryIssueSheet extends StatefulWidget {
  const _DeliveryIssueSheet({required this.round, required this.stop});

  final DriverRoundModel round;
  final DriverRoundStopModel stop;

  @override
  State<_DeliveryIssueSheet> createState() => _DeliveryIssueSheetState();
}

class _DeliveryIssueSheetState extends State<_DeliveryIssueSheet> {
  static const _categories = [
    'Recipient unavailable',
    'Address or entrance problem',
    'Cannot complete delivery',
    'Emergency or safety issue',
  ];

  final _note = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Material(
        key: const Key('delivery-issue-drawer'),
        color: RoundsColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RoundsRadii.large),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: RoundsColors.lineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Report exception',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.65,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Choose the exact problem. Rounds will prepare the full stop context for Operations.',
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OperationsContactContextCard(
                    round: widget.round,
                    stop: widget.stop,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What happened?',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final category in _categories)
                    _IssueChoice(
                      label: category,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('delivery-issue-note'),
                    controller: _note,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Add details (optional)',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: RoundsColors.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RoundsRadii.surface,
                        ),
                        borderSide: const BorderSide(color: RoundsColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RoundsRadii.surface,
                        ),
                        borderSide: const BorderSide(color: RoundsColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      key: const Key('continue-delivery-issue'),
                      onPressed: _category == null
                          ? null
                          : () => Navigator.of(context).pop(
                              DeliveryIssueDraft(
                                category: _category!,
                                note: _note.text,
                              ),
                            ),
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Continue to Messages'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RoundsColors.red,
                        disabledBackgroundColor: const Color(0xFFD9DFE5),
                        disabledForegroundColor: const Color(0xFF85909D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RoundsRadii.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IssueChoice extends StatelessWidget {
  const _IssueChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: selected
          ? RoundsColors.red.withValues(alpha: .08)
          : RoundsColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? RoundsColors.red : RoundsColors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(RoundsRadii.surface),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('delivery-issue-${label.toLowerCase().replaceAll(' ', '-')}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? RoundsColors.red : RoundsColors.muted,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? RoundsColors.red : RoundsColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
