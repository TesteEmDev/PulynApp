import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_models.dart';
import '../config/theme.dart';
import '../providers/index.dart';
import '../utils/logger.dart';
import '../utils/text_sanitizer.dart';

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

  /// Avisa quando o dedo entra/sai do mapa. A tela que hospeda o mapa usa isso
  /// para travar a própria rolagem (vertical e troca de abas) enquanto o mapa é
  /// arrastado — senão essas rolagens roubam o gesto e o mapa parece travado.
  final ValueChanged<bool>? onInteractionChanged;

  const EventMapWidget({
    required this.childrenList,
    this.eventoId,
    this.activeGame,
    this.onInteractionChanged,
    super.key,
  });

  @override
  ConsumerState<EventMapWidget> createState() => _EventMapWidgetState();
}

class _EventMapWidgetState extends ConsumerState<EventMapWidget>
    with TickerProviderStateMixin {
  String? _floorPlanUrl;
  // ✅ Decodificado uma única vez quando a planta carrega (evita rodar
  // base64Decode em toda rebuild, já que a imagem pode ter vários MB).
  ImageProvider? _floorPlanImage;
  
  // 🎮 Controllers para animações
  late AnimationController _pulseController;
  late AnimationController _zoomController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _zoomAnimation;
  
  // 🗺️ Posições dos avatares com animação
  // Um controller por criança: se dois avatares andam ao mesmo tempo, um não
  // cancela o outro (com um controller compartilhado, o `forward(from: 0)` de
  // um interrompia o do outro e deixava listeners órfãos movendo o avatar).
  final Map<String, AnimationController> _avatarAnims = {};
  final Map<String, AvatarPosition> _avatarPositions = {};
  final Map<String, Offset> _avatarTargets = {};
  
  // 🗺️ Transform controller para zoom/pan
  final TransformationController _transformController = TransformationController();

  // 📐 Área visível do mapa: usada para encaixar o canvas 450x320 inteiro na tela
  Size? _viewportSize;
  bool _initialFitDone = false;

  // 🖐️ Gestos do mapa
  late AnimationController _viewAnimController; // zoom animado (botões / duplo toque)
  Animation<Matrix4>? _viewAnim;
  int _activePointers = 0;
  bool _tapMoved = false;
  bool _multiTouch = false;
  Offset _tapDownPos = Offset.zero;
  Offset? _pendingTapPos; // 1º toque esperando o 2º (duplo toque)
  Timer? _doubleTapTimer;

  // 🏁 Feedback de chegada ao checkpoint (pulso no avatar + aviso no rodapé)
  final Map<String, int> _arrivalRings = {};
  final Map<String, Timer> _ringTimers = {};
  Timer? _messageTimer;
  String? _arrivalMessage;
  
  // 📱 Estados do UI (removido filtros para interface mais limpa)
  
  // 📏 Dimensões
  // ✅ Mesma "tela" (450x320) usada no admin web e no telão (AdminMap.tsx /
  // DisplayMap.tsx) — os map_x/map_y salvos pelos checkpoints são pixels
  // dentro desse canvas. Usar um tamanho diferente aqui deixava os
  // checkpoints e avatares fora da posição relativa correta no mobile.
  static const double mapWidth = 450;
  static const double mapHeight = 320;

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
    
    _viewAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    )..addListener(() {
        final anim = _viewAnim;
        if (anim != null) _transformController.value = anim.value;
      });

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
        ref.read(mapRefreshProvider.notifier).refresh();
      });

      // O avatar se move sozinho: CHILD_CHECKPOINT_PASSED atualiza o último
      // checkpoint da criança (realtimeCheckpointTrackingProvider), o build
      // recalcula o alvo e _syncAvatarTargets anima até o centro do checkpoint.
      ref.read(webSocketServiceProvider).on('CHILD_CHECKPOINT_PASSED', (data) {
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
    for (final controller in _avatarAnims.values) {
      controller.dispose();
    }
    _avatarAnims.clear();
    for (final timer in _ringTimers.values) {
      timer.cancel();
    }
    _messageTimer?.cancel();
    _doubleTapTimer?.cancel();
    // Se o mapa sair da tela com o dedo em cima, destrava a rolagem da tela pai.
    final onInteractionChanged = widget.onInteractionChanged;
    if (_activePointers > 0 && onInteractionChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onInteractionChanged(false));
    }
    _viewAnimController.dispose();
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
          _floorPlanImage = _decodeFloorPlanImage(floorPlanUrl);
        });
      }
    } catch (e) {
      log.w('[MAP] ⚠️ Erro ao carregar floor plan: $e');
    }
  }

  /// ✅ O backend guarda a planta como data URI base64
  /// ("data:image/png;base64,..."), não como uma URL http real — por isso
  /// não dá pra usar NetworkImage aqui, precisa decodificar pra bytes.
  ImageProvider? _decodeFloorPlanImage(String value) {
    try {
      if (value.startsWith('data:')) {
        final base64Part = value.split(',').last;
        return MemoryImage(base64Decode(base64Part));
      }
      return NetworkImage(value);
    } catch (e) {
      log.e('[MAP] ❌ Erro ao decodificar imagem da planta baixa: $e');
      return null;
    }
  }

  /// 📍 Alvo de cada avatar: o CENTRO do checkpoint onde a criança está, no
  /// mesmo ponto em que o marcador do checkpoint é desenhado (o círculo do
  /// checkpoint e o do avatar têm 40px, então o avatar cobre o checkpoint).
  /// Só quando mais de uma criança está no mesmo ponto elas são afastadas
  /// lado a lado, para nenhuma ficar escondida atrás da outra.
  Map<String, Offset> _computeAvatarTargets(List<Map<String, dynamic>> childPositions) {
    final byPoint = <String, List<String>>{};
    final base = <String, Offset>{};

    for (final p in childPositions) {
      final id = (p['child'] as Child).id;
      final x = (p['x'] as num).toDouble();
      final y = (p['y'] as num).toDouble();
      base[id] = Offset(x, y);
      byPoint.putIfAbsent('${x.round()}:${y.round()}', () => []).add(id);
    }

    const spacing = 14.0;
    final targets = <String, Offset>{};
    for (final ids in byPoint.values) {
      for (var i = 0; i < ids.length; i++) {
        final dx = (i - (ids.length - 1) / 2) * spacing;
        targets[ids[i]] = base[ids[i]]! + Offset(dx, 0);
      }
    }
    return targets;
  }

  /// Leva cada avatar até o alvo calculado. Chamado a cada build, mas só age
  /// quando o alvo de uma criança mudou (nova leitura de checkpoint).
  void _syncAvatarTargets(List<Map<String, dynamic>> childPositions, Map<String, Offset> targets) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final p in childPositions) {
        final child = p['child'] as Child;
        final target = targets[child.id];
        if (target == null || _avatarTargets[child.id] == target) continue;

        final isFirstTime = !_avatarPositions.containsKey(child.id);
        _avatarTargets[child.id] = target;

        if (isFirstTime) {
          // Primeira vez que vemos a criança (ex.: app reaberto): já nasce no
          // lugar certo, sem atravessar o mapa.
          setState(() {
            _avatarPositions[child.id] = AvatarPosition(
              childId: child.id,
              childName: child.nickname.isNotEmpty ? child.nickname : child.name,
              teamColor: child.teamColor,
              x: target.dx,
              y: target.dy,
            );
          });
        } else {
          final checkpointName = p['checkpointName'] as String?;
          _moveAvatarTo(
            child.id,
            target,
            onArrived: (p['hasCheckpoint'] == true && checkpointName != null && checkpointName.isNotEmpty)
                ? () => _onAvatarArrived(child, checkpointName)
                : null,
          );
        }
      }
    });
  }

  /// 🎬 Anima o avatar da posição atual até [target] (800ms).
  void _moveAvatarTo(String childId, Offset target, {VoidCallback? onArrived}) {
    final avatar = _avatarPositions[childId];
    if (avatar == null) return;

    _avatarAnims.remove(childId)?.dispose();

    final startX = avatar.x;
    final startY = avatar.y;
    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    _avatarAnims[childId] = controller;

    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        avatar.x = startX + (target.dx - startX) * curve.value;
        avatar.y = startY + (target.dy - startY) * curve.value;
      });
    });

    controller.forward().whenComplete(() {
      if (identical(_avatarAnims[childId], controller)) {
        _avatarAnims.remove(childId);
        controller.dispose();
        onArrived?.call();
      }
    });
  }

  /// Menor zoom = mapa inteiro na tela ("encaixe"). O maior é 4x isso.
  static const double _maxZoomFactor = 4.0;

  /// Folga (em px de cena) que dá para arrastar além da borda do mapa.
  static const double _panMargin = 24;

  double _fitScale(Size viewport) =>
      math.min(viewport.width / mapWidth, viewport.height / mapHeight).clamp(0.3, 1.5).toDouble();

  /// 📐 Matriz que encaixa o canvas 450x320 inteiro (e centralizado) na área
  /// visível. Sem isso o mapa abria cortado em telas de ~360-400dp de largura.
  Matrix4 _fitMatrix(Size viewport) {
    final scale = _fitScale(viewport);
    final dx = (viewport.width - mapWidth * scale) / 2;
    final dy = (viewport.height - mapHeight * scale) / 2;
    return Matrix4(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }

  /// Limite do arrasto. Com o zoom mínimo (mapa encaixado) a área permitida é
  /// exatamente a visível + uma folga, então o mapa nunca "foge" da tela — antes
  /// a margem fixa de 200 deixava arrastar o mapa para fora e se perder.
  EdgeInsets _mapBoundary(Size viewport) {
    final fit = _fitScale(viewport);
    final extraX = math.max(0.0, (viewport.width / fit - mapWidth) / 2);
    final extraY = math.max(0.0, (viewport.height / fit - mapHeight) / 2);
    return EdgeInsets.symmetric(horizontal: extraX + _panMargin, vertical: extraY + _panMargin);
  }

  /// Aplica os mesmos limites do arrasto a transformações feitas por código
  /// (botões +/− e duplo toque), que o InteractiveViewer não corrige sozinho.
  Matrix4 _clampView(Matrix4 m, Size viewport) {
    final s = m.entry(0, 0);
    final boundary = _mapBoundary(viewport);

    double axis(double t, double view, double content, double margin) {
      final lo = view - content - margin * s;
      final hi = margin * s;
      return lo > hi ? (view - content) / 2 : t.clamp(lo, hi).toDouble();
    }

    final tx = axis(m.entry(0, 3), viewport.width, mapWidth * s, boundary.left);
    final ty = axis(m.entry(1, 3), viewport.height, mapHeight * s, boundary.top);
    return Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  /// Anima a câmera do mapa até [target] (280ms).
  void _animateViewTo(Matrix4 target) {
    _viewAnim = Matrix4Tween(begin: _transformController.value, end: target).animate(
      CurvedAnimation(parent: _viewAnimController, curve: Curves.easeOutCubic),
    );
    _viewAnimController.forward(from: 0);
  }

  /// Volta ao mapa inteiro na tela.
  void _resetView() {
    final viewport = _viewportSize;
    if (viewport == null) return;
    _animateViewTo(_fitMatrix(viewport));
  }

  /// Aproxima/afasta multiplicando o zoom por [factor] em volta de [focal]
  /// (por padrão o centro da área visível).
  void _zoomBy(double factor, {Offset? focal}) {
    final viewport = _viewportSize;
    if (viewport == null) return;

    final current = _transformController.value;
    final s = current.entry(0, 0);
    final fit = _fitScale(viewport);
    final target = (s * factor).clamp(fit, fit * _maxZoomFactor).toDouble();
    if ((target - s).abs() < 0.001) return;

    final k = target / s;
    final f = focal ?? Offset(viewport.width / 2, viewport.height / 2);
    // Escala em volta de f: p' = k·p + f·(1 − k)
    final zoom = Matrix4(k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, f.dx * (1 - k), f.dy * (1 - k), 0, 1);
    _animateViewTo(_clampView(zoom.multiplied(current), viewport));
  }

  /// Duplo toque: aproxima no ponto tocado; se já estiver aproximado, volta ao encaixe.
  void _handleDoubleTap(Offset position) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final fit = _fitScale(viewport);
    if (_transformController.value.entry(0, 0) > fit * 1.4) {
      _resetView();
    } else {
      HapticFeedback.selectionClick();
      _zoomBy(2.2, focal: position);
    }
  }

  // 🖐️ Toques no mapa. Feitos com Listener (e não com onDoubleTap do
  // GestureDetector) porque o onDoubleTap segura a arena de gestos e atrasaria
  // em ~300ms o toque nos checkpoints e nos avatares.
  void _handlePointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1) {
      _tapMoved = false;
      _multiTouch = false;
      _tapDownPos = event.localPosition;
      widget.onInteractionChanged?.call(true);
    } else {
      _multiTouch = true;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if ((event.localPosition - _tapDownPos).distance > 12) _tapMoved = true;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasSingleTap = _activePointers == 1 && !_multiTouch && !_tapMoved;
    _releasePointer();

    _doubleTapTimer?.cancel();
    if (!wasSingleTap) {
      _pendingTapPos = null;
      return;
    }
    final pending = _pendingTapPos;
    if (pending != null && (event.localPosition - pending).distance < 40) {
      _pendingTapPos = null;
      _handleDoubleTap(event.localPosition);
    } else {
      // 1º toque: se o 2º não vier em 300ms, deixa de valer como duplo toque
      _pendingTapPos = event.localPosition;
      _doubleTapTimer = Timer(const Duration(milliseconds: 300), () => _pendingTapPos = null);
    }
  }

  void _releasePointer() {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) widget.onInteractionChanged?.call(false);
  }

  Widget _buildZoomButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Material(
      color: PulynColors.darkCard.withValues(alpha: 0.92),
      elevation: 2,
      shape: const CircleBorder(side: BorderSide(color: PulynColors.darkBorder)),
      child: IconButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        icon: Icon(icon),
        iconSize: 20,
        color: Colors.white,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
  }

  /// Encaixa o mapa na primeira vez que a área visível é conhecida.
  void _scheduleInitialFit(Size viewport) {
    _viewportSize = viewport;
    if (_initialFitDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialFitDone) return;
      _transformController.value = _fitMatrix(viewport);
      setState(() => _initialFitDone = true);
    });
  }

  /// 🏁 Feedback quando um avatar termina de chegar a um checkpoint: vibração
  /// leve, pulso em volta do avatar e um aviso curto no rodapé do mapa.
  void _onAvatarArrived(Child child, String checkpointName) {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    final name = child.nickname.isNotEmpty ? child.nickname : child.name.split(' ').first;
    setState(() {
      _arrivalRings[child.id] = DateTime.now().millisecondsSinceEpoch;
      _arrivalMessage = '$name chegou em $checkpointName';
    });

    _ringTimers[child.id]?.cancel();
    _ringTimers[child.id] = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _arrivalRings.remove(child.id));
    });
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _arrivalMessage = null);
    });
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
            
            // Status
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
        height: 480,
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
        height: 480,
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
            height: 480,
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
            'checkpointName': checkpoint['name'],
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
              name: sanitizeUtf16((zone['name'] ?? 'Zona Desconhecida').toString()),
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

    // 📍 Onde cada avatar deve ficar (centro do checkpoint) e animação até lá
    final avatarTargets = _computeAvatarTargets(childPositions);
    _syncAvatarTargets(childPositions, avatarTargets);

    return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 480, // Mapa maior e com mais espaço pra arrastar/zoom
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PulynColors.darkBorder),
            ),
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: PulynColors.darkBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mapa do Evento',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Arraste, pince ou toque 2x para dar zoom',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: PulynColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Jogo em andamento: um único selo (antes o nome aparecia duas vezes)
                      if (widget.activeGame != null)
                        Flexible(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: PulynColors.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PulynColors.success.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: PulynColors.success,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${widget.activeGame!['gameName'] ?? widget.activeGame!['name'] ?? 'Jogo ativo'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: PulynColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Volta ao encaixe inicial (mapa inteiro na tela)
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _resetView();
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        tooltip: 'Centralizar',
                        iconSize: 20,
                        color: PulynColors.textMuted,
                      ),
                    ],
                  ),
                ),

                // Mapa interativo
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(constraints.maxWidth, constraints.maxHeight);
                      _scheduleInitialFit(viewport);
                      final fitScale = _fitScale(viewport);
                      return Stack(
                        children: [
                          Positioned.fill(
                            // Escondido só até o encaixe inicial (1 frame), para não piscar cortado
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: _handlePointerDown,
                              onPointerMove: _handlePointerMove,
                              onPointerUp: _handlePointerUp,
                              onPointerCancel: (_) => _releasePointer(),
                              child: Opacity(
                              opacity: _initialFitDone ? 1 : 0,
                              child: InteractiveViewer(
                    transformationController: _transformController,
                    // Não deixa afastar além do "mapa inteiro" nem arrastar o mapa para fora da tela
                    minScale: fitScale,
                    maxScale: fitScale * _maxZoomFactor,
                    boundaryMargin: _mapBoundary(viewport),
                    // Tocar no mapa durante uma animação de zoom assume o controle
                    onInteractionStart: (_) => _viewAnimController.stop(),
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
                        image: _floorPlanImage != null
                            ? DecorationImage(
                                image: _floorPlanImage!,
                                fit: BoxFit.cover,
                                opacity: 0.4,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Background decorativo (padrão de piso)
                          if (_floorPlanImage == null)
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
                              // Caixa de largura FIXA (120px) centrada em map_x: o círculo
                              // (40px) fica sempre exatamente em (map_x, map_y). Antes a caixa
                              // crescia com o nome do checkpoint e o círculo saía deslocado pra
                              // direita, e o avatar não cobria o checkpoint. x/y são pixels.
                              left: pos['x']! - 60,
                              top: pos['y']! - 20,
                              width: 120,
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

                          // 👶 Filhos no mapa
                          ...childPositions.map((childPos) {
                            final childData = childPos['child'] as Child;

                            // Centro do avatar: posição animada, ou o alvo direto no
                            // 1º frame. x/y são PIXELS do canvas 450x320.
                            late double centerX;
                            late double centerY;
                            final animated = _avatarPositions[childData.id];
                            if (animated != null) {
                              centerX = animated.x;
                              centerY = animated.y;
                            } else {
                              final target = avatarTargets[childData.id] ??
                                  Offset((childPos['x'] as num).toDouble(), (childPos['y'] as num).toDouble());
                              centerX = target.dx;
                              centerY = target.dy;
                            }

                            try {
                              final teamColor = Color(int.parse('0xFF${childData.teamColor.replaceFirst('#', '')}'));
                              final displayName = childData.nickname.isNotEmpty
                                  ? childData.nickname
                                  : childData.name.split(' ').first;
                              final initial = childData.nickname.isNotEmpty
                                  ? childData.nickname[0].toUpperCase()
                                  : childData.name[0].toUpperCase();
                              final ringId = _arrivalRings[childData.id];

                              // Caixa 40x40 centrada no checkpoint. O avatar (34px) deixa o
                              // anel do checkpoint aparecendo em volta, e o nome fica ACIMA:
                              // assim o rótulo do checkpoint, logo abaixo, continua tocável.
                              return Positioned(
                                left: centerX - 20,
                                top: centerY - 20,
                                width: 40,
                                height: 40,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // Pulso de chegada (só por ~1,5s; antes todos pulsavam para sempre)
                                    if (ringId != null)
                                      IgnorePointer(
                                        child: TweenAnimationBuilder<double>(
                                          key: ValueKey(ringId),
                                          tween: Tween<double>(begin: 0, end: 1),
                                          duration: const Duration(milliseconds: 1400),
                                          curve: Curves.easeOut,
                                          builder: (context, t, _) => Opacity(
                                            opacity: (1 - t).clamp(0.0, 1.0),
                                            child: Container(
                                              width: 40 + 56 * t,
                                              height: 40 + 56 * t,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: teamColor, width: 3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: () => _showChildDetails(childData),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [teamColor, teamColor.withValues(alpha: 0.7)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(color: Colors.yellow, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: teamColor.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: childData.profileImage != null && childData.profileImage!.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  childData.profileImage!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Center(
                                                    child: Text(
                                                      initial,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    // Nome acima do avatar
                                    Positioned(
                                      bottom: 42,
                                      left: -40,
                                      right: -40,
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: PulynColors.darkCard.withValues(alpha: 0.92),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.yellow.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.yellow,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              return const SizedBox.shrink();
                            }
                          }),
                        ],
                      ),
                    ),
                  ),
                            ),
                            ),
                          ),
                          // Aviso de chegada ("Lucas chegou em Torre Encantada")
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: IgnorePointer(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: _arrivalMessage == null
                                    ? const SizedBox.shrink(key: ValueKey('sem-aviso'))
                                    : Container(
                                        key: ValueKey(_arrivalMessage),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: PulynColors.darkCard.withValues(alpha: 0.96),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: PulynColors.success.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              color: PulynColors.success,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _arrivalMessage!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          // Botões de zoom
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildZoomButton(Icons.add, 'Aproximar', () => _zoomBy(1.6)),
                                const SizedBox(height: 8),
                                _buildZoomButton(Icons.remove, 'Afastar', () => _zoomBy(1 / 1.6)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Legenda (uma linha compacta: sobra mais altura para o mapa)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: PulynColors.darkBorder),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _buildLegendItem('Meus filhos', Colors.yellow),
                      _buildLegendItem('Conquistado', PulynColors.success),
                      _buildLegendItem('Disponível', PulynColors.primary),
                      _buildLegendItem('Fora do ar', PulynColors.danger),
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
          label,
          style: const TextStyle(
            fontSize: 11,
            color: PulynColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
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
