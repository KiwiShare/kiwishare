class UserModel {
  final String id;
  final String displayName;
  final String? email;
  final String? username;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? bio;
  final int trustScore;
  final bool isVerified;
  final bool isStudentVerified;
  final String? studentInstitution;
  final String? studentEmail;
  final String? authProvider;
  final int kiwiGold;
  final bool isVip;
  final DateTime? vipExpiresAt;
  final bool vipAutoRenew;

  const UserModel({
    required this.id,
    required this.displayName,
    this.email,
    this.username,
    this.avatarUrl,
    this.coverImageUrl,
    this.bio,
    required this.trustScore,
    required this.isVerified,
    this.isStudentVerified = false,
    this.studentInstitution,
    this.studentEmail,
    this.authProvider,
    this.kiwiGold = 100,
    this.isVip = false,
    this.vipExpiresAt,
    this.vipAutoRenew = true,
  });

  /// Create a copy of this UserModel with updated fields.
  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? username,
    String? avatarUrl,
    String? coverImageUrl,
    String? bio,
    int? trustScore,
    bool? isVerified,
    bool? isStudentVerified,
    String? studentInstitution,
    String? studentEmail,
    String? authProvider,
    int? kiwiGold,
    bool? isVip,
    DateTime? vipExpiresAt,
    bool? vipAutoRenew,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bio: bio ?? this.bio,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      isStudentVerified: isStudentVerified ?? this.isStudentVerified,
      studentInstitution: studentInstitution ?? this.studentInstitution,
      studentEmail: studentEmail ?? this.studentEmail,
      authProvider: authProvider ?? this.authProvider,
      kiwiGold: kiwiGold ?? this.kiwiGold,
      isVip: isVip ?? this.isVip,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
      vipAutoRenew: vipAutoRenew ?? this.vipAutoRenew,
    );
  }

  /// Convert to Map for database/serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
      'coverImageUrl': coverImageUrl,
      'bio': bio,
      'trustScore': trustScore,
      'isVerified': isVerified,
      'isStudentVerified': isStudentVerified,
      'studentInstitution': studentInstitution,
      'studentEmail': studentEmail,
      'authProvider': authProvider,
      'kiwiGold': kiwiGold,
      'isVip': isVip,
      'vipExpiresAt': vipExpiresAt?.toIso8601String(),
      'vipAutoRenew': vipAutoRenew,
    };
  }

  /// Create from Map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      avatarUrl: map['avatarUrl'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      bio: map['bio'] as String?,
      trustScore: (map['trustScore'] is num)
          ? (map['trustScore'] as num).toInt()
          : 100,
      isVerified: map['isVerified'] == true,
      isStudentVerified: map['isStudentVerified'] == true,
      studentInstitution: map['studentInstitution'] as String?,
      studentEmail: map['studentEmail'] as String?,
      authProvider: map['authProvider'] as String?,
      kiwiGold: (map['kiwiGold'] is num)
          ? (map['kiwiGold'] as num).toInt()
          : 100,
      isVip: map['isVip'] == true,
      vipExpiresAt: map['vipExpiresAt'] != null
          ? DateTime.tryParse(map['vipExpiresAt'].toString())
          : null,
      vipAutoRenew: map['vipAutoRenew'] != false,
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
        other.email == email &&
        other.username == username &&
        other.avatarUrl == avatarUrl &&
        other.coverImageUrl == coverImageUrl &&
        other.trustScore == trustScore &&
        other.isVerified == isVerified &&
        other.authProvider == authProvider &&
        other.kiwiGold == kiwiGold;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      displayName,
      email,
      username,
      avatarUrl,
      coverImageUrl,
      trustScore,
      isVerified,
      authProvider,
      kiwiGold,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, email: $email, username: $username, avatarUrl: $avatarUrl, trustScore: $trustScore, isVerified: $isVerified, authProvider: $authProvider, kiwiGold: $kiwiGold)';
  }
}
