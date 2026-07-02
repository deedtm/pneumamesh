// This is a generated file - do not edit.
//
// Generated from proto/pneumacore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DiscoveryPacketType extends $pb.ProtobufEnum {
  static const DiscoveryPacketType UNSPECIFIED =
      DiscoveryPacketType._(0, _omitEnumNames ? '' : 'UNSPECIFIED');
  static const DiscoveryPacketType ACTIVE =
      DiscoveryPacketType._(1, _omitEnumNames ? '' : 'ACTIVE');
  static const DiscoveryPacketType SHARE =
      DiscoveryPacketType._(2, _omitEnumNames ? '' : 'SHARE');

  static const $core.List<DiscoveryPacketType> values = <DiscoveryPacketType>[
    UNSPECIFIED,
    ACTIVE,
    SHARE,
  ];

  static final $core.List<DiscoveryPacketType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DiscoveryPacketType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DiscoveryPacketType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
