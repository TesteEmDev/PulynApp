import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/logger.dart';
import '../../widgets/auth_widgets.dart';

/// Cadastro da família a partir de um convite (a tela que abre depois de
/// colar o link/código na tela de convite).
class FamilyInviteScreen extends ConsumerStatefulWidget {
  final String token;

  const FamilyInviteScreen({
    required this.token,
    super.key,
  });

  @override
  ConsumerState<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _FamilyInviteScreenState extends ConsumerState<FamilyInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true; // validando o convite
  bool _isSubmitting = false; // enviando o cadastro
  String? _errorMessage;
  // Cadastro concluído: null enquanto preenche. "pending" = precisa da aprovação da
  // recepção (convite vinculado a uma criança); "created" = conta já ativa, a criança
  // é vinculada depois pelo QR Code.
  String? _outcome;
  String? _outcomeMessage;
  Map<String, dynamic>? _inviteData;
  bool _hasLinkedChild = false;

  @override
  void initState() {
    super.initState();
    _validateInvite();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _validateInvite() async {
    try {
      log.i('[INVITE] 🔍 Validando convite: ${widget.token}');
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();

      final invite = await apiService.getFamilyInvite(widget.token);

      if (!mounted) return;

      log.i('[INVITE] ✅ Convite válido');

      // Verifica se o convite tem uma criança específica vinculada
      final linkedChild = invite['child'] as Map<String, dynamic>?;
      final hasLinkedChild = linkedChild != null;

      setState(() {
        _inviteData = invite;
        _isLoading = false;
        _hasLinkedChild = hasLinkedChild;

        // Se já tem email no convite, preenche
        if (invite['email'] != null) {
          _emailController.text = invite['email'];
        }

        // Se tem criança vinculada, não precisa de formulário de crianças
        if (hasLinkedChild) {
          log.i('[INVITE] ✅ Criança vinculada: ${linkedChild['name']}');
        }
      });
    } catch (e) {
      log.e('[INVITE] ❌ Erro ao validar convite: $e');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Convite inválido ou expirado';
      });
    }
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

  void _handleRegister() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 🔽 Fecha o teclado
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password != _confirmPasswordController.text) {
      _showError('As senhas não conferem');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      log.i('[INVITE] 📝 Registrando com convite...');

      final apiService = ref.read(apiServiceProvider);
      await apiService.init();

      final result = await apiService.registerWithInvite(
        widget.token,
        email,
        password,
        name,
      );

      if (!mounted) return;

      // Verifica o tipo de resultado
      final resultType = result['type'] as String?;

      if (resultType == 'auto_login') {
        // Cenário 1: Tem criança específica - login automático
        log.i('[INVITE] ✅ Login automático após registro');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cadastro feito! Entrando...'),
            backgroundColor: PulynColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) context.go('/home');
        });
      } else if (resultType == 'created') {
        // Cenário 2: só o responsável foi cadastrado; a conta já está ativa
        log.i('[INVITE] ✅ Conta criada; a criança será vinculada por QR Code');

        setState(() {
          _outcome = 'created';
          _outcomeMessage = result['message'] as String? ?? 'Conta criada!';
        });
      } else if (resultType == 'pending') {
        // Cenário 3: convite vinculado a uma criança - pendente de aprovação
        log.i('[INVITE] ⏳ Registro pendente de aprovação');

        setState(() {
          _outcome = 'pending';
          _outcomeMessage = result['message'] as String? ?? 'Cadastro realizado!';
        });
      } else {
        // Resposta inesperada: não deixa o botão travado
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      log.e('[INVITE] ❌ Erro ao registrar: $e');

      if (!mounted) return;

      String errorMessage = 'Erro ao registrar';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('already exists') || errorStr.contains('email já') || errorStr.contains('409')) {
        errorMessage = 'Email já registrado';
      } else if (errorStr.contains('convite expirado')) {
        errorMessage = 'Convite expirado. Solicite um novo convite.';
      } else if (errorStr.contains('convite já utilizado')) {
        errorMessage = 'Este convite já foi utilizado.';
      } else if (errorStr.contains('invalid')) {
        errorMessage = 'Dados inválidos';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Erro de conexão';
      } else if (errorStr.contains('410')) {
        errorMessage = 'Convite inválido ou expirado';
      }

      _showError(errorMessage);
      setState(() => _isSubmitting = false);
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

  /// "2026-10-05" / "2026-10-05T00:00:00Z" -> "05/10/2026" (sem converter fuso, para
  /// não recuar um dia). Se não for uma data reconhecível, mostra como veio.
  String _formatEventDate(dynamic raw) {
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  /// Moldura comum das telas: rolagem, largura máxima e seta de voltar.
  Widget _frame({required Widget child, bool showBack = true}) {
    return Scaffold(
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back),
                // Volta para a tela do código (e não para o login)
                onPressed: () => context.go('/invite'),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthHeader(title: '', fullLogo: false),
              SizedBox(height: 8),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validando convite...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) return _buildInvalidInvite();
    if (_outcome != null) return _buildSuccess();

    final event = _inviteData?['event'] as Map<String, dynamic>? ?? {};
    final eventName = '${event['name'] ?? 'Evento'}';
    final eventDate = _formatEventDate(event['date']);
    final linkedChild = _inviteData?['child'] as Map<String, dynamic>?;

    return _frame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Cadastro da família',
              subtitle: 'Crie sua conta para acompanhar seu filho durante a festa',
              fullLogo: false,
            ),
            const SizedBox(height: 24),

            // Evento do convite
            AuthInfoCard(
              icon: Icons.celebration_rounded,
              title: eventName,
              message: eventDate.isNotEmpty ? 'Data: $eventDate' : 'Convite para o evento',
              accent: PulynColors.accent,
            ),
            const SizedBox(height: 24),

            // Seus dados
            const AuthSectionTitle(icon: Icons.person_outline_rounded, title: 'Seus dados'),
            const SizedBox(height: 12),
            AuthFormCard(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
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
                  enabled: !_isSubmitting,
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
                  enabled: !_isSubmitting,
                  helperText: 'Mínimo de 6 caracteres',
                  validator: _validatePassword,
                ),
                const SizedBox(height: 14),
                AuthPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar senha',
                  enabled: !_isSubmitting,
                  validator: _validateConfirmPassword,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Criança já vinculada pelo convite, ou aviso de que o vínculo é feito depois
            if (_hasLinkedChild && linkedChild != null)
              AuthInfoCard(
                icon: Icons.child_care_rounded,
                title: '${linkedChild['name'] ?? 'Sem nome'}',
                message: 'Criança já vinculada ao seu convite',
                accent: PulynColors.success,
              )
            else
              const AuthInfoCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Seu filho é vinculado depois',
                message: 'Depois de entrar, escaneie o QR Code que a recepção entregar para acompanhar seu filho.',
              ),
            const SizedBox(height: 24),

            AuthPrimaryButton(
              label: 'Criar cadastro',
              icon: Icons.arrow_forward_rounded,
              loading: _isSubmitting,
              onPressed: _handleRegister,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : () => context.go('/login'),
                child: const Text('Já tenho conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convite inválido/expirado.
  Widget _buildInvalidInvite() {
    return _frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: PulynColors.danger.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off_rounded, size: 40, color: PulynColors.danger),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Confira se o código foi colado por inteiro ou peça um novo convite para a recepção do buffet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 32),
          AuthPrimaryButton(
            label: 'Digitar outro código',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go('/invite'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Já tenho conta'),
            ),
          ),
        ],
      ),
    );
  }

  /// Cadastro concluído. Dois casos: conta criada (vincular o filho pelo QR Code) ou
  /// aguardando a aprovação da recepção (convite já vinculado a uma criança).
  Widget _buildSuccess() {
    final created = _outcome == 'created';
    final steps = created
        ? const [
            'Entre no app com o email e a senha que você acabou de criar',
            'Peça à recepção o QR Code do seu filho',
            'Escaneie o QR Code no app para acompanhar a festa',
          ]
        : const [
            'A recepção do buffet vai revisar sua solicitação',
            'Você recebe uma notificação quando for aprovado',
            'Depois é só entrar aqui no app com seu email e senha',
          ];

    return _frame(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: PulynColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 44, color: PulynColors.success),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            created ? 'Conta criada!' : 'Cadastro realizado!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            _outcomeMessage ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 24),
          AuthFormCard(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                AuthStep(number: i + 1, text: steps[i]),
              ],
            ],
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: created ? 'Entrar' : 'Ir para o login',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
