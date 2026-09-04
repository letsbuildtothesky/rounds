class DriverHandoffSelection {
  const DriverHandoffSelection({
    required this.handoffType,
    this.leftAtLocation,
  });

  const DriverHandoffSelection.recipient()
    : handoffType = 'recipient',
      leftAtLocation = null;

  const DriverHandoffSelection.someoneElse()
    : handoffType = 'someone_else',
      leftAtLocation = null;

  const DriverHandoffSelection.leftAt(String location)
    : handoffType = 'left_at_location',
      leftAtLocation = location;

  final String handoffType;
  final String? leftAtLocation;
}
