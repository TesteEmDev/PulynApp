import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/auth_widgets.dart';

/// Último passo do cadastro: a conta só entra depois que o e-mail é confirmado com o código enviado.
class ConfirmarCadastroScreen extends ConsumerStatefulWidget {
  final String email;

  /// Código que veio no link do e-mail (já vem preenchido).
  final String? codigoInicial;

  const ConfirmarCadastroScreen({required this.email, this.codigoInicial, super.key});

  @override
  ConsumerState<ConfirmarCadastroScreen> createState() => _ConfirmarCadastroScreenState();
}

class _ConfirmarCadastroScreenState extends ConsumerState<ConfirmarCadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.codigoInicial != null) _codigoController.text = widget.codigoInicial!;
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _ativar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final resposta = await ref.read(apiServiceProvider).confirmarCadastro(
            widget.email,
            _codigoController.text.trim(),
          );
      // Entra com a sessão recebida; o roteador leva para a tela inicial.
      await ref.read(authProvider.notifier).finalizarCadastro(resposta);
      ref.invalidate(emailConfirmadoProvider);
      ref.read(cadastroPendenteProvider.notifier).state = null;
      if (!mounted) return;
      showSuccessSnackBar(context, 'Conta ativada. Bem-vindo ao Pulyn!');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).reenviarCadastro(widget.email);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Se a conta estiver pendente, enviamos um novo código.');
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
          onPressed: _isLoading
              ? null
              : () {
                  ref.read(cadastroPendenteProvider.notifier).state = null;
                  context.go('/login');
                },
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
                      title: 'Confirme seu e-mail',
                      subtitle: 'Enviamos um código de 6 números para ${widget.email}. Digite-o para ativar sua conta.',
                      fullLogo: false,
                    ),
                    const SizedBox(height: 28),
                    AuthFormCard(
                      children: [
                        TextFormField(
                          controller: _codigoController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          onFieldSubmitted: (_) => _ativar(),
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
                      label: 'Ativar conta',
                      icon: Icons.check_rounded,
                      loading: _isLoading,
                      onPressed: _ativar,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _reenviar,
                        child: const Text('Não recebi o código; enviar de novo'),
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
