import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';

// Ações da conta (alterar senha e excluir conta), usadas pela aba Perfil e pela tela de perfil.

/// Pede a senha atual numa caixa de diálogo. Devolve null se cancelar ou deixar em branco.
Future<String?> pedirSenhaAtual(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmar = 'Confirmar',
}) async {
  final controller = TextEditingController();
  final senha = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: PulynColors.darkCard,
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensagem),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Senha atual'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(confirmar)),
      ],
    ),
  );
  controller.dispose();
  return (senha == null || senha.isEmpty) ? null : senha;
}

/// Confirma, pede a senha e exclui a conta de família. Depois sai para a tela de login.
Future<void> excluirConta(BuildContext context, WidgetRef ref) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: PulynColors.darkCard,
      title: const Text('Excluir conta?'),
      content: const Text(
        'Sua conta e seus dados pessoais (nome e e-mail) serão apagados e você não conseguirá mais entrar. '
        'O histórico dos eventos permanece, sem identificação. Esta ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continuar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmou != true || !context.mounted) return;

  final senha = await pedirSenhaAtual(
    context,
    titulo: 'Confirme sua senha',
    mensagem: 'Digite sua senha para excluir a conta.',
    confirmar: 'Excluir',
  );
  if (senha == null || !context.mounted) return;

  // Captura o que precisa antes de navegar: depois de sair da tela, o ref desta tela não vale mais.
  final api = ref.read(apiServiceProvider);
  final sessao = ref.read(authProvider.notifier);
  try {
    await api.excluirConta(senha);
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    return;
  }
  // Primeiro sai para o login (ainda na rota atual), depois limpa a sessão. Assim a troca de rota não
  // acontece no meio da reconstrução da tela de perfil.
  if (context.mounted) context.go('/login');
  await Future<void>.delayed(Duration.zero);
  await sessao.logout();
}
