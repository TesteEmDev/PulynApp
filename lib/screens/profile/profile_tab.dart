import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/family_models.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/pulyn_logo.dart';

const _appVersion = '1.0.0';

/// Aba "Perfil" do menu de baixo: quem está logado, resumo das crianças, atalhos
/// e sair da conta. Só mostra o que funciona (nada de interruptores que não fazem nada).
///
/// É um widget "puro": os dados e as ações chegam por parâmetro (a HomeScreen liga aos
/// providers), o que deixa a tela simples de testar.
class ProfileTab extends StatelessWidget {
  /// Usuário logado.
  final AsyncValue<User?> auth;

  /// Se o e-mail da conta já foi confirmado (null enquanto não se sabe).
  final AsyncValue<bool>? emailConfirmado;

  /// Crianças vinculadas (o `.value` mantém a lista anterior enquanto recarrega, então
  /// a tela não pisca a cada leitura de checkpoint).
  final AsyncValue<List<Child>> children;

  /// Sair da conta (chamado só depois da confirmação).
  final VoidCallback onLogout;

  /// Tentar carregar o perfil de novo depois de um erro.
  final VoidCallback? onRetry;

  /// Exclui a conta depois de confirmar (e pedir a senha).
  final VoidCallback? onExcluirConta;

  const ProfileTab({
    required this.auth,
    required this.children,
    this.emailConfirmado,
    required this.onLogout,
    this.onRetry,
    this.onExcluirConta,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        elevation: 0,
        actions: const [PulynAppBarLogo()],
      ),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: PulynColors.danger),
                const SizedBox(height: 12),
                const Text('Não foi possível carregar seu perfil'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Você não está conectado'));
          }
          return _buildContent(context, user);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, User user) {
    final list = children.value ?? const <Child>[];
    final loadingFirstTime = children.isLoading && children.value == null;
    final totalPoints = list.fold<int>(0, (sum, c) => sum + c.currentScore);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.child_care_rounded,
                      value: loadingFirstTime ? '–' : '${list.length}',
                      label: list.length == 1 ? 'Criança vinculada' : 'Crianças vinculadas',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.emoji_events_rounded,
                      value: loadingFirstTime ? '–' : '$totalPoints',
                      label: 'Pontos somados',
                      accent: PulynColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const _SectionHeader(title: 'Minhas crianças'),
              const SizedBox(height: 12),
              if (list.isEmpty && !loadingFirstTime)
                const _EmptyChildren()
              else
                for (final child in list) ...[
                  _ChildTile(child: child),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 14),

              if (emailConfirmado != null) ...[
                _EmailStatusCard(status: emailConfirmado!),
                const SizedBox(height: 14),
              ],

              const _SectionHeader(title: 'Conta'),
              const SizedBox(height: 12),
              _MenuTile(
                icon: Icons.people_alt_outlined,
                title: 'Gerenciar crianças vinculadas',
                subtitle: 'Ver e desvincular',
                onTap: () => context.push('/manage-children'),
              ),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.event_note_outlined,
                title: 'Meus eventos',
                subtitle: 'Ver os eventos e adicionar um com o código',
                onTap: () => context.push('/my-events'),
              ),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.edit_outlined,
                title: 'Editar dados',
                subtitle: 'Nome, telefone e e-mail',
                onTap: () => context.push('/profile'),
              ),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.info_outline_rounded,
                title: 'Sobre o app',
                subtitle: 'Pulyn Family · versão $_appVersion',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Pulyn Family',
                  applicationVersion: _appVersion,
                  applicationLegalese: 'Diversão em Movimento!',
                ),
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PulynColors.danger,
                  side: BorderSide(color: PulynColors.danger.withValues(alpha: 0.6)),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PulynColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da conta?'),
        content: const Text('Você vai precisar entrar de novo para acompanhar seus filhos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: PulynColors.danger),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) onLogout();
  }
}

String _roleLabel(String perfil) {
  switch (perfil.toLowerCase()) {
    case 'family':
      return 'Responsável';
    case 'admin':
      return 'Administrador';
    case 'reception':
      return 'Recepção';
    case 'master':
      return 'Master';
    default:
      return perfil;
  }
}

Color _parseHex(String hex, {Color fallback = PulynColors.primary}) {
  try {
    return Color(int.parse('0xFF${hex.replaceFirst('#', '')}'));
  } catch (_) {
    return fallback;
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user.nome.trim().isNotEmpty ? user.nome.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PulynColors.primary.withValues(alpha: 0.28),
            PulynColors.darkCard,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PulynColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PulynColors.primary, PulynColors.primaryLight],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 3),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nome.isEmpty ? 'Usuário' : user.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PulynColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PulynColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _roleLabel(user.perfil),
                    style: const TextStyle(
                      color: PulynColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = PulynColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PulynColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final Child child;

  const _ChildTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final cor = _parseHex(child.teamColor);
    final nome = child.apelido.isNotEmpty ? child.apelido : child.nome.split(' ').first;
    final initial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final team = child.teamName.isNotEmpty ? child.teamName : 'Sem time ainda';

    return Material(
      color: PulynColors.darkCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/child/${child.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PulynColors.darkBorder),
          ),
          child: Row(
            children: [
              ChildAvatar(
                avatarId: child.profileImage,
                inicial: initial,
                cor: cor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$team · ${child.currentScore} pts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PulynColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PulynColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.child_care_rounded, size: 40, color: PulynColors.primary),
          const SizedBox(height: 10),
          const Text(
            'Nenhuma criança vinculada ainda',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'A recepção do buffet vincula seus filhos. Procure a equipe no dia do evento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PulynColors.textMuted, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Mostra se o e-mail está confirmado. Quando não está, toque leva para a confirmação.
class _EmailStatusCard extends StatelessWidget {
  final AsyncValue<bool> status;

  const _EmailStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final confirmado = status.valueOrNull;
    if (status.isLoading || status.hasError || confirmado == null) return const SizedBox.shrink();

    final cor = confirmado ? PulynColors.secondary : PulynColors.accent;
    return Material(
      color: PulynColors.darkCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: confirmado ? null : () => context.push('/confirmar-email'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(confirmado ? Icons.verified_rounded : Icons.warning_amber_rounded, color: cor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmado ? 'E-mail confirmado' : 'E-mail ainda não confirmado',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      confirmado
                          ? 'Sua conta pode ser recuperada por este e-mail.'
                          : 'Toque para receber o código e confirmar.',
                      style: const TextStyle(color: PulynColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!confirmado) const Icon(Icons.chevron_right_rounded, color: PulynColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PulynColors.darkCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PulynColors.darkBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: PulynColors.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: PulynColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PulynColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
