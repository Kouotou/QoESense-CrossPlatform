import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/capabilities.dart';
import '../domain/enums.dart';
import 'app_services.dart';

/// One thing the study needs from the participant.
enum SetupItem { location, phone, backgroundLocation, notifications, usageAccess, battery, overlay, backgroundPopups }

/// Shown right after onboarding (owner request, 2026-11-25): a participant finished every
/// approval but didn't realise they had reached the app. A smiling QoESense star says
/// welcome, then the screen checks that everything was really allowed:
/// - all allowed: "you are now done with all the steps" and a Continue button;
/// - something missing: each missing item with a button to allow it. Coming back from a
///   settings screen re-checks, and the welcome plays again once everything is allowed.
///
/// Existing Android installs see it once after the update, so participants whose rating
/// pop-up was blocked get the chance to fix it.
class WelcomeCheckScreen extends StatefulWidget {
  const WelcomeCheckScreen({super.key, required this.services, required this.onContinue});

  final AppServices services;
  final Future<void> Function() onContinue;

  /// What is still missing, given the capability report, the battery exemption and (Android,
  /// Xiaomi) the background pop-up status. Pure, so it's unit-tested.
  static List<SetupItem> missing({
    required ClientPlatform platform,
    required PlatformCapabilities caps,
    required bool batteryOk,
    String? backgroundPopups,
  }) {
    bool lacks(FieldGroup g) => caps.of(g) == FieldAvailability.permissionMissing;
    final ios = platform == ClientPlatform.ios;
    return [
      if (lacks(FieldGroup.location) || (!ios && lacks(FieldGroup.radioSignal))) SetupItem.location,
      if (!ios && lacks(FieldGroup.radioAccessTechnology)) SetupItem.phone,
      if (lacks(FieldGroup.backgroundLocation)) SetupItem.backgroundLocation,
      if (lacks(FieldGroup.notifications)) SetupItem.notifications,
      if (!ios && lacks(FieldGroup.foregroundApp)) SetupItem.usageAccess,
      if (!ios && !batteryOk) SetupItem.battery,
      if (!ios && lacks(FieldGroup.surveyOverlay)) SetupItem.overlay,
      if (!ios && backgroundPopups == 'denied') SetupItem.backgroundPopups,
    ];
  }

  @override
  State<WelcomeCheckScreen> createState() => _WelcomeCheckScreenState();
}

class _WelcomeCheckScreenState extends State<WelcomeCheckScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  /// The welcome plays for at least this long before the result shows.
  static const _checkingMs = 1600;

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  List<SetupItem>? _missing;
  bool _checking = true;
  bool _busy = false;

  AppServices get _s => widget.services;
  bool get _ios => _s.platform == ClientPlatform.ios;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check(welcome: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wiggle.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_check(welcome: false));
  }

  Future<List<SetupItem>> _load() async {
    final caps = await _s.capabilities.load();
    final battery = _ios ? true : await _s.permissions.isBatteryOptimizationIgnored();
    final popups = await _s.backgroundPopupStatus?.call().catchError((Object _) => 'unknown');
    return WelcomeCheckScreen.missing(platform: _s.platform, caps: caps, batteryOk: battery, backgroundPopups: popups);
  }

  /// [welcome]: the first check, with the full welcome. Later checks (back from settings)
  /// replay the welcome only when they complete the setup.
  Future<void> _check({required bool welcome}) async {
    if (welcome) {
      setState(() => _checking = true);
      unawaited(_wiggle.forward(from: 0));
    }
    final results = await Future.wait([
      _load(),
      if (welcome) Future<void>.delayed(const Duration(milliseconds: _checkingMs)),
    ]);
    final missing = results.first as List<SetupItem>;
    if (!mounted) return;
    final completedNow = !welcome && missing.isEmpty && (_missing?.isNotEmpty ?? false);
    setState(() {
      _missing = missing;
      _checking = false;
    });
    if (completedNow) unawaited(_wiggle.forward(from: 0));
  }

  Future<void> _fix(SetupItem item) async {
    _busy = true;
    try {
      switch (item) {
        case SetupItem.location || SetupItem.phone:
          await _s.permissions.requestForeground();
          await _thenSettingsIfStillMissing(item);
        case SetupItem.backgroundLocation || SetupItem.notifications:
          await _s.permissions.requestBackground();
          await _thenSettingsIfStillMissing(item);
        case SetupItem.usageAccess:
          await _s.control.openSettings(SettingsTarget.usageAccess);
        case SetupItem.battery:
          await _s.control.openSettings(SettingsTarget.batteryOptimization);
        case SetupItem.overlay:
          await _s.control.openSettings(SettingsTarget.overlay);
        case SetupItem.backgroundPopups:
          await _s.control.openSettings(SettingsTarget.backgroundPopup);
      }
    } finally {
      _busy = false;
    }
    await _check(welcome: false);
  }

  /// A permission refused twice can't be asked again: the app's settings page is the only way.
  Future<void> _thenSettingsIfStillMissing(SetupItem item) async {
    if ((await _load()).contains(item)) await _s.control.openSettings(SettingsTarget.appDetails);
  }

  String _label(AppLocalizations l10n, SetupItem item) => switch (item) {
    SetupItem.location => l10n.checkLocation,
    SetupItem.phone => l10n.checkPhone,
    SetupItem.backgroundLocation => l10n.checkBackgroundLocation,
    SetupItem.notifications => l10n.checkNotifications,
    SetupItem.usageAccess => l10n.checkUsageAccess,
    SetupItem.battery => l10n.checkBattery,
    SetupItem.overlay => l10n.checkOverlay,
    SetupItem.backgroundPopups => l10n.checkBackgroundPopups,
  };

  String? _hint(AppLocalizations l10n, SetupItem item) => switch (item) {
    SetupItem.backgroundLocation => l10n.checkBackgroundLocationHint,
    SetupItem.backgroundPopups => l10n.checkBackgroundPopupsHint,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final missing = _missing;
    final done = !_checking && missing != null && missing.isEmpty;
    final Widget body;
    if (_checking || missing == null) {
      body = Column(
        key: const ValueKey('checking'),
        children: [
          Text(l10n.welcomeCheckChecking, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ],
      );
    } else if (done) {
      body = Column(
        key: const ValueKey('done'),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Flexible(
                child: Text(l10n.welcomeCheckDone, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.welcomeCheckDoneDetail, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          FilledButton(
            key: const ValueKey('welcomeContinue'),
            style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            onPressed: widget.onContinue,
            child: Text(l10n.welcomeCheckContinue),
          ),
        ],
      );
    } else {
      body = Column(
        key: const ValueKey('missing'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.welcomeCheckMissingTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.welcomeCheckMissingBody, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          for (final item in missing)
            Card(
              key: ValueKey('missing:${item.name}'),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label(l10n, item), style: theme.textTheme.bodyLarge),
                          if (_hint(l10n, item) case final hint?)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(hint, style: theme.textTheme.bodySmall),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: () => _fix(item), child: Text(l10n.welcomeCheckAllow)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey('welcomeSkip'),
            onPressed: widget.onContinue,
            child: Text(l10n.welcomeCheckSkip),
          ),
        ],
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(child: _SpeechBubble(text: done || _checking ? l10n.welcomeCheckHello : l10n.welcomeCheckAlmost)),
            const SizedBox(height: 6),
            Center(child: WelcomeMascot(animation: _wiggle, size: 150)),
            const SizedBox(height: 18),
            Text(l10n.welcomeCheckTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: body),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
          child: Text(
            text,
            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        CustomPaint(size: const Size(18, 10), painter: _BubbleTail(scheme.primaryContainer)),
      ],
    );
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}

/// The QoESense icon (Cameroon flag, yellow star) with a smiling face on the star. [animation]
/// runs 0 → 1 once per welcome: a happy shake that settles, with a little hop and a wink.
class WelcomeMascot extends StatelessWidget {
  const WelcomeMascot({super.key, required this.animation, this.size = 150});
  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'QoESense',
    image: true,
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final fade = 1 - Curves.easeOut.transform(t);
        final angle = math.sin(t * math.pi * 8) * 0.16 * fade;
        final hop = -math.sin(t * math.pi * 4).abs() * 10 * fade;
        final scale = 1 + 0.06 * math.sin(t * math.pi) * fade;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: CustomPaint(
                size: Size.square(size),
                painter: _MascotPainter(wink: t > 0.55 && t < 0.72),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.wink});
  final bool wink;

  static const _green = Color(0xFF007A5E);
  static const _red = Color(0xFFCE1126);
  static const _yellow = Color(0xFFFCD116);
  static const _ink = Color(0xFF00503C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22));
    canvas.drawRRect(rect.shift(Offset(0, s * 0.03)), Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(Rect.fromLTWH(0, 0, s / 3, s), Paint()..color = _green);
    canvas.drawRect(Rect.fromLTWH(s / 3, 0, s / 3 + 0.5, s), Paint()..color = _red);
    canvas.drawRect(Rect.fromLTWH(2 * s / 3, 0, s / 3 + 0.5, s), Paint()..color = _yellow);
    canvas.restore();

    // The star: five points, slightly fuller than a flag star so the face fits.
    final c = Offset(s / 2, s * 0.53);
    final outer = s * 0.43, inner = s * 0.2;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFF2B705));
    canvas.drawPath(
      star,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeJoin = StrokeJoin.round,
    );

    // Face.
    final eyeY = c.dy - s * 0.035, eyeDx = s * 0.075;
    final ink = Paint()..color = _ink;
    final left = Offset(c.dx - eyeDx, eyeY), right = Offset(c.dx + eyeDx, eyeY);
    canvas.drawOval(Rect.fromCenter(center: left, width: s * 0.06, height: s * 0.085), ink);
    canvas.drawCircle(left + Offset(s * 0.01, -s * 0.015), s * 0.012, Paint()..color = Colors.white);
    if (wink) {
      canvas.drawArc(
        Rect.fromCenter(center: right, width: s * 0.07, height: s * 0.05),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawOval(Rect.fromCenter(center: right, width: s * 0.06, height: s * 0.085), ink);
      canvas.drawCircle(right + Offset(s * 0.01, -s * 0.015), s * 0.012, Paint()..color = Colors.white);
    }
    // Cheeks.
    final blush = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx - s * 0.13, c.dy + s * 0.035), width: s * 0.06, height: s * 0.035),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx + s * 0.13, c.dy + s * 0.035), width: s * 0.06, height: s * 0.035),
      blush,
    );
    // Open smile.
    final mouth = Path()
      ..moveTo(c.dx - s * 0.075, c.dy + s * 0.03)
      ..quadraticBezierTo(c.dx, c.dy + s * 0.14, c.dx + s * 0.075, c.dy + s * 0.03)
      ..close();
    canvas.drawPath(mouth, ink);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.075), width: s * 0.06, height: s * 0.03),
      Paint()..color = const Color(0xFFE5534B),
    );
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.wink != wink;
}
