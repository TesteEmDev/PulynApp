import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../config/api_config.dart';
import '../../providers/index.dart';

/// Tela para selecionar o ambiente (Local, Render, Produção)
class EnvironmentSelectorScreen extends ConsumerStatefulWidget {
  const EnvironmentSelectorScreen({super.key});

  @override
  ConsumerState<EnvironmentSelectorScreen> createState() =>
      _EnvironmentSelectorScreenState();
}

class _EnvironmentSelectorScreenState
    extends ConsumerState<EnvironmentSelectorScreen> {
  late ApiEnvironment _selectedEnvironment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedEnvironment = ApiConfig.currentEnvironment;
  }

  void _selectEnvironment(ApiEnvironment environment) {
    setState(() => _selectedEnvironment = environment);
  }

  Future<void> _saveEnvironment() async {
    setState(() => _isSaving = true);

    try {
      // Salvar em SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_environment', _selectedEnvironment.toString());

      // Mudar ambiente na API
      final apiService = ref.read(apiServiceProvider);
      apiService.setEnvironment(_selectedEnvironment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Ambiente salvo: ${_selectedEnvironment.toString().split('.').last.toUpperCase()}'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );

        // Voltar para login
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go('/login');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao salvar: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _getEnvironmentUrl(ApiEnvironment env) {
    switch (env) {
      case ApiEnvironment.local:
        return ApiConfig.apiBaseUrlLocal;
      case ApiEnvironment.render:
        return ApiConfig.apiBaseUrlRender;
      case ApiEnvironment.production:
        return ApiConfig.apiBaseUrlProd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo-pulyn.png',
              height: 40,
              width: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('Seleção de Ambiente'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ℹ️ Configurar Servidor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione o servidor onde sua API Pulyn está hospedada. A configuração será salva no seu dispositivo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecionado: ${_selectedEnvironment.toString().split('.').last.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Environment Options
              Text(
                'Ambientes Disponíveis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // Local
              _buildEnvironmentCard(
                environment: ApiEnvironment.local,
                title: '💻 Local',
                description: 'Conectar com API em sua máquina',
                url: ApiConfig.apiBaseUrlLocal,
                isSelected: _selectedEnvironment == ApiEnvironment.local,
                onTap: () => _selectEnvironment(ApiEnvironment.local),
              ),
              const SizedBox(height: 12),

              // Render
              _buildEnvironmentCard(
                environment: ApiEnvironment.render,
                title: '☁️ Render (Hospedado)',
                description: 'Conectar com API hospedada no Render',
                url: ApiConfig.apiBaseUrlRender,
                isSelected: _selectedEnvironment == ApiEnvironment.render,
                onTap: () => _selectEnvironment(ApiEnvironment.render),
              ),
              const SizedBox(height: 12),

              // Production
              _buildEnvironmentCard(
                environment: ApiEnvironment.production,
                title: '🚀 Produção',
                description: 'Conectar com API em produção',
                url: ApiConfig.apiBaseUrlProd,
                isSelected: _selectedEnvironment == ApiEnvironment.production,
                onTap: () => _selectEnvironment(ApiEnvironment.production),
              ),

              const SizedBox(height: 32),

              // URL Configuration
              Text(
                'URLs Configuradas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // URLs List
              _buildUrlInfoCard(
                environment: 'Local',
                url: ApiConfig.apiBaseUrlLocal,
                status: _selectedEnvironment == ApiEnvironment.local ? '✅' : '⚪',
              ),
              const SizedBox(height: 8),
              _buildUrlInfoCard(
                environment: 'Render',
                url: ApiConfig.apiBaseUrlRender,
                status: _selectedEnvironment == ApiEnvironment.render ? '✅' : '⚪',
              ),
              const SizedBox(height: 8),
              _buildUrlInfoCard(
                environment: 'Produção',
                url: ApiConfig.apiBaseUrlProd,
                status: _selectedEnvironment == ApiEnvironment.production ? '✅' : '⚪',
              ),

              const SizedBox(height: 24),

              // Connection Status
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Servidor Selecionado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getEnvironmentUrl(_selectedEnvironment),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Instructions
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Instruções',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Selecione o ambiente onde sua API está rodando\n'
                      '2. Para Local: certifique-se que sua API está em http://localhost:3001\n'
                      '3. Para Render: use sua URL do Render (ex: backendpulyn.onrender.com)\n'
                      '4. Clique em "SALVAR E CONTINUAR" para confirmar\n'
                      '5. A configuração será mantida entre sessões',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEnvironment,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '✅ SALVAR E CONTINUAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentCard({
    required ApiEnvironment environment,
    required String title,
    required String description,
    required String url,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    url,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInfoCard({
    required String environment,
    required String url,
    required String status,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(status, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  environment,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  url,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
