import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

part 'generated/state.freezed.dart';
part 'generated/state.g.dart';

@freezed
class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool isInit,
    @Default(false) bool isCoreRunning,
  }) = _AppState;

  factory AppState.fromJson(Map<String, dynamic> json) => _$AppStateFromJson(json);
}

@freezed
class AppBarState with _$AppBarState {
  const factory AppBarState({
    @Default("") String title,
    @Default(true) bool showBack,
  }) = _AppBarState;
}

@freezed
class ThemeProps with _$ThemeProps {
  const factory ThemeProps({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(true) bool pureBlack,
  }) = _ThemeProps;
}
