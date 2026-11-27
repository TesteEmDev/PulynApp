import 'package:flutter/material.dart';
import '../../utils/validadores.dart';
import '../../utils/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/validation_service.dart';
import '../../utils/logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Texto do alerta para uma falha ao entrar. As mensagens do servidor ("Email ou senha incorretos", etc.)
  /// já vêm prontas na exceção; erros de rede ganham um texto próprio.
  String _mensagemDoErro(Object erro) {
    if (erro is DioException) {
      final semRede = erro.type == DioExceptionType.connectionError ||
          erro.type == DioExceptionType.connectionTimeout ||
          erro.type == DioExceptionType.sendTimeout ||
          erro.type == DioExceptionType.receiveTimeout;
      return semRede ? 'Sem conexão com o servidor. Verifique sua internet.' : 'Não foi possível entrar. Tente de novo.';
    }
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Não foi possível entrar. Tente de novo.' : texto;
  }

  Future<void> _handleLogin() async {
    // O botão continua com a aparência normal enquanto carrega; toques repetidos são ignorados
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final senha = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      log.i('[LOGIN] 🔐 Tentando fazer login com email: $email');

      // Varredura antes de entrar: a conta existe? Sem conta, avisa na hora em vez de deixar a pessoa
      // esperando uma resposta de "senha incorreta" para um e-mail que nunca foi cadastrado.
      final api = ref.read(apiServiceProvider);
      await api.init();
      final contaExiste = await ValidationService(api).contaExiste(email);
      if (!mounted) return;
      if (contaExiste == false) {
        showErrorSnackBar(context, '❌ Não existe conta com este e-mail. Confira o endereço ou crie uma conta.');
        setState(() => _isLoading = false);
        return;
      }

      await ref.read(authProvider.notifier).login(email, senha);

      // Deu certo: a sessão mudou e o roteador leva para a home (esta tela sai). Não precisa soltar o botão.
      log.i('[LOGIN] ✅ Login realizado com sucesso');
    } on EmailNaoConfirmadoException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ref.read(cadastroPendenteProvider.notifier).state = e.email;
    } catch (e) {
      log.e('[LOGIN] ❌ Erro ao fazer login: $e');
      if (!mounted) return;
      showErrorSnackBar(context, '❌ ${_mensagemDoErro(e)}');
      setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) => validarEmail(value);

  String? _validatePassword(String? value) => validarSenha(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo-pulyn.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Bem-vindo de volta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),

                const SizedBox(height: 8),

                Text(
                  'Acesse sua conta para acompanhar seus filhos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'seu@email.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: _validatePassword,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: _handleLogin,
                  child: _isLoading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Entrando...'),
                          ],
                        )
                      : const Text('Fazer Login'),
                ),

                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => context.push('/esqueci-senha'),
                    child: const Text('Esqueci minha senha'),
                  ),
                ),

                // Register Link
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => context.push('/register'),
                    child: const Text('Não tem uma conta? Registre-se'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
