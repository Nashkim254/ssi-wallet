class Credential {
  final String id;
  final String name;
  final String type;
  final String format; // W3C VC, ISO mdoc, SD-JWT VC
  final String issuerName;
  final String? issuerDid;
  final String? holderDid;
  final DateTime issuedDate;
  final DateTime? expiryDate;
  final Map<String, dynamic> claims;
  final String? proofType;
  final CredentialState state;
  final String? imageUrl;
  final String? backgroundColor;
  final String? textColor;

  Credential({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    required this.issuerName,
    this.issuerDid,
    this.holderDid,
    required this.issuedDate,
    this.expiryDate,
    required this.claims,
    this.proofType,
    this.state = CredentialState.valid,
    this.imageUrl,
    this.backgroundColor,
    this.textColor,
  });

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['type'] as String,
      type: json['type'] as String,
      format: json['format'] as String,
      issuerName: json['issuerName'] as String? ?? 'Unknown Issuer',
      issuerDid: json['issuerDid'] as String?,
      holderDid: json['holderDid'] as String?,
      issuedDate: DateTime.parse(json['issuedDate'] as String),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      claims: Map<String, dynamic>.from(json['claims'] as Map? ?? {}),
      proofType: json['proofType'] as String?,
      state: _parseState(json['state'] as String?),
      imageUrl: json['imageUrl'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      textColor: json['textColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'format': format,
        'issuerName': issuerName,
        'issuerDid': issuerDid,
        'holderDid': holderDid,
        'issuedDate': issuedDate.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'claims': claims,
        'proofType': proofType,
        'state': state.toString().split('.').last,
        'imageUrl': imageUrl,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
      };

  static CredentialState _parseState(String? state) {
    switch (state?.toLowerCase()) {
      case 'valid':
        return CredentialState.valid;
      case 'expired':
        return CredentialState.expired;
      case 'revoked':
        return CredentialState.revoked;
      case 'suspended':
        return CredentialState.suspended;
      default:
        return CredentialState.valid;
    }
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }

  String get statusText {
    if (state == CredentialState.revoked) return 'Revoked';
    if (state == CredentialState.suspended) return 'Suspended';
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring Soon';
    return 'Valid';
  }

  Credential copyWith({
    String? id,
    String? name,
    String? type,
    String? format,
    String? issuerName,
    String? issuerDid,
    String? holderDid,
    DateTime? issuedDate,
    DateTime? expiryDate,
    Map<String, dynamic>? claims,
    String? proofType,
    CredentialState? state,
    String? imageUrl,
    String? backgroundColor,
    String? textColor,
  }) {
    return Credential(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      format: format ?? this.format,
      issuerName: issuerName ?? this.issuerName,
      issuerDid: issuerDid ?? this.issuerDid,
      holderDid: holderDid ?? this.holderDid,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      claims: claims ?? this.claims,
      proofType: proofType ?? this.proofType,
      state: state ?? this.state,
      imageUrl: imageUrl ?? this.imageUrl,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }
}

enum CredentialState {
  valid,
  expired,
  revoked,
  suspended,
}
