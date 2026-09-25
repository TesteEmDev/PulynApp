// Modelos para rastreio de avatares no mapa

class ScoreEntry {
  final String id;
  final String childId;
  final String childName;
  final String checkpointId;
  final String checkpointName;
  final int points;
  final DateTime timestamp;
  final String teamColor;
  final String gameType; // zone_conquest, treasure_hunt, monster_hunt

  ScoreEntry({
    required this.id,
    required this.childId,
    required this.childName,
    required this.checkpointId,
    required this.checkpointName,
    required this.points,
    required this.timestamp,
    required this.teamColor,
    required this.gameType,
  });

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'] as String? ?? '',
      childId: json['childId'] ?? json['child_id'] ?? '',
      childName: json['childName'] ?? json['child_name'] ?? 'Criança',
      checkpointId: json['checkpointId'] ?? json['checkpoint_id'] ?? '',
      checkpointName: json['checkpointName'] ?? json['checkpoint_name'] ?? 'Checkpoint',
      points: (json['points'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      teamColor: json['teamColor'] ?? json['team_color'] ?? '#FFFFFF',
      gameType: json['gameType'] ?? json['game_type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'childName': childName,
      'checkpointId': checkpointId,
      'checkpointName': checkpointName,
      'points': points,
      'timestamp': timestamp.toIso8601String(),
      'teamColor': teamColor,
      'gameType': gameType,
    };
  }
}

class ChildCheckpointInfo {
  final String checkpointId;
  final String checkpointName;
  final DateTime lastReadAt;
  final double? mapX;
  final double? mapY;

  ChildCheckpointInfo({
    required this.checkpointId,
    required this.checkpointName,
    required this.lastReadAt,
    this.mapX,
    this.mapY,
  });
}

class AvatarTrackingData {
  final String childId;
  final String avatar;
  final String nickname;
  final double x;
  final double y;
  final String teamColor;

  AvatarTrackingData({
    required this.childId,
    required this.avatar,
    required this.nickname,
    required this.x,
    required this.y,
    required this.teamColor,
  });
}
