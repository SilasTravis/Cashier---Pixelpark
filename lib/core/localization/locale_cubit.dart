import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../local_source/local_source.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._localSource)
    : super(Locale(_localSource.getLanguageCode()));

  final LocalSource _localSource;

  Future<void> changeLanguage(String languageCode) async {
    if (state.languageCode == languageCode) return;
    await _localSource.setLanguageCode(languageCode);
    emit(Locale(languageCode));
  }
}
