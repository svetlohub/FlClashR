// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../clash_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClashConfigImpl _$$ClashConfigImplFromJson(Map<String, dynamic> json) =>
    _$ClashConfigImpl(
      port: (json['port'] as num?)?.toInt() ?? 7890,
      socksPort: (json['socksPort'] as num?)?.toInt() ?? 7891,
      mode: json['mode'] as String? ?? "rule",
      logLevel: json['logLevel'] as String? ?? "info",
    );

Map<String, dynamic> _$$ClashConfigImplToJson(_$ClashConfigImpl instance) =>
    <String, dynamic>{
      'port': instance.port,
      'socksPort': instance.socksPort,
      'mode': instance.mode,
      'logLevel': instance.logLevel,
    };
