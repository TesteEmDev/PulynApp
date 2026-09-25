import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../utils/logger.dart';
import '../utils/network_helper.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isListening = false;
  final List<Function(Map<String, dynamic>)> _listeners = [];

  // Callbacks para diferentes tipos de eventos
  final Map<String, List<Function(Map<String, dynamic>)>> _eventHandlers = {};

  /// Conecta ao WebSocket com formato igual ao frontend web
  Future<bool> connectWithAuth(String baseUrl, String? token, String? eventoId) async {
    try {
      if (eventoId == null) {
        log.w('[WebSocket] Evento ID não definido, não conectando');
        return false;
      }

      log.i('[WebSocket] Conectando ao evento $eventoId em $baseUrl');
      
      // ✅ Resolve localhost para emulador Android
      final resolvedUrl = NetworkHelper.resolveLocalhost(baseUrl);
      
      // ✅ Converte para WebSocket URL
      final wsUrl = resolvedUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceFirst('/api', ''); // Remove /api path como no frontend

      // ✅ Adiciona evento_id como query parameter (igual frontend web)
      final fullWsUrl = '$wsUrl?evento_id=$eventoId';

      log.i('[WebSocket] URL final: $fullWsUrl');
      
      // ✅ Conecta com autenticação se tiver token (igual frontend web)
      if (token != null) {
        // Protocolo de autenticação igual ao frontend
        _channel = WebSocketChannel.connect(
          Uri.parse(fullWsUrl),
          protocols: ['pulyn-auth', token],
        );
      } else {
        _channel = WebSocketChannel.connect(Uri.parse(fullWsUrl));
      }

      // Aguarda a conexão estar pronta
      await _channel!.ready;
      _isConnected = true;

      log.i('[WebSocket] ✅ Conectado ao evento $eventoId');

      // ✅ Inicia listener apenas UMA VEZ
      if (!_isListening) {
        _listen();
      }

      // ✅ Envia heartbeat igual frontend web
      _sendHeartbeat(eventoId);
      
      return true;
    } catch (e) {
      log.e('[WebSocket] ❌ Erro ao conectar: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Conecta ao WebSocket (método antigo, mantido para compatibilidade)
  Future<bool> connect(String baseUrl) async {
    return await connectWithAuth(baseUrl, null, null);
  }

  /// Envia heartbeat igual ao frontend web
  void _sendHeartbeat(String eventoId) {
    if (_isConnected) {
      send({
        'type': 'HEARTBEAT',
        'payload': {
          'evento_id': eventoId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    }
  }

  /// Listener para mensagens recebidas (chamado apenas UMA VEZ)
  void _listen() {
    if (_isListening) return;
    _isListening = true;
    
    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String?;
          
          // ✅ Ignora heartbeat logs como no frontend
          final isHeartbeat = type == 'HEARTBEAT' || type == 'PONG';
          
          if (!isHeartbeat) {
            log.i('[WebSocket] 📨 Evento recebido: $type');
          }

          // Notifica listeners genéricos
          for (final listener in _listeners) {
            listener(data);
          }

          // Notifica handlers específicos por tipo
          if (type != null && _eventHandlers.containsKey(type)) {
            for (final handler in _eventHandlers[type]!) {
              handler(data);
            }
          }
        } catch (e) {
          log.e('[WebSocket] ❌ Erro ao decodificar mensagem: $e');
        }
      },
      onError: (error) {
        log.e('[WebSocket] ❌ Erro no stream: $error');
        _isConnected = false;
        _isListening = false;
      },
      onDone: () {
        log.w('[WebSocket] ⚠️ Conexão fechada');
        _isConnected = false;
        _isListening = false;
      },
    );
  }

  /// Se deve reconectar automaticamente
  Future<void> reconnectIfNeeded(String baseUrl) async {
    if (!_isConnected) {
      log.i('[WebSocket] Tentando reconectar...');
      await Future.delayed(const Duration(seconds: 2));
      await connect(baseUrl);
    }
  }

  /// Registra listener para todos os eventos
  void onMessage(Function(Map<String, dynamic>) callback) {
    _listeners.add(callback);
  }

  /// Registra listener para tipo específico
  void on(String eventType, Function(Map<String, dynamic>) callback) {
    _eventHandlers.putIfAbsent(eventType, () => []);
    _eventHandlers[eventType]!.add(callback);
    log.i('[WebSocket] 📋 Listener registrado para evento: $eventType (total: ${_eventHandlers[eventType]!.length})');
  }

  /// Remove listener
  void off(String eventType, Function(Map<String, dynamic>) callback) {
    _eventHandlers[eventType]?.remove(callback);
  }

  /// Envia mensagem para o servidor
  void send(Map<String, dynamic> data) {
    if (_isConnected) {
      try {
        _channel?.sink.add(jsonEncode(data));
        final type = data['type'];
        if (type != 'HEARTBEAT') {
          log.i('[WebSocket] 📤 Mensagem enviada: $type');
        }
      } catch (e) {
        log.e('[WebSocket] ❌ Erro ao enviar mensagem: $e');
      }
    } else {
      log.w('[WebSocket] ⚠️ Não conectado, mensagem não enviada');
    }
  }

  /// Fecha a conexão
  Future<void> disconnect() async {
    log.i('[WebSocket] Desconectando...');
    _isConnected = false;
    _isListening = false;
    _listeners.clear();
    _eventHandlers.clear();
    await _channel?.sink.close();
    _channel = null;
  }

  /// Status da conexão
  bool get isConnected => _isConnected;
}
