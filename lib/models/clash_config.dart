import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/clash_config.freezed.dart';
part 'generated/clash_config.g.dart';

@freezed
class ClashConfig with _$ClashConfig {
  const factory ClashConfig({
    @Default(7890) int port,
    @Default(7891) int socksPort,
    @Default("rule") String mode,
    @Default("info") String logLevel,
  }) = _ClashConfig;

  factory ClashConfig.fromJson(Map<String, dynamic> json) =>
      _$ClashConfigFromJson(json);
}
