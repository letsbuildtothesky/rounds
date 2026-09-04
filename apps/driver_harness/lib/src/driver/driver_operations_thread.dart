class DriverMessageAttachmentModel {
  const DriverMessageAttachmentModel.location({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  }) : kind = 'location';

  final String kind;
  final String label;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;

  factory DriverMessageAttachmentModel.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != 'location') {
      throw const FormatException('Unsupported message attachment');
    }
    return DriverMessageAttachmentModel.location(
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };

  String get copyReference =>
      '$label · ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

class DriverOperationsMessageModel {
  const DriverOperationsMessageModel({
    required this.id,
    required this.sender,
    required this.body,
    required this.sentAt,
    this.attachments = const [],
    this.savedLocally = false,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime sentAt;
  final List<DriverMessageAttachmentModel> attachments;
  final bool savedLocally;

  factory DriverOperationsMessageModel.fromJson(Map<String, dynamic> json) =>
      DriverOperationsMessageModel(
        id: json['id'] as String,
        sender: json['sender'] as String,
        body: json['body'] as String,
        attachments: ((json['attachments'] as List<dynamic>?) ?? const [])
            .map(
              (attachment) => DriverMessageAttachmentModel.fromJson(
                attachment as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
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
