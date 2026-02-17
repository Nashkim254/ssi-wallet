import 'package:ssi/pigeon/ssi_api.g.dart';

/// Presentation request model
class PresentationRequest {
  final String interactionId;
  final String verifierName;
  final String verifierUrl;
  final String? verifierLogo;
  final List<RequestedClaim> requestedClaims;
  final List<String> matchingCredentialIds;
  final Map<String, bool>? intentToRetain;

  PresentationRequest({
    required this.interactionId,
    required this.verifierName,
    required this.verifierUrl,
    this.verifierLogo,
    required this.requestedClaims,
    required this.matchingCredentialIds,
    this.intentToRetain,
  });

  factory PresentationRequest.fromDto(PresentationRequestDto dto) {
    return PresentationRequest(
      interactionId: dto.interactionId,
      verifierName: dto.verifierName,
      verifierUrl: dto.verifierUrl,
      verifierLogo: dto.verifierLogo,
      requestedClaims: dto.requestedClaims
          .whereType<RequestedClaimDto>()
          .map((c) => RequestedClaim.fromDto(c))
          .toList(),
      matchingCredentialIds:
          dto.matchingCredentialIds.whereType<String>().toList(),
      intentToRetain: dto.intentToRetain
          ?.map((key, value) => MapEntry(key ?? '', value ?? false)),
    );
  }
}

/// Requested claim model
class RequestedClaim {
  final String claimName;
  final String claimPath;
  final bool required;
  final String? purpose;

  RequestedClaim({
    required this.claimName,
    required this.claimPath,
    required this.required,
    this.purpose,
  });

  factory RequestedClaim.fromDto(RequestedClaimDto dto) {
    return RequestedClaim(
      claimName: dto.claimName,
      claimPath: dto.claimPath,
      required: dto.required,
      purpose: dto.purpose,
    );
  }
}

/// Presentation submission model
class PresentationSubmission {
  final String interactionId;
  final String credentialId;
  final List<String> selectedClaims;

  PresentationSubmission({
    required this.interactionId,
    required this.credentialId,
    required this.selectedClaims,
  });

  PresentationSubmissionDto toDto() {
    return PresentationSubmissionDto(
      interactionId: interactionId,
      credentialId: credentialId,
      selectedClaims: selectedClaims,
    );
  }
}
