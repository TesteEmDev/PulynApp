import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

/// Escolha de tema do usuário (true = claro). Fica salva no aparelho e vale na próxima abertura.
final temaClaroProvider = StateNotifierProvider<TemaClaroNotifier, bool>((ref) => TemaClaroNotifier());

class TemaClaroNotifier extends StateNotifier<bool> {
  static const _chave = 'tema_claro';

  TemaClaroNotifier() : super(false) {
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aplicar(prefs.getBool(_chave) ?? false);
    } catch (_) {
      // Sem armazenamento disponível, segue no tema escuro.
    }
  }

  Future<void> definir(bool claro) async {
    _aplicar(claro);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, claro);
    } catch (_) {
      // Se não conseguir salvar, a escolha vale só nesta abertura.
    }
  }

  void _aplicar(bool claro) {
    PulynColors.claro = claro;
    state = claro;
  }
}
