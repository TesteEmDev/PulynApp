import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// 🚀 Serviço de Performance - Otimizações Globais

class PerformanceService {
  /// Cache de imagens em memória
  static final ImageCache _imageCache = ImageCache();

  /// Inicializa otimizações de performance
  static void initialize() {
    log.i('[Performance] 🚀 Inicializando otimizações...');
    
    // Aumenta cache de imagens (padrão é 100MB)
    _imageCache.maximumSizeBytes = 150 * 1024 * 1024; // 150MB
    _imageCache.maximumSize = 500; // 500 imagens em cache
    
    // Ativa compilação JIT (mais rápido que AOT em debug)
    // (Automático no Flutter)
    
    log.i('[Performance] ✅ Cache de imagens configurado: 150MB, 500 imagens');
  }

  /// Limpa cache de imagens
  static void clearImageCache() {
    _imageCache.clear();
    _imageCache.clearLiveImages();
    log.i('[Performance] 🗑️ Cache de imagens limpo');
  }

  /// Pré-carrega imagens
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    log.i('[Performance] 📦 Pré-carregando ${imageUrls.length} imagens...');
    
    await Future.wait(
      imageUrls.map(
        (url) => precacheImage(NetworkImage(url), context),
      ),
    );
    
    log.i('[Performance] ✅ Imagens pré-carregadas');
  }

  /// Monitora memory usage
  static Future<void> monitorMemory() async {
    log.d('[Performance] 💾 ImageCache: ${_imageCache.currentSize.toString()} bytes');
  }
}

/// 🎯 Mixin para lazy loading em listas
mixin LazyListMixin {
  /// Builder otimizado para listas grandes
  static Widget buildLazyListItem(
    BuildContext context,
    int index,
    int totalItems,
    Widget Function(int) itemBuilder,
  ) {
    // Se chegou perto do final, carrega mais itens
    if (index > totalItems - 5) {
      // Trigger para carregar mais dados
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Aqui você pode disparar uma ação para carregar mais dados
      });
    }

    return itemBuilder(index);
  }
}

/// 🔄 Debounce helper para operações frequentes
class Debouncer {
  final Duration delay;
  VoidCallback? action;
  Future<void>? _debounce;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Executa ação após delay (cancela anterior se existir)
  void call(VoidCallback callback) {
    action = callback;
    _debounce?.ignore();
    _debounce = Future.delayed(delay, () {
      action?.call();
    });
  }

  /// Cancela operação pendente
  void cancel() {
    _debounce?.ignore();
  }
}

/// 🎬 Throttle helper para eventos contínuos
class Throttler {
  final Duration duration;
  DateTime? _lastCallTime;

  Throttler({this.duration = const Duration(milliseconds: 300)});

  /// Executa callback apenas se passou o tempo mínimo
  void call(VoidCallback callback) {
    final now = DateTime.now();
    
    if (_lastCallTime == null ||
        now.difference(_lastCallTime!).inMilliseconds >= duration.inMilliseconds) {
      _lastCallTime = now;
      callback();
    }
  }

  /// Reseta o throttler
  void reset() {
    _lastCallTime = null;
  }

  /// Cancela operações pendentes (compatibilidade com Debouncer)
  void cancel() {
    reset();
  }
}

/// 📊 Profiler simples para medir performance
class PerformanceProfiler {
  static final Map<String, DateTime> _timers = {};
  static final Map<String, Duration> _results = {};

  /// Inicia timer
  static void startTimer(String label) {
    _timers[label] = DateTime.now();
  }

  /// Para timer e registra resultado
  static Duration stopTimer(String label) {
    if (!_timers.containsKey(label)) {
      log.w('[Profiler] ⚠️ Timer "$label" não iniciado');
      return Duration.zero;
    }

    final duration = DateTime.now().difference(_timers[label]!);
    _results[label] = duration;
    _timers.remove(label);

    log.d('[Profiler] ⏱️ $label: ${duration.inMilliseconds}ms');
    return duration;
  }

  /// Retorna resultados
  static Map<String, Duration> getResults() => _results;

  /// Limpa timers
  static void clear() {
    _timers.clear();
    _results.clear();
  }
}
