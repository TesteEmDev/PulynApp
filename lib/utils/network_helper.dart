import 'dart:io';
import '../utils/logger.dart';

/// Helper para resolver URLs de localhost em emuladores/devices
class NetworkHelper {
  /// Em emuladores Android, 'localhost' é o emulador, não a máquina host
  /// Para acessar a máquina host, use '10.0.2.2' no Android Emulator
  /// Para DEVICE FÍSICO, use o IP local da máquina (192.168.x.x ou 10.x.x.x)
  static String resolveLocalhost(String url) {
    if (!url.contains('localhost')) {
      return url;
    }

    try {
      if (Platform.isAndroid) {
        // Para device físico, usar IP local
        // ✅ IP configurado: 192.168.0.60
        final resolvedUrl = url.replaceFirst('localhost', '192.168.0.60');
        log.i('🌐 URL resolvida para Android: $resolvedUrl');
        return resolvedUrl;
      } else if (Platform.isIOS) {
        // No iOS Simulator, localhost funciona normalmente
        log.i('🌐 URL de iOS: $url');
        return url;
      } else {
        // Desktop/web
        log.i('🌐 URL de Desktop: $url');
        return url;
      }
    } catch (e) {
      log.e('❌ Erro ao resolver URL: $e');
      return url;
    }
  }

  /// Detecta se está em emulador Android
  static Future<bool> isAndroidEmulator() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Em emuladores, geralmente esses arquivos não existem
      final buildFP = await File('/system/build.fingerprint').exists();
      final buildSerial = await File('/system/build.serial').exists();
      return !buildFP || !buildSerial;
    } catch (e) {
      log.w('⚠️ Erro ao detectar emulador: $e');
      return false;
    }
  }

  /// Testa conectividade com um endpoint
  static Future<bool> testConnectivity(String url) async {
    try {
      // Simplificado: não testa neste momento
      // O erro de conexão será tratado pela API/WebSocket
      return true;
    } catch (e) {
      return false;
    }
  }
}
