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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final copy = _L01Copy(controller.locale);
      final compact = MediaQuery.sizeOf(context).width <= 340;
      return Scaffold(
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
                      _ProfileHeader(copy: copy, compact: compact),
                      _Identity(session: session, copy: copy, compact: compact),
                      _WorkContext(
                        session: session,
                        copy: copy,
                        compact: compact,
                      ),
                      _ProfileSection(
                        title: copy.driver,
                        thai: copy.isThai,
                        compact: compact,
                        rows: [
                          _ProfileRowData(
                            title: copy.vehicle,
                            subtitle: _vehicle(session, copy),
                          ),
                        ],
                      ),
                      _ProfileSection(
                        title: copy.app,
                        thai: copy.isThai,
                        compact: compact,
                        rows: [
                          _ProfileRowData(
                            key: const Key('l01-language'),
                            title: copy.language,
                            value: controller.locale == HarnessLocale.thai
                                ? 'ไทย'
                                : 'English',
                            onTap: () => _showLanguage(context, copy),
                          ),
                          _ProfileRowData(
                            key: const Key('l01-permissions'),
                            title: copy.permissions,
                            subtitle: copy.permissionsSubtitle,
                            onTap: () => _openPermissions(context),
                          ),
                          if (_supportStop(session) != null)
                            _ProfileRowData(
                              key: const Key('l01-support'),
                              title: copy.helpSupport,
                              subtitle: copy.supportSubtitle,
                              onTap: () => _openSupport(context),
                            ),
                        ],
                      ),
                      _ProfileSection(
                        bottomPadding: 28,
                        thai: copy.isThai,
                        compact: compact,
                        rows: [
                          _ProfileRowData(
                            key: const Key('l01-sign-out'),
                            title: copy.signOut,
                            destructive: true,
                            onTap: () => _showSignOut(context, copy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _ProfileBottomNav(copy: copy, onHome: onHome, onJobs: onJobs),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _showLanguage(BuildContext context, _L01Copy copy) async {
    final choice = await showModalBottomSheet<HarnessLocale>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(selected: controller.locale, copy: copy),
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
      MaterialPageRoute(
        builder: (_) => DriverPermissionsScreen(locale: controller.locale),
      ),
    );
  }

  Future<void> _showSignOut(BuildContext context, _L01Copy copy) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignOutSheet(copy: copy),
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
  const _ProfileHeader({required this.copy, required this.compact});

  final _L01Copy copy;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-header'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.headerPaddingHorizontal,
      compact
          ? (copy.isThai
                ? DriverL01Metrics.compactThaiHeaderPaddingTop
                : DriverL01Metrics.compactEnglishHeaderPaddingTop)
          : (copy.isThai
                ? DriverL01Metrics.thaiHeaderPaddingTop
                : DriverL01Metrics.headerPaddingTop),
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.headerPaddingHorizontal,
      compact
          ? (copy.isThai
                ? DriverL01Metrics.compactThaiHeaderPaddingBottom
                : DriverL01Metrics.compactEnglishHeaderPaddingBottom)
          : (copy.isThai
                ? DriverL01Metrics.thaiHeaderPaddingBottom
                : DriverL01Metrics.headerPaddingBottom),
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.account,
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: copy.isThai
                ? DriverL01Metrics.thaiEyebrowSize
                : DriverL01Metrics.eyebrowSize,
            height: copy.isThai ? DriverL01Metrics.thaiEyebrowHeight : 1,
            fontWeight: copy.isThai ? FontWeight.w600 : FontWeight.w800,
            letterSpacing: copy.isThai ? 0 : 1.04,
          ),
        ),
        SizedBox(
          height: copy.isThai
              ? DriverL01Metrics.thaiEyebrowBottom
              : DriverL01Metrics.eyebrowBottom,
        ),
        Text(
          copy.profile,
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: compact
                ? (copy.isThai
                      ? DriverL01Metrics.compactThaiHeaderTitleSize
                      : DriverL01Metrics.compactEnglishHeaderTitleSize)
                : (copy.isThai
                      ? DriverL01Metrics.thaiTitleSize
                      : DriverL01Metrics.titleSize),
            height: copy.isThai ? DriverL01Metrics.thaiTitleHeight : 1,
            fontWeight: FontWeight.w800,
            letterSpacing: copy.isThai ? 0 : -1.87,
          ),
        ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.session,
    required this.copy,
    required this.compact,
  });

  final DriverSessionModel session;
  final _L01Copy copy;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-identity'),
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.identityPaddingHorizontal,
      compact
          ? (copy.isThai
                ? DriverL01Metrics.compactThaiIdentityPaddingTop
                : DriverL01Metrics.compactEnglishIdentityPaddingTop)
          : (copy.isThai
                ? DriverL01Metrics.thaiIdentityPaddingTop
                : DriverL01Metrics.identityPaddingTop),
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.identityPaddingHorizontal,
      compact
          ? (copy.isThai
                ? DriverL01Metrics.compactThaiIdentityPaddingBottom
                : DriverL01Metrics.compactEnglishIdentityPaddingBottom)
          : (copy.isThai
                ? DriverL01Metrics.thaiIdentityPaddingBottom
                : DriverL01Metrics.identityPaddingBottom),
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: compact
              ? (copy.isThai
                    ? DriverL01Metrics.compactThaiAvatarSize
                    : DriverL01Metrics.compactEnglishAvatarSize)
              : (copy.isThai
                    ? DriverL01Metrics.thaiAvatarSize
                    : DriverL01Metrics.avatarSize),
          height: compact
              ? (copy.isThai
                    ? DriverL01Metrics.compactThaiAvatarSize
                    : DriverL01Metrics.compactEnglishAvatarSize)
              : (copy.isThai
                    ? DriverL01Metrics.thaiAvatarSize
                    : DriverL01Metrics.avatarSize),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F5),
            border: Border.all(color: RoundsColors.line),
            borderRadius: BorderRadius.circular(DriverL01Metrics.avatarRadius),
          ),
          child: Text(
            _initials(session.userName, copy),
            style: TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: compact
                  ? (copy.isThai
                        ? DriverL01Metrics.compactThaiAvatarTextSize
                        : DriverL01Metrics.compactEnglishAvatarTextSize)
                  : (copy.isThai
                        ? DriverL01Metrics.thaiAvatarTextSize
                        : DriverL01Metrics.avatarTextSize),
              fontWeight: copy.isThai ? FontWeight.w800 : FontWeight.w900,
              letterSpacing: copy.isThai ? 0 : -.96,
            ),
          ),
        ),
        SizedBox(
          width: compact
              ? (copy.isThai
                    ? DriverL01Metrics.compactThaiIdentityColumnGap
                    : DriverL01Metrics.compactEnglishIdentityColumnGap)
              : (copy.isThai
                    ? DriverL01Metrics.thaiIdentityColumnGap
                    : DriverL01Metrics.identityColumnGap),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.userName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: compact
                      ? (copy.isThai
                            ? DriverL01Metrics.compactThaiIdentityNameSize
                            : DriverL01Metrics.compactEnglishIdentityNameSize)
                      : (copy.isThai
                            ? DriverL01Metrics.thaiIdentityNameSize
                            : DriverL01Metrics.identityNameSize),
                  height: copy.isThai
                      ? DriverL01Metrics.thaiIdentityNameHeight
                      : 1.03,
                  fontWeight: FontWeight.w800,
                  letterSpacing: copy.isThai ? 0 : -1.12,
                ),
              ),
              SizedBox(
                height: copy.isThai
                    ? DriverL01Metrics.thaiIdentitySubTop
                    : DriverL01Metrics.identitySubTop,
              ),
              Text(
                copy.teamDriverProfile,
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: compact
                      ? (copy.isThai
                            ? DriverL01Metrics.compactThaiIdentitySubSize
                            : DriverL01Metrics.compactEnglishIdentitySubSize)
                      : (copy.isThai
                            ? DriverL01Metrics.thaiIdentitySubSize
                            : DriverL01Metrics.identitySubSize),
                  height: copy.isThai
                      ? DriverL01Metrics.thaiIdentitySubHeight
                      : 1.25,
                  fontWeight: copy.isThai ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
              SizedBox(
                height: copy.isThai
                    ? DriverL01Metrics.thaiIdentityStatusTop
                    : DriverL01Metrics.identityStatusTop,
              ),
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
                  Text(
                    copy.activeTeamDriver,
                    style: TextStyle(
                      color: RoundsColors.green,
                      fontSize: compact
                          ? (copy.isThai
                                ? DriverL01Metrics.compactThaiIdentityStatusSize
                                : DriverL01Metrics
                                      .compactEnglishIdentityStatusSize)
                          : (copy.isThai
                                ? DriverL01Metrics.thaiIdentityStatusSize
                                : DriverL01Metrics.identityStatusSize),
                      height: copy.isThai
                          ? DriverL01Metrics.thaiIdentityStatusHeight
                          : 1,
                      fontWeight: copy.isThai
                          ? FontWeight.w700
                          : FontWeight.w800,
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
  const _WorkContext({
    required this.session,
    required this.copy,
    required this.compact,
  });

  final DriverSessionModel session;
  final _L01Copy copy;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('l01-work-context'),
    constraints: BoxConstraints(
      minHeight: copy.isThai ? DriverL01Metrics.thaiWorkMinHeight : 0,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.workPaddingHorizontal,
      vertical: compact
          ? (copy.isThai
                ? DriverL01Metrics.compactThaiWorkPaddingVertical
                : DriverL01Metrics.compactEnglishWorkPaddingVertical)
          : (copy.isThai
                ? DriverL01Metrics.thaiWorkPaddingVertical
                : DriverL01Metrics.workPaddingVertical),
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
                session.teamName ?? copy.teamAssignment,
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: copy.isThai
                      ? DriverL01Metrics.thaiWorkNameSize
                      : DriverL01Metrics.workNameSize,
                  height: copy.isThai ? DriverL01Metrics.thaiWorkNameHeight : 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: copy.isThai ? 0 : -.32,
                ),
              ),
              SizedBox(
                height: copy.isThai
                    ? DriverL01Metrics.thaiWorkSubTop
                    : DriverL01Metrics.workSubTop,
              ),
              Text(
                copy.teamDriver,
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverL01Metrics.workSubSize,
                  height: copy.isThai ? DriverL01Metrics.thaiWorkSubHeight : 1,
                  fontWeight: copy.isThai ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          copy.active,
          style: TextStyle(
            color: RoundsColors.green,
            fontSize: DriverL01Metrics.workStateSize,
            fontWeight: copy.isThai ? FontWeight.w700 : FontWeight.w800,
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
    required this.thai,
    required this.compact,
    this.title,
    this.bottomPadding = DriverL01Metrics.sectionPaddingBottom,
  });

  final String? title;
  final List<_ProfileRowData> rows;
  final bool thai;
  final bool compact;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.sectionPaddingHorizontal,
      compact
          ? (thai
                ? DriverL01Metrics.compactThaiSectionPaddingTop
                : DriverL01Metrics.compactEnglishSectionPaddingTop)
          : (thai
                ? DriverL01Metrics.thaiSectionPaddingTop
                : DriverL01Metrics.sectionPaddingTop),
      compact
          ? DriverL01Metrics.compactHorizontalPadding
          : DriverL01Metrics.sectionPaddingHorizontal,
      bottomPadding != DriverL01Metrics.sectionPaddingBottom
          ? bottomPadding
          : (compact
                ? DriverL01Metrics.compactSectionPaddingBottom
                : (thai
                      ? DriverL01Metrics.thaiSectionPaddingBottom
                      : bottomPadding)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: thai
                  ? DriverL01Metrics.thaiSectionTitleSize
                  : DriverL01Metrics.sectionTitleSize,
              height: thai ? DriverL01Metrics.thaiSectionTitleHeight : 1,
              fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
            ),
          ),
          SizedBox(
            height: thai
                ? DriverL01Metrics.thaiSectionTitleBottom
                : DriverL01Metrics.sectionTitleBottom,
          ),
        ],
        const Divider(height: 1),
        for (final row in rows)
          _ProfileRow(data: row, thai: thai, compact: compact),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.data,
    required this.thai,
    required this.compact,
  });

  final _ProfileRowData data;
  final bool thai;
  final bool compact;

  @override
  Widget build(BuildContext context) => InkWell(
    key: data.key,
    onTap: data.onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact
            ? (thai
                  ? DriverL01Metrics.compactThaiRowMinHeight
                  : DriverL01Metrics.compactEnglishRowMinHeight)
            : (thai
                  ? DriverL01Metrics.thaiRowMinHeight
                  : DriverL01Metrics.rowMinHeight),
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
                      fontSize: compact
                          ? (thai
                                ? DriverL01Metrics.compactThaiRowTitleSize
                                : DriverL01Metrics.compactEnglishRowTitleSize)
                          : (thai
                                ? DriverL01Metrics.thaiRowTitleSize
                                : DriverL01Metrics.rowTitleSize),
                      height: thai ? DriverL01Metrics.thaiRowTitleHeight : 1.2,
                      fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
                    ),
                  ),
                  if (data.subtitle != null) ...[
                    SizedBox(
                      height: thai
                          ? DriverL01Metrics.thaiRowSubTop
                          : DriverL01Metrics.rowSubTop,
                    ),
                    Text(
                      data.subtitle!,
                      style: TextStyle(
                        color: RoundsColors.muted,
                        fontSize: compact
                            ? (thai
                                  ? DriverL01Metrics.compactThaiRowSubSize
                                  : DriverL01Metrics.compactEnglishRowSubSize)
                            : (thai
                                  ? DriverL01Metrics.thaiRowSubSize
                                  : DriverL01Metrics.rowSubSize),
                        height: thai ? DriverL01Metrics.thaiRowSubHeight : 1.3,
                        fontWeight: thai ? FontWeight.w600 : FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (data.value != null)
              Text(
                data.value!,
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverL01Metrics.rowValueSize,
                  height: thai ? DriverL01Metrics.thaiRowValueHeight : 1,
                  fontWeight: thai ? FontWeight.w600 : FontWeight.w700,
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
  const _ProfileBottomNav({
    required this.copy,
    required this.onHome,
    required this.onJobs,
  });

  final _L01Copy copy;
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
            label: copy.home,
            thai: copy.isThai,
            onTap: onHome,
          ),
        ),
        Expanded(
          child: _ProfileNav(
            icon: Icons.location_on_outlined,
            label: copy.jobs,
            thai: copy.isThai,
            onTap: onJobs,
          ),
        ),
        Expanded(
          child: _ProfileNav(
            icon: Icons.schedule,
            label: copy.hours,
            thai: copy.isThai,
          ),
        ),
        Expanded(
          child: _ProfileNav(
            icon: Icons.person_outline,
            label: copy.profile,
            thai: copy.isThai,
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
    required this.thai,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool thai;
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
            fontSize: thai
                ? DriverL01Metrics.thaiBottomNavLabelSize
                : DriverL01Metrics.bottomNavLabelSize,
            height: thai ? DriverL01Metrics.thaiBottomNavLabelHeight : 1,
            fontWeight: thai ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected, required this.copy});

  final HarnessLocale selected;
  final _L01Copy copy;

  @override
  Widget build(BuildContext context) => _ProfileSheet(
    copy: copy,
    kicker: copy.languageKicker,
    title: copy.appLanguage,
    child: Column(
      children: [
        _LanguageChoice(
          label: 'English',
          copy: copy,
          selected: selected == HarnessLocale.english,
          onTap: () => Navigator.of(context).pop(HarnessLocale.english),
        ),
        _LanguageChoice(
          label: 'ไทย',
          copy: copy,
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
    required this.copy,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _L01Copy copy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: copy.isThai
            ? DriverL01Metrics.thaiSheetChoiceMinHeight
            : DriverL01Metrics.sheetChoiceMinHeight,
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
              style: TextStyle(
                fontSize: copy.isThai ? 14.5 : 15,
                height: copy.isThai ? 1.4 : 1,
                fontWeight: copy.isThai ? FontWeight.w700 : FontWeight.w800,
              ),
            ),
            Text(
              selected ? copy.selected : copy.select,
              style: TextStyle(
                color: selected ? RoundsColors.orange : RoundsColors.muted,
                fontSize: 12.5,
                height: copy.isThai ? 1.4 : 1,
                fontWeight: copy.isThai ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet({required this.copy});

  final _L01Copy copy;

  @override
  Widget build(BuildContext context) => _ProfileSheet(
    copy: copy,
    kicker: copy.account,
    title: copy.signOutQuestion,
    subtitle: copy.signOutSubtitle,
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
            child: Text(
              copy.signOut,
              style: TextStyle(
                fontSize: copy.isThai
                    ? DriverL01Metrics.thaiSheetButtonSize
                    : DriverL01Metrics.sheetPrimarySize,
                height: copy.isThai
                    ? DriverL01Metrics.thaiSheetButtonHeight
                    : 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          height: DriverL01Metrics.sheetSecondaryHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              copy.cancel,
              style: TextStyle(
                fontSize: copy.isThai
                    ? DriverL01Metrics.thaiSheetButtonSize
                    : DriverL01Metrics.sheetSecondarySize,
                height: copy.isThai
                    ? DriverL01Metrics.thaiSheetButtonHeight
                    : 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.copy,
    required this.kicker,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final _L01Copy copy;
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
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: copy.isThai
                  ? DriverL01Metrics.thaiSheetKickerSize
                  : DriverL01Metrics.sheetKickerSize,
              height: copy.isThai ? DriverL01Metrics.thaiSheetKickerHeight : 1,
              fontWeight: copy.isThai ? FontWeight.w700 : FontWeight.w800,
              letterSpacing: copy.isThai ? 0 : 1.04,
            ),
          ),
          SizedBox(
            height: copy.isThai
                ? DriverL01Metrics.thaiSheetKickerBottom
                : DriverL01Metrics.sheetKickerBottom,
          ),
          Text(
            title,
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: MediaQuery.sizeOf(context).width <= 340
                  ? (copy.isThai
                        ? DriverL01Metrics.compactThaiSheetTitleSize
                        : DriverL01Metrics.compactEnglishSheetTitleSize)
                  : (copy.isThai
                        ? DriverL01Metrics.thaiSheetTitleSize
                        : DriverL01Metrics.sheetTitleSize),
              height: copy.isThai ? DriverL01Metrics.thaiSheetTitleHeight : 1,
              fontWeight: FontWeight.w800,
              letterSpacing: copy.isThai ? 0 : -1.26,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DriverL01Metrics.sheetSubTop),
            Text(
              subtitle!,
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: DriverL01Metrics.sheetSubSize,
                height: copy.isThai
                    ? DriverL01Metrics.thaiSheetSubHeight
                    : 1.35,
                fontWeight: copy.isThai ? FontWeight.w600 : FontWeight.w700,
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

String _vehicle(DriverSessionModel session, _L01Copy copy) {
  final values = [session.vehicleLabel, session.vehiclePlate]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? copy.noVehicle : values.join(' · ');
}

String _initials(String value, _L01Copy copy) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final result = words.take(2).map((word) => word[0].toUpperCase()).join();
  return result.isEmpty ? copy.initialsFallback : result;
}

class _L01Copy {
  const _L01Copy(this.locale);

  final HarnessLocale locale;
  bool get isThai => locale == HarnessLocale.thai;

  String get account => isThai ? 'บัญชี' : 'ACCOUNT';
  String get profile => isThai ? 'โปรไฟล์' : 'Profile';
  String get teamDriverProfile =>
      isThai ? 'โปรไฟล์คนขับทีม' : 'Team driver profile';
  String get activeTeamDriver =>
      isThai ? 'คนขับทีม · ใช้งานอยู่' : 'Active Team driver';
  String get teamAssignment => isThai ? 'ทีมที่มอบหมาย' : 'Team assignment';
  String get teamDriver => isThai ? 'คนขับทีม' : 'Team driver';
  String get active => isThai ? 'ใช้งานอยู่' : 'Active';
  String get driver => isThai ? 'คนขับ' : 'Driver';
  String get vehicle => isThai ? 'ยานพาหนะ' : 'Vehicle';
  String get noVehicle =>
      isThai ? 'ไม่มีข้อมูลยานพาหนะ' : 'No vehicle details provided';
  String get app => isThai ? 'แอป' : 'App';
  String get language => isThai ? 'ภาษา' : 'Language';
  String get permissions => isThai ? 'การอนุญาต' : 'Permissions';
  String get permissionsSubtitle => isThai
      ? 'ตำแหน่งและกล้องเมื่อจำเป็น'
      : 'Location and contextual camera access';
  String get helpSupport => isThai ? 'ความช่วยเหลือ' : 'Help & support';
  String get supportSubtitle => isThai
      ? 'แชตฝ่ายจัดงานสำหรับรอบนี้'
      : 'Message Operations for this Round';
  String get signOut => isThai ? 'ออกจากระบบ' : 'Sign out';
  String get home => isThai ? 'หน้าแรก' : 'Home';
  String get jobs => isThai ? 'งาน' : 'Jobs';
  String get hours => isThai ? 'ชั่วโมง' : 'Hours';
  String get languageKicker => isThai ? 'ภาษา' : 'LANGUAGE';
  String get appLanguage => isThai ? 'ภาษาในแอป' : 'App language';
  String get selected => isThai ? 'เลือกแล้ว' : 'Selected';
  String get select => isThai ? 'เลือก' : 'Select';
  String get signOutQuestion => isThai ? 'ออกจากระบบ?' : 'Sign out?';
  String get signOutSubtitle => isThai
      ? 'จะกลับไปหน้าลงชื่อเข้าใช้คนขับ'
      : 'You will return to the Driver entry screen.';
  String get cancel => isThai ? 'ยกเลิก' : 'Cancel';
  String get initialsFallback => isThai ? 'ข' : 'DR';
}
