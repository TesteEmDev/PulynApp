import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_models.dart';
import '../config/theme.dart';
import '../providers/index.dart';
import '../utils/logger.dart';

/// Zone configuration para o mapa do buffet
class ZoneConfig {
  final String name;
  final Color color;
  final double x; // percentual
  final double y;
  final double w;
  final double h;

  ZoneConfig({
    required this.name,
    required this.color,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

/// 🎯 Modelo para posição animada de avatar
class AvatarPosition {
  final String childId;
  final String childName;
  final String teamColor;
  double x; // pixel absoluto
  double y; // pixel absoluto
  
  AvatarPosition({
    required this.childId,
    required this.childName,
    required this.teamColor,
    required this.x,
    required this.y,
  });
  
  AvatarPosition copyWith({
    double? x,
    double? y,
  }) {
    return AvatarPosition(
      childId: childId,
      childName: childName,
      teamColor: teamColor,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

/// 🗺️ Widget de Mapa do Evento com Zonas, Checkpoints e Filhos - VERSÃO MELHORADA
class EventMapWidget extends ConsumerStatefulWidget {
  final List<Child>? childrenList; // Lista de filhos vinculados no app (todos são "meus filhos")
  final String? eventoId; // ID do evento para carregar floor plan
  final Map<String, dynamic>? activeGame; // Jogo ativo para exibição

  const EventMapWidget({
    required this.childrenList,
    this.eventoId,
    this.activeGame,
    super.key,
  });

  @override
  ConsumerState<EventMapWidget> createState() => _EventMapWidgetState();
}

class _EventMapWidgetState extends ConsumerState<EventMapWidget> 
    with TickerProviderStateMixin {
  String? _floorPlanUrl;
  
  // 🎮 Controllers para animações
  late AnimationController _pulseController;
  late AnimationController _zoomController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _zoomAnimation;
  
  // 🗺️ Posições dos avatares com animação
  late AnimationController _avatarMoveController;
  final Map<String, AvatarPosition> _avatarPositions = {};
  final Map<String, Offset> _avatarTargets = {};
  
  // 🗺️ Transform controller para zoom/pan
  final TransformationController _transformController = TransformationController();
  
  // 📱 Estados do UI (removido filtros para interface mais limpa)
  
  // 📏 Dimensões
  static const double mapWidth = 350;
  static const double mapHeight = 280;

  @override
  void initState() {
    super.initState();
    // NÃO chamar _loadFloorPlan() aqui - ref não está disponível
    
    // 🎮 Setup animações
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _avatarMoveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _zoomAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));
    
    // ✨ Inicia animação de pulso
    _pulseController.repeat(reverse: true);
    
    // ✅ Setup WebSocket triggers para refresh imediato (igual home_screen.dart)
    Future.microtask(() {
      ref.read(webSocketServiceProvider).on('SCORE_UPDATE', (data) {
        ref.read(mapRefreshProvider.notifier).refresh();
      });
      
      ref.read(webSocketServiceProvider).on('TERRITORY_CONQUERED', (data) {
        log.i('📍 [EVENT_MAP_WIDGET] TERRITORY_CONQUERED RECEBIDO! Data: $data');
        _handleTerritoryConquered(data);
        ref.read(mapRefreshProvider.notifier).refresh();
      });
      
      ref.read(webSocketServiceProvider).on('RANKING_UPDATE', (data) {
        ref.read(mapRefreshProvider.notifier).refresh();
      });
    });


  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _zoomController.dispose();
    _avatarMoveController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorPlanFromRef() async {
    if (widget.eventoId == null) {
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final floorPlanUrl = await apiService.getFloorPlan(widget.eventoId!);
      
      if (mounted && floorPlanUrl != null && floorPlanUrl.isNotEmpty) {
        setState(() {
          _floorPlanUrl = floorPlanUrl;
        });
      }
    } catch (e) {
      log.w('[MAP] ⚠️ Erro ao carregar floor plan: $e');
    }
  }

  /// 🎯 Gerencia o movimento do avatar quando um território é conquistado
  /// Suporta todos os tipos de jogos: zone_conquest, treasure_hunt, monster_hunt
  void _handleTerritoryConquered(Map<String, dynamic> data) {
    try {
      // 🔍 Debug completo do evento
      log.i('🎯 [MAP] ========== TERRITORY_CONQUERED RECEBIDO ==========');
      log.i('🎯 [MAP] Dados completos: $data');
      
      // Extrai dados do evento - suporta tanto o formato antigo quanto o novo
      final criancaId = data['criancaId'] as String? ?? data['payload']?['criancaId'] as String?;
      final criancaName = data['criancaName'] as String? ?? data['payload']?['criancaName'] as String?;
      final checkpointId = data['checkpointId'] as String? ?? data['payload']?['checkpointId'] as String?;
      final teamColor = (data['teamColor'] as String? ?? data['payload']?['teamColor'] as String?) ?? '#FF0000';
      final gameType = (data['gameType'] as String? ?? data['payload']?['gameType'] as String?) ?? 'zone_conquest';
      final mapX = data['mapX'] ?? data['payload']?['mapX'];
      final mapY = data['mapY'] ?? data['payload']?['mapY'];
      
      log.i('🔍 [MAP] Dados extraídos:');
      log.i('🔍 [MAP]   - criancaId: $criancaId');
      log.i('🔍 [MAP]   - checkpointId: $checkpointId');
      log.i('🔍 [MAP]   - criancaName: $criancaName');
      log.i('🔍 [MAP]   - teamColor: $teamColor');
      log.i('🔍 [MAP]   - gameType: $gameType');
      log.i('🔍 [MAP]   - mapX: $mapX, mapY: $mapY');
      
      if (criancaId == null || checkpointId == null) {
        log.w('❌ [MAP] Dados inválidos! criancaId=$criancaId, checkpointId=$checkpointId');
        log.w('❌ [MAP] Payload structure: ${data.keys.toList()}');
        return;
      }
      
      log.i('✅ [MAP] Validação passou! Chamando animação para $gameType...');
      
      // 🎬 Anima o avatar em movimento
      _animateAvatarToCheckpoint(
        childId: criancaId,
        childName: criancaName ?? 'Criança',
        checkpointId: checkpointId,
        teamColor: teamColor,
        directMapX: (mapX as num?)?.toDouble(),
        directMapY: (mapY as num?)?.toDouble(),
      );
      
      log.i('✅ [MAP] Função de animação chamada para $criancaName no $gameType!');
    } catch (e, st) {
      log.e('🎯 [MAP] ❌ ERRO ao processar TERRITORY_CONQUERED: $e');
      log.e('🎯 [MAP] Stack: $st');
    }
  }
  
  /// 🎬 Anima um avatar movendo de sua posição atual para um checkpoint
  /// Suporta ambos: buscar coordenadas do banco OU usar coordenadas diretas do evento
  Future<void> _animateAvatarToCheckpoint({
    required String childId,
    required String childName,
    required String checkpointId,
    required String teamColor,
    double? directMapX,
    double? directMapY,
  }) async {
    try {
      log.i('🎬 [MAP] ========== INICIANDO ANIMAÇÃO ==========');
      log.i('🎬 [MAP] Criança: $childName ($childId)');
      log.i('🎬 [MAP] Checkpoint alvo: $checkpointId');
      log.i('🎬 [MAP] Coordenadas diretas: directMapX=$directMapX, directMapY=$directMapY');
      
      // Se ainda não existe posição para este filho, cria uma posição inicial genérica
      if (!_avatarPositions.containsKey(childId)) {
        _avatarPositions[childId] = AvatarPosition(
          childId: childId,
          childName: childName,
          teamColor: teamColor,
          x: mapWidth / 2,
          y: mapHeight / 2,
        );
        log.i('🎯 [MAP] Criada posição inicial em center: (${mapWidth / 2}, ${mapHeight / 2})');
      }
      
      // 📍 Calcula a posição alvo do checkpoint
      late Offset checkpointPos;
      
      // ✨ NOVO: Se as coordenadas foram enviadas diretamente no evento, usa elas primeiro
      if (directMapX != null && directMapY != null && directMapX >= 0 && directMapY >= 0) {
        checkpointPos = Offset(directMapX, directMapY);
        log.i('✅ [MAP] Coordenadas diretas do evento: ($directMapX, $directMapY) pixels');
      } else {
        // Fallback: Buscar do checkpoint no cache/API
        Map<String, dynamic>? checkpoint;
        String foundEventId = '';
        
        try {
          // Tenta ler o evento ativo SINCRONAMENTE (se já foi carregado)
          final activeEventAsync = ref.read(activeEventProvider);
          
          log.i('📊 [MAP] Tipo de activeEventAsync: ${activeEventAsync.runtimeType}');
          
          if (activeEventAsync is AsyncData && activeEventAsync.value != null) {
            final event = activeEventAsync.value!;
            foundEventId = event['id'] as String;
            log.i('✅ [MAP] Evento encontrado: $foundEventId');
            
            // Tenta ler checkpoints SINCRONAMENTE (se já foram carregados)
            final checkpointsAsync = ref.read(checkpointsByEventProvider(foundEventId));
            
            log.i('📊 [MAP] Tipo de checkpointsAsync: ${checkpointsAsync.runtimeType}');
            
            if (checkpointsAsync is AsyncData) {
              final checkpoints = checkpointsAsync.value ?? [];
              log.i('📊 [MAP] Checkpoints em cache: ${checkpoints.length}');
              
              if (checkpoints.isNotEmpty) {
                checkpoint = checkpoints.firstWhere(
                  (cp) => cp['id'].toString().toLowerCase() == checkpointId.toLowerCase(),
                  orElse: () {
                    log.w('❌ [MAP] Checkpoint $checkpointId não encontrado em ${checkpoints.length} disponíveis');
                    // Debug: lista todos os IDs disponíveis
                    log.i('📋 [MAP] IDs disponíveis: ${checkpoints.map((c) => '${c['id']} (${c['name']})').join(", ")}');
                    return {};
                  },
                );
                
                if (checkpoint.isNotEmpty) {
                  log.i('✅ [MAP] Checkpoint encontrado: ${checkpoint['name']}');
                }
              } else {
                log.w('⚠️ [MAP] Nenhum checkpoint no cache!');
                // 🔄 FALLBACK: Busca checkpoints diretamente da API se não estão em cache
                log.i('🔄 [MAP] Tentando buscar checkpoints da API...');
                final apiService = ref.read(apiServiceProvider);
                await apiService.init();
                final checkpointsFromApi = await apiService.getCheckpointsByEvent(foundEventId);
                log.i('📍 [MAP] Checkpoints da API: ${checkpointsFromApi.length}');
                
                if (checkpointsFromApi.isNotEmpty) {
                  checkpoint = checkpointsFromApi.firstWhere(
                    (cp) => cp['id'].toString().toLowerCase() == checkpointId.toLowerCase(),
                    orElse: () => {},
                  );
                  if (checkpoint.isNotEmpty) {
                    log.i('✅ [MAP] Checkpoint encontrado via API!');
                  }
                }
              }
            } else {
              log.w('⚠️ [MAP] checkpointsAsync não é AsyncData, é: ${checkpointsAsync.runtimeType}');
              // 🔄 FALLBACK: Busca checkpoints diretamente da API
              log.i('🔄 [MAP] Tentando buscar checkpoints da API (AsyncData failed)...');
              final apiService = ref.read(apiServiceProvider);
              await apiService.init();
              final checkpointsFromApi = await apiService.getCheckpointsByEvent(foundEventId);
              log.i('📍 [MAP] Checkpoints da API: ${checkpointsFromApi.length}');
              
              if (checkpointsFromApi.isNotEmpty) {
                checkpoint = checkpointsFromApi.firstWhere(
                  (cp) => cp['id'].toString().toLowerCase() == checkpointId.toLowerCase(),
                  orElse: () => {},
                );
                if (checkpoint.isNotEmpty) {
                  log.i('✅ [MAP] Checkpoint encontrado via API!');
                }
              }
            }
          } else {
            log.w('⚠️ [MAP] activeEventAsync não é AsyncData ou value é null');
            log.i('   Tipo: ${activeEventAsync.runtimeType}');
          }
        } catch (e) {
          log.w('⚠️ [MAP] Erro ao buscar checkpoint: $e');
        }
        
        if (checkpoint != null && checkpoint.isNotEmpty) {
          // ✅ Usa coordenadas reais do checkpoint (em pixels, não percentual!)
          final storedX = checkpoint['map_x'] ?? checkpoint['mapX'];
          final storedY = checkpoint['map_y'] ?? checkpoint['mapY'];
          
          log.i('🔍 [MAP] Procurando coords: map_x=$storedX, map_y=$storedY');
          
          if (storedX != null && storedY != null) {
            try {
              final x = double.tryParse(storedX.toString());
              final y = double.tryParse(storedY.toString());
              
              if (x != null && y != null && x.isFinite && y.isFinite) {
                // ✅ As coords são EM PIXELS dentro do mapa (0-350 x 0-280)
                checkpointPos = Offset(x, y);
                log.i('✅ [MAP] Coords válidas: ($x, $y) pixels');
              } else {
                checkpointPos = Offset(mapWidth / 2, mapHeight / 2);
                log.w('⚠️ [MAP] Parse falhou: x=$x, y=$y, usando center');
              }
            } catch (e) {
              checkpointPos = Offset(mapWidth / 2, mapHeight / 2);
              log.w('⚠️ [MAP] Erro ao parsear: $e');
            }
          } else {
            checkpointPos = Offset(mapWidth / 2, mapHeight / 2);
            log.w('⚠️ [MAP] Coords NULL, usando center');
          }
        } else {
          // Fallback - se checkpoint não encontrado
          checkpointPos = Offset(mapWidth / 2, mapHeight / 2);
          log.w('⚠️ [MAP] Checkpoint vazio, usando center');
        }
      }
      
      _avatarTargets[childId] = checkpointPos;
      
      final currentPos = _avatarPositions[childId]!;
      log.i('🎬 [MAP] Animação: (${currentPos.x}, ${currentPos.y}) → (${checkpointPos.dx}, ${checkpointPos.dy})');
      
      // 🎬 Anima a transição (800ms suave) COM ATUALIZAÇÃO DE POSIÇÃO DURANTE A ANIMAÇÃO
      if (mounted) {
        log.i('🎬 [MAP] Widget mounted, iniciando animação...');
        
        // Posição inicial e final
        final startX = currentPos.x;
        final startY = currentPos.y;
        final endX = checkpointPos.dx;
        final endY = checkpointPos.dy;
        
        // 🎬 Listener que atualiza a posição A CADA FRAME da animação
        void onAnimationUpdate() {
          if (mounted) {
            final progress = _avatarMoveController.value; // 0.0 a 1.0
            
            final newX = startX + (endX - startX) * progress;
            final newY = startY + (endY - startY) * progress;
            
            setState(() {
              final current = _avatarPositions[childId];
              if (current != null) {
                _avatarPositions[childId] = current.copyWith(
                  x: newX,
                  y: newY,
                );
              }
            });
          }
        }
        
        // Registra listener e inicia animação
        _avatarMoveController.addListener(onAnimationUpdate);
        
        try {
          await _avatarMoveController.forward(from: 0.0);
        } finally {
          // Remove listener após animação terminar
          _avatarMoveController.removeListener(onAnimationUpdate);
          
          // Garante que posição final está correta
          if (mounted) {
            setState(() {
              final current = _avatarPositions[childId];
              if (current != null) {
                _avatarPositions[childId] = current.copyWith(
                  x: endX,
                  y: endY,
                );
                log.i('✅ [MAP] Posição final atualizada!');
              }
            });
          }
        }
      } else {
        log.w('⚠️ [MAP] Widget NÃO mounted, animação cancelada');
      }
      
      log.i('✨ [MAP] ========== ANIMAÇÃO CONCLUÍDA ==========');
    } catch (e, st) {
      log.w('❌ [MAP] ❌ ERRO NA ANIMAÇÃO: $e');
      log.w('❌ [MAP] Stack:\n$st');
    }
  }

  /// 🎯 Mostra detalhes de checkpoint em bottom sheet
  void _showCheckpointDetails(Map<String, dynamic> checkpoint) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PulynColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Checkpoint info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCheckpointColor(checkpoint),
                    boxShadow: [
                      BoxShadow(
                        color: _getCheckpointColor(checkpoint).withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkpoint['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkpoint['zone'] ?? checkpoint['location'] ?? 'Zona não definida',
                        style: const TextStyle(
                          fontSize: 14,
                          color: PulynColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Status e pontos
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PulynColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          checkpoint['status'] == 'online' 
                            ? Icons.wifi 
                            : Icons.wifi_off,
                          color: checkpoint['status'] == 'online'
                            ? PulynColors.success
                            : PulynColors.danger,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          checkpoint['status'] == 'online' ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: checkpoint['status'] == 'online'
                              ? PulynColors.success
                              : PulynColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PulynColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.star,
                          color: PulynColors.accent,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '+${checkpoint['points']} pts',
                          style: const TextStyle(
                            color: PulynColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  /// 👶 Mostra detalhes de criança em bottom sheet
  void _showChildDetails(Child child) {
    HapticFeedback.lightImpact();
    
    final teamColor = Color(int.parse('0xFF${child.teamColor.replaceFirst('#', '')}'));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PulynColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Child info
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [teamColor, teamColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      child.nickname.isNotEmpty 
                        ? child.nickname[0].toUpperCase()
                        : child.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.nickname.isNotEmpty ? child.nickname : child.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${child.age} anos • ${child.teamName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: PulynColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Score e conquistas
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PulynColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: PulynColors.accent,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${child.currentScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Pontos',
                          style: TextStyle(
                            color: PulynColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PulynColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.flag,
                          color: PulynColors.success,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${child.achievements.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Conquistas',
                          style: TextStyle(
                            color: PulynColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  /// 🎨 Obtém cor do checkpoint baseado no status
  Color _getCheckpointColor(Map<String, dynamic> checkpoint) {
    // Verifica se algum dos meus filhos conquistou este checkpoint
    final childrenToCheck = widget.childrenList ?? [];
    final isConquered = childrenToCheck.any((child) => 
      child.achievements.any((achievement) => achievement.title == checkpoint['name'])
    );
    
    final isOnline = checkpoint['status'] == 'online';
    
    if (isConquered) return PulynColors.success;
    if (isOnline) return PulynColors.primary;
    return PulynColors.danger;
  }

  // Zonas do buffet - AGORA BUSCADAS DO BACKEND!
  // Removidas as zonas hardcoded - agora vêm do backend via provider
  static final List<ZoneConfig> zones = []; // Vazio - será preenchido pelo provider

  /// Retorna zonas padrão como fallback
  List<ZoneConfig> _getDefaultZones() {
    return [
      ZoneConfig(
        name: 'Entrada',
        color: const Color(0xFF1E9BD7),
        x: 30,
        y: 5,
        w: 40,
        h: 18,
      ),
      ZoneConfig(
        name: 'Área Verde',
        color: const Color(0xFF10B981),
        x: 5,
        y: 28,
        w: 42,
        h: 38,
      ),
      ZoneConfig(
        name: 'Área Azul',
        color: const Color(0xFF1E9BD7),
        x: 53,
        y: 28,
        w: 42,
        h: 38,
      ),
      ZoneConfig(
        name: 'Área Central',
        color: const Color(0xFFF59E0B),
        x: 20,
        y: 70,
        w: 60,
        h: 25,
      ),
    ];
  }

  /// Converte string de cor para Color
  Color _getZoneColor(dynamic colorInput) {
    if (colorInput == null) return const Color(0xFF1E9BD7); // Padrão azul
    
    try {
      if (colorInput is String) {
        // Tenta converter hex string: "0xFF1E9BD7" ou "#1E9BD7"
        String hex = colorInput.replaceFirst('#', '0xFF');
        return Color(int.parse(hex));
      }
    } catch (e) {
      log.w('⚠️ Erro ao converter cor: $colorInput');
    }
    
    return const Color(0xFF1E9BD7); // Fallback
  }

  /// Busca checkpoints usando provider com cache
  Widget _buildCheckpointsFromProvider() {
    // ✅ Primeiro busca o evento ativo
    final activeEventAsync = ref.watch(activeEventProvider);
    
    return activeEventAsync.when(
      loading: () => Container(
        height: 380,
        decoration: BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PulynColors.darkBorder),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Container(
        height: 380,
        decoration: BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PulynColors.danger),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: PulynColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Erro ao carregar mapa',
                style: TextStyle(color: PulynColors.danger, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      data: (activeEvent) {
        if (activeEvent == null) {
          return _buildMapWithCheckpoints(_getFallbackCheckpoints(), []);  // ✅ Adicionado segundo arg
        }
        
        final eventoId = activeEvent['id'] as String;
        
        // ✅ Busca checkpoints usando provider com cache
        final checkpointsAsync = ref.watch(checkpointsByEventProvider(eventoId));
        
        // ✅ NOVO: Busca zonas do backend
        final zonesAsync = ref.watch(zonesByEventProvider(eventoId));
        
        return checkpointsAsync.when(
          loading: () => Container(
            height: 380,
            decoration: BoxDecoration(
              color: PulynColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PulynColors.darkBorder),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) {
            return _buildMapWithCheckpoints(_getFallbackCheckpoints(), []);
          },
          data: (checkpoints) {
            if (checkpoints.isEmpty) {
              return _buildMapWithCheckpoints(_getFallbackCheckpoints(), []);
            }
            
            // ✅ Retorna também as zonas
            return zonesAsync.when(
              loading: () => _buildMapWithCheckpoints(checkpoints, []),
              error: (error, _) => _buildMapWithCheckpoints(checkpoints, []),
              data: (zones) => _buildMapWithCheckpoints(checkpoints, zones),
            );
          },
        );
      },
    );
  }

  /// Dados fictícios como fallback (só enquanto não há dados reais)
  List<Map<String, dynamic>> _getFallbackCheckpoints() {
    return [
      {
        'id': '1',
        'name': 'Torre Encantada',
        'zone': 'Entrada',
        'points': 10,
        'status': 'online',
      },
      {
        'id': '2',
        'name': 'Caverna Misteriosa',
        'zone': 'Área Verde',
        'points': 15,
        'status': 'online',
      },
      {
        'id': '3',
        'name': 'Jardim Secreto',
        'zone': 'Área Azul',
        'points': 10,
        'status': 'online',
      },
      {
        'id': '4',
        'name': 'Castelo da Diversão',
        'zone': 'Área Central',
        'points': 20,
        'status': 'online',
      },
      {
        'id': '5',
        'name': 'Floresta Mágica',
        'zone': 'Área Central',
        'points': 12,
        'status': 'offline',
      },
    ];
  }

  /// Normaliza nome da zona para comparação
  String _normalizeZoneName(String? name) {
    return (name ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  /// Obtém posição do checkpoint no mapa
  /// Primeiro tenta usar map_x e map_y da tabela, senão calcula pela zona
  Map<String, double> _getCheckpointPosition(
      Map<String, dynamic> checkpoint,
      List<Map<String, dynamic>> allCheckpoints) {
    // ✅ Primeiro: tentar puxar posição salva na tabela (map_x, map_y)
    final storedX = checkpoint['map_x'] ?? checkpoint['mapX'];
    final storedY = checkpoint['map_y'] ?? checkpoint['mapY'];
    
    if (storedX != null && storedY != null) {
      try {
        final x = double.tryParse(storedX.toString());
        final y = double.tryParse(storedY.toString());
        
        if (x != null && y != null && x.isFinite && y.isFinite) {
          return {'x': x, 'y': y};
        }
      } catch (e) {
        // sem log
      }
    }
    
    // ✅ Fallback: calcular pela zona
    final zoneName = checkpoint['zone'] ?? checkpoint['location'] ?? 'Entrada';
    final zone = zones.firstWhere(
      (z) => _normalizeZoneName(z.name) == _normalizeZoneName(zoneName),
      orElse: () => zones[0],
    );

    final sameZone = allCheckpoints
        .where((c) =>
            _normalizeZoneName(c['zone'] ?? c['location'] ?? 'Entrada') == _normalizeZoneName(zoneName))
        .toList();
    final index = sameZone.indexOf(checkpoint);
    final count = sameZone.length;

    final xOffset = count > 1 ? (index / (count - 1)) * 0.6 + 0.2 : 0.5;

    return {
      'x': zone.x + zone.w * xOffset,
      'y': zone.y + zone.h * 0.75,
    };
  }

  @override
  Widget build(BuildContext context) {
    // ✅ NOVO: Escutar mudanças no provider de posições (rastreio)
    // NOTA: ref.listen() DEVE estar aqui no build(), não em initState()!
    ref.listen<Map<String, Map<String, dynamic>>>(
      avatarTrackingPositionsProvider,
      (previous, next) {
        if (previous == null) return; // Skip na primeira vez
        
        log.i('[TRACKING_LISTENER] 🔄 Posições atualizadas! ${next.length} crianças');
        
        // Para cada criança com nova posição
        next.forEach((childId, posData) {
          final newX = (posData['x'] as num?)?.toDouble() ?? 175.0;
          final newY = (posData['y'] as num?)?.toDouble() ?? 140.0;
          
          log.i('[TRACKING_LISTENER] 📍 $childId → ($newX, $newY)');
          
          // Animar avatar para nova posição
          _animateAvatarToPosition(childId, newX, newY);
        });
      },
    );
    
    // ✅ Carregar floor plan na primeira vez que o widget for construído
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_floorPlanUrl == null && widget.eventoId != null) {
        _loadFloorPlanFromRef();
      }
    });
    
    // ✅ Usar provider com cache para evitar loading infinito
    return _buildCheckpointsFromProvider();
  }

  /// Calcula posições dos filhos pelas zonas do mapa com dados em tempo real
  List<Map<String, dynamic>> _calculateChildPositions(
    List<Child> childrenToDisplay,
    List<Map<String, dynamic>> checkpoints,
    Map<String, Map<String, dynamic>> childLastCheckpoint,
  ) {
    if (childrenToDisplay.isEmpty) {
      return [];
    }
    
    final positions = <Map<String, dynamic>>[];

    for (final child in childrenToDisplay) {
      // ✅ Busca o último checkpoint conquistado dessa criança
      final lastCheckpointData = childLastCheckpoint[child.id];
      
      if (lastCheckpointData != null) {
        // ✅ Criança tem um checkpoint - posiciona lá
        final checkpointId = lastCheckpointData['checkpointId'];
        
        final checkpoint = checkpoints.firstWhere(
          (cp) => cp['id'].toString().toLowerCase() == checkpointId.toString().toLowerCase(),
          orElse: () => {},
        );
        
        if (checkpoint.isNotEmpty && checkpoint['id'] != null) {
          final cpPos = _getCheckpointPosition(checkpoint, checkpoints);
          
          positions.add({
            'child': child,
            'x': cpPos['x'] ?? 50,
            'y': cpPos['y'] ?? 50,
            'zone': checkpoint['zone'] ?? checkpoint['location'] ?? 'Checkpoint',
            'hasCheckpoint': true,
          });
          
          continue;
        }
      }
      
      // ✅ Criança sem checkpoint ainda - distribui nas zonas
      if (zones.isEmpty) {
        // Se não tem zonas, coloca no centro
        positions.add({
          'child': child,
          'x': mapWidth / 2,
          'y': mapHeight / 2,
          'zone': 'Centro',
          'hasCheckpoint': false,
        });
      } else {
        // ✅ Proteção extra contra divisão por zero
        if (zones.isEmpty || childrenToDisplay.isEmpty) {
          positions.add({
            'child': child,
            'x': mapWidth / 2,
            'y': mapHeight / 2,
            'zone': 'Centro (fallback)',
            'hasCheckpoint': false,
          });
          continue;
        }
        
        final zoneIdx = childrenToDisplay.indexOf(child) % zones.length;
        final zone = zones[zoneIdx];
        const cols = 2;
        final col = (childrenToDisplay.indexOf(child) % cols);

        final x = zone.x + zone.w * (col == 0 ? 0.3 : 0.7);
        final y = zone.y + zone.h * (0.3 + (childrenToDisplay.indexOf(child) ~/ cols) * 0.25);

        positions.add({
          'child': child,
          'x': x,
          'y': y,
          'zone': zone.name,
          'hasCheckpoint': false,
        });
      }
    }

    return positions;
  }

  Widget _buildMapWithCheckpoints(
    List<Map<String, dynamic>> checkpoints,
    List<Map<String, dynamic>> zonesFromBackend,
  ) {
    // ✅ Converte zonas do backend para ZoneConfig
    // Backend envia: {id, name, color, x, y, width, height}
    List<ZoneConfig> convertedZones = zonesFromBackend.isEmpty
        ? _getDefaultZones() // Fallback se vazio
        : zonesFromBackend.map((zone) {
            final x = double.tryParse(zone['x']?.toString() ?? '0') ?? 0;
            final y = double.tryParse(zone['y']?.toString() ?? '0') ?? 0;
            final w = double.tryParse((zone['width'] ?? zone['w'])?.toString() ?? '20') ?? 20;
            final h = double.tryParse((zone['height'] ?? zone['h'])?.toString() ?? '20') ?? 20;
            
            log.i('🎨 [MAP] Convertendo zona: ${zone['name']} (x:$x, y:$y, w:$w, h:$h)');
            
            return ZoneConfig(
              name: zone['name'] ?? 'Zona Desconhecida',
              color: _getZoneColor(zone['color']),
              x: x,
              y: y,
              w: w,
              h: h,
            );
          }).toList();

    log.i('🎨 [MAP] ✅ Zonas carregadas: ${convertedZones.length} áreas do backend');
    
    // ✅ Watch TODOS os providers em tempo real
    final childrenRealtime = ref.watch(mapChildrenRealtimeProvider);
    final childLastCheckpoint = ref.watch(childLastCheckpointProvider);
    
    // ✅ Extrai dados children de forma segura
    final childrenToDisplay = childrenRealtime.whenData((children) => children).value ?? widget.childrenList ?? [];
    
    // ✅ Calcula posições com dados EM TEMPO REAL
    final childPositions = _calculateChildPositions(
      childrenToDisplay,
      checkpoints,
      childLastCheckpoint,
    );

    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 380, // Altura reduzida após remoção dos filtros
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PulynColors.darkBorder),
            ),
            child: Column(
              children: [
                // Header com filtros
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: PulynColors.darkBorder),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mapa Interativo',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.activeGame != null 
                                    ? '${widget.activeGame!['name'] ?? 'Jogo'} em andamento ⚡'
                                    : 'Toque para interagir • Pinçar para zoom',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: PulynColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botão centralizar
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              // Reset zoom
                              _transformController.value = Matrix4.identity();
                            },
                            icon: const Icon(Icons.center_focus_strong),
                            tooltip: 'Centralizar',
                            iconSize: 20,
                            color: PulynColors.textMuted,
                          ),
                          if (widget.activeGame != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    PulynColors.success,
                                    PulynColors.success.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: PulynColors.success.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.play_circle_filled,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.activeGame!['gameName'] ?? 'Nenhum jogo ativo',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mapa interativo
                Expanded(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 3.0,
                    constrained: false,
                    child: Container(
                      width: mapWidth,
                      height: mapHeight,
                      decoration: BoxDecoration(
                        color: PulynColors.darkCard.withValues(alpha: 0.3),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1a2a3a).withValues(alpha: 0.5),
                            const Color(0xFF2a3a4a).withValues(alpha: 0.5),
                          ],
                        ),
                        image: _floorPlanUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_floorPlanUrl!),
                                fit: BoxFit.cover,
                                opacity: 0.4,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Background decorativo (padrão de piso)
                          if (_floorPlanUrl == null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FloorPatternPainter(),
                              ),
                            ),

                          // Zonas background com animação
                          ...convertedZones.map((zone) {
                            log.i('🎨 [ZONES] Renderizando zona: ${zone.name} @ (${zone.x}, ${zone.y})');
                            return AnimatedBuilder(
                              animation: _zoomAnimation,
                              builder: (context, child) => Positioned(
                                left: zone.x,
                                top: zone.y,
                                child: Container(
                                  width: zone.w,
                                  height: zone.h,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: zone.color.withValues(alpha: 0.8),  // ✅ Aumentei alpha para 0.8
                                      width: 2,
                                    ),
                                    color: zone.color.withValues(alpha: 0.2),  // ✅ Aumentei alpha para 0.2
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      zone.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: zone.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Checkpoints com animação e interatividade
                          ...checkpoints.map((checkpoint) {
                            final pos = _getCheckpointPosition(checkpoint, checkpoints);
                            final color = _getCheckpointColor(checkpoint);
                            
                            // Verifica se algum dos meus filhos conquistou este checkpoint
                            final childrenToCheck = widget.childrenList ?? [];
                            final isConquered = childrenToCheck.any((child) => 
                              child.achievements.any((achievement) => achievement.title == checkpoint['name'])
                            );

                            return Positioned(
                              left: pos['x']! - 20,  // ✅ CORRIGIDO: pos['x'] já é pixel, não percentual!
                              top: pos['y']! - 20,   // ✅ CORRIGIDO: pos['y'] já é pixel, não percentual!
                              child: GestureDetector(
                                onTap: () => _showCheckpointDetails(checkpoint),
                                child: AnimatedBuilder(
                                  animation: isConquered ? _pulseAnimation : _zoomAnimation,
                                  builder: (context, child) => Transform.scale(
                                    scale: isConquered ? _pulseAnimation.value : 1.0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Marker melhorado
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: color, width: 3),
                                            color: PulynColors.darkCard.withValues(alpha: 0.95),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.4),
                                                blurRadius: 12,
                                                spreadRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              isConquered 
                                                ? Icons.check_circle
                                                : checkpoint['status'] == 'online'
                                                  ? Icons.radio_button_unchecked
                                                  : Icons.cancel,
                                              color: color,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Label melhorado
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: PulynColors.darkCard.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: color.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                checkpoint['name'],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '+${checkpoint['points']}pts',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // 👶 Filhos no mapa com interatividade
                          ...childPositions.map((childPos) {
                            final childData = childPos['child'] as Child;
                            
                            // ✅ CORREÇÃO: Usa posição animada se existir
                            late double leftPixel;
                            late double topPixel;

                            if (_avatarPositions.containsKey(childData.id)) {
                              // Avatar foi movido - usa posição em pixels diretamente
                              final avatarPos = _avatarPositions[childData.id]!;
                              leftPixel = avatarPos.x - 20; // Avatar tem 40px de largura, centraliza
                              topPixel = avatarPos.y - 20;   // Avatar tem 40px de altura, centraliza
                            } else {
                              // Avatar não foi movido - converte percentual para pixel
                              final xPercent = childPos['x'] as double;
                              final yPercent = childPos['y'] as double;
                              leftPixel = (xPercent / 100) * mapWidth - 20;
                              topPixel = (yPercent / 100) * mapHeight - 20;
                            }
                            
                            try {
                              final teamColor = Color(int.parse('0xFF${childData.teamColor.replaceFirst('#', '')}'));
                              
                              return Positioned(
                                left: leftPixel,
                                top: topPixel,
                                child: GestureDetector(
                                  onTap: () => _showChildDetails(childData),
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation, // Todas as crianças têm animação no app da família
                                    builder: (context, child) => Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Avatar do filho melhorado
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  teamColor,
                                                  teamColor.withValues(alpha: 0.7),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: Colors.yellow, // Todas as crianças são "meus filhos"
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: teamColor.withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: childData.profileImage != null && childData.profileImage!.isNotEmpty
                                                ? ClipOval(
                                                    child: Image.network(
                                                      childData.profileImage!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Center(
                                                          child: Text(
                                                            childData.nickname.isNotEmpty
                                                                ? childData.nickname[0].toUpperCase()
                                                                : childData.name[0].toUpperCase(),
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(
                                                      childData.nickname.isNotEmpty
                                                          ? childData.nickname[0].toUpperCase()
                                                          : childData.name[0].toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Nome melhorado
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: PulynColors.darkCard.withValues(alpha: 0.9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.yellow.withValues(alpha: 0.5), // Todas são "meus filhos"
                                              ),
                                            ),
                                            child: Text(
                                              childData.nickname.isNotEmpty
                                                  ? childData.nickname
                                                  : childData.name.split(' ').first,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.yellow, // Todas são "meus filhos"
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              return const SizedBox.shrink();
                            }
                          }),
                          // Mini mapa de navegação no canto
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                color: PulynColors.darkCard.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PulynColors.darkBorder),
                              ),
                              child: CustomPaint(
                                painter: _MiniMapPainter(
                                  zones: zones,
                                  checkpoints: checkpoints,
                                  childrenPositions: childPositions,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Legend melhorada
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: PulynColors.darkBorder),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: PulynColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Legenda:',
                            style: TextStyle(
                              fontSize: 12,
                              color: PulynColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildLegendItem('🟢 Online', PulynColors.primary),
                          _buildLegendItem('🔴 Offline', PulynColors.danger),
                          _buildLegendItem('✅ Conquistado', PulynColors.success),
                          _buildLegendItem('👶 Meus Filhos', Colors.yellow),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.replaceAll(RegExp(r'[🟢🔴✅⭐]'), '').trim(),
          style: const TextStyle(
            fontSize: 11,
            color: PulynColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 🎯 NOVO: Anima avatar de sua posição atual para uma nova posição
  /// Usado pelo avatarTrackingPositionsProvider para rastreio em tempo real
  /// Muito mais simples que _animateAvatarToCheckpoint - apenas move para coordenadas diretas
  Future<void> _animateAvatarToPosition(String childId, double newX, double newY) async {
    try {
      log.i('🎬 [ANIMATE_POS] Animando $childId para ($newX, $newY)');
      
      // Se não existe avatar para essa criança, criar um na posição atual
      if (!_avatarPositions.containsKey(childId)) {
        log.i('🎬 [ANIMATE_POS] Avatar $childId não existe, criando em posição inicial');
        _avatarPositions[childId] = AvatarPosition(
          childId: childId,
          childName: 'Criança',
          teamColor: '#FFFFFF',
          x: mapWidth / 2,
          y: mapHeight / 2,
        );
      }
      
      final currentAvatar = _avatarPositions[childId]!;
      final startX = currentAvatar.x;
      final startY = currentAvatar.y;
      
      log.i('🎬 [ANIMATE_POS] De ($startX, $startY) para ($newX, $newY)');
      
      // Reset e play da animação
      _avatarMoveController.reset();
      await _avatarMoveController.forward();
      
      // Animar suavemente com Tween
      final animationX = Tween<double>(begin: startX, end: newX).animate(
        CurvedAnimation(parent: _avatarMoveController, curve: Curves.easeInOutCubic),
      );
      
      final animationY = Tween<double>(begin: startY, end: newY).animate(
        CurvedAnimation(parent: _avatarMoveController, curve: Curves.easeInOutCubic),
      );
      
      // Listener para atualizar posição durante animação
      _avatarMoveController.addListener(() {
        if (mounted) {
          setState(() {
            currentAvatar.x = animationX.value;
            currentAvatar.y = animationY.value;
          });
        }
      });
      
      log.i('✅ [ANIMATE_POS] Animação concluída para $childId');
    } catch (e, st) {
      log.e('❌ [ANIMATE_POS] Erro ao animar: $e');
      log.e('❌ [ANIMATE_POS] Stack: $st');
    }
  }
}

/// 🎨 CustomPainter para desenhar padrão de piso do buffet
class _FloorPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3a4a5a).withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Desenhar grade de piso
    const spacing = 30.0;
    
    // Linhas verticais
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Linhas horizontais
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FloorPatternPainter oldDelegate) => false;
}

/// 🗺️ CustomPainter para mini mapa
class _MiniMapPainter extends CustomPainter {
  final List<ZoneConfig> zones;
  final List<Map<String, dynamic>> checkpoints;
  final List<Map<String, dynamic>> childrenPositions;

  _MiniMapPainter({
    required this.zones,
    required this.checkpoints,
    required this.childrenPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Desenhar zonas
    for (final zone in zones) {
      final paint = Paint()
        ..color = zone.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
        
      final rect = Rect.fromLTWH(
        (zone.x / 100) * size.width,
        (zone.y / 100) * size.height,
        (zone.w / 100) * size.width,
        (zone.h / 100) * size.height,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
    
    // Desenhar checkpoints
    for (final checkpoint in checkpoints) {
      final paint = Paint()
        ..color = checkpoint['status'] == 'online' 
          ? PulynColors.primary 
          : PulynColors.danger
        ..style = PaintingStyle.fill;
        
      // Posição simplificada para mini mapa
      final x = (checkpoint['zone'] == 'Entrada' ? 0.4 : 
                checkpoint['zone'] == 'Área Verde' ? 0.2 :
                checkpoint['zone'] == 'Área Azul' ? 0.8 : 0.5) * size.width;
      final y = size.height * 0.5;
      
      canvas.drawCircle(
        Offset(x, y),
        2,
        paint,
      );
    }
    
    // Desenhar crianças
    for (final child in childrenPositions) {
      final paint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;
        
      final x = (child['x'] as double) / 100 * size.width;
      final y = (child['y'] as double) / 100 * size.height;
      
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) => 
    zones != oldDelegate.zones || 
    checkpoints != oldDelegate.checkpoints ||
    childrenPositions != oldDelegate.childrenPositions;
}
