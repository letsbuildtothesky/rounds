class DriverMessageAttachmentModel {
  const DriverMessageAttachmentModel.location({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  }) : kind = 'location',
       fileName = null,
       contentType = null,
       byteSize = null,
       localPath = null,
       sha256 = null,
       durationMilliseconds = null,
       mediaAssetId = null,
       storageBucket = null,
       storagePath = null,
       tusEndpoint = null,
       uploadUrl = null,
       uploadOffset = 0,
       downloadUrl = null;

  const DriverMessageAttachmentModel.media({
    required this.kind,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    this.localPath,
    this.sha256,
    this.durationMilliseconds,
    this.mediaAssetId,
    this.storageBucket,
    this.storagePath,
    this.tusEndpoint,
    this.uploadUrl,
    this.uploadOffset = 0,
    this.downloadUrl,
  }) : assert(kind == 'image' || kind == 'file' || kind == 'voice'),
       label = '',
       latitude = 0,
       longitude = 0,
       accuracyMeters = null,
       capturedAt = null;

  final String kind;
  final String label;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? fileName;
  final String? contentType;
  final int? byteSize;
  final String? localPath;
  final String? sha256;
  final int? durationMilliseconds;
  final String? mediaAssetId;
  final String? storageBucket;
  final String? storagePath;
  final String? tusEndpoint;
  final String? uploadUrl;
  final int uploadOffset;
  final String? downloadUrl;

  factory DriverMessageAttachmentModel.fromJson(
    Map<String, dynamic> json, {
    bool local = false,
  }) {
    final kind = json['kind'] as String?;
    if (kind == 'location') {
      return DriverMessageAttachmentModel.location(
        label: json['label'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );
    }
    if (kind != 'image' && kind != 'file' && kind != 'voice') {
      throw const FormatException('Unsupported message attachment');
    }
    return DriverMessageAttachmentModel.media(
      kind: kind!,
      fileName: json['fileName'] as String,
      contentType: json['contentType'] as String,
      byteSize: json['byteSize'] as int,
      localPath: local ? json['localPath'] as String? : null,
      sha256: local ? json['sha256'] as String? : null,
      durationMilliseconds: json['durationMilliseconds'] as int?,
      mediaAssetId: json['mediaAssetId'] as String?,
      storageBucket: local ? json['storageBucket'] as String? : null,
      storagePath: local ? json['storagePath'] as String? : null,
      tusEndpoint: local ? json['tusEndpoint'] as String? : null,
      uploadUrl: local ? json['uploadUrl'] as String? : null,
      uploadOffset: local ? (json['uploadOffset'] as int? ?? 0) : 0,
      downloadUrl: json['downloadUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => kind == 'location'
      ? {
          'kind': kind,
          'label': label,
          'latitude': latitude,
          'longitude': longitude,
          if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
          'capturedAt': capturedAt!.toUtc().toIso8601String(),
        }
      : {
          'kind': kind,
          'mediaAssetId': mediaAssetId,
          'fileName': fileName,
          'contentType': contentType,
          'byteSize': byteSize,
          if (durationMilliseconds != null)
            'durationMilliseconds': durationMilliseconds,
          if (downloadUrl != null) 'downloadUrl': downloadUrl,
        };

  Map<String, Object?> toLocalJson() => {
    ...toJson(),
    if (localPath != null) 'localPath': localPath,
    if (sha256 != null) 'sha256': sha256,
    if (storageBucket != null) 'storageBucket': storageBucket,
    if (storagePath != null) 'storagePath': storagePath,
    if (tusEndpoint != null) 'tusEndpoint': tusEndpoint,
    if (uploadUrl != null) 'uploadUrl': uploadUrl,
    if (uploadOffset > 0) 'uploadOffset': uploadOffset,
  };

  DriverMessageAttachmentModel copyWithUpload({
    String? mediaAssetId,
    String? storageBucket,
    String? storagePath,
    String? tusEndpoint,
    String? uploadUrl,
    int? uploadOffset,
    bool clearUpload = false,
  }) => DriverMessageAttachmentModel.media(
    kind: kind,
    fileName: fileName!,
    contentType: contentType!,
    byteSize: byteSize!,
    localPath: localPath,
    sha256: sha256,
    durationMilliseconds: durationMilliseconds,
    mediaAssetId: mediaAssetId ?? this.mediaAssetId,
    storageBucket: storageBucket ?? this.storageBucket,
    storagePath: storagePath ?? this.storagePath,
    tusEndpoint: tusEndpoint ?? this.tusEndpoint,
    uploadUrl: clearUpload ? null : uploadUrl ?? this.uploadUrl,
    uploadOffset: clearUpload ? 0 : uploadOffset ?? this.uploadOffset,
    downloadUrl: downloadUrl,
  );

  String get copyReference => kind == 'location'
      ? '$label · ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
      : '${kind == 'voice' ? 'Voice note' : fileName}';
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
