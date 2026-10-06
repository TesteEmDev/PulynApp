// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  email: json['email'] as String,
  senha: json['senha'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'senha': instance.senha};

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
  nome: json['nome'] as String,
  profileImage: json['profileImage'] as String?,
  perfil: json['perfil'] as String,
  empresaId: json['empresaId'] as String,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'nome': instance.nome,
  'profileImage': instance.profileImage,
  'perfil': instance.perfil,
  'empresaId': instance.empresaId,
};

Child _$ChildFromJson(Map<String, dynamic> json) => Child(
  id: json['id'] as String,
  eventoId: json['eventoId'] as String?,
  nome: json['nome'] as String,
  apelido: json['apelido'] as String,
  idade: (json['idade'] as num).toInt(),
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
  'eventoId': instance.eventoId,
  'nome': instance.nome,
  'apelido': instance.apelido,
  'idade': instance.idade,
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
  descricao: json['descricao'] as String,
  icon: json['icon'] as String,
  unlockedAt: DateTime.parse(json['unlockedAt'] as String),
  pontos: (json['pontos'] as num).toInt(),
);

Map<String, dynamic> _$AchievementToJson(Achievement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'descricao': instance.descricao,
      'icon': instance.icon,
      'unlockedAt': instance.unlockedAt.toIso8601String(),
      'pontos': instance.pontos,
    };

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  id: json['id'] as String,
  nome: json['nome'] as String,
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
  'nome': instance.nome,
  'date': instance.date.toIso8601String(),
  'status': instance.status,
  'children': instance.children,
  'teams': instance.teams,
};

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
  id: json['id'] as String,
  nome: json['nome'] as String,
  color: json['color'] as String,
  totalPoints: (json['totalPoints'] as num).toInt(),
  ranking: (json['ranking'] as num).toInt(),
  childrenIds: (json['childrenIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
  'id': instance.id,
  'nome': instance.nome,
  'color': instance.color,
  'totalPoints': instance.totalPoints,
  'ranking': instance.ranking,
  'childrenIds': instance.childrenIds,
};

Notification _$NotificationFromJson(Map<String, dynamic> json) => Notification(
  id: json['id'] as String,
  title: json['title'] as String,
  mensagem: json['mensagem'] as String,
  type: json['type'] as String,
  childId: json['childId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  read: json['read'] as bool,
);

Map<String, dynamic> _$NotificationToJson(Notification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'mensagem': instance.mensagem,
      'type': instance.type,
      'childId': instance.childId,
      'createdAt': instance.createdAt.toIso8601String(),
      'read': instance.read,
    };

ScoreUpdate _$ScoreUpdateFromJson(Map<String, dynamic> json) => ScoreUpdate(
  childId: json['childId'] as String,
  childName: json['childName'] as String,
  pontos: (json['pontos'] as num).toInt(),
  checkpointName: json['checkpointName'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  teamColor: json['teamColor'] as String,
);

Map<String, dynamic> _$ScoreUpdateToJson(ScoreUpdate instance) =>
    <String, dynamic>{
      'childId': instance.childId,
      'childName': instance.childName,
      'pontos': instance.pontos,
      'checkpointName': instance.checkpointName,
      'timestamp': instance.timestamp.toIso8601String(),
      'teamColor': instance.teamColor,
    };
