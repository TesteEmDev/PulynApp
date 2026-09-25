import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../models/family_models.dart';
import 'index.dart'; // Import para acessar os providers definidos em index.dart

/// Provider para WebSocket Service (singleton)
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Provider que gerencia conexão WebSocket
final webSocketConnectionProvider =
    StateNotifierProvider<WebSocketNotifier, AsyncValue<bool>>((ref) {
  return WebSocketNotifier(ref);
});

class WebSocketNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  late WebSocketService _webSocketService;
  bool _isInitialized = false;

  WebSocketNotifier(this.ref)
      : super(const AsyncValue.data(false)) {
    _webSocketService = ref.read(webSocketServiceProvider);
    
    // ✅ Escuta mudanças de autenticação
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && !_isInitialized) {
          // ✅ Apenas conecta DEPOIS que usuário faz login
          log.i('[WebSocket] Usuário autenticado, conectando...');
          _initializeConnection();
        } else if (user == null && _isInitialized) {
          // ✅ Desconecta quando faz logout
          log.i('[WebSocket] Usuário deslogado, desconectando...');
          disconnect();
        }
      });
    });
  }

  Future<void> _initializeConnection() async {
    try {
      state = const AsyncValue.loading();
      
      // ✅ Precisa do evento ativo para conectar (igual frontend web)
      final activeEventAsync = ref.read(activeEventProvider);
      
      await activeEventAsync.when(
        loading: () => Future.delayed(const Duration(seconds: 2)),
        error: (error, _) async {
          log.e('[WebSocket] ❌ Erro ao obter evento ativo: $error');
          state = AsyncValue.error(error, StackTrace.current);
        },
        data: (activeEvent) async {
          if (activeEvent == null) {
            log.w('[WebSocket] ⚠️ Nenhum evento ativo encontrado');
            state = const AsyncValue.data(false);
            return;
          }

          final eventoId = activeEvent['id'] as String;
          final baseUrl = ApiConfig.getApiBaseUrl();
          
          // ✅ Obter token de autenticação do SharedPreferences
          final apiService = ref.read(apiServiceProvider);
          await apiService.init();
          final token = await apiService.getStoredToken();

          log.i('[WebSocket] Conectando ao evento $eventoId com auth: ${token != null}');
          
          // ✅ Conecta com formato igual ao frontend web
          final success = await _webSocketService.connectWithAuth(baseUrl, token, eventoId);

          if (success) {
            _isInitialized = true;
            state = const AsyncValue.data(true);
            log.i('[WebSocket] ✅ Conectado e sincronizando com evento $eventoId');
            _setupEventHandlers();
          } else {
            state = const AsyncValue.data(false);
          }
        },
      );
      
    } catch (e, st) {
      log.e('[WebSocket] ❌ Erro ao conectar: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Configura handlers para eventos específicos
  void _setupEventHandlers() {
    // Score updates
    _webSocketService.on('SCORE_UPDATE', (data) {
      // ✅ Não precisa invalidar - o StreamProvider tem listeners diretos
    });

    // Territory conquered
    _webSocketService.on('TERRITORY_CONQUERED', (data) {
      // ✅ Não precisa invalidar - o StreamProvider tem listeners diretos
    });

    // Ranking updated
    _webSocketService.on('RANKING_UPDATE', (data) {
      log.i('[WebSocket Handler] 🏆 Ranking updated');
      // ✅ Não precisa invalidar - o StreamProvider tem listeners diretos
    });

    // Event started
    _webSocketService.on('EVENT_STARTED', (data) {
      log.i('[WebSocket Handler] 🎮 Event started: ${data['eventoId']}');
      // ✅ Não precisa invalidar - o StreamProvider tem listeners diretos
    });

    // Event ended
    _webSocketService.on('EVENT_ENDED', (data) {
      log.i('[WebSocket Handler] ✅ Event ended: ${data['eventoId']}');
      // ✅ Não precisa invalidar - o StreamProvider tem listeners diretos
    });

    // New notification
    _webSocketService.on('NOTIFICATION', (data) {
      log.i('[WebSocket Handler] 📬 New notification: ${data['title']}');
    });
  }

  Future<void> reconnect() async {
    await _initializeConnection();
  }

  Future<void> disconnect() async {
    _isInitialized = false;
    await _webSocketService.disconnect();
    state = const AsyncValue.data(false);
    log.i('[WebSocket] Desconectado');
  }

  void sendMessage(String type, Map<String, dynamic> payload) {
    _webSocketService.send({
      'type': type,
      ...payload,
    });
  }
}

// Provider para status da conexão
final webSocketStatusProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    final service = ref.watch(webSocketServiceProvider);
    yield service.isConnected;
    await Future.delayed(const Duration(seconds: 1));
  }
});
