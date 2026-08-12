import 'package:flutter/material.dart';

import '../../../../core/theme/nocturne_colors.dart';

/// Placeholder — replaced by the real app shell (title bar, sidebar, header,
/// shift bar) next.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NocturneColors.bg,
      body: Center(
        child: Text(
          'Kassa',
          style: TextStyle(color: NocturneColors.text),
        ),
      ),
    );
  }
}
