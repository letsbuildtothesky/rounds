/// Optional v2.3 storage binding. Does not alter legacy command payloads/fences.
abstract interface class DriverAuthBoundary {
  void lock();
  Future<void> authenticate(String bearer);
}
