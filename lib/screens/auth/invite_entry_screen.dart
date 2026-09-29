import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../utils/logger.dart';
import '../../widgets/auth_widgets.dart';

/// Tela onde a família cola o link/código do convite recebido do buffet.
/// É o destino do onboarding: dela a pessoa segue para o cadastro pelo convite.
class InviteEntryScreen extends ConsumerStatefulWidget {
  const InviteEntryScreen({super.key});

  @override
  ConsumerState<InviteEntryScreen> createState() => _InviteEntryScreenState();
}

class _InviteEntryScreenState extends ConsumerState<InviteEntryScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleInviteCode() {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cole o link ou o código do convite'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: PulynColors.danger,
        ),
      );
      return;
    }

    // ✅ Se o usuário cola a URL completa, extrair apenas o token
    String token = code;
    if (code.contains('/family/invite/')) {
      // Extrai a última parte após /family/invite/
      token = code.split('/family/invite/').last;
      log.i('[InviteEntry] Token extraído de URL: $token');
    }

    // Navega para a tela de cadastro pelo convite, com o token
    context.go('/family/invite/$token');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _codeController.text = text;
      _codeController.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Bem-vindo!',
                    subtitle: 'Acompanhe a jornada do seu filho em tempo real',
                  ),
                  const SizedBox(height: 32),

                  const AuthInfoCard(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Para começar, use o seu convite',
                    message: 'O buffet envia o link por email ou WhatsApp.',
                  ),
                  const SizedBox(height: 20),

                  AuthFormCard(
                    children: [
                      TextField(
                        controller: _codeController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _handleInviteCode(),
                        decoration: InputDecoration(
                          labelText: 'Link ou código do convite',
                          hintText: 'Cole aqui...',
                          prefixIcon: const Icon(Icons.link_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Colar',
                            icon: const Icon(Icons.content_paste_rounded),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthPrimaryButton(
                        label: 'Continuar',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _handleInviteCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Já tenho conta'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const AuthInfoCard(
                    icon: Icons.help_outline_rounded,
                    title: 'Não recebeu o convite?',
                    message: 'Fale com o buffet ou salão de festas onde seu filho vai comemorar.',
                    accent: PulynColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
