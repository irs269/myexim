import 'package:flutter/widgets.dart';

import '../core/app_scope.dart';

/// Appelle [onRepoChanged] quand les données bancaires changent (ex. après un envoi),
/// pour que les écrans déjà ouverts se rechargent d'eux-mêmes.
mixin RepoListener<T extends StatefulWidget> on State<T> {
  Listenable? _changes;

  void onRepoChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = AppScope.repo(context).changes;
    if (changes != _changes) {
      _changes?.removeListener(_notify);
      _changes = changes..addListener(_notify);
    }
  }

  void _notify() {
    if (mounted) onRepoChanged();
  }

  @override
  void dispose() {
    _changes?.removeListener(_notify);
    super.dispose();
  }
}
