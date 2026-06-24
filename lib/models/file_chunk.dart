

class FileChunk {
  final String transferId;
  final int sequenceNumber;
  final int totalChunks;
  final List<int> data;
  final String checksum;
  final String destinationId;
  final String originId;

  const FileChunk({
    required this.transferId,
    required this.sequenceNumber,
    required this.totalChunks,
    required this.data,
    required this.checksum,
    required this.destinationId,
    required this.originId,
  });

  List<int> toBytes() {
    final tid = transferId.codeUnits;
    final dest = destinationId.codeUnits;
    final orig = originId.codeUnits;
    final buf = <int>[];
    buf.addAll(_int32(tid.length));
    buf.addAll(tid);
    buf.addAll(_int32(dest.length));
    buf.addAll(dest);
    buf.addAll(_int32(orig.length));
    buf.addAll(orig);
    buf.addAll(_int32(sequenceNumber));
    buf.addAll(_int32(totalChunks));
    buf.addAll(_int32(data.length));
    buf.addAll(data);
    buf.addAll(checksum.codeUnits);
    return buf;
  }

  static List<int> _int32(int v) => [
    (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF
  ];
}