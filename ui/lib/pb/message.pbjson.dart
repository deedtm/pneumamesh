// This is a generated file - do not edit.
//
// Generated from pb/message.proto.

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

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'register_timestamp',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'registerTimestamp'
    },
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEi0KEnJlZ2lzdGVyX3'
    'RpbWVzdGFtcBgDIAEoA1IRcmVnaXN0ZXJUaW1lc3RhbXA=');

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'sender', '3': 1, '4': 1, '5': 11, '6': '.pb.User', '10': 'sender'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRIgCgZzZW5kZXIYASABKAsyCC5wYi5Vc2VyUgZzZW5kZXISEgoEdGV4dB'
    'gCIAEoCVIEdGV4dBIcCgl0aW1lc3RhbXAYAyABKANSCXRpbWVzdGFtcA==');

@$core.Deprecated('Use fullStateDescriptor instead')
const FullState$json = {
  '1': 'FullState',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.pb.User', '10': 'user'},
    {'1': 'current_room', '3': 2, '4': 1, '5': 9, '10': 'currentRoom'},
    {'1': 'network', '3': 3, '4': 1, '5': 9, '10': 'network'},
    {'1': 'wifi_ssid', '3': 4, '4': 1, '5': 9, '10': 'wifiSsid'},
    {'1': 'wifi_bssid', '3': 5, '4': 1, '5': 9, '10': 'wifiBssid'},
  ],
};

/// Descriptor for `FullState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fullStateDescriptor = $convert.base64Decode(
    'CglGdWxsU3RhdGUSHAoEdXNlchgBIAEoCzIILnBiLlVzZXJSBHVzZXISIQoMY3VycmVudF9yb2'
    '9tGAIgASgJUgtjdXJyZW50Um9vbRIYCgduZXR3b3JrGAMgASgJUgduZXR3b3JrEhsKCXdpZmlf'
    'c3NpZBgEIAEoCVIId2lmaVNzaWQSHQoKd2lmaV9ic3NpZBgFIAEoCVIJd2lmaUJzc2lk');

@$core.Deprecated('Use discoveryPacketDescriptor instead')
const DiscoveryPacket$json = {
  '1': 'DiscoveryPacket',
  '2': [
    {'1': 'network_name', '3': 1, '4': 1, '5': 9, '10': 'networkName'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'addrs', '3': 3, '4': 3, '5': 9, '10': 'addrs'},
  ],
};

/// Descriptor for `DiscoveryPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoveryPacketDescriptor = $convert.base64Decode(
    'Cg9EaXNjb3ZlcnlQYWNrZXQSIQoMbmV0d29ya19uYW1lGAEgASgJUgtuZXR3b3JrTmFtZRIXCg'
    'dwZWVyX2lkGAIgASgJUgZwZWVySWQSFAoFYWRkcnMYAyADKAlSBWFkZHJz');
