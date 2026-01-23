import 'package:json_annotation/json_annotation.dart';

class Did {
  final String id;
  final String didString;
  final String method;
  final String keyType;
  final DateTime createdAt;
  final bool isDefault;
  final Map<String, dynamic>? metadata;

  Did({
    required this.id,
    required this.didString,
    required this.method,
    required this.keyType,
    required this.createdAt,
    this.isDefault = false,
    this.metadata,
  });

  factory Did.fromJson(Map<String, dynamic> json) {
    return Did(
      id: json['id'] as String,
      didString: json['didString'] as String,
      method: json['method'] as String,
      keyType: json['keyType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'didString': didString,
        'method': method,
        'keyType': keyType,
        'createdAt': createdAt.toIso8601String(),
        'isDefault': isDefault,
        'metadata': metadata,
      };

  String get shortDid {
    if (didString.length <= 20) return didString;
    return '${didString.substring(0, 10)}...${didString.substring(didString.length - 8)}';
  }

  Did copyWith({
    String? id,
    String? didString,
    String? method,
    String? keyType,
    DateTime? createdAt,
    bool? isDefault,
    Map<String, dynamic>? metadata,
  }) {
    return Did(
      id: id ?? this.id,
      didString: didString ?? this.didString,
      method: method ?? this.method,
      keyType: keyType ?? this.keyType,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
      metadata: metadata ?? this.metadata,
    );
  }
}
