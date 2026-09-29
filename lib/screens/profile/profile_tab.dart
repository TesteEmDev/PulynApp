import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/family_models.dart';
import '../../widgets/pulyn_logo.dart';
import '../qr_scan/open_qr_scanner.dart';

const _appVersion = '1.0.0';

/// Aba "Perfil" do menu de baixo: quem está logado, resumo das crianças, atalhos
/// e sair da conta. Só mostra o que funciona (nada de interruptores que não fazem nada).
///
/// É um widget "puro": os dados e as ações chegam por parâmetro (a HomeScreen liga aos
/// providers), o que deixa a tela simples de testar.
class ProfileTab extends StatelessWidget {
  /// Usuário logado.
  final AsyncValue<User?> auth;

  /// Crianças vinculadas (o `.value` mantém a lista anterior enquanto recarrega, então
  /// a tela não pisca a cada leitura de checkpoint).
  final AsyncValue<List<Child>> children;

  /// Sair da conta (chamado só depois da confirmação).
  final VoidCallback onLogout;

  /// Tentar carregar o perfil de novo depois de um erro.
  final VoidCallback? onRetry;

  /// Chamado depois que uma criança é vinculada pelo QR Code (para recarregar a lista).
  final VoidCallback? onChildLinked;

  const ProfileTab({
    required this.auth,
    required this.children,
    required this.onLogout,
    this.onRetry,
    this.onChildLinked,
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

              _SectionHeader(
                title: 'Minhas crianças',
                actionLabel: 'Vincular',
                onAction: () => _openQrScanner(context),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty && !loadingFirstTime)
                _EmptyChildren(onLink: () => _openQrScanner(context))
              else
                for (final child in list) ...[
                  _ChildTile(child: child),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 14),

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

  void _openQrScanner(BuildContext context) => openQrScanner(context, onChildLinked: onChildLinked);

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

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'family':
      return 'Responsável';
    case 'admin':
      return 'Administrador';
    case 'reception':
      return 'Recepção';
    case 'master':
      return 'Master';
    default:
      return role;
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
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';

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
                  user.name.isEmpty ? 'Usuário' : user.name,
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
                    _roleLabel(user.role),
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
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
      ],
    );
  }
}

class _ChildTile extends StatelessWidget {
  final Child child;

  const _ChildTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(child.teamColor);
    final name = child.nickname.isNotEmpty ? child.nickname : child.name.split(' ').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
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
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
  final VoidCallback onLink;

  const _EmptyChildren({required this.onLink});

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
          const Icon(Icons.qr_code_2_rounded, size: 40, color: PulynColors.primary),
          const SizedBox(height: 10),
          const Text(
            'Nenhuma criança vinculada ainda',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Escaneie o QR Code que a recepção entregar para acompanhar seu filho.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PulynColors.textMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onLink,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Vincular com QR Code'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
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
