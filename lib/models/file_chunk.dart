class FileChunk {
  final String transferId;
  final int sequenceNumber;
  final int totalChunks;
  final List<int> data;         // raw bytes
  final String checksum;        // SHA-256 of data
  final String destinationId;   // final recipient device ID
  final String originId;        // sender device ID

  const FileChunk({
    required this.transferId,
    required this.sequenceNumber,
    required this.totalChunks,
    required this.data,
    required this.checksum,
    required this.destinationId,
    required this.originId,
  });

  // Serialize to bytes for TCP wire format
  // [4B transferId len][transferId][4B seq][4B total][4B dataLen][data][64B checksum]
  List<int> toBytes() {
    final tid = transferId.codeUnits;
    final dest = destinationId.codeUnits;
    final orig = originId.codeUnits;
    final buf = BytesBuilder();
    buf.add(_int32(tid.length));
    buf.add(tid);
    buf.add(_int32(dest.length));
    buf.add(dest);
    buf.add(_int32(orig.length));
    buf.add(orig);
    buf.add(_int32(sequenceNumber));
    buf.add(_int32(totalChunks));
    buf.add(_int32(data.length));
    buf.add(data);
    buf.add(checksum.codeUnits);
    return buf.toBytes();
  }

  static List<int> _int32(int v) => [
    (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF
  ];
}