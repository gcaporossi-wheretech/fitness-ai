/// User domain model matching the auth service UserResponse schema.
class User {
  const User({
    required this.id,
    required this.email,
    this.name,
    this.age,
    this.goals,
    this.limitations,
    this.aiCredits = 0,
    this.language = 'it',
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? name;
  final int? age;
  final Map<String, dynamic>? goals;
  final Map<String, dynamic>? limitations;
  final int aiCredits;
  final String language;
  final DateTime createdAt;

  /// Create from JSON (API response).
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'] as String,
      name: json['name'] as String?,
      age: json['age'] as int?,
      goals: json['goals'] as Map<String, dynamic>?,
      limitations: json['limitations'] as Map<String, dynamic>?,
      aiCredits: (json['ai_credits'] ?? json['aiCredits'] ?? 0) as int,
      language: (json['language'] ?? 'it') as String,
      createdAt: json['created_at'] is DateTime
          ? json['created_at'] as DateTime
          : DateTime.parse(
              (json['created_at'] ?? json['createdAt']).toString()),
    );
  }

  /// Serialize to JSON for Hive caching.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'age': age,
      'goals': goals,
      'limitations': limitations,
      'ai_credits': aiCredits,
      'language': language,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    int? age,
    Map<String, dynamic>? goals,
    Map<String, dynamic>? limitations,
    int? aiCredits,
    String? language,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      goals: goals ?? this.goals,
      limitations: limitations ?? this.limitations,
      aiCredits: aiCredits ?? this.aiCredits,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
