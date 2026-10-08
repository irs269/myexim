import 'package:flutter/widgets.dart';

import '../data/bank_repository.dart';
import 'l10n/strings.dart';
import 'session.dart';

/// Dépendances globales : `AppScope.repo(context)`, `AppScope.of(context).session`…
/// Les widgets qui lisent la langue sont reconstruits quand elle change.
class AppScope extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppScope({
    super.key,
    required this.repository,
    required this.session,
    required ValueNotifier<AppLanguage> language,
    required super.child,
  }) : super(notifier: language);

  final BankRepository repository;
  final SessionController session;
  ValueNotifier<AppLanguage> get language => notifier!;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static BankRepository repo(BuildContext context) => of(context).repository;
}
