import 'package:dio/dio.dart';
import '../utils/logger.dart';
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

  /// Valida força da senha
  ValidationResult validatePassword(String password) {
    log.i('[VALIDATION] 🔐 Validando força da senha');

    if (password.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'Senha é obrigatória',
        strength: PasswordStrength.empty,
      );
    }

    if (password.length < 6) {
      return ValidationResult(
        valid: false,
        message: 'Senha deve ter no mínimo 6 caracteres',
        strength: PasswordStrength.weak,
      );
    }

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasNumbers = password.contains(RegExp(r'\d'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int strength = 0;
    if (password.length >= 8) strength++;
    if (hasUppercase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialChar) strength++;

    late PasswordStrength passwordStrength;
    late String message;

    if (strength >= 3) {
      passwordStrength = PasswordStrength.strong;
      message = '✅ Senha forte!';
    } else if (strength >= 1) {
      passwordStrength = PasswordStrength.medium;
      message = '⚠️ Senha moderada - considere adicionar maiúsculas e números';
    } else {
      passwordStrength = PasswordStrength.weak;
      message = '❌ Senha fraca - adicione maiúsculas, números ou caracteres especiais';
    }

    log.i('[VALIDATION] 🔐 Força da senha: $passwordStrength');

    return ValidationResult(
      valid: true,
      message: message,
      strength: passwordStrength,
    );
  }

  /// Valida nome completo
  ValidationResult validateName(String name) {
    log.i('[VALIDATION] 👤 Validando nome: $name');

    if (name.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'Nome é obrigatório',
      );
    }

    if (name.length < 2) {
      return ValidationResult(
        valid: false,
        message: 'Nome deve ter no mínimo 2 caracteres',
      );
    }

    if (name.length > 100) {
      return ValidationResult(
        valid: false,
        message: 'Nome não pode ter mais de 100 caracteres',
      );
    }

    // Valida se contém números
    if (RegExp(r'\d').hasMatch(name)) {
      return ValidationResult(
        valid: false,
        message: 'Nome não pode conter números',
      );
    }

    // Valida se tem pelo menos 2 palavras (nome e sobrenome)
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return ValidationResult(
        valid: false,
        message: 'Por favor, insira seu nome completo (nome e sobrenome)',
      );
    }

    log.i('[VALIDATION] ✅ Nome válido');

    return ValidationResult(valid: true, message: 'Nome válido');
  }

  /// Valida email
  ValidationResult validateEmail(String email) {
    log.i('[VALIDATION] 📧 Validando email: $email');

    if (email.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'Email é obrigatório',
      );
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(
        valid: false,
        message: 'Email inválido',
      );
    }

    log.i('[VALIDATION] ✅ Email válido');

    return ValidationResult(valid: true, message: 'Email válido');
  }

  /// Valida confirmação de senha
  ValidationResult validatePasswordMatch(String password, String confirmPassword) {
    log.i('[VALIDATION] 🔄 Validando correspondência de senhas');

    if (confirmPassword.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'Confirmação de senha é obrigatória',
      );
    }

    if (password != confirmPassword) {
      return ValidationResult(
        valid: false,
        message: 'As senhas não correspondem',
      );
    }

    log.i('[VALIDATION] ✅ Senhas correspondem');

    return ValidationResult(valid: true, message: 'Senhas correspondem');
  }

  /// Valida CPF (opcional, se necessário)
  ValidationResult validateCPF(String cpf) {
    log.i('[VALIDATION] 🆔 Validando CPF: $cpf');

    String cleanCPF = cpf.replaceAll(RegExp(r'\D'), '');

    if (cleanCPF.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'CPF é obrigatório',
      );
    }

    if (cleanCPF.length != 11) {
      return ValidationResult(
        valid: false,
        message: 'CPF deve ter 11 dígitos',
      );
    }

    // Valida se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cleanCPF)) {
      return ValidationResult(
        valid: false,
        message: 'CPF inválido',
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
        message: 'CPF inválido',
      );
    }

    log.i('[VALIDATION] ✅ CPF válido');

    return ValidationResult(valid: true, message: 'CPF válido');
  }

  /// Valida telefone
  ValidationResult validatePhone(String phone) {
    log.i('[VALIDATION] 📱 Validando telefone: $phone');

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.isEmpty) {
      return ValidationResult(
        valid: false,
        message: 'Telefone é obrigatório',
      );
    }

    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return ValidationResult(
        valid: false,
        message: 'Telefone deve ter 10 ou 11 dígitos',
      );
    }

    log.i('[VALIDATION] ✅ Telefone válido');

    return ValidationResult(valid: true, message: 'Telefone válido');
  }
}

class ValidationResult {
  final bool valid;
  final String message;
  final PasswordStrength? strength;

  ValidationResult({
    required this.valid,
    required this.message,
    this.strength,
  });

  @override
  String toString() => 'ValidationResult(valid: $valid, message: $message)';
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
