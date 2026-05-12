import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/clash_config.freezed.dart';
part 'generated/clash_config.g.dart';

@freezed
class ClashConfig with _$ClashConfig {
  const factory ClashConfig({
    @Default(7890) int port,
    @Default(7891) int socksPort,
    @Default(0) int redirPort,
    @Default(0) int tproxyPort,
    @Default(0) int mixedPort,
    @Default(true) bool allowLan,
    @Default("rule") String mode,
    @Default("info") String logLevel,
    @Default("127.0.0.1:9090") String externalController,
    @Default("") String secret,
  }) = _ClashConfig;

  factory ClashConfig.fromJson(Map<String, dynamic> json) =>
      _$ClashConfigFromJson(json);
}
