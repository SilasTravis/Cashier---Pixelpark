import 'dart:async';

import 'package:flutter/material.dart';

import '../../../generated/l10n.dart';
import '../../theme/nocturne_colors.dart';
import '../lan_bridge_state.dart';

/// Title-bar badge shown only while a remote (LAN bridge) session is relaying
/// on this till: a pulsing amber dot + "Masofaviy sessiya faol". The tooltip
/// says since when. Collapses to nothing otherwise.
///
/// Constructor-injected (no DI lookup) so it is testable on its own.
class LanBridgeIndicator extends StatelessWidget {
  const LanBridgeIndicator({
    super.key,
    required this.states,
    required this.current,
  });

  final Stream<LanBridgeState> states;
  final LanBridgeState Function() current;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LanBridgeState>(
      initialData: current(),
      stream: states,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || state.activeSessionId == null) {
          return const SizedBox.shrink();
        }
        final since = state.activeSince?.toLocal();
        final tooltip = since == null
            ? ''
            : '${since.hour.toString().padLeft(2, '0')}:'
                  '${since.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Tooltip(
            message: tooltip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(),
                const SizedBox(width: 6),
                Text(
                  AppLocalization.of(context).lanBridgeActive,
                  style: TextStyle(
                    fontSize: 12,
                    color: NocturneColors.text.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 8 px amber dot fading in and out once a second. Mounted only while a
/// session is active, so its timer lives exactly as long as the badge.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> {
  static const _period = Duration(seconds: 1);

  Timer? _timer;
  bool _bright = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_period, (_) {
      if (mounted) setState(() => _bright = !_bright);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _bright ? 1 : 0.3,
      duration: _period,
      curve: Curves.easeInOut,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: NocturneColors.warning,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
