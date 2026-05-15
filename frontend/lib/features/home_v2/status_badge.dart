import 'package:flutter/material.dart';

import '../../core/ui_tokens.dart';

enum StatusTone { active, warning, info, success, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  Color _bg(BuildContext context) {
    switch (tone) {
      case StatusTone.success:
        return UiTokens.success.withOpacity(0.18);
      case StatusTone.active:
        return UiTokens.accent.withOpacity(0.18);
      case StatusTone.warning:
        return UiTokens.warning.withOpacity(0.18);
      case StatusTone.info:
        return UiTokens.info.withOpacity(0.18);
      case StatusTone.neutral:
        return UiTokens.surface(context);
    }
  }

  Color _fg(BuildContext context) {
    switch (tone) {
      case StatusTone.success:
        return UiTokens.success;
      case StatusTone.active:
      case StatusTone.warning:
        return UiTokens.accent;
      case StatusTone.info:
        return UiTokens.info;
      case StatusTone.neutral:
        return UiTokens.muted(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _fg(context),
        ),
      ),
    );
  }
}
