import 'driver_session.dart';

enum DriverEntryStage { phone, otp, path, teamInvite }

class DriverTeamInviteModel {
  const DriverTeamInviteModel({
    required this.id,
    required this.tenantId,
    required this.businessName,
    required this.businessInitials,
    required this.locationLabel,
    this.expiresAt,
  });

  factory DriverTeamInviteModel.fromJson(Map<String, dynamic> json) =>
      DriverTeamInviteModel(
        id: json['id'] as String,
        tenantId: json['tenantId'] as String,
        businessName: json['businessName'] as String,
        businessInitials: json['businessInitials'] as String,
        locationLabel: json['locationLabel'] as String,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
      );

  final String id;
  final String tenantId;
  final String businessName;
  final String businessInitials;
  final String locationLabel;
  final DateTime? expiresAt;
}

class DriverPhoneVerificationResult {
  const DriverPhoneVerificationResult({this.session, this.pendingInvite});

  final DriverSessionModel? session;
  final DriverTeamInviteModel? pendingInvite;
}
