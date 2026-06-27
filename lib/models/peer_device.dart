enum PeerStatus {
  discovered,
  connected,
  relaying,
}

class PeerDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String publicKey;
  final int hops;
  final PeerStatus status;
  final String? nextHopId;

  const PeerDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.publicKey,
    this.hops = 0,
    this.status = PeerStatus.discovered,
    this.nextHopId,
  });

  PeerDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? publicKey,
    int? hops,
    PeerStatus? status,
    String? nextHopId,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      publicKey: publicKey ?? this.publicKey,
      hops: hops ?? this.hops,
      status: status ?? this.status,
      nextHopId: nextHopId ?? this.nextHopId,
    );
  }
}