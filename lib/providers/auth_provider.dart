import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/family_models.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// ✅ FutureProvider que aguarda a inicialização completa
final authInitProvider = FutureProvider<void>((ref) async {
  await ref.read(authProvider.notifier)._ensureInitialized();
});

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  late SharedPreferences _prefs;
  bool _initialized = false;
  
  // ✅ Armazena dados do usuário mesmo com getMyProfile() falhando
  User? _cachedUser;

  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initAsync();
  }

  /// ✅ Versão async-safe da inicialização
  void _initAsync() {
    _ensureInitialized();
  }

  /// Garante que a inicialização acontece apenas UMA VEZ
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _init();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final token = _prefs.getString('auth_token');
      final cachedUserJson = _prefs.getString('cached_user');
      
      log.i('[AUTH] 🔄 Inicializando com token: ${token != null ? "✅" : "❌"}');
      
      if (token != null) {
        // ✅ Temos token salvo, tenta carregar usuário em cache
        if (cachedUserJson != null) {
          try {
            final Map<String, dynamic> userMap = jsonDecode(cachedUserJson);
            _cachedUser = User.fromJson(userMap);
            log.i('[AUTH] ✅ Usuário restaurado do cache: ${_cachedUser!.email}');
            state = AsyncValue.data(_cachedUser);
            
            // ✅ Em background, tenta fazer refresh do usuário (sem bloquear)
            _refreshUserBackground();
          } catch (e) {
            log.e('[AUTH] ❌ Erro ao deserializar usuário: $e');
            state = const AsyncValue.data(null);
          }
        } else {
          // Sem cache mas tem token, tenta carregar do servidor
          log.i('[AUTH] Token presente mas sem cache local, carregando do servidor...');
          await _loadUserFromServer();
        }
      } else {
        log.i('[AUTH] ❌ Sem token persistido');
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      log.e('[AUTH] ❌ Erro ao inicializar: $e');
      state = const AsyncValue.data(null);
    }
  }
  
  /// ✅ Carrega usuário do servidor na inicialização
  Future<void> _loadUserFromServer() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      try {
        final user = await apiService.getMyProfile();
        _cachedUser = user;
        _saveUserToCache(user);
        state = AsyncValue.data(user);
        log.i('[AUTH] ✅ Usuário carregado do servidor: ${user.email}');
      } catch (e) {
        // ✅ Se /familias/me não existir, mantém usuário em cache
        if (e.toString().contains('404')) {
          log.w('[AUTH] ⚠️ Endpoint /familias/me não disponível, usando cache');
          if (_cachedUser != null) {
            state = AsyncValue.data(_cachedUser);
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      log.e('[AUTH] ❌ Erro ao carregar usuário do servidor: $e');
      state = const AsyncValue.data(null);
    }
  }
  
  /// ✅ Refresh em background sem bloquear a UI
  void _refreshUserBackground() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      try {
        final user = await apiService.getMyProfile();
        _cachedUser = user;
        _saveUserToCache(user);
        state = AsyncValue.data(user);
        log.i('[AUTH] ✅ Usuário sincronizado em background');
      } catch (e) {
        // ✅ Se /familias/me não existir, mantém usuário em cache
        if (e.toString().contains('404')) {
          log.w('[AUTH] ⚠️ Background: Endpoint /familias/me não disponível, mantendo cache');
          if (_cachedUser != null) {
            state = AsyncValue.data(_cachedUser);
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      log.w('[AUTH] ⚠️ Background refresh falhou (mantendo cache): $e');
      // Mantém o usuário em cache se o refresh falhar
    }
  }
  
  /// ✅ Salva usuário em cache para próxima inicialização
  void _saveUserToCache(User user) {
    try {
      final userJson = jsonEncode(user.toJson());
      _prefs.setString('cached_user', userJson);
      log.i('[AUTH] 💾 Usuário salvo em cache');
    } catch (e) {
      log.e('[AUTH] ❌ Erro ao salvar cache: $e');
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _ensureInitialized();
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      final loginResponse = await apiService.login(email, password);
      
      // ✅ Salva o usuário em cache
      _cachedUser = loginResponse.user;
      _saveUserToCache(loginResponse.user);
      
      // ✅ Garante que o token está salvo ANTES de atualizar o estado
      await _prefs.setString('auth_token', loginResponse.token);
      log.i('[AUTH] ✅ Login bem-sucedido para $email');
      
      state = AsyncValue.data(loginResponse.user);
    } catch (e, st) {
      log.e('[AUTH] ❌ Erro no login: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = const AsyncValue.loading();
    try {
      log.i('[AUTH] 📝 INICIANDO REGISTRO');
      log.i('[AUTH] 📧 Email: $email');
      log.i('[AUTH] 👤 Nome: $name');
      
      await _ensureInitialized();
      log.i('[AUTH] ✅ SharedPreferences inicializado');
      
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      log.i('[AUTH] ✅ ApiService inicializado');
      
      log.i('[AUTH] 🔄 Chamando /auth/register...');
      final loginResponse = await apiService.register(email, password, name);
      log.i('[AUTH] ✅ Resposta recebida do servidor');
      log.i('[AUTH] 🎫 Token recebido: ${loginResponse.token.substring(0, 20)}...');
      
      // ✅ Salva o usuário em cache
      _cachedUser = loginResponse.user;
      _saveUserToCache(loginResponse.user);
      log.i('[AUTH] 💾 Usuário salvo em cache');
      
      // ✅ Salva o token
      await _prefs.setString('auth_token', loginResponse.token);
      log.i('[AUTH] 🔐 Token salvo em SharedPreferences');
      
      log.i('[AUTH] ✅ REGISTRO CONCLUÍDO COM SUCESSO');
      log.i('[AUTH] 👤 Usuário: ${loginResponse.user.email} (${loginResponse.user.name})');
      
      state = AsyncValue.data(loginResponse.user);
    } catch (e, st) {
      log.e('[AUTH] ❌ ERRO NO REGISTRO: $e');
      log.e('[AUTH] 📍 StackTrace: $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await _ensureInitialized();
      await _prefs.remove('auth_token');
      await _prefs.remove('cached_user');
      _cachedUser = null;  // ✅ Limpa cache ao fazer logout
      state = const AsyncValue.data(null);
      log.i('[AUTH] ✅ Logout realizado');
    } catch (e, st) {
      log.e('[AUTH] ❌ Erro ao fazer logout: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshUser() async {
    try {
      await _ensureInitialized();
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      final user = await apiService.getMyProfile();
      _cachedUser = user;
      _saveUserToCache(user);
      state = AsyncValue.data(user);
      log.i('[AUTH] ✅ Usuário atualizado');
    } catch (e, st) {
      log.w('[AUTH] ⚠️ Erro ao atualizar usuário: $e');
      // Se falhar, mantém o usuário anterior em cache
      if (_cachedUser != null) {
        state = AsyncValue.data(_cachedUser);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  bool get isAuthenticated => state.whenData((user) => user != null).value ?? false;
}
