import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/auth_widgets.dart';

/// Recuperação de senha em duas etapas: 1) o e-mail recebe um código; 2) o código e a senha nova redefinem a senha.
class EsqueciSenhaScreen extends ConsumerStatefulWidget {
  const EsqueciSenhaScreen({super.key});

  @override
  ConsumerState<EsqueciSenhaScreen> createState() => _EsqueciSenhaScreenState();
}

class _EsqueciSenhaScreenState extends ConsumerState<EsqueciSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _codigoEnviado = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe o e-mail';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(texto)) return 'E-mail inválido';
    return null;
  }

  String? _validarCodigo(String? valor) {
    if (!RegExp(r'^\d{6}$').hasMatch(valor?.trim() ?? '')) return 'O código tem 6 números';
    return null;
  }

  String? _validarNovaSenha(String? valor) {
    if ((valor ?? '').length < 6) return 'A senha precisa ter pelo menos 6 caracteres';
    return null;
  }

  String? _validarConfirmacao(String? valor) {
    if (valor != _novaSenhaController.text) return 'As senhas não conferem';
    return null;
  }

  Future<void> _pedirCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).pedirCodigoSenha(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      showSuccessSnackBar(context, 'Se o e-mail estiver cadastrado, enviamos um código.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).redefinirSenha(
            email: _emailController.text.trim(),
            codigo: _codigoController.text.trim(),
            novaSenha: _novaSenhaController.text,
          );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Senha redefinida. Entre com a nova senha.');
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    AuthHeader(
                      title: 'Esqueci minha senha',
                      subtitle: _codigoEnviado
                          ? 'Digite o código que chegou no seu e-mail e escolha a nova senha'
                          : 'Informe seu e-mail e enviaremos um código para redefinir a senha',
                      fullLogo: false,
                    ),
                    const SizedBox(height: 28),
                    AuthFormCard(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isLoading && !_codigoEnviado,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _validarEmail,
                        ),
                        if (_codigoEnviado) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codigoController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Código de 6 números',
                              prefixIcon: Icon(Icons.pin_outlined),
                              counterText: '',
                            ),
                            validator: _validarCodigo,
                          ),
                          const SizedBox(height: 8),
                          AuthPasswordField(
                            controller: _novaSenhaController,
                            label: 'Nova senha',
                            enabled: !_isLoading,
                            validator: _validarNovaSenha,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          AuthPasswordField(
                            controller: _confirmarController,
                            label: 'Repita a nova senha',
                            enabled: !_isLoading,
                            validator: _validarConfirmacao,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _redefinir(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    AuthPrimaryButton(
                      label: _codigoEnviado ? 'Redefinir senha' : 'Enviar código',
                      icon: Icons.arrow_forward_rounded,
                      loading: _isLoading,
                      onPressed: _codigoEnviado ? _redefinir : _pedirCodigo,
                    ),
                    if (_codigoEnviado) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _pedirCodigo,
                          child: const Text('Não recebi o código; enviar de novo'),
                        ),
                      ),
                    ],
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
