/// Mirrors the backend `Mapcars.Domain.Enums.TripStatus` (same ordering, so the
/// integer wire form maps 1:1). Tolerates both int and string serialization.
enum TripStatus {
  requested,
  driverAssigned,
  driverArrived,
  inProgress,
  completed,
  cancelledByRider,
  cancelledByDriver,
  expired,
  unknown;

  bool get isActive =>
      this == driverAssigned || this == driverArrived || this == inProgress;

  bool get isCancelled =>
      this == cancelledByRider || this == cancelledByDriver;

  /// Nobody accepted the request before its search window ran out.
  bool get isExpired => this == expired;

  /// Any ending that isn't a completed ride. Cancelled and expired need
  /// different words for the rider — one is "your ride was cancelled", the
  /// other is "we couldn't find anyone" — but every screen that asks "is this
  /// still happening?" wants both.
  bool get isOver => isCancelled || isExpired;

  static TripStatus fromApi(Object? v) {
    if (v is int) {
      // Bound is `expired`, the last real status — `unknown` is this client's
      // own sentinel and must never be reachable from a wire value.
      return (v >= 0 && v < unknown.index)
          ? TripStatus.values[v]
          : unknown;
    }
    switch (v?.toString().toLowerCase().replaceAll('_', '')) {
      case 'requested':
        return requested;
      case 'driverassigned':
        return driverAssigned;
      case 'driverarrived':
        return driverArrived;
      case 'inprogress':
        return inProgress;
      case 'completed':
        return completed;
      case 'cancelledbyrider':
        return cancelledByRider;
      case 'cancelledbydriver':
        return cancelledByDriver;
      case 'expired':
        return expired;
      default:
        return unknown;
    }
  }
}
