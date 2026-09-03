import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import 'operations_chat_screen.dart';
import 'post_delivery_screen.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({
    required this.controller,
    required this.session,
    required this.onHome,
    required this.onJobs,
    super.key,
  });

  final HarnessAppController controller;
  final DriverSessionModel session;
  final VoidCallback onHome;
  final VoidCallback onJobs;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.surface,
    body: SafeArea(
      child: MediaQuery.withNoTextScaling(
        child: Column(
          children: [
            const _ProfileTopBar(),
            Expanded(
              child: ListView(
                key: const Key('l01-body'),
                padding: EdgeInsets.zero,
                children: [
                  const _ProfileHeader(),
                  _Identity(session: session),
                  _WorkContext(session: session),
                  _ProfileSection(
                    title: 'Driver',
                    rows: [
                      _ProfileRowData(
                        title: 'Vehicle',
                        subtitle: _vehicle(session),
                        value: 'Assigned',
                      ),
                    ],
                  ),
                  _ProfileSection(
                    title: 'App',
                    rows: [
                      _ProfileRowData(
                        key: const Key('l01-language'),
                        title: 'Language',
                        value: controller.locale == HarnessLocale.thai
                            ? 'ไทย'
                            : 'English',
                        onTap: () => _showLanguage(context),
                      ),
                      _ProfileRowData(
                        key: const Key('l01-permissions'),
                        title: 'Permissions',
                        subtitle: 'Location and contextual camera access',
                        onTap: () => _openPermissions(context),
                      ),
                      if (_supportStop(session) != null)
                        _ProfileRowData(
                          key: const Key('l01-support'),
                          title: 'Help & support',
                          subtitle: 'Message Operations for this Round',
                          onTap: () => _openSupport(context),
                        ),
                    ],
                  ),
                  _ProfileSection(
                    bottomPadding: 28,
                    rows: [
                      _ProfileRowData(
                        key: const Key('l01-sign-out'),
                        title: 'Sign out',
                        destructive: true,
                        onTap: () => _showSignOut(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _ProfileBottomNav(onHome: onHome, onJobs: onJobs),
          ],
        ),
      ),
    ),
  );

  Future<void> _showLanguage(BuildContext context) async {
    final choice = await showModalBottomSheet<HarnessLocale>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(selected: controller.locale),
    );
    if (choice != null) await controller.selectLocale(choice);
  }

  void _openSupport(BuildContext context) {
    final round = session.currentRound;
    final stop = _supportStop(session);
    if (round == null || stop == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationsChatScreen(
          controller: controller,
          round: round,
          stop: stop,
        ),
      ),
    );
  }

  void _openPermissions(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DriverPermissionsScreen()),
    );
  }

  Future<void> _showSignOut(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SignOutSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await controller.signOutDriver();
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-topbar'),
    height: DriverL01Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverL01Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Rounds',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverL01Metrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 3, bottom: 2),
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(
          width: DriverL01Metrics.topButtonSize,
          height: DriverL01Metrics.topButtonSize,
          child: Icon(
            Icons.notifications_none,
            color: RoundsColors.lineStrong,
            size: DriverL01Metrics.topIconSize,
          ),
        ),
      ],
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-header'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      DriverL01Metrics.headerPaddingHorizontal,
      DriverL01Metrics.headerPaddingTop,
      DriverL01Metrics.headerPaddingHorizontal,
      DriverL01Metrics.headerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverL01Metrics.eyebrowSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.04,
          ),
        ),
        SizedBox(height: DriverL01Metrics.eyebrowBottom),
        Text(
          'Profile',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: DriverL01Metrics.titleSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.87,
          ),
        ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.session});

  final DriverSessionModel session;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-identity'),
    padding: const EdgeInsets.fromLTRB(
      DriverL01Metrics.identityPaddingHorizontal,
      DriverL01Metrics.identityPaddingTop,
      DriverL01Metrics.identityPaddingHorizontal,
      DriverL01Metrics.identityPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: DriverL01Metrics.avatarSize,
          height: DriverL01Metrics.avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F5),
            border: Border.all(color: RoundsColors.line),
            borderRadius: BorderRadius.circular(DriverL01Metrics.avatarRadius),
          ),
          child: Text(
            _initials(session.userName),
            style: const TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: DriverL01Metrics.avatarTextSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -.96,
            ),
          ),
        ),
        const SizedBox(width: DriverL01Metrics.identityColumnGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.userName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverL01Metrics.identityNameSize,
                  height: 1.03,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.12,
                ),
              ),
              const SizedBox(height: DriverL01Metrics.identitySubTop),
              const Text(
                'Team driver profile',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverL01Metrics.identitySubSize,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DriverL01Metrics.identityStatusTop),
              Row(
                children: [
                  Container(
                    width: DriverL01Metrics.identityStatusDotSize,
                    height: DriverL01Metrics.identityStatusDotSize,
                    decoration: const BoxDecoration(
                      color: RoundsColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Active Team driver',
                    style: TextStyle(
                      color: RoundsColors.green,
                      fontSize: DriverL01Metrics.identityStatusSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WorkContext extends StatelessWidget {
  const _WorkContext({required this.session});

  final DriverSessionModel session;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-work-context'),
    padding: const EdgeInsets.symmetric(
      horizontal: DriverL01Metrics.workPaddingHorizontal,
      vertical: DriverL01Metrics.workPaddingVertical,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.teamName ?? 'Team assignment',
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverL01Metrics.workNameSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.32,
                ),
              ),
              const SizedBox(height: DriverL01Metrics.workSubTop),
              const Text(
                'Team driver',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverL01Metrics.workSubSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Active',
          style: TextStyle(
            color: RoundsColors.green,
            fontSize: DriverL01Metrics.workStateSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ProfileRowData {
  const _ProfileRowData({
    required this.title,
    this.key,
    this.subtitle,
    this.value,
    this.destructive = false,
    this.onTap,
  });

  final Key? key;
  final String title;
  final String? subtitle;
  final String? value;
  final bool destructive;
  final VoidCallback? onTap;
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.rows,
    this.title,
    this.bottomPadding = DriverL01Metrics.sectionPaddingBottom,
  });

  final String? title;
  final List<_ProfileRowData> rows;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      DriverL01Metrics.sectionPaddingHorizontal,
      DriverL01Metrics.sectionPaddingTop,
      DriverL01Metrics.sectionPaddingHorizontal,
      bottomPadding,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: DriverL01Metrics.sectionTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverL01Metrics.sectionTitleBottom),
        ],
        const Divider(height: 1),
        for (final row in rows) _ProfileRow(data: row),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.data});

  final _ProfileRowData data;

  @override
  Widget build(BuildContext context) => InkWell(
    key: data.key,
    onTap: data.onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DriverL01Metrics.rowMinHeight,
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: RoundsColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      color: data.destructive
                          ? RoundsColors.red
                          : RoundsColors.ink,
                      fontSize: DriverL01Metrics.rowTitleSize,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: DriverL01Metrics.rowSubTop),
                    Text(
                      data.subtitle!,
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverL01Metrics.rowSubSize,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (data.value != null)
              Text(
                data.value!,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverL01Metrics.rowValueSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (data.onTap != null) ...[
              const SizedBox(width: 9),
              const Icon(
                Icons.chevron_right,
                color: RoundsColors.muted,
                size: DriverL01Metrics.chevronSize,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ProfileBottomNav extends StatelessWidget {
  const _ProfileBottomNav({required this.onHome, required this.onJobs});

  final VoidCallback onHome;
  final VoidCallback onJobs;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-bottom-nav'),
    height: DriverL01Metrics.bottomNavHeight,
    padding: const EdgeInsets.fromLTRB(
      DriverL01Metrics.bottomNavPaddingHorizontal,
      DriverL01Metrics.bottomNavPaddingTop,
      DriverL01Metrics.bottomNavPaddingHorizontal,
      DriverL01Metrics.bottomNavPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ProfileNav(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: onHome,
          ),
        ),
        Expanded(
          child: _ProfileNav(
            icon: Icons.location_on_outlined,
            label: 'Jobs',
            onTap: onJobs,
          ),
        ),
        const Expanded(
          child: _ProfileNav(icon: Icons.schedule, label: 'Hours'),
        ),
        const Expanded(
          child: _ProfileNav(
            icon: Icons.person_outline,
            label: 'Profile',
            active: true,
          ),
        ),
      ],
    ),
  );
}

class _ProfileNav extends StatelessWidget {
  const _ProfileNav({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: DriverL01Metrics.bottomNavIconSize,
          color: active ? RoundsColors.orange : RoundsColors.muted,
        ),
        const SizedBox(height: DriverL01Metrics.bottomNavGap),
        Text(
          label,
          style: TextStyle(
            color: active ? RoundsColors.orange : RoundsColors.muted,
            fontSize: DriverL01Metrics.bottomNavLabelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected});

  final HarnessLocale selected;

  @override
  Widget build(BuildContext context) => _ProfileSheet(
    kicker: 'LANGUAGE',
    title: 'App language',
    child: Column(
      children: [
        _LanguageChoice(
          label: 'English',
          selected: selected == HarnessLocale.english,
          onTap: () => Navigator.of(context).pop(HarnessLocale.english),
        ),
        _LanguageChoice(
          label: 'ไทย',
          selected: selected == HarnessLocale.thai,
          onTap: () => Navigator.of(context).pop(HarnessLocale.thai),
        ),
      ],
    ),
  );
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DriverL01Metrics.sheetChoiceMinHeight,
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: RoundsColors.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              selected ? 'Selected' : 'Select',
              style: TextStyle(
                color: selected ? RoundsColors.orange : RoundsColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) => _ProfileSheet(
    kicker: 'ACCOUNT',
    title: 'Sign out?',
    subtitle: 'You will return to the Driver entry screen.',
    child: Column(
      children: [
        const SizedBox(height: DriverL01Metrics.sheetButtonTop),
        SizedBox(
          key: const Key('l01-confirm-sign-out'),
          width: double.infinity,
          height: DriverL01Metrics.sheetPrimaryHeight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: RoundsColors.red),
            child: const Text('Sign out'),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          height: DriverL01Metrics.sheetSecondaryHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
      ],
    ),
  );
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.kicker,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-sheet'),
    padding: const EdgeInsets.fromLTRB(
      DriverL01Metrics.sheetPaddingHorizontal,
      DriverL01Metrics.sheetPaddingTop,
      DriverL01Metrics.sheetPaddingHorizontal,
      DriverL01Metrics.sheetPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DriverL01Metrics.sheetRadius),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: DriverL01Metrics.sheetGrabWidth,
              height: DriverL01Metrics.sheetGrabHeight,
              margin: const EdgeInsets.only(
                bottom: DriverL01Metrics.sheetGrabBottom,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD7DDE2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            kicker,
            style: const TextStyle(
              color: RoundsColors.orange,
              fontSize: DriverL01Metrics.sheetKickerSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.04,
            ),
          ),
          const SizedBox(height: DriverL01Metrics.sheetKickerBottom),
          Text(
            title,
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: DriverL01Metrics.sheetTitleSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.26,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DriverL01Metrics.sheetSubTop),
            Text(
              subtitle!,
              style: const TextStyle(
                color: RoundsColors.muted,
                fontSize: DriverL01Metrics.sheetSubSize,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

DriverRoundStopModel? _supportStop(DriverSessionModel session) {
  final round = session.currentRound;
  if (round == null || round.stops.isEmpty) return null;
  return nextOperationalStop(round) ?? round.stops.first;
}

String _vehicle(DriverSessionModel session) {
  final values = [session.vehicleLabel, session.vehiclePlate]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? 'No vehicle details provided' : values.join(' · ');
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final result = words.take(2).map((word) => word[0].toUpperCase()).join();
  return result.isEmpty ? 'DR' : result;
}
