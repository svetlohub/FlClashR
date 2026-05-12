// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../clash_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ClashConfig _$ClashConfigFromJson(Map<String, dynamic> json) {
  return _ClashConfig.fromJson(json);
}

/// @nodoc
mixin _$ClashConfig {
  int get port => throw _privateConstructorUsedError;
  int get socksPort => throw _privateConstructorUsedError;
  String get mode => throw _privateConstructorUsedError;
  String get logLevel => throw _privateConstructorUsedError;

  /// Serializes this ClashConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ClashConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClashConfigCopyWith<ClashConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClashConfigCopyWith<$Res> {
  factory $ClashConfigCopyWith(
          ClashConfig value, $Res Function(ClashConfig) then) =
      _$ClashConfigCopyWithImpl<$Res, ClashConfig>;
  @useResult
  $Res call({int port, int socksPort, String mode, String logLevel});
}

/// @nodoc
class _$ClashConfigCopyWithImpl<$Res, $Val extends ClashConfig>
    implements $ClashConfigCopyWith<$Res> {
  _$ClashConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClashConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? port = null,
    Object? socksPort = null,
    Object? mode = null,
    Object? logLevel = null,
  }) {
    return _then(_value.copyWith(
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      socksPort: null == socksPort
          ? _value.socksPort
          : socksPort // ignore: cast_nullable_to_non_nullable
              as int,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      logLevel: null == logLevel
          ? _value.logLevel
          : logLevel // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClashConfigImplCopyWith<$Res>
    implements $ClashConfigCopyWith<$Res> {
  factory _$$ClashConfigImplCopyWith(
          _$ClashConfigImpl value, $Res Function(_$ClashConfigImpl) then) =
      __$$ClashConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int port, int socksPort, String mode, String logLevel});
}

/// @nodoc
class __$$ClashConfigImplCopyWithImpl<$Res>
    extends _$ClashConfigCopyWithImpl<$Res, _$ClashConfigImpl>
    implements _$$ClashConfigImplCopyWith<$Res> {
  __$$ClashConfigImplCopyWithImpl(
      _$ClashConfigImpl _value, $Res Function(_$ClashConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of ClashConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? port = null,
    Object? socksPort = null,
    Object? mode = null,
    Object? logLevel = null,
  }) {
    return _then(_$ClashConfigImpl(
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      socksPort: null == socksPort
          ? _value.socksPort
          : socksPort // ignore: cast_nullable_to_non_nullable
              as int,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      logLevel: null == logLevel
          ? _value.logLevel
          : logLevel // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ClashConfigImpl implements _ClashConfig {
  const _$ClashConfigImpl(
      {this.port = 7890,
      this.socksPort = 7891,
      this.mode = "rule",
      this.logLevel = "info"});

  factory _$ClashConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClashConfigImplFromJson(json);

  @override
  @JsonKey()
  final int port;
  @override
  @JsonKey()
  final int socksPort;
  @override
  @JsonKey()
  final String mode;
  @override
  @JsonKey()
  final String logLevel;

  @override
  String toString() {
    return 'ClashConfig(port: $port, socksPort: $socksPort, mode: $mode, logLevel: $logLevel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClashConfigImpl &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.socksPort, socksPort) ||
                other.socksPort == socksPort) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.logLevel, logLevel) ||
                other.logLevel == logLevel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, port, socksPort, mode, logLevel);

  /// Create a copy of ClashConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClashConfigImplCopyWith<_$ClashConfigImpl> get copyWith =>
      __$$ClashConfigImplCopyWithImpl<_$ClashConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClashConfigImplToJson(
      this,
    );
  }
}

abstract class _ClashConfig implements ClashConfig {
  const factory _ClashConfig(
      {final int port,
      final int socksPort,
      final String mode,
      final String logLevel}) = _$ClashConfigImpl;

  factory _ClashConfig.fromJson(Map<String, dynamic> json) =
      _$ClashConfigImpl.fromJson;

  @override
  int get port;
  @override
  int get socksPort;
  @override
  String get mode;
  @override
  String get logLevel;

  /// Create a copy of ClashConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClashConfigImplCopyWith<_$ClashConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
