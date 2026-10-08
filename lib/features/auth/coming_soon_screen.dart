import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../shared/widgets.dart';
import 'auth_widgets.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AuthScaffold(
      title: title,
      subtitle: s.comingSoonBody,
      children: const [SizedBox(height: 40), Center(child: CircleIcon(icon: Icons.hourglass_empty, size: 96))],
    );
  }
}
