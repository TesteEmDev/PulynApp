import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/auth_widgets.dart';

/// Confirma o e-mail da conta: manda um código para o endereço cadastrado e pede o código de volta.
class ConfirmarEmailScreen extends ConsumerStatefulWidget {
  const ConfirmarEmailScreen({super.key});

  @override
  ConsumerState<ConfirmarEmailScreen> createState() => _ConfirmarEmailScreenState();
}

class _ConfirmarEmailScreenState extends ConsumerState<ConfirmarEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  bool _codigoEnviado = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _enviarCodigo() async {
    setState(() => _isLoading = true);
    try {
      final jaConfirmado = await ref.read(apiServiceProvider).enviarCodigoConfirmacao();
      if (!mounted) return;
      if (jaConfirmado) {
        showSuccessSnackBar(context, 'Seu e-mail já está confirmado');
        _voltar();
        return;
      }
      setState(() => _codigoEnviado = true);
      showSuccessSnackBar(context, 'Código enviado para o seu e-mail.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).confirmarEmail(_codigoController.text.trim());
      ref.invalidate(emailConfirmadoProvider);
      if (!mounted) return;
      showSuccessSnackBar(context, 'E-mail confirmado!');
      _voltar();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).valueOrNull?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar e-mail'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _voltar,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      title: 'Confirme seu e-mail',
                      subtitle: email.isEmpty
                          ? 'Enviaremos um código para o e-mail da sua conta'
                          : 'Enviaremos um código para $email',
                      fullLogo: false,
                    ),
                    const SizedBox(height: 28),
                    AuthFormCard(
                      children: [
                        if (!_codigoEnviado)
                          const Text(
                            'Confirmar o e-mail ajuda a recuperar sua conta se você esquecer a senha.',
                          )
                        else
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
                            validator: (valor) => RegExp(r'^\d{6}$').hasMatch(valor?.trim() ?? '')
                                ? null
                                : 'O código tem 6 números',
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AuthPrimaryButton(
                      label: _codigoEnviado ? 'Confirmar' : 'Enviar código',
                      icon: Icons.mark_email_read_outlined,
                      loading: _isLoading,
                      onPressed: _codigoEnviado ? _confirmar : _enviarCodigo,
                    ),
                    if (_codigoEnviado) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _enviarCodigo,
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
