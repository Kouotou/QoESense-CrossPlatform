import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../application/mos_pipeline.dart';
import '../application/self_report.dart';
import '../domain/enums.dart';
import '../domain/ids.dart';
import 'app_services.dart';

/// The iOS in-app survey, shown when the participant taps a survey notification (iOS can't
/// draw over other apps). The 1-5 score uses the reference scale and caption; the optional
/// "what were you doing?" answer is the D-6 self-report. The answer goes to the same native
/// queue as a notification-action tap, with presentationMode NOTIFICATION.
class SurveySheet extends StatefulWidget {
  const SurveySheet({super.key, required this.prompt, required this.inbox, this.clock = DateTime.now});

  final SurveyPrompt prompt;
  final SurveyInbox inbox;
  final DateTime Function() clock;

  /// Shows the sheet; resolves once it is closed.
  static Future<void> show(BuildContext context, SurveyPrompt prompt, SurveyInbox inbox) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SurveySheet(prompt: prompt, inbox: inbox),
  );

  @override
  State<SurveySheet> createState() => _SurveySheetState();
}

class _SurveySheetState extends State<SurveySheet> {
  int? _score;
  SelfReportOption? _context;
  bool _sending = false;

  Future<void> _submit() async {
    final score = _score;
    if (score == null) return;
    setState(() => _sending = true);
    final tapMs = widget.clock().millisecondsSinceEpoch;
    try {
      await widget.inbox.submit(
        SurveyAnswer(
          responseId: newUuidV4(),
          score: score,
          triggerType: widget.prompt.triggerType,
          tapMs: tapMs,
          promptedAtMs: widget.prompt.promptedAtMs > 0 && widget.prompt.promptedAtMs <= tapMs
              ? widget.prompt.promptedAtMs
              : null,
          presentationMode: PresentationMode.notification,
          selfReport: _context?.context,
        ),
      );
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  static String _label(AppLocalizations l10n, SelfReportOption o) => switch (o) {
    SelfReportOption.whatsappCall => l10n.surveyContextWhatsappCall,
    SelfReportOption.whatsappChat => l10n.surveyContextWhatsappChat,
    SelfReportOption.facebook => l10n.surveyContextFacebook,
    SelfReportOption.instagram => l10n.surveyContextInstagram,
    SelfReportOption.zoom => l10n.surveyContextZoom,
    SelfReportOption.googleMeet => l10n.surveyContextGoogleMeet,
    SelfReportOption.somethingElse => l10n.surveyContextSomethingElse,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.surveyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.surveyCaption, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              key: const ValueKey('score'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [for (var i = 1; i <= 5; i++) ButtonSegment(value: i, label: Text('$i'))],
              selected: {?_score},
              onSelectionChanged: (s) => setState(() => _score = s.firstOrNull),
            ),
            const SizedBox(height: 24),
            Text(l10n.surveyContextQuestion, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in SelfReportOption.values)
                  ChoiceChip(
                    key: ValueKey(o),
                    label: Text(_label(l10n, o)),
                    selected: _context == o,
                    onSelected: (on) => setState(() => _context = on ? o : null),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('submitSurvey'),
              onPressed: _score == null || _sending ? null : _submit,
              child: Text(l10n.surveySubmit),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.surveyNotNow)),
          ],
        ),
      ),
    );
  }
}
