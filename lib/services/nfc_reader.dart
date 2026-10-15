import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../utils/logger.dart';

/// Situação do NFC no celular.
enum NfcSupport {
  /// Ligado e pronto para ler.
  enabled,

  /// O celular tem NFC, mas está desligado nas configurações.
  disabled,

  /// O celular não tem NFC (ou o sistema não permite ler tags).
  unsupported,
}

/// A leitura não foi concluída (a pessoa cancelou, ou a pulseira não pôde ser lida).
class NfcReadException implements Exception {
  final String mensagem;

  /// `true` quando a própria pessoa fechou a leitura (não é um erro a mostrar).
  final bool cancelled;

  const NfcReadException(this.mensagem, {this.cancelled = false});

  @override
  String toString() => mensagem;
}

/// Converte o UID lido pelo celular no formato que o backend usa: hexadecimal,
/// maiúsculas, sem separadores (o mesmo que o leitor RC522 dos checkpoints grava).
/// Um NTAG213 tem 7 bytes → 14 caracteres.
String uidToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buffer.toString();
}

/// Leitura da pulseira NFC. É uma interface para as telas poderem ser testadas sem NFC.
abstract class NfcReader {
  Future<NfcSupport> support();

  /// Espera a pessoa encostar uma pulseira e devolve o UID (veja [uidToHex]).
  /// Lança [NfcReadException] se for cancelado ou se não conseguir ler.
  Future<String> readBraceletUid();

  /// Encerra uma leitura em andamento (ao fechar a tela).
  Future<void> cancel();
}

/// Implementação real, em cima do `nfc_manager` (Android e iOS).
class PlatformNfcReader implements NfcReader {
  const PlatformNfcReader();

  @override
  Future<NfcSupport> support() async {
    try {
      switch (await NfcManager.instance.checkAvailability()) {
        case NfcAvailability.enabled:
          return NfcSupport.enabled;
        case NfcAvailability.disabled:
          return NfcSupport.disabled;
        case NfcAvailability.unsupported:
          return NfcSupport.unsupported;
      }
    } catch (e) {
      // Plataforma sem o plugin (testes, web, desktop): trata como sem NFC.
      log.w('[NFC] Não foi possível checar o NFC: $e');
      return NfcSupport.unsupported;
    }
  }

  @override
  Future<String> readBraceletUid() async {
    final completer = Completer<String>();

    Future<void> finish({String? uid, NfcReadException? error, String? iosError}) async {
      if (completer.isCompleted) return;
      if (uid != null) {
        log.i('[NFC] ✅ UID lido com sucesso: $uid');
        completer.complete(uid);
      } else {
        log.e('[NFC] ❌ Falha ao ler UID');
        completer.completeError(error ?? const NfcReadException('Não foi possível ler a pulseira.'));
      }
      try {
        await NfcManager.instance.stopSession(
          alertMessageIos: uid != null ? 'Pulseira lida!' : null,
          errorMessageIos: iosError,
        );
      } catch (e) {
        log.w('[NFC] Erro ao encerrar sessão: $e');
      }
    }

    try {
      log.i('[NFC] 🔍 Iniciando leitura de pulseira...');
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        alertMessageIos: 'Encoste a pulseira do seu filho na parte de cima do iPhone.',
        onDiscovered: (tag) async {
          log.i('[NFC] 📍 Tag detectada: ${tag.runtimeType}');
          final bytes = _uidBytes(tag);

          if (bytes == null) {
            log.w('[NFC] ⚠️ bytes is null');
            await finish(
              error: const NfcReadException('Não foi possível extrair o UID desta pulseira.'),
              iosError: 'Falha ao extrair dados da pulseira.',
            );
            return;
          }

          if (bytes.isEmpty) {
            log.w('[NFC] ⚠️ bytes is empty');
            await finish(
              error: const NfcReadException('Pulseira não possui dados válidos.'),
              iosError: 'Pulseira vazia.',
            );
            return;
          }

          log.i('[NFC] 📊 UID bytes: ${bytes.length} bytes - $bytes');
          final hex = uidToHex(bytes);
          log.i('[NFC] 🔤 UID hex: $hex');

          await finish(uid: hex);
        },
        onSessionErrorIos: (error) {
          log.e('[NFC] iOS erro: ${error.code}');
          final cancelled = error.code == NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled;
          if (!completer.isCompleted) {
            completer.completeError(NfcReadException(
              cancelled ? 'Leitura cancelada.' : 'Não foi possível ler a pulseira.',
              cancelled: cancelled,
            ));
          }
        },
      );
    } catch (e) {
      log.e('[NFC] ❌ Erro ao iniciar leitura: $e');
      if (!completer.isCompleted) {
        completer.completeError(NfcReadException('Erro ao iniciar leitor: $e'));
      }
    }

    return completer.future;
  }

  @override
  Future<void> cancel() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Sem sessão aberta: nada a fazer.
    }
  }

  /// UID do tag. Android e iOS expõem tipos diferentes (e o cast de um no outro
  /// falha), então cada plataforma lê do seu jeito.
  static Uint8List? _uidBytes(NfcTag tag) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return NfcTagAndroid.from(tag)?.id;
      case TargetPlatform.iOS:
        // Um NTAG/Ultralight aparece no iOS como "MiFare" (família Ultralight).
        return MiFareIos.from(tag)?.identifier;
      default:
        return null;
    }
  }
}
