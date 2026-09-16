class UserModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final int trustScore;
  final bool isVerified;
  final String? authProvider;

  const UserModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.trustScore,
    required this.isVerified,
    this.authProvider,
  });

  /// Create a copy of this UserModel with updated fields.
  UserModel copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    int? trustScore,
    bool? isVerified,
    String? authProvider,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  /// Convert to Map for database/serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'trustScore': trustScore,
      'isVerified': isVerified,
      'authProvider': authProvider,
    };
  }

  /// Create from Map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      trustScore: map['trustScore'] as int,
      isVerified: map['isVerified'] as bool,
      authProvider: map['authProvider'] as String?,
    );
  }

  /// JSON serialization helper matching user's instruction.
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      UserModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.trustScore == trustScore &&
        other.isVerified == isVerified &&
        other.authProvider == authProvider;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      displayName,
      avatarUrl,
      trustScore,
      isVerified,
      authProvider,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, avatarUrl: $avatarUrl, trustScore: $trustScore, isVerified: $isVerified, authProvider: $authProvider)';
  }
}
