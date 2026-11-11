import 'package:flutter/material.dart';
import '../../utils/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import 'conta_acoes.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = ref.watch(authProvider);
    authState.whenData((user) {
      if (user != null) {
        _nameController.text = user.nome;
        _emailController.text = user.email;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveChanges() async {
    final nome = _nameController.text.trim();
    final email = _emailController.text.trim();
    final emailAtual = ref.read(authProvider).valueOrNull?.email ?? '';

    // Trocar o e-mail (que é o login) exige o e-mail atual confirmado e a senha atual.
    String? senhaAtual;
    if (email.toLowerCase() != emailAtual.toLowerCase()) {
      final confirmado = ref.read(emailConfirmadoProvider).valueOrNull;
      if (confirmado == false) {
        await _avisarConfirmarEmail();
        return;
      }
      senhaAtual = await _pedirSenha(
        titulo: 'Confirme sua senha',
        mensagem: 'Para trocar o e-mail, informe a senha atual.',
      );
      if (senhaAtual == null) return;
    }

    try {
      await ref.read(apiServiceProvider).atualizarPerfil(nome: nome, email: email, senhaAtual: senhaAtual);
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Perfil atualizado com sucesso!');
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Aviso quando a pessoa tenta trocar o e-mail sem ter confirmado o atual.
  Future<void> _avisarConfirmarEmail() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PulynColors.darkCard,
        title: const Text('Confirme seu e-mail'),
        content: const Text(
          'Para poder alterar o e-mail da conta, primeiro confirme o e-mail atual. Enviamos um código para ele.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Agora não')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar agora')),
        ],
      ),
    );
    if (confirmar == true && mounted) context.push('/confirmar-email');
  }

  /// Pede a senha atual numa caixa de diálogo. Devolve null se cancelar ou deixar em branco.
  Future<String?> _pedirSenha({
    required String titulo,
    required String mensagem,
    String confirmar = 'Confirmar',
  }) => pedirSenhaAtual(context, titulo: titulo, mensagem: mensagem, confirmar: confirmar);

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PulynColors.darkCard,
        title: const Text('Fazer Logout?'),
        content: const Text('Tem certeza que deseja sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar perfil',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Usuário não autenticado'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header
                _buildProfileHeader(user),
                const SizedBox(height: 32),

                // Edit Mode Fields
                if (_isEditing) ...[
                  _buildEditSection(),
                  const SizedBox(height: 24),
                ] else
                  // View Mode
                  ...[
                    _buildInfoSection(user),
                    const SizedBox(height: 32),
                  ],

                // Settings Section
                _buildSettingsSection(),
                const SizedBox(height: 24),

                // Logout Button
                if (!_isEditing)
                  ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Fazer Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                else
                  // Save/Cancel Buttons
                  ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isEditing = false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleSaveChanges(),
                            child: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: PulynColors.primary,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          user.nome,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: PulynColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Email
        Text(
          user.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PulynColors.textMuted,
          ),
        ),
        // Role badge
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: PulynColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            user.perfil.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PulynColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações Pessoais',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        // Name Info
        _buildInfoCard(
          icon: Icons.person_outline,
          label: 'Nome Completo',
          value: user.nome,
        ),
        const SizedBox(height: 12),
        // Email Info
        _buildInfoCard(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email,
        ),
        const SizedBox(height: 12),
        // Role Info
        _buildInfoCard(
          icon: Icons.security_outlined,
          label: 'Tipo de Conta',
          value: user.perfil.toUpperCase(),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: PulynColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: PulynColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Editar Perfil',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        // Name Field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nome Completo',
            hintText: 'Seu nome',
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: PulynColors.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulynColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulynColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: PulynColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Email Field (read-only)
        TextFormField(
          controller: _emailController,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'seu@email.com',
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: PulynColors.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulynColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulynColors.darkBorder),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulynColors.darkBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Email não pode ser alterado',
          style: TextStyle(
            fontSize: 12,
            color: PulynColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferências',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        _buildSettingOption(
          icon: Icons.brightness_4_outlined,
          label: 'Tema Escuro',
          subtitle: 'Sempre ativado',
          enabled: true,
          onChanged: (value) {
            // TODO: Implementar
          },
          disabled: true,
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.info_outlined,
          label: 'Sobre',
          subtitle: 'Versão 1.0.1',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Pulyn Family',
              applicationVersion: '1.0.1',
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.mark_email_read_outlined,
          label: 'Confirmar e-mail',
          subtitle: 'Confirma o endereço da sua conta',
          onTap: () => context.push('/confirmar-email'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.lock_outline,
          label: 'Alterar senha',
          subtitle: 'Troca a senha e encerra as outras sessões',
          onTap: () => context.push('/alterar-senha'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.delete_outline,
          label: 'Excluir conta',
          subtitle: 'Apaga sua conta e seus dados pessoais',
          onTap: () => excluirConta(context, ref),
        ),
      ],
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool enabled,
    required Function(bool) onChanged,
    bool disabled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: PulynColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: disabled ? null : onChanged,
            activeThumbColor: PulynColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PulynColors.darkBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: PulynColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PulynColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: PulynColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: PulynColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: PulynColors.danger,
          ),
          const SizedBox(height: 16),
          const Text('Erro ao carregar perfil'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(authProvider);
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }
}
