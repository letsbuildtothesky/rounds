import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_entry.dart';

class DriverEntryFlowScreen extends StatefulWidget {
  const DriverEntryFlowScreen({
    required this.controller,
    this.previewStage,
    this.previewInvite,
    super.key,
  });

  final HarnessAppController controller;
  final DriverEntryStage? previewStage;
  final DriverTeamInviteModel? previewInvite;

  @override
  State<DriverEntryFlowScreen> createState() => _DriverEntryFlowScreenState();
}

class _DriverEntryFlowScreenState extends State<DriverEntryFlowScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _phone.addListener(_refresh);
    _otp.addListener(_refresh);
  }

  @override
  void dispose() {
    _phone.removeListener(_refresh);
    _otp.removeListener(_refresh);
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final stage = widget.previewStage ?? widget.controller.driverEntryStage;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth <= 340;
            final short = constraints.maxHeight <= 720;
            return Stack(
              children: [
                Column(
                  children: [
                    _EntryTopBar(
                      showBack: stage != DriverEntryStage.phone,
                      onBack: widget.controller.driverEntryBack,
                    ),
                    Expanded(
                      child: switch (stage) {
                        DriverEntryStage.phone => _phoneBody(compact, short),
                        DriverEntryStage.otp => _otpBody(compact, short),
                        DriverEntryStage.path => _pathBody(compact, short),
                        DriverEntryStage.teamInvite => _inviteBody(
                          compact,
                          short,
                        ),
                      },
                    ),
                  ],
                ),
                if (stage != DriverEntryStage.path)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _footer(stage, compact, short),
                  ),
                if (widget.controller.driverError != null)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: stage == DriverEntryStage.path ? 24 : 96,
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('entry-error'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: RoundsColors.ink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.controller.driverError!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _phoneBody(bool compact, bool short) => _EntryBody(
    compact: compact,
    short: short,
    eyebrow: 'Welcome',
    title: 'Your phone number',
    lead: 'Use the number you drive with.',
    child: Column(
      children: [
        SizedBox(
          height: short
              ? 35
              : compact
              ? 44
              : DriverA02A05Metrics.phoneMarginTop,
        ),
        Container(
          key: const Key('a02-phone-line'),
          height: short
              ? 72
              : compact
              ? 78
              : DriverA02A05Metrics.phoneLineHeight,
          padding: EdgeInsets.only(
            bottom: short ? 12 : DriverA02A05Metrics.phoneLinePaddingBottom,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: RoundsColors.ink, width: 2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+66',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: compact ? 23 : DriverA02A05Metrics.countrySize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverA02A05Metrics.countryTracking,
                ),
              ),
              SizedBox(
                width: compact ? 13 : DriverA02A05Metrics.countryMarginRight,
              ),
              Expanded(
                child: TextField(
                  key: const Key('a02-phone-input'),
                  controller: _phone,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThaiPhoneFormatter(),
                  ],
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: compact ? 27 : DriverA02A05Metrics.phoneInputSize,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DriverA02A05Metrics.phoneInputTracking,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '81 234 5678',
                    hintStyle: TextStyle(color: Color(0xFFC1C8CF)),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: DriverA02A05Metrics.trustTop),
        Row(
          children: [
            Icon(
              Icons.check,
              size: DriverA02A05Metrics.trustIconSize,
              color: RoundsColors.green,
            ),
            SizedBox(width: DriverA02A05Metrics.trustGap),
            const Expanded(
              child: Text(
                'One number for every Rounds business.',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverA02A05Metrics.trustSize,
                  height: DriverA02A05Metrics.trustHeight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _otpBody(bool compact, bool short) {
    final digits = _otp.text.replaceAll(RegExp(r'\D'), '');
    final sentTo = widget.controller.driverPhoneE164 ?? '+66812345678';
    final national = sentTo.startsWith('+66') ? sentTo.substring(3) : sentTo;
    return _EntryBody(
      compact: compact,
      short: short,
      eyebrow: 'Verify',
      title: 'Enter the code',
      belowTitle: Padding(
        padding: const EdgeInsets.only(top: DriverA02A05Metrics.otpSentTop),
        child: Text(
          'Sent to +66 ${_formatPhone(national)}',
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverA02A05Metrics.otpSentSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: short
                ? 37
                : compact
                ? 47
                : DriverA02A05Metrics.otpMarginTop,
          ),
          GestureDetector(
            key: const Key('a03-otp-slots'),
            onTap: _otpFocus.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Row(
                  children: List.generate(6, (index) {
                    final value = index < digits.length ? digits[index] : '';
                    final active = index == digits.length && digits.length < 6;
                    return Expanded(
                      child: Container(
                        height: short
                            ? 58
                            : compact
                            ? 64
                            : DriverA02A05Metrics.otpSlotHeight,
                        margin: EdgeInsets.only(
                          left: index == 0 ? 0 : DriverA02A05Metrics.otpSlotGap,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2,
                              color: active
                                  ? RoundsColors.orange
                                  : value.isNotEmpty
                                  ? RoundsColors.ink
                                  : RoundsColors.lineStrong,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: RoundsColors.ink,
                            fontSize: compact
                                ? 35
                                : DriverA02A05Metrics.otpSlotSize,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      key: const Key('a03-otp-input'),
                      controller: _otp,
                      focusNode: _otpFocus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DriverA02A05Metrics.resendTop),
          TextButton(
            key: const Key('a03-resend'),
            onPressed: widget.controller.driverLoading
                ? null
                : widget.controller.resendDriverPhoneOtp,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: RoundsColors.muted,
            ),
            child: const Text.rich(
              TextSpan(
                text: "Didn't get it? ",
                children: [
                  TextSpan(
                    text: 'Send again',
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: DriverA02A05Metrics.resendSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathBody(bool compact, bool short) => _EntryBody(
    compact: compact,
    short: short,
    tight: true,
    eyebrow: 'New driver',
    title: 'How do you drive?',
    child: Container(
      margin: EdgeInsets.only(
        top: short
            ? 24
            : compact
            ? 31
            : DriverA02A05Metrics.pathListTop,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Column(
        children: [
          _PathRow(
            key: const Key('a04-team'),
            index: '01',
            title: 'I drive for a business',
            subtitle: 'I’m part of their delivery team.',
            icon: Icons.apartment_outlined,
            compact: compact,
            short: short,
            onPressed: () {
              if (!widget.controller.selectTeamDriverPath()) {
                _openInviteCodeSheet();
              }
            },
          ),
          _PathRow(
            key: const Key('a04-independent'),
            index: '02',
            title: 'I drive independently',
            subtitle: 'Get jobs from businesses on Rounds.',
            icon: Icons.location_on_outlined,
            compact: compact,
            short: short,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Independent Driver onboarding is not active in this own-fleet release.',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _inviteBody(bool compact, bool short) {
    final invite = widget.previewInvite ?? widget.controller.driverTeamInvite!;
    return _EntryBody(
      compact: compact,
      short: short,
      tight: true,
      eyebrow: 'Team invite',
      title: 'Join ${invite.businessName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('a05-invite-hero'),
            margin: EdgeInsets.only(
              top: short
                  ? 20
                  : compact
                  ? 27
                  : DriverA02A05Metrics.inviteHeroTop,
            ),
            padding: EdgeInsets.only(
              top: short ? 19 : DriverA02A05Metrics.inviteHeroPaddingTop,
              bottom: short ? 19 : DriverA02A05Metrics.inviteHeroPaddingBottom,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: RoundsColors.line),
                bottom: BorderSide(color: RoundsColors.line),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: compact
                          ? 58
                          : DriverA02A05Metrics.merchantMarkSize,
                      height: compact
                          ? 58
                          : DriverA02A05Metrics.merchantMarkSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RoundsColors.ink,
                        borderRadius: BorderRadius.circular(
                          DriverA02A05Metrics.merchantMarkRadius,
                        ),
                      ),
                      child: Text(
                        invite.businessInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DriverA02A05Metrics.merchantMarkTextSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: DriverA02A05Metrics.merchantGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite.businessName,
                            style: TextStyle(
                              color: RoundsColors.ink,
                              fontSize: compact
                                  ? 21
                                  : DriverA02A05Metrics.merchantTitleSize,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.96,
                            ),
                          ),
                          const SizedBox(
                            height: DriverA02A05Metrics.merchantMetaTop,
                          ),
                          Text(
                            invite.locationLabel,
                            style: const TextStyle(
                              color: RoundsColors.muted,
                              fontSize: DriverA02A05Metrics.merchantMetaSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(
                    top: DriverA02A05Metrics.verifiedTop,
                  ),
                  padding: const EdgeInsets.only(
                    top: DriverA02A05Metrics.verifiedPaddingTop,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: RoundsColors.line)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: DriverA02A05Metrics.verifiedIconSize,
                        height: DriverA02A05Metrics.verifiedIconSize,
                        child: Icon(
                          Icons.check,
                          size: 23,
                          color: RoundsColors.green,
                        ),
                      ),
                      SizedBox(width: DriverA02A05Metrics.verifiedGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite verified',
                              style: TextStyle(
                                color: RoundsColors.ink,
                                fontSize: DriverA02A05Metrics.verifiedTitleSize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(
                              height: DriverA02A05Metrics.verifiedMetaTop,
                            ),
                            Text(
                              'This business invited you to its delivery team.',
                              style: TextStyle(
                                color: RoundsColors.muted,
                                fontSize: DriverA02A05Metrics.verifiedMetaSize,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DriverA02A05Metrics.alternateTop),
          TextButton(
            key: const Key('a05-another-code'),
            onPressed: _openInviteCodeSheet,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: RoundsColors.inkSecondary,
            ),
            child: const Text(
              'Use another invite code',
              style: TextStyle(
                fontSize: DriverA02A05Metrics.alternateSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(DriverEntryStage stage, bool compact, bool short) {
    final phoneReady = _phone.text.replaceAll(RegExp(r'\D'), '').length == 9;
    final otpReady = _otp.text.replaceAll(RegExp(r'\D'), '').length == 6;
    final enabled =
        !widget.controller.driverLoading &&
        switch (stage) {
          DriverEntryStage.phone => phoneReady,
          DriverEntryStage.otp => otpReady,
          DriverEntryStage.teamInvite =>
            (widget.previewInvite ?? widget.controller.driverTeamInvite) !=
                null,
          DriverEntryStage.path => false,
        };
    final label = switch (stage) {
      DriverEntryStage.teamInvite =>
        'Join ${(widget.previewInvite ?? widget.controller.driverTeamInvite)?.businessName ?? 'business'}',
      _ => 'Continue',
    };
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : DriverA02A05Metrics.footerPaddingHorizontal,
          short ? 10 : DriverA02A05Metrics.footerPaddingTop,
          compact ? 16 : DriverA02A05Metrics.footerPaddingHorizontal,
          DriverA02A05Metrics.footerPaddingBottom,
        ),
        child: SizedBox(
          height: short
              ? 54
              : compact
              ? 58
              : DriverA02A05Metrics.buttonHeight,
          child: FilledButton(
            key: Key('entry-primary-${stage.name}'),
            onPressed: enabled
                ? () {
                    switch (stage) {
                      case DriverEntryStage.phone:
                        widget.controller.requestDriverPhoneOtp(_phone.text);
                        break;
                      case DriverEntryStage.otp:
                        widget.controller.verifyDriverPhoneOtp(_otp.text);
                        break;
                      case DriverEntryStage.teamInvite:
                        widget.controller.acceptDriverTeamInvite();
                        break;
                      case DriverEntryStage.path:
                        break;
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: RoundsColors.ink,
              disabledBackgroundColor: const Color(0xFFDCE1E5),
              disabledForegroundColor: const Color(0xFF9AA4AE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DriverA02A05Metrics.buttonRadius,
                ),
              ),
            ),
            child: widget.controller.driverLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: DriverA02A05Metrics.buttonSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: DriverA02A05Metrics.buttonTracking,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInviteCodeSheet() async {
    final code = TextEditingController();
    var ready = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x4D0A121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DriverA02A05Metrics.sheetRadius),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          key: const Key('a05-code-sheet'),
          padding: EdgeInsets.fromLTRB(
            DriverA02A05Metrics.sheetPaddingHorizontal,
            DriverA02A05Metrics.sheetPaddingTop,
            DriverA02A05Metrics.sheetPaddingHorizontal,
            MediaQuery.viewInsetsOf(context).bottom +
                DriverA02A05Metrics.sheetPaddingBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: DriverA02A05Metrics.sheetGrabWidth,
                  height: DriverA02A05Metrics.sheetGrabHeight,
                  margin: const EdgeInsets.only(
                    bottom: DriverA02A05Metrics.sheetGrabBottom,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DDE2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'BUSINESS INVITE',
                style: TextStyle(
                  color: RoundsColors.orange,
                  fontSize: DriverA02A05Metrics.sheetKickerSize,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: DriverA02A05Metrics.sheetKickerBottom),
              const Text(
                'Enter invite code',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverA02A05Metrics.sheetTitleSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: DriverA02A05Metrics.sheetSubtitleTop),
              const Text(
                'Use the six-digit code from your business.',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverA02A05Metrics.sheetSubtitleSize,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                height: DriverA02A05Metrics.sheetCodeHeight,
                margin: const EdgeInsets.only(
                  top: DriverA02A05Metrics.sheetCodeTop,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: RoundsColors.ink, width: 2),
                  ),
                ),
                child: TextField(
                  key: const Key('a05-code-input'),
                  controller: code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (value) => setSheetState(
                    () =>
                        ready = value.replaceAll(RegExp(r'\D'), '').length == 6,
                  ),
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverA02A05Metrics.sheetCodeSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6.1,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '000000',
                    hintStyle: TextStyle(color: Color(0xFFC4CBD2)),
                  ),
                ),
              ),
              const SizedBox(height: DriverA02A05Metrics.sheetPrimaryTop),
              SizedBox(
                height: DriverA02A05Metrics.sheetPrimaryHeight,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('a05-use-code'),
                  onPressed: ready && !widget.controller.driverLoading
                      ? () async {
                          final resolved = await widget.controller
                              .resolveDriverTeamInvite(code.text);
                          if (resolved && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }
                      : null,
                  child: const Text('Use code'),
                ),
              ),
              SizedBox(
                height: DriverA02A05Metrics.sheetSecondaryHeight,
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    code.dispose();
  }

  String _formatPhone(String digits) {
    if (digits.length <= 2) return digits;
    if (digits.length <= 5) {
      return '${digits.substring(0, 2)} ${digits.substring(2)}';
    }
    return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
  }
}

class _EntryTopBar extends StatelessWidget {
  const _EntryTopBar({required this.showBack, required this.onBack});

  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('entry-topbar'),
    height: DriverA02A05Metrics.topBarHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverA02A05Metrics.topBarPaddingHorizontal,
      ),
      child: Row(
        children: [
          if (showBack)
            Transform.translate(
              offset: const Offset(-7, 0),
              child: SizedBox.square(
                dimension: DriverA02A05Metrics.backSize,
                child: IconButton(
                  key: const Key('entry-back'),
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: DriverA02A05Metrics.backIconSize,
                  ),
                ),
              ),
            ),
          if (showBack) const SizedBox(width: 5),
          const _EntryBrand(),
        ],
      ),
    ),
  );
}

class _EntryBrand extends StatelessWidget {
  const _EntryBrand();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Rounds',
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: DriverA02A05Metrics.brandSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverA02A05Metrics.brandTracking,
        ),
      ),
      Container(
        width: DriverA02A05Metrics.dotSize,
        height: DriverA02A05Metrics.dotSize,
        margin: const EdgeInsets.only(
          left: DriverA02A05Metrics.dotMarginLeft,
          bottom: DriverA02A05Metrics.dotMarginBottom,
        ),
        decoration: const BoxDecoration(
          color: RoundsColors.orange,
          shape: BoxShape.circle,
        ),
      ),
    ],
  );
}

class _EntryBody extends StatelessWidget {
  const _EntryBody({
    required this.compact,
    required this.short,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.tight = false,
    this.lead,
    this.belowTitle,
  });

  final bool compact;
  final bool short;
  final bool tight;
  final String eyebrow;
  final String title;
  final String? lead;
  final Widget? belowTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = short
        ? tight
              ? 18.0
              : 27.0
        : tight
        ? DriverA02A05Metrics.tightBodyPaddingTop
        : compact
        ? 31.0
        : DriverA02A05Metrics.bodyPaddingTop;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : DriverA02A05Metrics.bodyPaddingHorizontal,
        top,
        compact ? 16 : DriverA02A05Metrics.bodyPaddingHorizontal,
        DriverA02A05Metrics.bodyPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: RoundsColors.orange,
              fontSize: DriverA02A05Metrics.eyebrowSize,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: DriverA02A05Metrics.eyebrowTracking,
            ),
          ),
          const SizedBox(height: DriverA02A05Metrics.eyebrowBottom),
          Text(
            title,
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: short
                  ? 38
                  : compact
                  ? 40
                  : DriverA02A05Metrics.titleSize,
              height: DriverA02A05Metrics.titleHeight,
              fontWeight: FontWeight.w900,
              letterSpacing: DriverA02A05Metrics.titleTracking,
            ),
          ),
          if (lead != null) ...[
            SizedBox(height: short ? 12 : DriverA02A05Metrics.leadTop),
            Text(
              lead!,
              style: TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: short ? 15 : DriverA02A05Metrics.leadSize,
                height: DriverA02A05Metrics.leadHeight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          ?belowTitle,
          child,
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.compact,
    required this.short,
    required this.onPressed,
    super.key,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final bool short;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: short
        ? 124
        : compact
        ? 143
        : DriverA02A05Metrics.pathRowHeight,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: short
              ? 15
              : compact
              ? 19
              : DriverA02A05Metrics.pathRowPaddingVertical,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: RoundsColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    index,
                    style: const TextStyle(
                      color: RoundsColors.orange,
                      fontSize: DriverA02A05Metrics.pathIndexSize,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: DriverA02A05Metrics.pathIndexTracking,
                    ),
                  ),
                  SizedBox(
                    height: short ? 7 : DriverA02A05Metrics.pathIndexBottom,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: short
                          ? 22
                          : compact
                          ? 24
                          : DriverA02A05Metrics.pathTitleSize,
                      height: DriverA02A05Metrics.pathTitleHeight,
                      fontWeight: FontWeight.w800,
                      letterSpacing: DriverA02A05Metrics.pathTitleTracking,
                    ),
                  ),
                  SizedBox(
                    height: short ? 7 : DriverA02A05Metrics.pathSubtitleTop,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: RoundsColors.muted,
                      fontSize: short
                          ? 12.5
                          : compact
                          ? 13
                          : DriverA02A05Metrics.pathSubtitleSize,
                      height: DriverA02A05Metrics.pathSubtitleHeight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 14 : DriverA02A05Metrics.pathColumnGap),
            Container(
              width: compact ? 48 : DriverA02A05Metrics.pathIconSize,
              height: compact ? 48 : DriverA02A05Metrics.pathIconSize,
              decoration: BoxDecoration(
                border: Border.all(color: RoundsColors.line),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 27, color: RoundsColors.inkSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThaiPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 9) digits = digits.substring(0, 9);
    final formatted = digits.length <= 2
        ? digits
        : digits.length <= 5
        ? '${digits.substring(0, 2)} ${digits.substring(2)}'
        : '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
