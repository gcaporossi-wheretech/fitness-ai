import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/storage/hive_storage.dart';

/// App locale, persisted in Hive. Defaults to Italian.
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() {
    final code = HiveStorage.user.get(_key);
    return Locale((code is String && code.isNotEmpty) ? code : 'it');
  }

  /// Change the app language ('it' or 'en') and persist it.
  void setLanguage(String code) {
    HiveStorage.user.put(_key, code);
    state = Locale(code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
