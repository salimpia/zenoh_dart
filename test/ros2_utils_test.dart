import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zenoh_dart/zenoh_dart.dart';

void main() {
  group('Ros2Cdr', () {
    test('encodeString and decodeString roundtrip', () {
      const original = 'Hello from ROS 2 Zenoh Dart!';
      final encoded = Ros2Cdr.encodeString(original);

      // Verify CDR header (4 bytes)
      expect(encoded.sublist(0, 4), equals([0x00, 0x01, 0x00, 0x00]));

      // Verify length prefix (4 bytes little endian = original.length + 1)
      final byteData = ByteData.sublistView(encoded);
      final len = byteData.getUint32(4, Endian.little);
      expect(len, equals(original.length + 1));

      // Verify null termination
      expect(encoded.last, equals(0x00));

      // Verify decode
      final decoded = Ros2Cdr.decodeString(encoded);
      expect(decoded, equals(original));
    });

    test('encodeTwist and decodeTwist roundtrip', () {
      final encoded = Ros2Cdr.encodeTwist(
        linearX: 1.5,
        linearY: -0.5,
        linearZ: 0.0,
        angularX: 0.0,
        angularY: 0.0,
        angularZ: 3.141592,
      );

      // Verify total length: 4 header + 48 data = 52 bytes
      expect(encoded.length, equals(52));

      final decoded = Ros2Cdr.decodeTwist(encoded);
      expect(decoded.linearX, closeTo(1.5, 1e-6));
      expect(decoded.linearY, closeTo(-0.5, 1e-6));
      expect(decoded.linearZ, closeTo(0.0, 1e-6));
      expect(decoded.angularX, closeTo(0.0, 1e-6));
      expect(decoded.angularY, closeTo(0.0, 1e-6));
      expect(decoded.angularZ, closeTo(3.141592, 1e-6));
    });
  });

  group('RmwZenoh', () {
    test('createAttachment and parseAttachment roundtrip', () {
      const seq = 42;
      const timestamp = 1786246073000000;
      final customGid = [
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
      ];

      final attachment = RmwZenoh.createAttachment(
        sequenceNumber: seq,
        sourceTimestampNs: timestamp,
        gid: customGid,
      );

      // Verify 33 bytes (8 seq + 8 ts + 1 len + 16 gid)
      expect(attachment.length, equals(33));
      expect(attachment[16], equals(16));

      final parsed = RmwZenoh.parseAttachment(attachment);
      expect(parsed, isNotNull);
      expect(parsed!.sequenceNumber, equals(seq));
      expect(parsed.sourceTimestampNs, equals(timestamp));
      expect(parsed.gid, equals(customGid));
    });

    test('buildTopicKey generates correct Jazzy key expressions', () {
      final key = RmwZenoh.buildTopicKey(
        domainId: 30,
        topic: '/chatter',
        typeName: 'std_msgs::msg::dds_::String_',
        typeHash: Ros2TypeHash.stdMsgsString,
      );

      expect(
        key,
        equals(
          '30/chatter/std_msgs::msg::dds_::String_/RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18',
        ),
      );

      final simpleKey = RmwZenoh.buildTopicKey(domainId: 30, topic: 'cmd_vel');
      expect(simpleKey, equals('30/cmd_vel'));
    });
  });
}
