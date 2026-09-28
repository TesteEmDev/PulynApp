// Providers locais definidos aqui
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'auth_provider.dart';
import 'websocket_provider.dart';
import '../models/family_models.dart';
import '../utils/logger.dart';

// ✅ Exporta providers externos
export 'auth_provider.dart' show apiServiceProvider, authProvider, authInitProvider;
export 'websocket_provider.dart' show webSocketConnectionProvider, webSocketServiceProvider, webSocketStatusProvider;
export 'events_provider.dart' show currentEventProvider, upcomingEventsProvider, eventDetailsProvider, eventResultsProvider, certificateProvider;

// ✅ Exporta providers locais
export 'index.dart' show activeEventProvider, activeGameProvider, mapChildrenRealtimeProvider, checkpointsByEventProvider, zonesByEventProvider, checkpointsCacheProvider, mapRefreshProvider, scoreLogProvider, childLastCheckpointProvider;

// ✅ Provider para evento ativo (StreamProvider com polling a cada 5 segundos)
// MUDADO DE FutureProvider PARA StreamProvider para refetch automático!
final activeEventProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) async* {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  // Carrega INICIALMENTE
  try {
    final event = await apiService.getActiveEvent();
    log.i('[EVENT] 📅 Evento ativo: ${event?['name'] ?? 'NENHUM'}');
    yield event;
  } catch (e) {
    log.w('[EVENT] ⚠️ Erro ao carregar evento: $e');
    yield null;
  }
  
  // Polling automático a cada 5 segundos
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    try {
      final event = await apiService.getActiveEvent();
      yield event;
    } catch (e) {
      // silencioso no polling
    }
  }
});

// ✅ Provider para jogo ativo do evento (StreamProvider com polling a cada 5 segundos)
// MUDADO DE FutureProvider PARA StreamProvider para refetch automático!
final activeGameProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) async* {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  // Carrega INICIALMENTE
  try {
    final activeGame = await apiService.getActiveGame();
    
    if (activeGame == null) {
      log.i('[GAME] 🎮 Jogo ativo: NENHUM');
      yield null;
    } else {
      // 🎯 Usar gameName (nome da brincadeira ativa), não name (nome do evento)
      final gameName = activeGame['gameName'] ?? 'Nenhum jogo em andamento';
      log.i('[GAME] 🎮 Jogo ativo: $gameName');
      yield {
        'id': activeGame['id'],
        'name': activeGame['name'], // Nome do evento
        'gameName': gameName, // Nome da brincadeira ativa
        'gameId': activeGame['gameId'],
        'description': activeGame['gameDescription'] ?? 'Jogo em andamento',
        'type': activeGame['gameType'] ?? 'standard',
        'duration': activeGame['duration'],
        'default_points': activeGame['default_points'],
        'hasActiveGame': activeGame['hasActiveGame'] ?? false,
      };
    }
  } catch (e) {
    log.w('[GAME] ⚠️ Erro ao carregar jogo: $e');
    yield null;
  }
  
  // Polling automático a cada 5 segundos
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    try {
      final activeGame = await apiService.getActiveGame();
      if (activeGame != null) {
        final gameName = activeGame['gameName'] ?? 'Nenhum jogo em andamento';
        yield {
          'id': activeGame['id'],
          'name': activeGame['name'],
          'gameName': gameName,
          'gameId': activeGame['gameId'],
          'description': activeGame['gameDescription'] ?? 'Jogo em andamento',
          'type': activeGame['gameType'] ?? 'standard',
          'duration': activeGame['duration'],
          'default_points': activeGame['default_points'],
          'hasActiveGame': activeGame['hasActiveGame'] ?? false,
        };
      } else {
        yield null;
      }
    } catch (e) {
      // silencioso no polling
    }
  }
});

// ✅ Provider para atualização de crianças em tempo real via polling + WebSocket trigger
// Exatamente igual ao childrenProvider do home_screen.dart que FUNCIONA!
final mapChildrenRealtimeProvider = StreamProvider.autoDispose<List<Child>>((ref) async* {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  // ✅ Watch o refresh notifier para refetch quando necessário
  ref.watch(mapRefreshProvider);
  
  // ✅ Carrega dados INICIALMENTE
  log.i('[MAP_PROVIDER] 🔄 Carregando filhos (inicial)...');
  try {
    final children = await apiService.getChildren();
    log.i('[MAP_PROVIDER] ✅ Filhos carregados: ${children.length}');
    yield children;
  } catch (e) {
    log.e('[MAP_PROVIDER] ❌ Erro ao carregar: $e');
    yield [];
  }
  
  // ✅ Polling automático a cada 5 segundos
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    try {
      final children = await apiService.getChildren();
      log.i('[MAP_PROVIDER] 📡 Dados atualizados via polling');
      yield children;
    } catch (e) {
      log.e('[MAP_PROVIDER] ❌ Erro no polling: $e');
    }
  }
});

/// Notifier para trigger manual de refresh do mapa
class MapRefreshNotifier extends StateNotifier<int> {
  MapRefreshNotifier() : super(0);
  
  void refresh() {
    state++;
    log.i('[MAP] 🔄 Trigger refresh: $state');
  }
}

final mapRefreshProvider = StateNotifierProvider((ref) {
  return MapRefreshNotifier();
});

// ✅ Provider para scoreLog - rastreia conquistas em tempo real
final scoreLogProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  // ✅ Watch o refresh notifier para refetch quando necessário
  ref.watch(mapRefreshProvider);
  
  // ✅ Carrega histórico INICIALMENTE
  try {
    final activeEvent = await apiService.getActiveEvent();
    if (activeEvent != null) {
      final history = await apiService.getScoreHistory(activeEvent['id']);
      yield history;
    } else {
      yield [];
    }
  } catch (e) {
    yield [];
  }
  
  // ✅ Polling automático a cada 10 segundos
  while (true) {
    await Future.delayed(const Duration(seconds: 10));
    try {
      final activeEvent = await apiService.getActiveEvent();
      if (activeEvent != null) {
        final history = await apiService.getScoreHistory(activeEvent['id']);
        yield history;
      }
    } catch (e) {
      // silencioso
    }
  }
});

/// Provider que calcula o ÚLTIMO checkpoint conquistado de cada criança
///
/// ✅ Combina duas fontes:
/// 1. scoreLogProvider (histórico via `pontuacoes`, alimentado por polling) —
///    hoje só é gravado pelo fluxo de Zona (Zone Conquest).
/// 2. realtimeCheckpointTrackingProvider (leituras via WebSocket
///    TERRITORY_CONQUERED) — o backend já dispara esse evento para os 3
///    jogos (Zona, Caça ao Tesouro, Caça ao Monstro), então é essa fonte
///    que faz o rastreio funcionar em todos os jogos, não só na Zona.
final childLastCheckpointProvider = Provider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  final scoreLogAsync = ref.watch(scoreLogProvider);
  final realtimeTracking = ref.watch(realtimeCheckpointTrackingProvider);

  final lastCheckpointMap = <String, Map<String, dynamic>>{};
  final scoreLog = scoreLogAsync.value ?? [];

  if (scoreLog.isNotEmpty) {
    // Inverte a lista (mais recentes primeiro)
    final sorted = [...scoreLog].reversed.toList();

    for (final entry in sorted) {
      try {
        // ✅ Tentar TODOS os possíveis nomes de campo
        String? childId;
        if (entry.containsKey('child_id')) {
          childId = entry['child_id'] as String?;
        } else if (entry.containsKey('childId')) {
          childId = entry['childId'] as String?;
        } else if (entry.containsKey('crianca_id')) {
          childId = entry['crianca_id'] as String?;
        }
        
        String? checkpointId;
        if (entry.containsKey('checkpoint_id')) {
          checkpointId = entry['checkpoint_id'] as String?;
        } else if (entry.containsKey('checkpointId')) {
          checkpointId = entry['checkpointId'] as String?;
        } else if (entry.containsKey('checkpoint')) {
          checkpointId = entry['checkpoint'] as String?;
        }
        
        String? checkpointName;
        if (entry.containsKey('checkpoint_name')) {
          checkpointName = entry['checkpoint_name'] as String?;
        } else if (entry.containsKey('checkpointName')) {
          checkpointName = entry['checkpointName'] as String?;
        }
        
        if (childId == null) {
          continue;
        }
        
        // Se já tem um registro para essa criança, pula
        if (lastCheckpointMap.containsKey(childId)) {
          continue;
        }
        
        if (checkpointId != null) {
          lastCheckpointMap[childId] = {
            'checkpointId': checkpointId,
            'checkpointName': checkpointName,
            'timestamp': entry['created_at'] ?? DateTime.now().toIso8601String(),
            'points': entry['points'] ?? 0,
          };
        }
      } catch (e) {
        // sem log
      }
    }
  }

  // ✅ Sobrepõe com leituras em tempo real via WebSocket. Cobre Caça ao
  // Tesouro e Caça ao Monstro, que hoje não gravam em `pontuacoes` (fonte
  // usada acima) — sem isso, o avatar só se movia no jogo Zona.
  realtimeTracking.forEach((childId, reading) {
    lastCheckpointMap[childId] = {
      'checkpointId': reading.checkpointId,
      'checkpointName': reading.checkpointName,
      'timestamp': reading.timestamp.toIso8601String(),
      'points': reading.points,
    };
  });

  return lastCheckpointMap;
});

/// Provider para cache de checkpoints por evento
final checkpointsCacheProvider = StateNotifierProvider<CheckpointsCacheNotifier, Map<String, List<Map<String, dynamic>>>>((ref) {
  return CheckpointsCacheNotifier();
});

class CheckpointsCacheNotifier extends StateNotifier<Map<String, List<Map<String, dynamic>>>> {
  CheckpointsCacheNotifier() : super({});

  void setCheckpoints(String eventoId, List<Map<String, dynamic>> checkpoints) {
    state = {...state, eventoId: checkpoints};
  }

  List<Map<String, dynamic>>? getCheckpoints(String eventoId) {
    return state[eventoId];
  }

  void clearCache() {
    state = {};
  }
}

/// Provider para buscar checkpoints com cache
final checkpointsByEventProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventoId) async {
  final cache = ref.read(checkpointsCacheProvider);
  final cachedCheckpoints = cache[eventoId];
  
  // Se tem no cache, retorna sem log
  if (cachedCheckpoints != null) {
    return cachedCheckpoints;
  }

  // Se não tem no cache, busca da API (só loga uma vez)
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  log.i('[CHECKPOINTS] 🔄 Buscando checkpoints para evento: $eventoId');
  final checkpoints = await apiService.getCheckpointsByEvent(eventoId);
  log.i('[CHECKPOINTS] ✅ Retorno da API: ${checkpoints.length} checkpoints');
  
  // Salva no cache
  ref.read(checkpointsCacheProvider.notifier).setCheckpoints(eventoId, checkpoints);
  
  return checkpoints;
});

/// Provider para buscar zonas (áreas) do evento do backend
final zonesByEventProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventoId) async {
  try {
    if (eventoId.isEmpty) {
      log.w('[ZONES] ⚠️ eventoId vazio');
      return [];
    }
    
    final apiService = ref.read(apiServiceProvider);
    await apiService.init();
    
    log.i('[ZONES] 🔄 Buscando zonas do backend para evento: $eventoId');
    
    try {
      // Busca zonas usando o novo método getZonesByEvent
      final zones = await apiService.getZonesByEvent(eventoId);
      
      if (zones.isNotEmpty) {
        log.i('[ZONES] ✅ Zonas carregadas do backend: ${zones.length} áreas');
        // Atualizar cache
        await _cacheZonesToStorage(apiService, eventoId, zones);
        return zones;
      } else {
        log.i('[ZONES] 📝 Nenhuma zona no backend');
        // Tentar cache
        final cached = await _loadZonesFromStorage(apiService, eventoId);
        if (cached.isNotEmpty) {
          log.i('[ZONES] ✅ Zonas carregadas do cache: ${cached.length} áreas');
          return cached;
        }
        return [];
      }
    } catch (apiError) {
      log.w('[ZONES] ⚠️ Erro ao chamar API: $apiError');
      // Tentar cache quando API falha
      final cached = await _loadZonesFromStorage(apiService, eventoId);
      if (cached.isNotEmpty) {
        log.i('[ZONES] ✅ Zonas carregadas do cache (fallback após erro): ${cached.length} áreas');
        return cached;
      }
      return [];
    }
  } catch (e, st) {
    log.e('[ZONES] ❌ Erro ao carregar zonas: $e');
    log.e('[ZONES] Stack: $st');
    return [];
  }
});

/// Carrega zonas do cache (SharedPreferences)
Future<List<Map<String, dynamic>>> _loadZonesFromStorage(
  dynamic apiService,
  String eventoId,
) async {
  try {
    final key = 'zones_$eventoId';
    final stored = apiService.prefs.getString(key);
    
    if (stored != null) {
      final zones = (jsonDecode(stored) as List)
          .map((z) => Map<String, dynamic>.from(z as Map))
          .toList();
      log.i('[ZONES] 📦 Zonas do cache: ${zones.length} áreas');
      return zones;
    }
  } catch (e) {
    log.w('[ZONES] ⚠️ Erro ao carregar cache: $e');
  }
  return [];
}

/// Salva zonas no cache (SharedPreferences)
Future<void> _cacheZonesToStorage(
  dynamic apiService,
  String eventoId,
  List<Map<String, dynamic>> zones,
) async {
  try {
    final key = 'zones_$eventoId';
    final zonesJson = jsonEncode(zones);
    await apiService.prefs.setString(key, zonesJson);
    log.i('[ZONES] � Zonas cacheadas com sucesso');
  } catch (e) {
    log.w('[ZONES] ⚠️ Erro ao cachear zonas: $e');
  }
}

// ✅ Provider para rastreamento em TEMPO REAL via WebSocket
// Escuta eventos de SCORE_UPDATE e atualiza posições de crianças instantaneamente
final realtimeCheckpointTrackingProvider = StateNotifierProvider<RealtimeTrackingNotifier, Map<String, CheckpointReading>>((ref) {
  final notifier = RealtimeTrackingNotifier();
  
  // ✅ Setup listener de WebSocket quando o provider é criado
  Future.microtask(() {
    final webSocketService = ref.read(webSocketServiceProvider);
    
    // Escuta evento SCORE_UPDATE quando criança lê uma pulseira
    webSocketService.on('SCORE_UPDATE', (data) {
      // ✅ O WebSocketService entrega a mensagem inteira ({type, payload}),
      // não só o payload — os campos ficam dentro de data['payload'].
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? data;
      log.i('⚡ PULSEIRA LIDA - Criança: ${payload['child_name'] ?? payload['criancaName'] ?? 'N/A'} | Checkpoint: ${payload['checkpoint_name'] ?? payload['checkpointName'] ?? 'N/A'} | Pontos: ${payload['points'] ?? 0}');

      try {
        final childId = payload['criancaId'] ?? payload['crianca_id'] ?? payload['child_id'] ?? payload['childId'];
        final checkpointId = payload['checkpointId'] ?? payload['checkpoint_id'] ?? payload['checkpoint'];
        final checkpointName = payload['checkpointName'] ?? payload['checkpoint_name'] ?? '';
        final points = payload['points'] ?? 0;

        if (childId != null && checkpointId != null) {
          notifier.updateChildCheckpoint(
            childId.toString(),
            checkpointId.toString(),
            checkpointName.toString(),
            points,
          );
        }
      } catch (e) {
        // erro silencioso
      }
    });

    // Escuta CHILD_CHECKPOINT_PASSED. Enviado pelo backend em TODOS os jogos
    // (Zona, Zone Conquest equipe/individual, Caça ao Tesouro, Caça ao
    // Monstro) sempre que a criança passa por um checkpoint. Não usar
    // TERRITORY_CONQUERED aqui: ele não é enviado pelos modos Zone Conquest.
    webSocketService.on('CHILD_CHECKPOINT_PASSED', (data) {
      // ✅ Mesmo bug do SCORE_UPDATE: os campos vêm dentro de data['payload'].
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? data;
      log.i('🏆 TERRITÓRIO CONQUISTADO - Criança: ${payload['criancaName'] ?? 'N/A'} | Checkpoint: ${payload['checkpointId'] ?? 'N/A'}');

      try {
        final childId = payload['criancaId'] ?? payload['crianca_id'] ?? payload['child_id'] ?? payload['childId'];
        final checkpointId = payload['checkpointId'] ?? payload['checkpoint_id'];
        final checkpointName = payload['checkpointName'] ?? payload['checkpoint_name'] ?? '';
        final teamColor = payload['teamColor'] ?? '#FFFFFF';
        final points = payload['points'] ?? 10;

        if (childId != null && checkpointId != null) {
          notifier.updateChildCheckpoint(
            childId.toString(),
            checkpointId.toString(),
            checkpointName.toString(),
            points is num ? points.toInt() : 10,
            teamColor: teamColor.toString(),
          );
        }
      } catch (e) {
        // erro silencioso
      }
    });
  });
  
  return notifier;
});

/// Classe para armazenar informações de leitura de checkpoint
class CheckpointReading {
  final String checkpointId;
  final String checkpointName;
  final int points;
  final DateTime timestamp;
  final String? teamColor;
  
  CheckpointReading({
    required this.checkpointId,
    required this.checkpointName,
    required this.points,
    DateTime? timestamp,
    this.teamColor,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Notifier para rastreamento em tempo real
class RealtimeTrackingNotifier extends StateNotifier<Map<String, CheckpointReading>> {
  RealtimeTrackingNotifier() : super({});
  
  /// Atualiza a posição de uma criança quando ela lê uma pulseira
  void updateChildCheckpoint(
    String childId,
    String checkpointId,
    String checkpointName,
    int points, {
    String? teamColor,
  }) {
    log.i('[TRACKING_NOTIFIER] 📍 Atualizando criança $childId → checkpoint $checkpointName');
    
    state = {
      ...state,
      childId: CheckpointReading(
        checkpointId: checkpointId,
        checkpointName: checkpointName,
        points: points,
        teamColor: teamColor,
      ),
    };
    
    log.i('[TRACKING_NOTIFIER] ✅ Estado atualizado. Total: ${state.length} crianças rastreadas');
  }
  
  /// Obtém o último checkpoint de uma criança
  CheckpointReading? getChildLastCheckpoint(String childId) {
    return state[childId];
  }
  
  /// Limpa o rastreamento de uma criança (ou de todas)
  void clearTracking({String? childId}) {
    if (childId != null) {
      state = {...state}..remove(childId);
      log.i('[TRACKING_NOTIFIER] 🗑️ Rastreamento de $childId removido');
    } else {
      state = {};
      log.i('[TRACKING_NOTIFIER] 🗑️ Todos os rastreamentos removidos');
    }
  }
}


/// 🎯 PROVIDER PARA RASTREIO: Calcula posições de avatares baseado em scoreLog
/// 
/// Regra: Avatar é posicionado no último checkpoint que a criança conquistou
/// Aplicável para: Zone Conquest, Treasure Hunt, Monster Hunt
final avatarTrackingPositionsProvider = Provider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  final childrenAsync = ref.watch(mapChildrenRealtimeProvider);
  // ✅ Já combina histórico (scoreLog/pontuacoes) com leituras em tempo real
  // via WebSocket (TERRITORY_CONQUERED), que cobrem os 3 jogos.
  final lastCheckpointByChild = ref.watch(childLastCheckpointProvider);
  final checkpointsAsync = ref.watch(checkpointsByEventProvider(ref.watch(activeEventProvider).value?['id'] as String? ?? ''));

  return childrenAsync.whenData((children) {
    return checkpointsAsync.whenData((checkpoints) {
      final positions = <String, Map<String, dynamic>>{};

      log.i('[TRACKING] 🎯 Calculando posições para ${children.length} crianças');

      final checkpointSlots = <String, int>{}; // Conta quantas crianças já estão em cada checkpoint

      for (final child in children) {
        final lastInfo = lastCheckpointByChild[child.id];
        final checkpointId = lastInfo?['checkpointId'];

        final checkpoint = checkpointId != null
            ? checkpoints.firstWhere(
                (cp) => cp['id'].toString() == checkpointId.toString(),
                orElse: () => <String, dynamic>{},
              )
            : <String, dynamic>{};
        final mapX = checkpoint['map_x'] ?? checkpoint['mapX'];
        final mapY = checkpoint['map_y'] ?? checkpoint['mapY'];

        if (mapX != null && mapY != null) {
          // Avatar vai para o checkpoint
          final baseX = (mapX as num).toDouble();
          final baseY = (mapY as num).toDouble();
          final slot = checkpointSlots[checkpointId] ?? 0;
          checkpointSlots[checkpointId] = slot + 1;

          // Distribuir avatares em volta do checkpoint (não sobrepor)
          final offsets = [-35.0, 0.0, 35.0];
          final offsetX = offsets[slot % offsets.length];
          final row = (slot / 3).floor();

          positions[child.id] = {
            'x': baseX + offsetX,
            'y': baseY + 68 + (row * 50),
            'checkpointId': checkpointId,
            'checkpointName': lastInfo?['checkpointName'],
          };

          log.i('[TRACKING] 📍 ${child.nickname}: checkpoint=${lastInfo?['checkpointName']} @ (${baseX + offsetX}, ${baseY + 68 + (row * 50)})');
        } else {
          // Se não tem leitura, coloca em posição padrão (centro do mapa)
          positions[child.id] = {
            'x': 225.0, // Centro da largura (450/2)
            'y': 160.0, // Centro da altura (320/2)
            'checkpointId': null,
            'checkpointName': 'Centro',
          };

          log.i('[TRACKING] 📍 ${child.nickname}: sem leitura, posicionado no centro');
        }
      }

      log.i('[TRACKING] ✅ Posições calculadas para ${positions.length} crianças');
      return positions;
    }).value ?? {};
  }).value ?? {};
});

/// Provider que retorna posições em tempo real quando scoreLog muda
/// (dispara recalcuação automática)
final liveAvatarPositionsProvider = StreamProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async* {
  // Emitir valor inicial
  final initialPositions = ref.read(avatarTrackingPositionsProvider);
  yield initialPositions;
  
  // Escutar mudanças no scoreLog
  ref.listen(scoreLogProvider, (previous, next) {
    log.i('[TRACKING] 🔄 scoreLog mudou, recalculando posições...');
  });
  
  // Polling periódico para garantir sincronização
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    final positions = ref.read(avatarTrackingPositionsProvider);
    yield positions;
  }
});
