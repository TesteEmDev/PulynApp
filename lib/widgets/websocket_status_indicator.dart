import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/websocket_provider.dart';

/// Indicador visual de status do WebSocket
class WebSocketStatusIndicator extends ConsumerWidget {
  final bool showLabel;

  const WebSocketStatusIndicator({
    super.key,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webSocketService = ref.watch(webSocketServiceProvider);
    final isConnected = webSocketService.isConnected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: isConnected ? 'Conectado' : 'Desconectado',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner de desconexão (topo da tela)
class WebSocketDisconnectionBanner extends ConsumerWidget {
  const WebSocketDisconnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webSocketService = ref.watch(webSocketServiceProvider);
    final isConnected = webSocketService.isConnected;

    if (isConnected) {
      return const SizedBox();
    }

    return Container(
      color: Colors.orange,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: const Text(
              'Sem conexão - Alguns dados podem estar desatualizados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(webSocketConnectionProvider.notifier).reconnect();
            },
            child: const Text(
              'Reconectar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
