import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_models.dart';
import '../config/api_config.dart';
import '../utils/network_helper.dart';
import '../utils/logger.dart';
import '../utils/text_sanitizer.dart';

class ApiService {
  late Dio _dio;
  late String _baseUrl;
  late SharedPreferences _prefs;
  bool _initialized = false;

  // ✅ Expor Dio publicamente para uso direto
  Dio get dio => _dio;

  // ✅ Expor SharedPreferences publicamente para uso em helpers
  SharedPreferences get prefs => _prefs;

  ApiService() {
    _baseUrl = ApiConfig.getApiBaseUrl();
    // ✅ Resolve localhost para emulador Android
    _baseUrl = NetworkHelper.resolveLocalhost(_baseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: '$_baseUrl/api', // ✅ Adiciona /api no baseUrl
        connectTimeout: const Duration(seconds: 30), // Aumentado de 10 para 30
        receiveTimeout: const Duration(seconds: 30), // Aumentado de 10 para 30
        sendTimeout: const Duration(seconds: 30), // Adicionado
      ),
    );
    // ✅ Interceptor será adicionado em init(), não aqui
  }

  /// Altera o ambiente e reconecta
  void setEnvironment(ApiEnvironment environment) {
    ApiConfig.setEnvironment(environment);
    _baseUrl = ApiConfig.getApiBaseUrl();
    // ✅ Resolve localhost para emulador Android
    _baseUrl = NetworkHelper.resolveLocalhost(_baseUrl);
    _dio.options.baseUrl = '$_baseUrl/api'; // ✅ Adiciona /api
  }

  /// Retorna o ambiente atual
  ApiEnvironment getCurrentEnvironment() {
    return ApiConfig.currentEnvironment;
  }

  /// ✅ Inicializa SharedPreferences e configura interceptor
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    
    _prefs = await SharedPreferences.getInstance();
    
    // ✅ Interceptor só é adicionado DEPOIS que _prefs está pronto
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _addToken,
        onError: _handleError,
      ),
    );
  }

  Future<void> _addToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _prefs.getString('auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ✅ Trata 401 - token expirado ou inválido
    if (err.response?.statusCode == 401) {
      log.e('[API] ❌ 401 Unauthorized - Token inválido');
      log.e('[API] Response: ${err.response?.data}');
      // Remove token expirado e força logout
      await _prefs.remove('auth_token');
      // A app saberá fazer logout pela mudança do authProvider
    }
    return handler.next(err);
  }

  /// ✅ Valida se response.data é válido e casteia com segurança
  Map<String, dynamic> _validateResponseData(dynamic data) {
    if (data == null) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        error: 'Response data is null',
        type: DioExceptionType.unknown,
      );
    }
    
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        error: 'Response data is not a Map: ${data.runtimeType}',
        type: DioExceptionType.unknown,
      );
    }
    
    return data;
  }

  /// ✅ Valida se response.data é uma lista
  List<dynamic> _validateResponseList(dynamic data) {
    if (data == null) return [];
    
    if (data is! List<dynamic>) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        error: 'Response data is not a List: ${data.runtimeType}',
        type: DioExceptionType.unknown,
      );
    }
    
    return data;
  }

  // ===== Auth Endpoints =====

  /// ✅ POST /auth/login - Com validação robusta
  Future<LoginResponse> login(String email, String password) async {
    try {
      // ✅ Garante que _prefs está inicializado ANTES de fazer login
      if (!_initialized) {
        _prefs = await SharedPreferences.getInstance();
      }
      
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      
      final data = _validateResponseData(response.data);
      
      // ✅ Tentar múltiplos caminhos possíveis na resposta
      final token = data['token'] ?? data['data']?['token'];
      final userData = data['user'] ?? data['data']?['user'];
      
      if (token == null || userData == null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          error: 'Missing token or user in response',
          type: DioExceptionType.unknown,
        );
      }
      
      final user = User(
        id: userData['id'] ?? '',
        email: userData['email'] ?? email,
        name: userData['name'] ?? userData['family_name'] ?? 'User',
        role: userData['role'] ?? 'family',
        empresaId: userData['empresa_id'] ?? '',
        profileImage: userData['profileImage'],
      );
      
      final loginResponse = LoginResponse(token: token, user: user);
      await _prefs.setString('auth_token', token);
      return loginResponse;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ POST /auth/register - Com validação robusta e logs detalhados
  Future<LoginResponse> register(
    String email,
    String password,
    String name, {
    String? familyName,
  }) async {
    try {
      log.i('[API] 🔍 INICIANDO REGISTRO');
      log.i('[API] 📧 Email: $email');
      log.i('[API] 👤 Nome: $name');
      
      // ✅ Garante que _prefs está inicializado ANTES de fazer register
      if (!_initialized) {
        log.i('[API] ⏳ Inicializando SharedPreferences...');
        _prefs = await SharedPreferences.getInstance();
        log.i('[API] ✅ SharedPreferences inicializado');
      }
      
      log.i('[API] 🌐 Enviando POST para /auth/register');
      log.i('[API] 📦 Payload: email=$email, name=$name, password=****');
      
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'family_name': familyName ?? name,
        },
      );
      
      log.i('[API] 📥 Resposta recebida com status: ${response.statusCode}');
      log.i('[API] 📊 Dados da resposta: ${response.data}');
      
      final data = _validateResponseData(response.data);
      log.i('[API] ✅ Dados validados');
      
      final token = data['token'] ?? data['data']?['token'];
      final userData = data['user'] ?? data['data']?['user'];
      
      log.i('[API] 🎫 Token presente: ${token != null}');
      log.i('[API] 👤 Dados do usuário presentes: ${userData != null}');
      
      if (token == null || userData == null) {
        log.e('[API] ❌ ERRO: Token ou UserData ausentes na resposta');
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          error: 'Missing token or user in response',
          type: DioExceptionType.unknown,
        );
      }
      
      final user = User(
        id: userData['id'] ?? '',
        email: userData['email'] ?? email,
        name: userData['name'] ?? userData['family_name'] ?? name,
        role: userData['role'] ?? 'family',
        empresaId: userData['empresa_id'] ?? userData['empresa_name'] ?? '',
        profileImage: userData['profileImage'],
      );
      
      log.i('[API] ✅ Usuário criado: ${user.email}');
      
      final loginResponse = LoginResponse(token: token, user: user);
      
      log.i('[API] 💾 Salvando token em SharedPreferences...');
      await _prefs.setString('auth_token', token);
      log.i('[API] ✅ Token salvo com sucesso');
      
      log.i('[API] ✅ REGISTRO CONCLUÍDO COM SUCESSO');
      return loginResponse;
    } catch (e) {
      log.e('[API] ❌ ERRO NO REGISTRO: $e');
      log.e('[API] 📍 Tipo de erro: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _prefs.remove('auth_token');
  }

  // ===== ENDPOINTS DO BACKEND =====

  /// ✅ GET /familias/me - Com validação
  Future<User> getMyProfile() async {
    try {
      final response = await _dio.get('/familias/me');
      final data = _validateResponseData(response.data);
      return User.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Método para obter token armazenado (para WebSocket)
  Future<String?> getStoredToken() async {
    await init();
    return _prefs.getString('auth_token');
  }

  /// ✅ Sanitizar string para evitar erro UTF-16
  String _sanitizeString(String? str) {
    if (str == null) return '';
    try {
      // Remove caracteres inválidos, mantém apenas ASCII + acentos comuns
      return str
          .replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u017F]'), '') // Remove caracteres fora do range
          .trim();
    } catch (e) {
      return '';
    }
  }

  /// ✅ GET /leituras/eventos/{eventoId}/historico - Histórico de conquistas
  Future<List<Map<String, dynamic>>> getScoreHistory(String eventoId) async {
    try {
      final response = await _dio.get(
        '/leituras/eventos/$eventoId/historico',
        // allGames=1: inclui leituras de Tesouro/Monstro/Zone Conquest, que não
        // gravam em `pontuacoes` — necessário pro rastreio do avatar.
        queryParameters: {'allGames': '1'},
      );
      final data = response.data;
      
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// ✅ GET /familias/children - Com validação e debug detalhado
  Future<List<Child>> getChildren() async {
    try {
      final response = await _dio.get('/familias/children');
      
      // ✅ Pode ser array direto ou objeto com 'children'
      dynamic data = response.data;
      List<dynamic> childrenList;
      
      if (data is List) {
        childrenList = data;
      } else if (data is Map && data.containsKey('children')) {
        childrenList = data['children'] as List<dynamic>;
      } else if (data is Map && data.containsKey('success')) {
        childrenList = data['children'] as List<dynamic>? ?? [];
      } else {
        throw Exception('Formato de resposta inválido');
      }
      
      // ✅ Sanitizar strings para evitar problemas UTF-16
      String? sanitizeString(String? str) {
        if (str == null) return null;
        try {
          return sanitizeUtf16(str);
        } catch (e) {
          return ''; // Fallback para string vazia
        }
      }
      
      // ✅ Mapear e sanitizar dados antes de desserializar
      final sanitizedList = childrenList.map((child) {
        if (child is! Map<String, dynamic>) return child;
        return {
          ...child,
          'name': sanitizeString(child['name'] as String?) ?? '',
          'nickname': sanitizeString(child['nickname'] as String?) ?? '',
          'teamName': sanitizeString(child['teamName'] as String?) ?? 'Sem time',
          'teamColor': sanitizeString(child['teamColor'] as String?) ?? '#cccccc',
          'profileImage': sanitizeString(child['profileImage'] as String?),
        };
      }).toList();
      
      final result = sanitizedList.map((child) => Child.fromJson(child as Map<String, dynamic>)).toList();
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ GET /familias/children/:id/scores - Com validação
  Future<Map<String, dynamic>> getChildScores(String childId) async {
    try {
      final response = await _dio.get('/familias/children/$childId/scores');
      return _validateResponseData(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ GET /familias/children/:id/achievements - Com validação
  Future<List<Achievement>> getChildAchievements(String childId) async {
    try {
      final response = await _dio.get('/familias/children/$childId/achievements');
      final data = _validateResponseData(response.data);
      final achievements = data['achievements'] as List<dynamic>?;
      if (achievements == null) return [];
      return achievements
          .map((achievement) => Achievement.fromJson(achievement as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Se endpoint não existe ou erro, retorna lista vazia
      return [];
    }
  }

  /// ✅ GET /familias/notifications - Com validação
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _dio.get('/familias/notifications');
      final data = _validateResponseData(response.data);
      final notifications = data['notifications'] as List<dynamic>?;
      if (notifications == null) return [];
      return notifications.map((notif) => notif as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// ✅ GET /ranking/criancas/:evento_id - Com validação
  Future<List<Map<String, dynamic>>> getRankingChildren(String eventoId) async {
    try {
      final response = await _dio.get('/ranking/criancas/$eventoId');
      final data = _validateResponseList(response.data);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ GET /ranking/times/:evento_id - Com validação
  Future<List<Map<String, dynamic>>> getRankingTeams(String eventoId) async {
    try {
      final response = await _dio.get('/ranking/times/$eventoId');
      final data = _validateResponseList(response.data);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ GET /familias/children - Busca filhos da família com evento_id
  Future<Map<String, dynamic>?> getActiveEvent() async {
    try {
      final response = await _dio.get('/familias/children');
      
      // Backend retorna { success: true, children: [...] }
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      
      final children = data['children'] as List?;
      if (children == null || children.isEmpty) {
        log.w('[API] ⚠️ Nenhuma criança encontrada para família');
        return null;
      }
      
      // Extrai evento_id da primeira criança
      final firstChild = children.first;
      if (firstChild is! Map<String, dynamic>) return null;
      
      final eventoId = firstChild['evento_id'] as String?;
      if (eventoId == null || eventoId.isEmpty) {
        log.w('[API] ⚠️ Criança sem evento_id');
        return null;
      }
      
      log.i('[API] ✅ evento_id extraído: $eventoId');
      return {
        'id': eventoId,
        'name': 'Evento Ativo',
        'status': 'active',
      };
    } catch (e) {
      log.w('[API] ⚠️ Erro ao buscar evento ativo: $e');
      return null;
    }
  }

  /// ✅ GET /familias/active-event - Jogo ativo (via evento ativo) 
  Future<Map<String, dynamic>?> getActiveGame() async {
    try {
      final response = await _dio.get('/familias/active-event');
      
      if (response.data == null) {
        return null;
      }
      
      final data = _validateResponseData(response.data);
      final activeGame = data['activeGame'] as Map<String, dynamic>?;
      
      return activeGame;
    } catch (e) {
      return null;
    }
  }

  /// ✅ GET /eventos/:id/floor-plan - Planta baixa do evento (imagem base64 do buffet)
  Future<String?> getFloorPlan(String eventoId) async {
    try {
      final response = await _dio.get('/eventos/$eventoId/floor-plan');
      final data = _validateResponseData(response.data);
      
      // Backend retorna { floorPlan: { dataUrl, name, type } }
      final floorPlan = data['floorPlan'] as Map<String, dynamic>?;
      if (floorPlan != null) {
        return floorPlan['dataUrl'] as String?;
      }
      
      return null;
    } catch (e) {
      // Floor plan é opcional - silent fail
      log.w('[API] ⚠️ Erro ao carregar floor plan: $e');
      return null;
    }
  }

  /// ✅ GET /brincadeiras?evento_id={id} - Brincadeiras do evento
  Future<List<Map<String, dynamic>>> getBrincadeiras(String eventoId) async {
    try {
      final response = await _dio.get('/brincadeiras', queryParameters: {'evento_id': eventoId});
      
      final data = _validateResponseList(response.data);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// ✅ GET /eventos/{eventoId}/zones - Zonas do evento
  Future<List<Map<String, dynamic>>> getZonesByEvent(String eventoId) async {
    try {
      final response = await _dio.get('/eventos/$eventoId/zones');
      
      final data = _validateResponseList(response.data);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      log.e('[API] ❌ Erro ao buscar zonas: $e');
      return [];
    }
  }

  /// ✅ GET /familias/active-event/checkpoints - Checkpoints do evento ativo
  Future<List<Map<String, dynamic>>> getActiveEventCheckpoints() async {
    try {
      final response = await _dio.get('/familias/active-event/checkpoints');
      
      final data = _validateResponseList(response.data);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// ✅ GET /checkpoints/evento/{eventoId} - Checkpoints de um evento específico (mesmo que admin usa)
  Future<List<Map<String, dynamic>>> getCheckpointsByEvent(String eventoId) async {
    try {
      log.i('[API] 🔍 Buscando checkpoints para evento: $eventoId');
      
      if (eventoId.isEmpty) {
        log.w('[API] ⚠️ eventoId está vazio!');
        return [];
      }
      
      final response = await _dio.get('/checkpoints/evento/$eventoId');
      
      log.i('[API] ✅ Checkpoints carregados com sucesso: ${response.data}');
      
      final data = _validateResponseList(response.data);
      final checkpoints = data.map((item) => item as Map<String, dynamic>).toList()
        // Filtrar checkpoints que não sejam da recepção (igual ao admin)
        .where((cp) => (cp['checkpoint_purpose'] ?? 'game').toString().toLowerCase() != 'reception')
        .map((cp) {
          // Sanitizar strings de checkpoint para evitar UTF-16 error
          return {
            ...cp,
            'name': _sanitizeString(cp['name'] as String?),
            'zone': _sanitizeString(cp['zone'] as String?),
            'location': _sanitizeString(cp['location'] as String?),
          };
        })
        .toList();
      
      log.i('[API] ✅ Checkpoints retornados: ${checkpoints.length}');
      return checkpoints;
    } catch (e) {
      log.e('[API] ❌ Erro ao buscar checkpoints para evento $eventoId: $e');
      if (e is DioException) {
        log.e('[API] 🔴 Status Code: ${e.response?.statusCode}');
        log.e('[API] 📝 Response: ${e.response?.data}');
      }
      return [];
    }
  }

  /// ✅ GET /familias/invites/{token} - Validar convite
  Future<Map<String, dynamic>> getFamilyInvite(String token) async {
    try {
      log.i('[API] 🔄 Validando convite: $token');
      final response = await _dio.get('/familias/invites/$token');
      log.i('[API] ✅ Convite validado');
      return _validateResponseData(response.data);
    } catch (e) {
      log.e('[API] ❌ Erro ao validar convite: $e');
      rethrow;
    }
  }

  /// ✅ POST /familias/invites/{token}/register - Registrar com convite
  Future<Map<String, dynamic>> registerWithInvite(
    String token,
    String email,
    String password,
    String parentName, {
    List<Map<String, dynamic>>? children,
  }) async {
    try {
      log.i('[API] 📝 REGISTRANDO COM CONVITE');
      log.i('[API] 🎫 Token: $token');
      log.i('[API] 📧 Email: $email');
      log.i('[API] 👤 Nome do Responsável: $parentName');
      
      if (!_initialized) {
        _prefs = await SharedPreferences.getInstance();
      }
      
      final requestBody = {
        'parentName': parentName,
        'email': email,
        'password': password,
        'children': ?children,
      };
      
      log.i('[API] 📦 Enviando corpo da requisição: $requestBody');
      
      final response = await _dio.post(
        '/familias/invites/$token/register',
        data: requestBody,
      );
      
      log.i('[API] ✅ Resposta recebida: ${response.statusCode}');
      log.i('[API] 📊 Dados da resposta: ${response.data}');
      
      final data = _validateResponseData(response.data);
      
      // Cenário 1: Resposta com token (registro + login automático)
      // Usado quando tem criança específica vinculada
      final tokenJwt = data['token'] ?? data['data']?['token'];
      final userData = data['user'] ?? data['data']?['user'];
      
      if (tokenJwt != null && userData != null) {
        log.i('[API] ✅ Registro com login automático (criança vinculada)');
        
        final user = User(
          id: userData['id'] ?? '',
          email: userData['email'] ?? email,
          name: userData['name'] ?? userData['family_name'] ?? parentName,
          role: userData['role'] ?? 'family',
          empresaId: userData['empresa_id'] ?? '',
          profileImage: userData['profileImage'],
        );
        
        await _prefs.setString('auth_token', tokenJwt);
        log.i('[API] ✅ Token salvo com sucesso');
        
        return {
          'success': true,
          'type': 'auto_login',
          'token': tokenJwt,
          'user': user,
          'message': 'Registrado e autenticado!',
        };
      }
      
      // Cenário 2: convite genérico e cadastro só do responsável (sem crianças): a
      // conta já nasce ativa e a criança é vinculada depois, lendo o QR Code no app
      if (data['success'] == true && data['status'] == 'active') {
        log.i('[API] ✅ Conta criada (sem crianças): vínculo depois, pelo QR Code');
        return {
          'success': true,
          'type': 'created',
          'status': 'active',
          'message': data['message'] ?? 'Conta criada!',
        };
      }

      // Cenário 3: Resposta sem token (registro pendente de aprovação)
      // Usado quando é convite genérico para múltiplas crianças
      if (data['success'] == true && data['status'] == 'pending') {
        log.i('[API] ✅ Registro em pendência de aprovação');
        log.i('[API] 📝 Mensagem: ${data['message']}');
        
        return {
          'success': true,
          'type': 'pending',
          'status': 'pending',
          'message': data['message'] ?? 'Cadastro realizado. Aguarde a aprovação da recepção.',
          'childId': data['childId'],
          'childIds': data['childIds'],
          'childrenCount': data['childrenCount'],
        };
      }
      
      // Se chegou aqui, resposta tem formato inesperado
      log.w('[API] ⚠️ Resposta em formato inesperado');
      throw Exception('Formato de resposta não reconhecido');
      
    } on DioException catch (e) {
      log.e('[API] ❌ ERRO NO REGISTRO COM CONVITE (Status ${e.response?.statusCode}): ${e.message}');
      
      // Tenta extrair mensagem de erro do backend
      String errorMessage = 'Erro ao registrar';
      try {
        if (e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          errorMessage = errorData['error'] ?? errorMessage;
          
          // Log a mensagem específica do backend
          log.e('[API] 📋 Erro do backend: $errorMessage');
          
          // Se é convite expirado ou já usado, log mais específico
          if (e.response?.statusCode == 410) {
            log.e('[API] 🔴 Status 410: ${errorData['status'] ?? 'desconhecido'}');
          }
        }
      } catch (_) {
        // Ignorar erros ao extrair mensagem
      }
      
      log.e('[API] 📍 Stack trace: ${StackTrace.current}');
      
      // Re-lançar com mensagem melhor
      throw Exception(errorMessage);
    } catch (e) {
      log.e('[API] ❌ ERRO INESPERADO NO REGISTRO COM CONVITE: $e');
      log.e('[API] 📍 Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }


  /// ✅ POST /family/qrcode/validate - Vincular criança com QR code
Future<Map<String, dynamic>> linkChildWithQRCode(String qrCodeValue) async {
  try {
    log.i('[API] 📱 Vinculando criança com QR: $qrCodeValue');
    log.i('[API] 📊 URL: /family/qrcode/validate');
    log.i('[API] 📦 Payload: {qrCodeValue: $qrCodeValue}');
    
    if (!_initialized) {
      log.i('[API] ⏳ Inicializando ApiService...');
      await init();
    }
    
    final response = await _dio.post(
      '/family/qrcode/validate',
      data: {'qrCodeValue': qrCodeValue},
    );
    
    log.i('[API] ✅ Resposta recebida com status: ${response.statusCode}');
    log.i('[API] 📊 Dados brutos: ${response.data}');
    log.i('[API] 📊 Tipo: ${response.data.runtimeType}');
    
    final data = _validateResponseData(response.data);
    
    // ✅ Validar que tem 'success' e 'linkedChild'
    if (data['success'] != true) {
      log.e('[API] ❌ Resposta não confirmou sucesso: ${data}');
      throw DioException(
        requestOptions: RequestOptions(path: '/family/qrcode/validate'),
        error: data['error'] ?? 'Resposta sem confirmação de sucesso',
        type: DioExceptionType.unknown,
      );
    }
    
    final linkedChild = data['linkedChild'];
    if (linkedChild == null) {
      log.e('[API] ❌ Falta "linkedChild" na resposta: ${data}');
      throw DioException(
        requestOptions: RequestOptions(path: '/family/qrcode/validate'),
        error: 'Dados da criança ausentes na resposta',
        type: DioExceptionType.unknown,
      );
    }
    
    log.i('[API] ✅ Criança vinculada com sucesso!');
    log.i('[API] 👶 Criança: ${linkedChild['nickname'] ?? linkedChild['name']} (ID: ${linkedChild['id']})');
    log.i('[API] 🎮 Evento: ${linkedChild['evento']}');
    
    return data;
  } on DioException catch (e) {
    log.e('[API] ❌ ERRO DIO ao vincular: ${e.message}');
    log.e('[API] 🔴 Status Code: ${e.response?.statusCode}');
    log.e('[API] 📝 Resposta do erro: ${e.response?.data}');
    log.e('[API] 📍 Stack: ${StackTrace.current}');
    
    // Re-lançar com mensagem mais amigável
    String userMessage = 'Erro ao vincular criança';
    try {
      if (e.response?.data is Map) {
        userMessage = e.response?.data['error'] ?? userMessage;
      }
    } catch (_) {}
    
    throw Exception(userMessage);
  } catch (e) {
    log.e('[API] ❌ ERRO GENÉRICO ao vincular: $e');
    log.e('[API] 📍 Tipo: ${e.runtimeType}');
    log.e('[API] 📍 Stack: ${StackTrace.current}');
    rethrow;
  }
}

  // WebSocket para atualizações em tempo real
  String getWebSocketUrl() => _baseUrl.replaceFirst('http', 'ws');
}