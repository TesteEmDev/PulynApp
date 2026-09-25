import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/logger.dart';

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
        const SnackBar(content: Text('Cole o código do convite')),
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

    // Navega para a tela de convite com o token
    context.go('/family/invite/$token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo-pulyn.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Bem-vindo!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Acompanhe a jornada do seu filho em tempo real',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 56),
              
              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 48,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Para começar, você precisa de um código de convite',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O código foi enviado por email ou WhatsApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Input Field
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Código de Convite',
                  hintText: 'Cole aqui...',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              ElevatedButton.icon(
                onPressed: _handleInviteCode,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
              ),
              
              const SizedBox(height: 48),
              
              // Help Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.help_outline, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Não recebeu o convite?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre em contato com o buffet/salão de festas onde seu filho fará a festa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
