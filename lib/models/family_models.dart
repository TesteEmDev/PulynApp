import 'package:json_annotation/json_annotation.dart';

part 'family_models.g.dart';

/// Modelo de Login
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class LoginResponse {
  final String token;
  final User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

/// Modelo de Usuário (Pai/Responsável)
@JsonSerializable()
class User {
  final String id;
  final String email;
  final String name;
  final String? profileImage;
  final String role;
  final String empresaId;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.profileImage,
    required this.role,
    required this.empresaId,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

/// Modelo de Criança
@JsonSerializable()
class Child {
  final String id;
  final String? evento_id;  // ✅ ADICIONADO - ID do evento para rastrear criança no mapa
  final String name;
  final String nickname;
  final int age;
  final String? profileImage;
  final int currentScore;
  final int totalScore;
  final String teamId;
  final String teamName;
  final String teamColor;
  final int rank;
  final List<Achievement> achievements;

  Child({
    required this.id,
    this.evento_id,  // ✅ Adicionado no construtor
    required this.name,
    required this.nickname,
    required this.age,
    this.profileImage,
    required this.currentScore,
    required this.totalScore,
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.rank,
    required this.achievements,
  });

  /// ✅ Getter para URL do avatar (com fallback para avatar padrão)
  String get avatarUrl {
    if (profileImage != null && profileImage!.isNotEmpty) {
      return profileImage!;
    }
    // Fallback para avatar padrão baseado no ID
    return 'https://api.dicebear.com/7.x/adventurer/svg?seed=$id';
  }

  factory Child.fromJson(Map<String, dynamic> json) => _$ChildFromJson(json);
  Map<String, dynamic> toJson() => _$ChildToJson(this);
}

/// Modelo de Conquista
@JsonSerializable()
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime unlockedAt;
  final int points;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
    required this.points,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
  Map<String, dynamic> toJson() => _$AchievementToJson(this);
}

/// Modelo de Evento
@JsonSerializable()
class Event {
  final String id;
  final String name;
  final DateTime date;
  final String status;
  final List<Child> children;
  final List<Team> teams;

  Event({
    required this.id,
    required this.name,
    required this.date,
    required this.status,
    required this.children,
    required this.teams,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);
}

/// Modelo de Time
@JsonSerializable()
class Team {
  final String id;
  final String name;
  final String color;
  final int totalPoints;
  final int ranking;
  final List<String> childrenIds;

  Team({
    required this.id,
    required this.name,
    required this.color,
    required this.totalPoints,
    required this.ranking,
    required this.childrenIds,
  });

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
  Map<String, dynamic> toJson() => _$TeamToJson(this);
}

/// Modelo de Notificação
@JsonSerializable()
class Notification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? childId;
  final DateTime createdAt;
  final bool read;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.childId,
    required this.createdAt,
    required this.read,
  });

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationToJson(this);
}

/// Modelo de Score em Tempo Real
@JsonSerializable()
class ScoreUpdate {
  final String childId;
  final String childName;
  final int points;
  final String checkpointName;
  final DateTime timestamp;
  final String teamColor;

  ScoreUpdate({
    required this.childId,
    required this.childName,
    required this.points,
    required this.checkpointName,
    required this.timestamp,
    required this.teamColor,
  });

  factory ScoreUpdate.fromJson(Map<String, dynamic> json) =>
      _$ScoreUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$ScoreUpdateToJson(this);
}
