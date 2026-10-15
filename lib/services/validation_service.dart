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
    log.i('[VALIDATION] 👤 Validando name: $nome');

    if (nome.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'Nome é obrigatório',
      );
    }

    if (nome.length < 2) {
      return ValidationResult(
        valid: false,
        mensagem: 'Nome deve ter no mínimo 2 caracteres',
      );
    }

    if (nome.length > 100) {
      return ValidationResult(
        valid: false,
        mensagem: 'Nome não pode ter mais de 100 caracteres',
      );
    }

    // Valida se contém números
    if (RegExp(r'\d').hasMatch(nome)) {
      return ValidationResult(
        valid: false,
        mensagem: 'Nome não pode conter números',
      );
    }

    // Valida se tem pelo menos 2 palavras (nome e sobrenome)
    final parts = nome.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return ValidationResult(
        valid: false,
        mensagem: 'Por favor, insira seu nome completo (nome e sobrenome)',
      );
    }

    log.i('[VALIDATION] ✅ Nome válido');

    return ValidationResult(valid: true, mensagem: 'Nome válido');
  }

  /// Valida email
  ValidationResult validateEmail(String email) {
    log.i('[VALIDATION] 📧 Validando email: $email');

    if (email.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'Email é obrigatório',
      );
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(
        valid: false,
        mensagem: 'Email inválido',
      );
    }

    log.i('[VALIDATION] ✅ Email válido');

    return ValidationResult(valid: true, mensagem: 'Email válido');
  }

  /// Valida confirmação de senha
  ValidationResult validatePasswordMatch(String senha, String confirmPassword) {
    log.i('[VALIDATION] 🔄 Validando correspondência de senhas');

    if (confirmPassword.isEmpty) {
      return ValidationResult(
        valid: false,
        mensagem: 'Confirmação de senha é obrigatória',
      );
    }

    if (senha != confirmPassword) {
      return ValidationResult(
        valid: false,
        mensagem: 'As senhas não correspondem',
      );
    }

    log.i('[VALIDATION] ✅ Senhas correspondem');

    return ValidationResult(valid: true, mensagem: 'Senhas correspondem');
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
