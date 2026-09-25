/// 🔧 Enum de ambientes disponíveis
enum ApiEnvironment {
  local,
  render,
  production;
}

/// 🔧 Configuração centralizada da API
/// Use este arquivo para mudar o URL da API facilmente
class ApiConfig {
  /// ✅ URLs para cada ambiente
  /// NOTA: Para testes locais em device/emulador, altere 'localhost' para seu IP da máquina
  /// Exemplo: http://192.168.1.100:3001
  /// 
  /// ⚠️ IMPORTANTE PARA EMULADOR ANDROID:
  /// - localhost → 10.0.2.2 (IP especial do emulador)
  /// - Se der timeout, tente o IP local da máquina (192.168.x.x)
  static const String apiBaseUrlLocal = 'http://192.168.0.60:3001';
  static const String apiBaseUrlLocalIP = 'http://10.0.2.2:3001'; // Emulador Android
  static const String apiBaseUrlLocalLAN = 'http://192.168.0.60:3001'; // Seu IP local
  static const String apiBaseUrlRender = 'https://backendpulyn.onrender.com'; // ✅ PRODUÇÃO
  static const String apiBaseUrlProd = 'https://api.pulyn.com.br';
  
  /// Ambiente padrão (RENDER para produção)
  static ApiEnvironment currentEnvironment = ApiEnvironment.render;
  
  /// ✅ URL base da API (dinâmica baseada no ambiente)
  static String get apiBaseUrl {
    switch (currentEnvironment) {
      case ApiEnvironment.local:
        return apiBaseUrlLocal;
      case ApiEnvironment.render:
        return apiBaseUrlRender;
      case ApiEnvironment.production:
        return apiBaseUrlProd;
    }
  }
  
  /// Endpoints principais
  static String get authLogin => '$apiBaseUrl/api/auth/login';
  static String get authRegister => '$apiBaseUrl/api/auth/register';
  static String get authProfile => '$apiBaseUrl/api/auth/profile';
  
  static String get familyChildren => '$apiBaseUrl/api/familias/children';
  static String get familyQRValidate => '$apiBaseUrl/api/familias/qrcode/validate';
  
  static String get childDetail => '$apiBaseUrl/api/criancas';
  static String get childAchievements => '$apiBaseUrl/api/achievements';
  
  static String get ranking => '$apiBaseUrl/api/ranking';
  static String get notifications => '$apiBaseUrl/api/notifications';
  
  /// Timeout padrão para requisições (segundos)
  static const int requestTimeout = 30;
  
  /// Headers padrão
  static Map<String, String> getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// Método para mudar ambiente
  static void setEnvironment(ApiEnvironment environment) {
    currentEnvironment = environment;
  }
  
  /// Método auxiliar para obter URL base
  static String getApiBaseUrl() => apiBaseUrl;
}
