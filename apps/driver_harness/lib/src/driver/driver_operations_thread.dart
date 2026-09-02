class DriverOperationsMessageModel {
  const DriverOperationsMessageModel({
    required this.id,
    required this.sender,
    required this.body,
    required this.sentAt,
    this.savedLocally = false,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime sentAt;
  final bool savedLocally;

  factory DriverOperationsMessageModel.fromJson(Map<String, dynamic> json) =>
      DriverOperationsMessageModel(
        id: json['id'] as String,
        sender: json['sender'] as String,
        body: json['body'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
      );
}

class DriverOperationsThreadModel {
  const DriverOperationsThreadModel({
    required this.id,
    required this.roundId,
    required this.stopId,
    required this.version,
    required this.messages,
  });

  final String id;
  final String roundId;
  final String stopId;
  final int version;
  final List<DriverOperationsMessageModel> messages;

  factory DriverOperationsThreadModel.fromJson(Map<String, dynamic> json) =>
      DriverOperationsThreadModel(
        id: json['id'] as String,
        roundId: json['roundId'] as String,
        stopId: json['stopId'] as String,
        version: json['version'] as int,
        messages: (json['messages'] as List<dynamic>)
            .map(
              (message) => DriverOperationsMessageModel.fromJson(
                message as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );
}
