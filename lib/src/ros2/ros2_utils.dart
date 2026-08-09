import 'dart:convert';
import 'dart:typed_data';

/// Standard ROS 2 Type Hashes (RIHS01) for common message types.
abstract class Ros2TypeHash {
  /// std_msgs/msg/String
  static const String stdMsgsString =
      'RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18';

  /// geometry_msgs/msg/Twist
  static const String geometryMsgsTwist =
      'RIHS01_9c45bf16fe0983d80e3c3ce97a5449767bb172e2cfbc39ba2e6ee5ec2136d85a';
}

/// Helper for ROS 2 CDR (Common Data Representation, Little Endian) serialization and deserialization.
class Ros2Cdr {
  const Ros2Cdr._();

  /// 4-byte encapsulation header for CDR Little Endian [0x00, 0x01, 0x00, 0x00]
  static const List<int> cdrHeaderLe = [0x00, 0x01, 0x00, 0x00];

  /// Serializes a string into ROS 2 `std_msgs/msg/String` CDR format.
  static Uint8List encodeString(String text) {
    final textBytes = utf8.encode(text);
    final textLenWithNull = textBytes.length + 1;

    final builder = BytesBuilder();
    builder.add(cdrHeaderLe);
    final lenBytes = ByteData(4)..setUint32(0, textLenWithNull, Endian.little);
    builder.add(lenBytes.buffer.asUint8List());
    builder.add(textBytes);
    builder.addByte(0x00); // null terminator

    return builder.toBytes();
  }

  /// Deserializes a ROS 2 `std_msgs/msg/String` CDR payload into a string.
  static String decodeString(Uint8List payload) {
    if (payload.length < 8) {
      return utf8.decode(payload, allowMalformed: true);
    }
    // Skip 4-byte header and 4-byte length prefix
    final strBytes = payload.sublist(8);
    // Remove trailing null terminator if present
    final cleanBytes =
        strBytes.isNotEmpty && strBytes.last == 0
            ? strBytes.sublist(0, strBytes.length - 1)
            : strBytes;
    return utf8.decode(cleanBytes, allowMalformed: true);
  }

  /// Serializes linear and angular velocities into ROS 2 `geometry_msgs/msg/Twist` CDR format.
  static Uint8List encodeTwist({
    double linearX = 0.0,
    double linearY = 0.0,
    double linearZ = 0.0,
    double angularX = 0.0,
    double angularY = 0.0,
    double angularZ = 0.0,
  }) {
    final builder = BytesBuilder();
    builder.add(cdrHeaderLe);

    final data = ByteData(48); // 6 doubles * 8 bytes
    data.setFloat64(0, linearX, Endian.little);
    data.setFloat64(8, linearY, Endian.little);
    data.setFloat64(16, linearZ, Endian.little);
    data.setFloat64(24, angularX, Endian.little);
    data.setFloat64(32, angularY, Endian.little);
    data.setFloat64(40, angularZ, Endian.little);

    builder.add(data.buffer.asUint8List());
    return builder.toBytes();
  }

  /// Deserializes a ROS 2 `geometry_msgs/msg/Twist` CDR payload into 6 velocity components.
  static ({
    double linearX,
    double linearY,
    double linearZ,
    double angularX,
    double angularY,
    double angularZ,
  }) decodeTwist(Uint8List payload) {
    if (payload.length < 52) {
      return (
        linearX: 0.0,
        linearY: 0.0,
        linearZ: 0.0,
        angularX: 0.0,
        angularY: 0.0,
        angularZ: 0.0,
      );
    }
    final byteData = ByteData.sublistView(payload, 4); // skip 4-byte header
    return (
      linearX: byteData.getFloat64(0, Endian.little),
      linearY: byteData.getFloat64(8, Endian.little),
      linearZ: byteData.getFloat64(16, Endian.little),
      angularX: byteData.getFloat64(24, Endian.little),
      angularY: byteData.getFloat64(32, Endian.little),
      angularZ: byteData.getFloat64(40, Endian.little),
    );
  }
}

/// Helper for ROS 2 `rmw_zenoh_cpp` integration.
class RmwZenoh {
  const RmwZenoh._();

  /// Default publisher GID (16 bytes)
  static const List<int> defaultGid = [
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
  ];

  /// Creates a standard `rmw_zenoh_cpp` binary attachment (33 bytes).
  ///
  /// Format:
  /// - 8 bytes `int64`: `sequence_number` (Little Endian)
  /// - 8 bytes `int64`: `source_timestamp` (nanoseconds since Unix epoch, Little Endian)
  /// - 1 byte `uint8`: `gid_len` (16)
  /// - 16 bytes: `source_gid`
  static Uint8List createAttachment({
    required int sequenceNumber,
    int? sourceTimestampNs,
    List<int>? gid,
  }) {
    final timestampNs =
        sourceTimestampNs ?? DateTime.now().microsecondsSinceEpoch * 1000;
    final sourceGid = gid ?? defaultGid;

    final builder = BytesBuilder();

    // 1. Sequence number (int64 LE)
    final seqBytes = ByteData(8)..setInt64(0, sequenceNumber, Endian.little);
    builder.add(seqBytes.buffer.asUint8List());

    // 2. Source timestamp (int64 LE nanoseconds)
    final timeBytes = ByteData(8)..setInt64(0, timestampNs, Endian.little);
    builder.add(timeBytes.buffer.asUint8List());

    // 3. GID length (uint8 = 16)
    builder.addByte(sourceGid.length);

    // 4. Source GID (16 bytes)
    builder.add(sourceGid);

    return builder.toBytes();
  }

  /// Parses an `rmw_zenoh_cpp` binary attachment.
  static ({int sequenceNumber, int sourceTimestampNs, Uint8List gid})?
      parseAttachment(Uint8List? attachment) {
    if (attachment == null || attachment.length < 17) {
      return null;
    }
    final byteData = ByteData.sublistView(attachment);
    final sequenceNumber = byteData.getInt64(0, Endian.little);
    final sourceTimestampNs = byteData.getInt64(8, Endian.little);
    final gidLen = attachment[16];
    final gid =
        attachment.length >= 17 + gidLen
            ? attachment.sublist(17, 17 + gidLen)
            : attachment.sublist(17);

    return (
      sequenceNumber: sequenceNumber,
      sourceTimestampNs: sourceTimestampNs,
      gid: gid,
    );
  }

  /// Builds a Zenoh Key Expression for ROS 2 topics matching `rmw_zenoh_cpp`.
  ///
  /// Examples:
  /// - `buildTopicKey(domainId: 30, topic: 'chatter', typeName: 'std_msgs::msg::dds_::String_', typeHash: Ros2TypeHash.stdMsgsString)`
  ///   -> `'30/chatter/std_msgs::msg::dds_::String_/RIHS01_...'`
  static String buildTopicKey({
    required int domainId,
    required String topic,
    String? typeName,
    String? typeHash,
  }) {
    final cleanTopic = topic.startsWith('/') ? topic.substring(1) : topic;
    if (typeName != null && typeHash != null) {
      return '$domainId/$cleanTopic/$typeName/$typeHash';
    } else if (typeName != null) {
      return '$domainId/$cleanTopic/$typeName';
    }
    return '$domainId/$cleanTopic';
  }
}
