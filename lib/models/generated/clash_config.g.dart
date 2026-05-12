// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../clash_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClashConfigImpl _$$ClashConfigImplFromJson(Map<String, dynamic> json) =>
    _$ClashConfigImpl(
      port: (json['port'] as num?)?.toInt() ?? 7890,
      socksPort: (json['socksPort'] as num?)?.toInt() ?? 7891,
      redirPort: (json['redirPort'] as num?)?.toInt() ?? 0,
      tproxyPort: (json['tproxyPort'] as num?)?.toInt() ?? 0,
      mixedPort: (json['mixedPort'] as num?)?.toInt() ?? 0,
      allowLan: json['allowLan'] as bool? ?? true,
      mode: json['mode'] as String? ?? "rule",
      logLevel: json['logLevel'] as String? ?? "info",
      externalController:
          json['externalController'] as String? ?? "127.0.0.1:9090",
      secret: json['secret'] as String? ?? "",
    );

Map<String, dynamic> _$$ClashConfigImplToJson(_$ClashConfigImpl instance) =>
    <String, dynamic>{
      'port': instance.port,
      'socksPort': instance.socksPort,
      'redirPort': instance.redirPort,
      'tproxyPort': instance.tproxyPort,
      'mixedPort': instance.mixedPort,
      'allowLan': instance.allowLan,
      'mode': instance.mode,
      'logLevel': instance.logLevel,
      'externalController': instance.externalController,
      'secret': instance.secret,
    };
