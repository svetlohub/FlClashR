// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileImpl _$$ProfileImplFromJson(Map<String, dynamic> json) =>
    _$ProfileImpl(
      id: json['id'] as String,
      label: json['label'] as String?,
      currentGroupName: json['currentGroupName'] as String?,
      url: json['url'] as String? ?? "",
      lastUpdateDate: json['lastUpdateDate'] == null
          ? null
          : DateTime.parse(json['lastUpdateDate'] as String),
      autoUpdateDuration:
          _durationFromJson((json['autoUpdateDuration'] as num).toInt()),
      subscriptionInfo: json['subscriptionInfo'] == null
          ? null
          : SubscriptionInfo.fromJson(
              json['subscriptionInfo'] as Map<String, dynamic>),
      autoUpdate: json['autoUpdate'] as bool? ?? true,
      selectedMap: (json['selectedMap'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      unfoldSet: json['unfoldSet'] == null
          ? const {}
          : _setFromJson(json['unfoldSet'] as List),
      overrideData: json['overrideData'] == null
          ? const OverrideData()
          : OverrideData.fromJson(json['overrideData'] as Map<String, dynamic>),
      providerHeaders: (json['providerHeaders'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'currentGroupName': instance.currentGroupName,
      'url': instance.url,
      'lastUpdateDate': instance.lastUpdateDate?.toIso8601String(),
      'autoUpdateDuration': _durationToJson(instance.autoUpdateDuration),
      'subscriptionInfo': instance.subscriptionInfo,
      'autoUpdate': instance.autoUpdate,
      'selectedMap': instance.selectedMap,
      'unfoldSet': _setToJson(instance.unfoldSet),
      'overrideData': instance.overrideData,
      'providerHeaders': instance.providerHeaders,
    };
