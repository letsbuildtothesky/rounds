import 'package:flutter/material.dart';

import '../../app/driver_design_system.dart';

class RoundsDrawerAction {
  const RoundsDrawerAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool destructive;
}

Future<String?> showRoundsActionDrawer(
  BuildContext context, {
  String? title,
  required List<RoundsDrawerAction> actions,
  bool showCancel = true,
  bool showChevrons = true,
  bool inset = false,
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: RoundsColors.ink.withValues(alpha: .38),
  builder: (context) {
    final drawer = _RoundsActionDrawer(
      title: title,
      actions: actions,
      showCancel: showCancel,
      showChevrons: showChevrons,
      inset: inset,
    );
    return inset
        ? Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: drawer,
          )
        : drawer;
  },
);

class _RoundsActionDrawer extends StatelessWidget {
  const _RoundsActionDrawer({
    required this.title,
    required this.actions,
    required this.showCancel,
    required this.showChevrons,
    required this.inset,
  });

  final String? title;
  final List<RoundsDrawerAction> actions;
  final bool showCancel;
  final bool showChevrons;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Material(
      key: const Key('rounds-action-drawer'),
      color: RoundsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: inset
            ? const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              )
            : const BorderRadius.vertical(
                top: Radius.circular(RoundsRadii.large),
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                key: const Key('rounds-action-drawer-handle'),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: RoundsColors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Text(
                  title!,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.45,
                  ),
                ),
              ),
              const Divider(height: 1, color: RoundsColors.line),
            ],
            for (var index = 0; index < actions.length; index++) ...[
              _DrawerActionRow(
                action: actions[index],
                showChevron: showChevrons,
              ),
              if (index != actions.length - 1)
                const Divider(height: 1, indent: 64, color: RoundsColors.line),
            ],
            if (showCancel) ...[
              const Divider(height: 1, color: RoundsColors.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: TextButton(
                  key: const Key('rounds-action-drawer-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: RoundsColors.inkSecondary,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: RoundsColors.lineStrong),
                      borderRadius: BorderRadius.circular(RoundsRadii.surface),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerActionRow extends StatelessWidget {
  const _DrawerActionRow({required this.action, required this.showChevron});

  final RoundsDrawerAction action;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? RoundsColors.red : RoundsColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('rounds-action-${action.value}'),
        onTap: () => Navigator.of(context).pop(action.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(action.icon, size: 24, color: color),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: action.destructive ? color : RoundsColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
