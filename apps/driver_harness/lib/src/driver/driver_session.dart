class DriverSessionModel {
  const DriverSessionModel({
    required this.userName,
    required this.driverId,
    required this.preferredLocale,
    this.teamName,
    this.vehicleLabel,
    this.vehiclePlate,
    this.completedRounds = const [],
    this.currentRound,
  });

  final String userName;
  final String driverId;
  final String preferredLocale;
  final String? teamName;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final List<DriverCompletedRoundModel> completedRounds;
  final DriverRoundModel? currentRound;

  factory DriverSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final driver = json['driver'] as Map<String, dynamic>;
    final team = json['team'] as Map<String, dynamic>?;
    final round = json['currentRound'];
    return DriverSessionModel(
      userName: user['displayName'] as String,
      driverId: driver['id'] as String,
      preferredLocale: driver['preferredLocale'] as String,
      teamName: team?['displayName'] as String?,
      vehicleLabel: driver['vehicleLabel'] as String?,
      vehiclePlate: driver['vehiclePlate'] as String?,
      completedRounds: (json['completedRounds'] as List<dynamic>? ?? const [])
          .map(
            (item) => DriverCompletedRoundModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      currentRound: round is Map<String, dynamic>
          ? DriverRoundModel.fromJson(round)
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'user': {'displayName': userName},
    'driver': {
      'id': driverId,
      'preferredLocale': preferredLocale,
      if (vehicleLabel != null) 'vehicleLabel': vehicleLabel,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
    },
    if (teamName != null) 'team': {'displayName': teamName},
    'completedRounds': completedRounds
        .map((round) => round.toJson())
        .toList(growable: false),
    'currentRound': currentRound?.toJson(),
  };
}

class DriverRoundModel {
  const DriverRoundModel({
    required this.id,
    required this.reference,
    required this.serviceDate,
    required this.state,
    required this.version,
    required this.tenantName,
    required this.pickup,
    required this.stops,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
  });

  final String id;
  final String reference;
  final String serviceDate;
  final String state;
  final int version;
  final String tenantName;
  final DriverPickupModel pickup;
  final List<DriverRoundStopModel> stops;
  final int? plannedDistanceMeters;
  final int? plannedDurationSeconds;

  factory DriverRoundModel.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>;
    final routePlan = json['routePlan'] as Map<String, dynamic>?;
    return DriverRoundModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      serviceDate: json['serviceDate'] as String,
      state: json['state'] as String,
      version: json['version'] as int,
      tenantName: tenant['displayName'] as String,
      pickup: DriverPickupModel.fromJson(
        json['pickup'] as Map<String, dynamic>,
      ),
      stops: (json['stops'] as List<dynamic>)
          .map(
            (item) =>
                DriverRoundStopModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      plannedDistanceMeters: (routePlan?['distanceMeters'] as num?)?.round(),
      plannedDurationSeconds: (routePlan?['durationSeconds'] as num?)?.round(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'reference': reference,
    'serviceDate': serviceDate,
    'state': state,
    'version': version,
    'tenant': {'displayName': tenantName},
    'pickup': pickup.toJson(),
    'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    if (plannedDistanceMeters != null || plannedDurationSeconds != null)
      'routePlan': {
        if (plannedDistanceMeters != null)
          'distanceMeters': plannedDistanceMeters,
        if (plannedDurationSeconds != null)
          'durationSeconds': plannedDurationSeconds,
      },
  };
}

class DriverCompletedRoundModel {
  const DriverCompletedRoundModel({
    required this.id,
    required this.reference,
    required this.serviceDate,
    required this.tenantName,
    required this.completedAt,
    required this.stopCount,
    required this.deliveredStopCount,
    required this.formallyClosedStopCount,
    required this.podCount,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
  });

  final String id;
  final String reference;
  final String serviceDate;
  final String tenantName;
  final DateTime completedAt;
  final int stopCount;
  final int deliveredStopCount;
  final int formallyClosedStopCount;
  final int podCount;
  final int? plannedDistanceMeters;
  final int? plannedDurationSeconds;

  bool get allPodSaved => stopCount > 0 && podCount == stopCount;

  String get evidenceLabel {
    if (allPodSaved) return 'POD saved';
    if (formallyClosedStopCount == stopCount && stopCount > 0) {
      return 'Return recorded';
    }
    if (podCount > 0 || formallyClosedStopCount > 0) return 'Evidence saved';
    return 'Completed';
  }

  factory DriverCompletedRoundModel.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>;
    return DriverCompletedRoundModel(
      id: json['id'] as String,
      reference: json['reference'] as String,
      serviceDate: json['serviceDate'] as String,
      tenantName: tenant['displayName'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      stopCount: json['stopCount'] as int,
      deliveredStopCount: json['deliveredStopCount'] as int,
      formallyClosedStopCount: json['formallyClosedStopCount'] as int,
      podCount: json['podCount'] as int,
      plannedDistanceMeters: (json['plannedDistanceMeters'] as num?)?.round(),
      plannedDurationSeconds: (json['plannedDurationSeconds'] as num?)?.round(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'reference': reference,
    'serviceDate': serviceDate,
    'tenant': {'displayName': tenantName},
    'completedAt': completedAt.toUtc().toIso8601String(),
    'stopCount': stopCount,
    'deliveredStopCount': deliveredStopCount,
    'formallyClosedStopCount': formallyClosedStopCount,
    'podCount': podCount,
    if (plannedDistanceMeters != null)
      'plannedDistanceMeters': plannedDistanceMeters,
    if (plannedDurationSeconds != null)
      'plannedDurationSeconds': plannedDurationSeconds,
  };
}

class DriverPickupModel {
  const DriverPickupModel({
    this.id = '',
    required this.displayName,
    required this.rawAddress,
    required this.contactName,
    required this.contactPhone,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String displayName;
  final String rawAddress;
  final String contactName;
  final String contactPhone;
  final double? latitude;
  final double? longitude;

  factory DriverPickupModel.fromJson(Map<String, dynamic> json) =>
      DriverPickupModel(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String,
        rawAddress: json['rawAddress'] as String,
        contactName: json['contactName'] as String,
        contactPhone: json['contactPhone'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'rawAddress': rawAddress,
    'contactName': contactName,
    'contactPhone': contactPhone,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

class DriverRoundStopModel {
  const DriverRoundStopModel({
    required this.id,
    required this.sequence,
    required this.state,
    required this.version,
    required this.destinationVersion,
    required this.manifestId,
    required this.manifestVersion,
    required this.deliveryReference,
    required this.recipientName,
    required this.recipientPhone,
    required this.rawAddress,
    required this.latitude,
    required this.longitude,
    required this.windowStart,
    required this.windowEnd,
    required this.manifestItems,
    this.contactAttempts = const [],
    this.accessNote,
  });

  final String id;
  final int sequence;
  final String state;
  final int version;
  final int destinationVersion;
  final String manifestId;
  final int manifestVersion;
  final String deliveryReference;
  final String recipientName;
  final String recipientPhone;
  final String rawAddress;
  final double latitude;
  final double longitude;
  final String windowStart;
  final String windowEnd;
  final List<DriverManifestItemModel> manifestItems;
  final List<DriverContactAttemptModel> contactAttempts;
  final String? accessNote;

  factory DriverRoundStopModel.fromJson(
    Map<String, dynamic> json,
  ) => DriverRoundStopModel(
    id: json['id'] as String,
    sequence: json['sequence'] as int,
    state: json['state'] as String,
    version: json['version'] as int,
    destinationVersion: json['destinationVersion'] as int,
    manifestId: json['manifestId'] as String,
    manifestVersion: json['manifestVersion'] as int,
    deliveryReference: json['deliveryReference'] as String,
    recipientName: json['recipientName'] as String,
    recipientPhone: json['recipientPhone'] as String,
    rawAddress: json['rawAddress'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    windowStart: json['windowStart'] as String,
    windowEnd: json['windowEnd'] as String,
    accessNote: json['accessNote'] as String?,
    manifestItems: (json['manifestItems'] as List<dynamic>)
        .map(
          (item) =>
              DriverManifestItemModel.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
    contactAttempts: (json['contactAttempts'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              DriverContactAttemptModel.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'sequence': sequence,
    'state': state,
    'version': version,
    'destinationVersion': destinationVersion,
    'manifestId': manifestId,
    'manifestVersion': manifestVersion,
    'deliveryReference': deliveryReference,
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
    'rawAddress': rawAddress,
    'latitude': latitude,
    'longitude': longitude,
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    if (accessNote != null) 'accessNote': accessNote,
    'manifestItems': manifestItems
        .map((item) => item.toJson())
        .toList(growable: false),
    'contactAttempts': contactAttempts
        .map((attempt) => attempt.toJson())
        .toList(growable: false),
  };
}

class DriverContactAttemptModel {
  const DriverContactAttemptModel({
    required this.id,
    required this.target,
    required this.channel,
    required this.outcome,
    required this.occurredAt,
    this.savedLocally = false,
  });

  final String id;
  final String target;
  final String channel;
  final String outcome;
  final DateTime occurredAt;
  final bool savedLocally;

  factory DriverContactAttemptModel.fromJson(Map<String, dynamic> json) =>
      DriverContactAttemptModel(
        id: json['id'] as String,
        target: json['target'] as String,
        channel: json['channel'] as String,
        outcome: json['outcome'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'target': target,
    'channel': channel,
    'outcome': outcome,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

class DriverManifestItemModel {
  const DriverManifestItemModel({
    required this.lineNumber,
    required this.description,
    required this.quantity,
    this.handlingNote,
  });

  final int lineNumber;
  final String description;
  final int quantity;
  final String? handlingNote;

  factory DriverManifestItemModel.fromJson(Map<String, dynamic> json) =>
      DriverManifestItemModel(
        lineNumber: json['lineNumber'] as int,
        description: json['description'] as String,
        quantity: json['quantity'] as int,
        handlingNote: json['handlingNote'] as String?,
      );

  Map<String, Object?> toJson() => {
    'lineNumber': lineNumber,
    'description': description,
    'quantity': quantity,
    if (handlingNote != null) 'handlingNote': handlingNote,
  };
}
