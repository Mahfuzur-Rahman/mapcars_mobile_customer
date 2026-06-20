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
  unknown;

  bool get isActive =>
      this == driverAssigned || this == driverArrived || this == inProgress;

  bool get isCancelled =>
      this == cancelledByRider || this == cancelledByDriver;

  static TripStatus fromApi(Object? v) {
    if (v is int) {
      return (v >= 0 && v < cancelledByDriver.index + 1)
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
      default:
        return unknown;
    }
  }
}
