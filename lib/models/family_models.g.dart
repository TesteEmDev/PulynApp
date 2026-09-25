// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{'token': instance.token, 'user': instance.user};

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  profileImage: json['profileImage'] as String?,
  role: json['role'] as String,
  empresaId: json['empresaId'] as String,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'profileImage': instance.profileImage,
  'role': instance.role,
  'empresaId': instance.empresaId,
};

Child _$ChildFromJson(Map<String, dynamic> json) => Child(
  id: json['id'] as String,
  evento_id: json['evento_id'] as String?,
  name: json['name'] as String,
  nickname: json['nickname'] as String,
  age: (json['age'] as num).toInt(),
  profileImage: json['profileImage'] as String?,
  currentScore: (json['currentScore'] as num).toInt(),
  totalScore: (json['totalScore'] as num).toInt(),
  teamId: json['teamId'] as String,
  teamName: json['teamName'] as String,
  teamColor: json['teamColor'] as String,
  rank: (json['rank'] as num).toInt(),
  achievements: (json['achievements'] as List<dynamic>)
      .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ChildToJson(Child instance) => <String, dynamic>{
  'id': instance.id,
  'evento_id': instance.evento_id,
  'name': instance.name,
  'nickname': instance.nickname,
  'age': instance.age,
  'profileImage': instance.profileImage,
  'currentScore': instance.currentScore,
  'totalScore': instance.totalScore,
  'teamId': instance.teamId,
  'teamName': instance.teamName,
  'teamColor': instance.teamColor,
  'rank': instance.rank,
  'achievements': instance.achievements,
};

Achievement _$AchievementFromJson(Map<String, dynamic> json) => Achievement(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  icon: json['icon'] as String,
  unlockedAt: DateTime.parse(json['unlockedAt'] as String),
  points: (json['points'] as num).toInt(),
);

Map<String, dynamic> _$AchievementToJson(Achievement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'icon': instance.icon,
      'unlockedAt': instance.unlockedAt.toIso8601String(),
      'points': instance.points,
    };

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  id: json['id'] as String,
  name: json['name'] as String,
  date: DateTime.parse(json['date'] as String),
  status: json['status'] as String,
  children: (json['children'] as List<dynamic>)
      .map((e) => Child.fromJson(e as Map<String, dynamic>))
      .toList(),
  teams: (json['teams'] as List<dynamic>)
      .map((e) => Team.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'date': instance.date.toIso8601String(),
  'status': instance.status,
  'children': instance.children,
  'teams': instance.teams,
};

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
  id: json['id'] as String,
  name: json['name'] as String,
  color: json['color'] as String,
  totalPoints: (json['totalPoints'] as num).toInt(),
  ranking: (json['ranking'] as num).toInt(),
  childrenIds: (json['childrenIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'totalPoints': instance.totalPoints,
  'ranking': instance.ranking,
  'childrenIds': instance.childrenIds,
};

Notification _$NotificationFromJson(Map<String, dynamic> json) => Notification(
  id: json['id'] as String,
  title: json['title'] as String,
  message: json['message'] as String,
  type: json['type'] as String,
  childId: json['childId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  read: json['read'] as bool,
);

Map<String, dynamic> _$NotificationToJson(Notification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'message': instance.message,
      'type': instance.type,
      'childId': instance.childId,
      'createdAt': instance.createdAt.toIso8601String(),
      'read': instance.read,
    };

ScoreUpdate _$ScoreUpdateFromJson(Map<String, dynamic> json) => ScoreUpdate(
  childId: json['childId'] as String,
  childName: json['childName'] as String,
  points: (json['points'] as num).toInt(),
  checkpointName: json['checkpointName'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  teamColor: json['teamColor'] as String,
);

Map<String, dynamic> _$ScoreUpdateToJson(ScoreUpdate instance) =>
    <String, dynamic>{
      'childId': instance.childId,
      'childName': instance.childName,
      'points': instance.points,
      'checkpointName': instance.checkpointName,
      'timestamp': instance.timestamp.toIso8601String(),
      'teamColor': instance.teamColor,
    };
