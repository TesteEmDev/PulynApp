import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: PulynColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password != _confirmPasswordController.text) {
      _showError('As senhas não conferem');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Dispara register
      await ref.read(authProvider.notifier).register(email, password, name);

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Erro ao registrar';

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('already exists') || errorStr.contains('email já') || errorStr.contains('409')) {
        errorMessage = 'Este email já foi registrado';
      } else if (errorStr.contains('invalid email')) {
        errorMessage = 'Email inválido';
      } else if (errorStr.contains('password')) {
        errorMessage = 'Senha muito curta';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Erro de conexão';
      }

      _showError(errorMessage);
      setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email é obrigatório';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória';
    }
    if (value.length < 6) {
      return 'Senha deve ter no mínimo 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme a senha';
    }
    if (value != _passwordController.text) {
      return 'As senhas não conferem';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nome é obrigatório';
    }
    if (value.length < 2) {
      return 'Nome deve ter no mínimo 2 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Criar conta',
                      subtitle: 'Cadastre-se para acompanhar seus filhos nas festas',
                      fullLogo: false,
                    ),
                    const SizedBox(height: 28),
                    AuthFormCard(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isLoading,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Nome completo',
                            hintText: 'João Silva',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'seu@email.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        AuthPasswordField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          helperText: 'Mínimo de 6 caracteres',
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 14),
                        AuthPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar senha',
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          validator: _validateConfirmPassword,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Criar conta',
                      icon: Icons.arrow_forward_rounded,
                      loading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => context.go('/login'),
                        child: const Text('Já tenho conta'),
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : () => context.go('/invite'),
                        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                        label: const Text('Tenho um código de convite'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
