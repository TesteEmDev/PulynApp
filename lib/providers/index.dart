// Providers locais definidos aqui
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'auth_provider.dart';
import 'websocket_provider.dart';
import '../models/family_models.dart';
import '../utils/logger.dart';
import '../constants/map_constants.dart';

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
final childLastCheckpointProvider = Provider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  final scoreLogAsync = ref.watch(scoreLogProvider);
  
  return scoreLogAsync.whenData((scoreLog) {
    final lastCheckpointMap = <String, Map<String, dynamic>>{};
    
    if (scoreLog.isEmpty) {
      return lastCheckpointMap;
    }
    
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
    
    return lastCheckpointMap;
  }).value ?? {};
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
  
  final checkpoints = await apiService.getCheckpointsByEvent(eventoId);
  
  // Salva no cache
  ref.read(checkpointsCacheProvider.notifier).setCheckpoints(eventoId, checkpoints);
  
  return checkpoints;
});

/// Provider para buscar zonas (áreas) do evento do backend
/// Com fallback para localStorage e DEFAULT_ZONES (exatamente como web version)
final zonesByEventProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventoId) async {
  try {
    if (eventoId.isEmpty) {
      log.w('[ZONES] ⚠️ eventoId vazio');
      return List<Map<String, dynamic>>.from(DEFAULT_ZONES);
    }
    
    final apiService = ref.read(apiServiceProvider);
    await apiService.init();
    
    log.i('[ZONES] 🔄 Buscando zonas do backend para evento: $eventoId');
    
    try {
      // Busca zonas do endpoint (o Dio já inclui autenticação automática)
      final response = await apiService.dio.get('/events/$eventoId/zones');
      
      if (response.statusCode == 200) {
        final zones = (response.data as List?)
            ?.map((z) => Map<String, dynamic>.from(z as Map))
            .toList() ?? [];
        
        if (zones.isNotEmpty) {
          log.i('[ZONES] ✅ Zonas carregadas do backend: ${zones.length} áreas');
          // Atualizar localStorage como cache (fallback futuro)
          await _cacheZonesToStorage(apiService, eventoId, zones);
          return zones;
        } else {
          log.i('[ZONES] 📝 Nenhuma zona no backend, tentando cache...');
          final cached = await _loadZonesFromStorage(apiService, eventoId);
          if (cached.isNotEmpty) {
            log.i('[ZONES] ✅ Zonas carregadas do cache: ${cached.length} áreas');
            return cached;
          }
          log.i('[ZONES] 📍 Usando zonas padrão');
          return List<Map<String, dynamic>>.from(DEFAULT_ZONES);
        }
      } else {
        log.w('[ZONES] ⚠️ Erro na resposta do backend: ${response.statusCode}');
        final cached = await _loadZonesFromStorage(apiService, eventoId);
        if (cached.isNotEmpty) {
          log.i('[ZONES] ✅ Zonas carregadas do cache (fallback): ${cached.length} áreas');
          return cached;
        }
        return List<Map<String, dynamic>>.from(DEFAULT_ZONES);
      }
    } catch (apiError) {
      log.w('[ZONES] ⚠️ Erro ao chamar API: $apiError');
      // Tentar cache quando API falha
      final cached = await _loadZonesFromStorage(apiService, eventoId);
      if (cached.isNotEmpty) {
        log.i('[ZONES] ✅ Zonas carregadas do cache (fallback após erro): ${cached.length} áreas');
        return cached;
      }
      log.i('[ZONES] 📍 Usando zonas padrão após falha da API');
      return List<Map<String, dynamic>>.from(DEFAULT_ZONES);
    }
  } catch (e, st) {
    log.e('[ZONES] ❌ Erro ao carregar zonas: $e');
    log.e('[ZONES] Stack: $st');
    return List<Map<String, dynamic>>.from(DEFAULT_ZONES);
  }
});

/// Carrega zonas do cache (SharedPreferences)
Future<List<Map<String, dynamic>>> _loadZonesFromStorage(
  ApiService apiService,
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
  ApiService apiService,
  String eventoId,
  List<Map<String, dynamic>> zones,
) async {
  try {
    final key = 'zones_$eventoId';
    final zonesJson = jsonEncode(zones);
    await apiService._prefs.setString(key, zonesJson);
    log.i('[ZONES] 💾 Zonas cacheadas com sucesso');
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
      log.i('⚡ PULSEIRA LIDA - Criança: ${data['child_name'] ?? 'N/A'} | Checkpoint: ${data['checkpoint_name'] ?? 'N/A'} | Pontos: ${data['points'] ?? 0}');
      
      try {
        final childId = data['child_id'] ?? data['childId'];
        final checkpointId = data['checkpoint_id'] ?? data['checkpointId'] ?? data['checkpoint'];
        final checkpointName = data['checkpoint_name'] ?? data['checkpointName'] ?? '';
        final points = data['points'] ?? 0;
        
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
    
    // Escuta evento TERRITORY_CONQUERED (zona conquistada)
    webSocketService.on('TERRITORY_CONQUERED', (data) {
      log.i('🏆 TERRITÓRIO CONQUISTADO - Time: ${data['teamName'] ?? 'N/A'} | Checkpoint: ${data['checkpoint_name'] ?? 'N/A'}');
      
      try {
        final childId = data['crianca_id'] ?? data['child_id'] ?? data['childId'];
        final checkpointId = data['checkpoint_id'] ?? data['checkpointId'];
        final checkpointName = data['checkpoint_name'] ?? data['checkpointName'] ?? '';
        final teamColor = data['teamColor'] ?? '#FFFFFF';
        
        if (childId != null && checkpointId != null) {
          notifier.updateChildCheckpoint(
            childId.toString(),
            checkpointId.toString(),
            checkpointName.toString(),
            10, // default points
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
  final scoreLogAsync = ref.watch(scoreLogProvider);
  final checkpointsAsync = ref.watch(checkpointsByEventProvider(ref.watch(activeEventProvider).value?['id'] as String? ?? ''));
  
  return childrenAsync.whenData((children) {
    return scoreLogAsync.whenData((scoreLog) {
      return checkpointsAsync.whenData((checkpoints) {
        final positions = <String, Map<String, dynamic>>{};
        
        log.i('[TRACKING] 🎯 Calculando posições para ${children.length} crianças');
        log.i('[TRACKING] 📊 Histórico de checkpoints: ${scoreLog.length} leituras');
        
        // Step 1: Encontrar último checkpoint de cada criança
        final childLastCheckpoint = <String, Map<String, dynamic>>{};
        
        // Ordenar scoreLog por data (mais recentes primeiro)
        final sorted = [...scoreLog];
        sorted.sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? a['created_at']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
          final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? b['created_at']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
        
        for (final entry in sorted) {
          final childId = entry['childId'] ?? entry['child_id'];
          if (childId == null || childLastCheckpoint.containsKey(childId)) continue;
          
          final checkpointId = entry['checkpointId'] ?? entry['checkpoint_id'] ?? entry['checkpoint'];
          final checkpointName = entry['checkpointName'] ?? entry['checkpoint_name'] ?? 'Checkpoint';
          
          if (checkpointId != null) {
            // Buscar coordenadas do checkpoint
            final checkpoint = checkpoints.firstWhere(
              (cp) => cp['id'].toString() == checkpointId.toString(),
              orElse: () => <String, dynamic>{},
            );
            
            childLastCheckpoint[childId] = {
              'checkpointId': checkpointId,
              'checkpointName': checkpointName,
              'mapX': checkpoint['map_x'] ?? checkpoint['mapX'],
              'mapY': checkpoint['map_y'] ?? checkpoint['mapY'],
            };
          }
        }
        
        log.i('[TRACKING] ✅ Último checkpoint encontrado para ${childLastCheckpoint.length} crianças');
        
        // Step 2: Calcular posição de cada criança
        final checkpointSlots = <String, int>{}; // Conta quantas crianças já estão em cada checkpoint
        
        for (final child in children) {
          final lastInfo = childLastCheckpoint[child.id];
          
          if (lastInfo != null && lastInfo['mapX'] != null && lastInfo['mapY'] != null) {
            // Avatar vai para o checkpoint
            final baseX = (lastInfo['mapX'] as num).toDouble();
            final baseY = (lastInfo['mapY'] as num).toDouble();
            final slot = checkpointSlots[lastInfo['checkpointId']] ?? 0;
            checkpointSlots[lastInfo['checkpointId']] = slot + 1;
            
            // Distribuir avatares em volta do checkpoint (não sobrepor)
            final offsets = [-35.0, 0.0, 35.0];
            final offsetX = offsets[slot % offsets.length];
            final row = (slot / 3).floor();
            
            positions[child.id] = {
              'x': baseX + offsetX,
              'y': baseY + 68 + (row * 50),
              'checkpointId': lastInfo['checkpointId'],
              'checkpointName': lastInfo['checkpointName'],
            };
            
            log.i('[TRACKING] 📍 ${child.nickname}: checkpoint=${lastInfo['checkpointName']} @ (${baseX + offsetX}, ${baseY + 68 + (row * 50)})');
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
