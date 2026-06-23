class RouteEntry {
  final String destinationId;
  final String nextHopId;    // direct peer we send to
  final String nextHopIp;
  final int nextHopPort;
  final int hopCount;
  final DateTime lastSeen;

  RouteEntry({
    required this.destinationId,
    required this.nextHopId,
    required this.nextHopIp,
    required this.nextHopPort,
    required this.hopCount,
    required this.lastSeen,
  });

  bool get isExpired =>
      DateTime.now().difference(lastSeen).inSeconds > 30;
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

  void invalidate(String deviceId) {
    _routes.removeWhere((k, v) =>
    k == deviceId || v.nextHopId == deviceId);
  }

  List<RouteEntry> get allRoutes => _routes.values.toList();
}