import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/auth_widgets.dart';

/// Troca de senha da conta logada, em tela cheia.
class AlterarSenhaScreen extends ConsumerStatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  ConsumerState<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends ConsumerState<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _atualController = TextEditingController();
  final _novaController = TextEditingController();
  final _repetirController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Atualiza o medidor de força a cada letra digitada.
    _novaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _atualController.dispose();
    _novaController.dispose();
    _repetirController.dispose();
    super.dispose();
  }

  /// Nota de 0 a 4 pela combinação de tamanho, letras, números e símbolos.
  int get _forca {
    final senha = _novaController.text;
    if (senha.isEmpty) return 0;
    var pontos = 0;
    if (senha.length >= 6) pontos++;
    if (senha.length >= 10) pontos++;
    if (RegExp(r'[A-Za-z]').hasMatch(senha) && RegExp(r'\d').hasMatch(senha)) pontos++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(senha) || (RegExp(r'[a-z]').hasMatch(senha) && RegExp(r'[A-Z]').hasMatch(senha))) {
      pontos++;
    }
    return pontos;
  }

  (String, Color) get _rotuloForca {
    switch (_forca) {
      case 0:
      case 1:
        return ('Fraca', PulynColors.danger);
      case 2:
        return ('Razoável', PulynColors.accent);
      case 3:
        return ('Boa', PulynColors.primaryLight);
      default:
        return ('Forte', PulynColors.secondary);
    }
  }

  String? _validarNova(String? valor) {
    if ((valor ?? '').length < 6) return 'Use pelo menos 6 caracteres';
    if (valor == _atualController.text) return 'A nova senha precisa ser diferente da atual';
    return null;
  }

  String? _validarRepetir(String? valor) {
    if (valor != _novaController.text) return 'As senhas não conferem';
    return null;
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).alterarSenha(
            senhaAtual: _atualController.text,
            novaSenha: _novaController.text,
          );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Senha alterada. As outras sessões foram encerradas.');
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
    final (rotulo, corForca) = _rotuloForca;
    final progresso = _novaController.text.isEmpty ? 0.0 : (_forca / 4).clamp(0.25, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [PulynColors.primary, PulynColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: PulynColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AuthHeader(
                      title: 'Alterar senha',
                      subtitle: 'Escolha uma senha nova. Os outros aparelhos onde você entrou serão desconectados.',
                      fullLogo: false,
                    ),
                    const SizedBox(height: 24),
                    AuthFormCard(
                      children: [
                        AuthPasswordField(
                          controller: _atualController,
                          label: 'Senha atual',
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          validator: (valor) => (valor ?? '').isEmpty ? 'Informe a senha atual' : null,
                        ),
                        const SizedBox(height: 16),
                        AuthPasswordField(
                          controller: _novaController,
                          label: 'Nova senha',
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.next,
                          validator: _validarNova,
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progresso,
                            minHeight: 6,
                            backgroundColor: PulynColors.darkBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(corForca),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _novaController.text.isEmpty ? 'Força da senha' : 'Força: $rotulo',
                          style: TextStyle(color: corForca, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Letras, números e símbolos deixam a senha mais forte',
                          style: TextStyle(color: PulynColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        AuthPasswordField(
                          controller: _repetirController,
                          label: 'Repita a nova senha',
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.done,
                          validator: _validarRepetir,
                          onFieldSubmitted: (_) => _salvar(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Salvar nova senha',
                      icon: Icons.check_rounded,
                      loading: _isLoading,
                      onPressed: _salvar,
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
