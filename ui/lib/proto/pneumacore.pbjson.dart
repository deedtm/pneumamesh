// This is a generated file - do not edit.
//
// Generated from proto/pneumacore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use discoveryPacketTypeDescriptor instead')
const DiscoveryPacketType$json = {
  '1': 'DiscoveryPacketType',
  '2': [
    {'1': 'UNSPECIFIED', '2': 0},
    {'1': 'ACTIVE', '2': 1},
    {'1': 'SHARE', '2': 2},
  ],
};

/// Descriptor for `DiscoveryPacketType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List discoveryPacketTypeDescriptor = $convert.base64Decode(
    'ChNEaXNjb3ZlcnlQYWNrZXRUeXBlEg8KC1VOU1BFQ0lGSUVEEAASCgoGQUNUSVZFEAESCQoFU0'
    'hBUkUQAg==');

@$core.Deprecated('Use roomDescriptor instead')
const Room$json = {
  '1': 'Room',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `Room`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roomDescriptor = $convert
    .base64Decode('CgRSb29tEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use discoveryPacketDescriptor instead')
const DiscoveryPacket$json = {
  '1': 'DiscoveryPacket',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.pneumacore.DiscoveryPacketType',
      '10': 'type'
    },
    {'1': 'timestamp', '3': 2, '4': 1, '5': 3, '10': 'timestamp'},
    {
      '1': 'rooms',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.pneumacore.Room',
      '10': 'rooms'
    },
  ],
};

/// Descriptor for `DiscoveryPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoveryPacketDescriptor = $convert.base64Decode(
    'Cg9EaXNjb3ZlcnlQYWNrZXQSMwoEdHlwZRgBIAEoDjIfLnBuZXVtYWNvcmUuRGlzY292ZXJ5UG'
    'Fja2V0VHlwZVIEdHlwZRIcCgl0aW1lc3RhbXAYAiABKANSCXRpbWVzdGFtcBImCgVyb29tcxgD'
    'IAMoCzIQLnBuZXVtYWNvcmUuUm9vbVIFcm9vbXM=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert
    .base64Decode('CgRVc2VyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use messagePacketDescriptor instead')
const MessagePacket$json = {
  '1': 'MessagePacket',
  '2': [
    {
      '1': 'sender',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pneumacore.User',
      '10': 'sender'
    },
    {
      '1': 'room',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pneumacore.Room',
      '10': 'room'
    },
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `MessagePacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messagePacketDescriptor = $convert.base64Decode(
    'Cg1NZXNzYWdlUGFja2V0EigKBnNlbmRlchgBIAEoCzIQLnBuZXVtYWNvcmUuVXNlclIGc2VuZG'
    'VyEiQKBHJvb20YAiABKAsyEC5wbmV1bWFjb3JlLlJvb21SBHJvb20SEgoEdGV4dBgDIAEoCVIE'
    'dGV4dBIcCgl0aW1lc3RhbXAYBCABKANSCXRpbWVzdGFtcA==');

@$core.Deprecated('Use positionInfoDescriptor instead')
const PositionInfo$json = {
  '1': 'PositionInfo',
  '2': [
    {'1': 'latitude', '3': 1, '4': 1, '5': 1, '10': 'latitude'},
    {'1': 'longitude', '3': 2, '4': 1, '5': 1, '10': 'longitude'},
    {'1': 'altitude', '3': 3, '4': 1, '5': 1, '10': 'altitude'},
    {'1': 'speed', '3': 4, '4': 1, '5': 1, '10': 'speed'},
    {'1': 'accuracy', '3': 5, '4': 1, '5': 1, '10': 'accuracy'},
    {'1': 'timestamp', '3': 6, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `PositionInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List positionInfoDescriptor = $convert.base64Decode(
    'CgxQb3NpdGlvbkluZm8SGgoIbGF0aXR1ZGUYASABKAFSCGxhdGl0dWRlEhwKCWxvbmdpdHVkZR'
    'gCIAEoAVIJbG9uZ2l0dWRlEhoKCGFsdGl0dWRlGAMgASgBUghhbHRpdHVkZRIUCgVzcGVlZBgE'
    'IAEoAVIFc3BlZWQSGgoIYWNjdXJhY3kYBSABKAFSCGFjY3VyYWN5EhwKCXRpbWVzdGFtcBgGIA'
    'EoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use sosPacketDescriptor instead')
const SosPacket$json = {
  '1': 'SosPacket',
  '2': [
    {
      '1': 'sender',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pneumacore.User',
      '10': 'sender'
    },
    {
      '1': 'position',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pneumacore.PositionInfo',
      '10': 'position'
    },
  ],
};

/// Descriptor for `SosPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sosPacketDescriptor = $convert.base64Decode(
    'CglTb3NQYWNrZXQSKAoGc2VuZGVyGAEgASgLMhAucG5ldW1hY29yZS5Vc2VyUgZzZW5kZXISNA'
    'oIcG9zaXRpb24YAiABKAsyGC5wbmV1bWFjb3JlLlBvc2l0aW9uSW5mb1IIcG9zaXRpb24=');
