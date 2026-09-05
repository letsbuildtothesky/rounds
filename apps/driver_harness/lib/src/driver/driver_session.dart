class DriverSessionModel {
  const DriverSessionModel({
    required this.userName,
    required this.driverId,
    required this.preferredLocale,
    this.userId,
    this.version = 1,
    this.teamName,
    this.teamTenantId,
    this.teamStatus,
    this.vehicleLabel,
    this.vehiclePlate,
    this.shift,
    this.completedRounds = const [],
    this.currentRound,
    this.pendingLiveChange,
  });

  final String userName;
  final String? userId;
  final String driverId;
  final int version;
  final String preferredLocale;
  final String? teamName;
  final String? teamTenantId;
  final String? teamStatus;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final DriverShiftModel? shift;
  final List<DriverCompletedRoundModel> completedRounds;
  final DriverRoundModel? currentRound;
  final DriverLiveDeliveryChangeModel? pendingLiveChange;

  factory DriverSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final driver = json['driver'] as Map<String, dynamic>;
    final team = json['team'] as Map<String, dynamic>?;
    final round = json['currentRound'];
    return DriverSessionModel(
      userName: user['displayName'] as String,
      userId: user['id'] as String?,
      driverId: driver['id'] as String,
      version: driver['version'] as int? ?? 1,
      preferredLocale: driver['preferredLocale'] as String,
      teamName: team?['displayName'] as String?,
      teamTenantId: team?['tenantId'] as String?,
      teamStatus: team?['status'] as String?,
      vehicleLabel: driver['vehicleLabel'] as String?,
      vehiclePlate: driver['vehiclePlate'] as String?,
      shift: json['shift'] is Map<String, dynamic>
          ? DriverShiftModel.fromJson(json['shift'] as Map<String, dynamic>)
          : null,
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
      pendingLiveChange: json['pendingLiveChange'] is Map<String, dynamic>
          ? DriverLiveDeliveryChangeModel.fromJson(
              json['pendingLiveChange'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'user': {if (userId != null) 'id': userId, 'displayName': userName},
    'driver': {
      'id': driverId,
      'version': version,
      'preferredLocale': preferredLocale,
      if (vehicleLabel != null) 'vehicleLabel': vehicleLabel,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
    },
    if (teamName != null || teamTenantId != null || teamStatus != null)
      'team': {
        if (teamTenantId != null) 'tenantId': teamTenantId,
        if (teamName != null) 'displayName': teamName,
        if (teamStatus != null) 'status': teamStatus,
      },
    if (shift != null) 'shift': shift!.toJson(),
    'completedRounds': completedRounds
        .map((round) => round.toJson())
        .toList(growable: false),
    'currentRound': currentRound?.toJson(),
    if (pendingLiveChange != null)
      'pendingLiveChange': pendingLiveChange!.toJson(),
  };
}

class DriverShiftModel {
  const DriverShiftModel({required this.effective, this.attendance});

  final DriverEffectiveShiftModel effective;
  final DriverShiftAttendanceModel? attendance;

  factory DriverShiftModel.fromJson(Map<String, dynamic> json) =>
      DriverShiftModel(
        effective: DriverEffectiveShiftModel.fromJson(
          json['effective'] as Map<String, dynamic>,
        ),
        attendance: json['attendance'] is Map<String, dynamic>
            ? DriverShiftAttendanceModel.fromJson(
                json['attendance'] as Map<String, dynamic>,
              )
            : null,
      );

  Map<String, Object?> toJson() => {
    'effective': effective.toJson(),
    if (attendance != null) 'attendance': attendance!.toJson(),
  };
}

class DriverEffectiveShiftModel {
  const DriverEffectiveShiftModel({
    required this.serviceDate,
    required this.timezone,
    required this.source,
    required this.startAt,
    required this.endAt,
    required this.startLocal,
    required this.endLocal,
    required this.crossesMidnight,
  });

  final String serviceDate;
  final String timezone;
  final String source;
  final DateTime startAt;
  final DateTime endAt;
  final String startLocal;
  final String endLocal;
  final bool crossesMidnight;

  int get scheduledMinutes => endAt.difference(startAt).inMinutes;

  factory DriverEffectiveShiftModel.fromJson(Map<String, dynamic> json) =>
      DriverEffectiveShiftModel(
        serviceDate: json['serviceDate'] as String,
        timezone: json['timezone'] as String,
        source: json['source'] as String,
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: DateTime.parse(json['endAt'] as String),
        startLocal: json['startLocal'] as String,
        endLocal: json['endLocal'] as String,
        crossesMidnight: json['crossesMidnight'] as bool,
      );

  Map<String, Object?> toJson() => {
    'serviceDate': serviceDate,
    'timezone': timezone,
    'source': source,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'startLocal': startLocal,
    'endLocal': endLocal,
    'crossesMidnight': crossesMidnight,
  };
}

class DriverShiftAttendanceModel {
  const DriverShiftAttendanceModel({
    required this.id,
    required this.version,
    required this.serviceDate,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final int version;
  final String serviceDate;
  final DateTime startedAt;
  final DateTime? endedAt;

  factory DriverShiftAttendanceModel.fromJson(Map<String, dynamic> json) =>
      DriverShiftAttendanceModel(
        id: json['id'] as String,
        version: json['version'] as int,
        serviceDate: json['serviceDate'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] is String
            ? DateTime.parse(json['endedAt'] as String)
            : null,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'serviceDate': serviceDate,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
  };
}

class DriverLiveDeliveryChangeModel {
  const DriverLiveDeliveryChangeModel({
    required this.id,
    required this.changeVersion,
    required this.roundId,
    required this.stopId,
    required this.appliedAt,
    required this.before,
    required this.after,
    required this.impact,
  });

  final String id;
  final int changeVersion;
  final String roundId;
  final String stopId;
  final DateTime appliedAt;
  final DriverLiveDeliveryValuesModel before;
  final DriverLiveDeliveryValuesModel after;
  final DriverLiveDeliveryImpactModel impact;

  factory DriverLiveDeliveryChangeModel.fromJson(Map<String, dynamic> json) =>
      DriverLiveDeliveryChangeModel(
        id: json['id'] as String,
        changeVersion: json['changeVersion'] as int,
        roundId: json['roundId'] as String,
        stopId: json['stopId'] as String,
        appliedAt: DateTime.parse(json['appliedAt'] as String),
        before: DriverLiveDeliveryValuesModel.fromJson(
          json['before'] as Map<String, dynamic>,
        ),
        after: DriverLiveDeliveryValuesModel.fromJson(
          json['after'] as Map<String, dynamic>,
        ),
        impact: DriverLiveDeliveryImpactModel.fromJson(
          json['impact'] as Map<String, dynamic>,
        ),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'changeVersion': changeVersion,
    'roundId': roundId,
    'stopId': stopId,
    'appliedAt': appliedAt.toUtc().toIso8601String(),
    'before': before.toJson(),
    'after': after.toJson(),
    'impact': impact.toJson(),
    'driverAckStatus': 'pending',
  };
}

class DriverLiveDeliveryValuesModel {
  const DriverLiveDeliveryValuesModel({
    required this.sequence,
    required this.rawAddress,
    required this.latitude,
    required this.longitude,
    required this.windowStart,
    required this.windowEnd,
    this.accessNote,
  });

  final int sequence;
  final String rawAddress;
  final double latitude;
  final double longitude;
  final String windowStart;
  final String windowEnd;
  final String? accessNote;

  factory DriverLiveDeliveryValuesModel.fromJson(Map<String, dynamic> json) =>
      DriverLiveDeliveryValuesModel(
        sequence: json['sequence'] as int,
        rawAddress: json['rawAddress'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        windowStart: json['windowStart'] as String,
        windowEnd: json['windowEnd'] as String,
        accessNote: json['accessNote'] as String?,
      );

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'rawAddress': rawAddress,
    'latitude': latitude,
    'longitude': longitude,
    if (accessNote != null) 'accessNote': accessNote,
    'windowStart': windowStart,
    'windowEnd': windowEnd,
  };
}

class DriverLiveDeliveryImpactModel {
  const DriverLiveDeliveryImpactModel({
    required this.distanceDeltaMeters,
    required this.durationDeltaSeconds,
    required this.downstreamStopCount,
    required this.promiseStatus,
    required this.shiftSafe,
    this.etaBefore,
    this.etaAfter,
    this.finishBefore,
    this.finishAfter,
  });

  final int distanceDeltaMeters;
  final int durationDeltaSeconds;
  final int downstreamStopCount;
  final String promiseStatus;
  final bool shiftSafe;
  final String? etaBefore;
  final String? etaAfter;
  final String? finishBefore;
  final String? finishAfter;

  factory DriverLiveDeliveryImpactModel.fromJson(Map<String, dynamic> json) =>
      DriverLiveDeliveryImpactModel(
        distanceDeltaMeters: (json['distanceDeltaMeters'] as num).round(),
        durationDeltaSeconds: (json['durationDeltaSeconds'] as num).round(),
        downstreamStopCount: json['downstreamStopCount'] as int,
        promiseStatus: json['promiseStatus'] as String,
        shiftSafe: json['shiftSafe'] as bool,
        etaBefore: json['etaBefore'] as String?,
        etaAfter: json['etaAfter'] as String?,
        finishBefore: json['finishBefore'] as String?,
        finishAfter: json['finishAfter'] as String?,
      );

  Map<String, Object?> toJson() => {
    'distanceDeltaMeters': distanceDeltaMeters,
    'durationDeltaSeconds': durationDeltaSeconds,
    'downstreamStopCount': downstreamStopCount,
    'promiseStatus': promiseStatus,
    'shiftSafe': shiftSafe,
    if (etaBefore != null) 'etaBefore': etaBefore,
    if (etaAfter != null) 'etaAfter': etaAfter,
    if (finishBefore != null) 'finishBefore': finishBefore,
    if (finishAfter != null) 'finishAfter': finishAfter,
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
    this.tenantId,
    this.tenantTimezone,
    this.routePlanSnapshot,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
    this.plannedStops = const [],
  });

  final String id;
  final String reference;
  final String serviceDate;
  final String state;
  final int version;
  final String tenantName;
  final String? tenantId;
  final String? tenantTimezone;
  final DriverPickupModel pickup;
  final List<DriverRoundStopModel> stops;
  final int? plannedDistanceMeters;
  final int? plannedDurationSeconds;
  final List<DriverPlannedStopModel> plannedStops;
  final Map<String, dynamic>? routePlanSnapshot;

  DriverPlannedStopModel? plannedStop(String stopId) {
    for (final stop in plannedStops) {
      if (stop.stopId == stopId) return stop;
    }
    return null;
  }

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
      tenantId: tenant['id'] as String?,
      tenantTimezone: tenant['timezone'] as String?,
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
      plannedStops: (routePlan?['stops'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                DriverPlannedStopModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      routePlanSnapshot: routePlan == null
          ? null
          : Map<String, dynamic>.from(routePlan),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'reference': reference,
    'serviceDate': serviceDate,
    'state': state,
    'version': version,
    'tenant': {
      if (tenantId != null) 'id': tenantId,
      'displayName': tenantName,
      if (tenantTimezone != null) 'timezone': tenantTimezone,
    },
    'pickup': pickup.toJson(),
    'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    if (routePlanSnapshot != null)
      'routePlan': routePlanSnapshot
    else if (plannedDistanceMeters != null ||
        plannedDurationSeconds != null ||
        plannedStops.isNotEmpty)
      'routePlan': {
        if (plannedDistanceMeters != null)
          'distanceMeters': plannedDistanceMeters,
        if (plannedDurationSeconds != null)
          'durationSeconds': plannedDurationSeconds,
        if (plannedStops.isNotEmpty)
          'stops': plannedStops.map((stop) => stop.toJson()).toList(),
      },
  };
}

class DriverPlannedStopModel {
  const DriverPlannedStopModel({
    required this.stopId,
    required this.eta,
    required this.departureAt,
    required this.legDurationSeconds,
  });

  final String stopId;
  final DateTime eta;
  final DateTime departureAt;
  final int legDurationSeconds;

  factory DriverPlannedStopModel.fromJson(Map<String, dynamic> json) =>
      DriverPlannedStopModel(
        stopId: json['stopId'] as String,
        eta: DateTime.parse(json['eta'] as String),
        departureAt: DateTime.parse(json['departureAt'] as String),
        legDurationSeconds: (json['legDurationSeconds'] as num).round(),
      );

  Map<String, Object?> toJson() => {
    'stopId': stopId,
    'eta': eta.toUtc().toIso8601String(),
    'departureAt': departureAt.toUtc().toIso8601String(),
    'legDurationSeconds': legDurationSeconds,
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
    this.tenantId,
    this.tenantTimezone,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
  });

  final String id;
  final String reference;
  final String serviceDate;
  final String tenantName;
  final String? tenantId;
  final String? tenantTimezone;
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
      tenantId: tenant['id'] as String?,
      tenantTimezone: tenant['timezone'] as String?,
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
    'tenant': {
      if (tenantId != null) 'id': tenantId,
      'displayName': tenantName,
      if (tenantTimezone != null) 'timezone': tenantTimezone,
    },
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
    this.deliveryId = '',
    this.deliveryNote,
    this.isSurprise = false,
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
  final String deliveryId;
  final String? deliveryNote;
  final bool isSurprise;
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
    deliveryId: json['deliveryId'] as String? ?? '',
    deliveryReference: json['deliveryReference'] as String,
    deliveryNote: json['deliveryNote'] as String?,
    isSurprise: json['isSurprise'] as bool? ?? false,
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
    if (deliveryId.isNotEmpty) 'deliveryId': deliveryId,
    'deliveryReference': deliveryReference,
    if (deliveryNote != null) 'deliveryNote': deliveryNote,
    'isSurprise': isSurprise,
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
        savedLocally: json['savedLocally'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'target': target,
    'channel': channel,
    'outcome': outcome,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (savedLocally) 'savedLocally': true,
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
