class RouteEntry {
  final String destinationId;
  final String? destinationName;
  final String nextHopId;    // direct peer we send to
  final String nextHopIp;
  final int nextHopPort;
  final int hopCount;
  final DateTime lastSeen;

  RouteEntry({
    required this.destinationId,
    this.destinationName,
    required this.nextHopId,
    required this.nextHopIp,
    this.nextHopPort = 8767,
    required this.hopCount,
    required this.lastSeen,
  });

  bool get isExpired =>
      DateTime.now().difference(lastSeen).inSeconds > 20;
}

class RoutingTable {
  final Map<String, RouteEntry> _routes = {};

  void upsert(RouteEntry entry) {
    final existing = _routes[entry.destinationId];
    if (existing == null || entry.hopCount < existing.hopCount) {
      _routes[entry.destinationId] = entry;
    }
  }

  RouteEntry? lookup(String destinationId) {
    final r = _routes[destinationId];
    if (r == null || r.isExpired) return null;
    return r;
  }

  void invalidate(String identifier) {
    _routes.removeWhere((k, v) =>
        k == identifier || v.nextHopId == identifier || v.nextHopIp == identifier);
  }

  List<RouteEntry> get allRoutes {
    _routes.removeWhere((k, v) => v.isExpired);
    return _routes.values.toList();
  }
}