import 'package:dio/dio.dart';
import '../utils/logger.dart';
import '../utils/validadores.dart';
import 'api_service.dart';

class ValidationService {
  final ApiService _apiService;

  ValidationService(this._apiService);

  /// Valida se o email já existe no sistema
  Future<bool> isEmailAvailable(String email) async {
    try {
      log.i('[VALIDATION] 🔍 Verificando disponibilidade do email: $email');

      final response = await _apiService.dio.get(
        '/auth/check-email',
        queryParameters: {'email': email.toLowerCase().trim()},
      );

      final data = response.data;
      final available = data['available'] ?? false;

      if (available) {
        log.i('[VALIDATION] ✅ Email disponível: $email');
      } else {
        log.w('[VALIDATION] ⚠️ Email já registrado: $email');
      }

      return available;
    } on DioException catch (e) {
      // Se o endpoint não existir, assume que o backend fará a validação
      if (e.response?.statusCode == 404) {
        log.i('[VALIDATION] ℹ️ Endpoint /auth/check-email não disponível, validação no servidor');
        return true;
      }
      log.e('[VALIDATION] ❌ Erro ao verificar email: $e');
      rethrow;
    }
  }

  /// Já existe conta com este e-mail? `null` quando não deu para saber (servidor sem esse recurso ou com falha):
  /// quem chama segue em frente e deixa o servidor decidir. Falta de rede é relançada, para a tela avisar.
  Future<bool?> contaExiste(String email) async {
    try {
      final response = await _apiService.dio.get(
        '/auth/check-email',
        queryParameters: {'email': email.toLowerCase().trim()},
      );
      final data = response.data;
      if (data is Map && data['available'] is bool) return !(data['available'] as bool);
      return null;
    } on DioException catch (e) {
      final semRede = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (semRede) rethrow;
      log.w('[VALIDATION] ℹ️ Não foi possível conferir a conta (${e.response?.statusCode}); o servidor decide no login');
      return null;
    }
  }

  /// Valida força da senha
  ValidationResult validatePassword(String senha) {
    log.i('[VALIDATION] 🔐 Validando força da senha');

    if (senha.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'Senha é obrigatória',
        strength: PasswordStrength.empty,
      );
    }

    if (senha.length < 6) {
      return ValidationResult(
        valid: false,
        mensagem: 'Senha deve ter no mínimo 6 caracteres',
        strength: PasswordStrength.weak,
      );
    }

    bool hasUppercase = senha.contains(RegExp(r'[A-Z]'));
    bool hasNumbers = senha.contains(RegExp(r'\d'));
    bool hasSpecialChar = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int strength = 0;
    if (senha.length >= 8) strength++;
    if (hasUppercase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialChar) strength++;

    late PasswordStrength passwordStrength;
    late String mensagem;

    if (strength >= 3) {
      passwordStrength = PasswordStrength.strong;
      mensagem = '✅ Senha forte!';
    } else if (strength >= 1) {
      passwordStrength = PasswordStrength.medium;
      mensagem = '⚠️ Senha moderada - considere adicionar maiúsculas e números';
    } else {
      passwordStrength = PasswordStrength.weak;
      mensagem = '❌ Senha fraca - adicione maiúsculas, números ou caracteres especiais';
    }

    log.i('[VALIDATION] 🔐 Força da senha: $passwordStrength');

    return ValidationResult(
      valid: true,
      mensagem: mensagem,
      strength: passwordStrength,
    );
  }

  /// Valida nome completo
  ValidationResult validateName(String nome) {
    final erro = validarNome(nome);
    return ValidationResult(valid: erro == null, mensagem: erro ?? 'Nome válido');
  }

  /// Valida email
  ValidationResult validateEmail(String email) {
    final erro = validarEmail(email);
    return ValidationResult(valid: erro == null, mensagem: erro ?? 'Email válido');
  }

  /// Valida confirmação de senha
  ValidationResult validatePasswordMatch(String senha, String confirmPassword) {
    final erro = validarConfirmacaoSenha(confirmPassword, senha);
    return ValidationResult(valid: erro == null, mensagem: erro ?? 'Senhas correspondem');
  }

  /// Valida CPF (opcional, se necessário)
  ValidationResult validateCPF(String cpf) {
    log.i('[VALIDATION] 🆔 Validando CPF: $cpf');

    String cleanCPF = cpf.replaceAll(RegExp(r'\D'), '');

    if (cleanCPF.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'CPF é obrigatório',
      );
    }

    if (cleanCPF.length != 11) {
      return ValidationResult(
        valid: false,
        mensagem: 'CPF deve ter 11 dígitos',
      );
    }

    // Valida se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cleanCPF)) {
      return ValidationResult(
        valid: false,
        mensagem: 'CPF inválido',
      );
    }

    // Calcula primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cleanCPF[i]) * (10 - i);
    }
    int firstDigit = (sum % 11) < 2 ? 0 : 11 - (sum % 11);

    // Calcula segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cleanCPF[i]) * (11 - i);
    }
    int secondDigit = (sum % 11) < 2 ? 0 : 11 - (sum % 11);

    if (int.parse(cleanCPF[9]) != firstDigit ||
        int.parse(cleanCPF[10]) != secondDigit) {
      return ValidationResult(
        valid: false,
        mensagem: 'CPF inválido',
      );
    }

    log.i('[VALIDATION] ✅ CPF válido');

    return ValidationResult(valid: true, mensagem: 'CPF válido');
  }

  /// Valida telefone
  ValidationResult validatePhone(String telefone) {
    log.i('[VALIDATION] 📱 Validando telefone: $telefone');

    String cleanPhone = telefone.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'Telefone é obrigatório',
      );
    }

    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return ValidationResult(
        valid: false,
        mensagem: 'Telefone deve ter 10 ou 11 dígitos',
      );
    }

    log.i('[VALIDATION] ✅ Telefone válido');

    return ValidationResult(valid: true, mensagem: 'Telefone válido');
  }
}

class ValidationResult {
  final bool valid;
  final String mensagem;
  final PasswordStrength? strength;

  ValidationResult({
    required this.valid,
    required this.mensagem,
    this.strength,
  });

  @override
  String toString() => 'ValidationResult(valid: $valid, mensagem: $mensagem)';
}

enum PasswordStrength {
  empty,
  weak,
  medium,
  strong,
}

extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return 'Vazia';
      case PasswordStrength.weak:
        return 'Fraca';
      case PasswordStrength.medium:
        return 'Moderada';
      case PasswordStrength.strong:
        return 'Forte';
    }
  }

  String get emoji {
    switch (this) {
      case PasswordStrength.empty:
        return '⭕';
      case PasswordStrength.weak:
        return '🔴';
      case PasswordStrength.medium:
        return '🟡';
      case PasswordStrength.strong:
        return '🟢';
    }
  }
}
