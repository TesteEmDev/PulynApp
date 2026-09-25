import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../utils/logger.dart';

class FamilyInviteScreen extends ConsumerStatefulWidget {
  final String token;

  const FamilyInviteScreen({
    required this.token,
    super.key,
  });

  @override
  ConsumerState<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _ChildFormData {
  String name = '';
  String nickname = '';
  int? age;
}

class _FamilyInviteScreenState extends ConsumerState<FamilyInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final List<_ChildFormData> _children = [_ChildFormData()];
  final List<TextEditingController> _childNameControllers = [TextEditingController()];
  final List<TextEditingController> _childNicknameControllers = [TextEditingController()];
  final List<TextEditingController> _childAgeControllers = [TextEditingController()];
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = true;
  String? _errorMessage;
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
    
    for (var controller in _childNameControllers) {
      controller.dispose();
    }
    for (var controller in _childNicknameControllers) {
      controller.dispose();
    }
    for (var controller in _childAgeControllers) {
      controller.dispose();
    }
    
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
          // Apenas preenche o nome da criança como referência
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

  void _addChild() {
    setState(() {
      _children.add(_ChildFormData());
      _childNameControllers.add(TextEditingController());
      _childNicknameControllers.add(TextEditingController());
      _childAgeControllers.add(TextEditingController());
    });
  }

  void _removeChild(int index) {
    if (_children.length <= 1) return; // Sempre precisa de pelo menos 1 criança
    
    setState(() {
      _children.removeAt(index);
      _childNameControllers[index].dispose();
      _childNameControllers.removeAt(index);
      _childNicknameControllers[index].dispose();
      _childNicknameControllers.removeAt(index);
      _childAgeControllers[index].dispose();
      _childAgeControllers.removeAt(index);
    });
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 🔽 Fecha o teclado
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ As senhas não conferem'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Se não tem criança vinculada, valida os dados das crianças
    if (!_hasLinkedChild) {
      for (int i = 0; i < _children.length; i++) {
        final childName = _childNameControllers[i].text.trim();
        if (childName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Informe o nome da criança ${i + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    try {
      log.i('[INVITE] 📝 Registrando com convite...');
      
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      
      // Prepara lista de crianças se não tem criança vinculada
      List<Map<String, dynamic>>? childrenPayload;
      if (!_hasLinkedChild) {
        childrenPayload = [];
        for (int i = 0; i < _children.length; i++) {
          final childName = _childNameControllers[i].text.trim();
          final childNickname = _childNicknameControllers[i].text.trim();
          final childAgeText = _childAgeControllers[i].text.trim();
          
          childrenPayload.add({
            'name': childName,
            'nickname': childNickname.isNotEmpty ? childNickname : childName,
            'age': childAgeText.isNotEmpty ? int.tryParse(childAgeText) : null,
          });
        }
        log.i('[INVITE] 📋 Crianças a registrar: ${childrenPayload.length}');
      }
      
      final result = await apiService.registerWithInvite(
        widget.token,
        email,
        password,
        name,
        children: childrenPayload,
      );
      
      if (!mounted) return;
      
      // Verifica o tipo de resultado
      final resultType = result['type'] as String?;
      
      if (resultType == 'auto_login') {
        // Cenário 1: Tem criança específica - login automático
        log.i('[INVITE] ✅ Login automático após registro');
        
        // Salva o token e marca como autenticado
        final token = result['token'] as String?;
        if (token != null) {
          // O interceptor do Dio e o auth provider vão usar o token salvo
          // Apenas redireciona para home
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Registrado e autenticado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) context.go('/home');
        });
      } else if (resultType == 'pending') {
        // Cenário 2: Convite genérico - pendente de aprovação
        log.i('[INVITE] ⏳ Registro pendente de aprovação');
        
        final message = result['message'] as String? ?? 'Cadastro realizado!';
        
        if (!mounted) return;
        
        // Mostra SnackBar moderno no topo, afastado da tela
        // Fica ativo indefinidamente até clicar em "Ir para Login"
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título com ícone
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cadastro Realizado!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Mensagem principal
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Info items
                _buildSnackBarInfoItem(
                  '1',
                  'A recepção do buffet revisará sua solicitação',
                ),
                const SizedBox(height: 8),
                _buildSnackBarInfoItem(
                  '2',
                  'Você receberá uma notificação quando aprovado',
                ),
                const SizedBox(height: 8),
                _buildSnackBarInfoItem(
                  '3',
                  'Poderá fazer login e acompanhar seus filhos',
                ),
                const SizedBox(height: 12),
                
                // Botão de ação
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      context.go('/login');
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text(
                      'Ir para Login',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            duration: const Duration(days: 365), // ← Fica ativo indefinidamente
            dismissDirection: DismissDirection.none, // ← Não pode deslizar pra fechar
          ),
        );
      }
    } catch (e) {
      log.e('[INVITE] ❌ Erro ao registrar: $e');
      
      if (!mounted) return;
      
      String errorMessage = '❌ Erro ao registrar';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('already exists') || errorStr.contains('email já') || errorStr.contains('409')) {
        errorMessage = '❌ Email já registrado';
      } else if (errorStr.contains('convite expirado')) {
        errorMessage = '❌ Convite expirado. Solicite um novo convite.';
      } else if (errorStr.contains('convite já utilizado')) {
        errorMessage = '❌ Este convite já foi utilizado.';
      } else if (errorStr.contains('invalid')) {
        errorMessage = '❌ Dados inválidos';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = '❌ Erro de conexão';
      } else if (errorStr.contains('informe entre 1 e 10')) {
        errorMessage = '❌ Informe entre 1 e 10 crianças';
      } else if (errorStr.contains('410')) {
        errorMessage = '❌ Convite inválido ou expirado';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nome é obrigatório';
    }
    if (value.length < 2) {
      return 'Nome deve ter no mínimo 2 caracteres';
    }
    return null;
  }

  Widget _buildInfoItem(String number, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnackBarInfoItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validando convite...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Voltar para Login'),
              ),
            ],
          ),
        ),
      );
    }

    final event = _inviteData?['event'] as Map<String, dynamic>? ?? {};
    final eventName = event['name'] ?? 'Evento';
    final eventDate = event['date'] ?? '';
    final linkedChild = _inviteData?['child'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro Familiar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
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
                  'Cadastro da Família',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                // Event info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evento:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        eventName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (eventDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Data: $eventDate',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    hintText: 'João Silva',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),

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
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Senha',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),

                // Children Section (only if no linked child)
                if (!_hasLinkedChild)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dados das crianças',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cadastre o(s) filho(s) que participarão do evento',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Criança ${index + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (_children.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeChild(index),
                                    ),
                                ],
                              ),
                              TextFormField(
                                controller: _childNameControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Nome completo',
                                  hintText: 'João Silva',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Nome é obrigatório';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _childNicknameControllers[index],
                                      decoration: const InputDecoration(
                                        labelText: 'Apelido',
                                        hintText: 'João',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: _childAgeControllers[index],
                                      decoration: const InputDecoration(
                                        labelText: 'Idade',
                                        hintText: '7',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              if (index < _children.length - 1)
                                const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_children.length < 10)
                        ElevatedButton.icon(
                          onPressed: _addChild,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar criança'),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Linked child info (if exists)
                if (_hasLinkedChild && linkedChild != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Criança vinculada',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              linkedChild['name'] ?? 'Sem nome',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Register Button
                ElevatedButton(
                  onPressed: _handleRegister,
                  child: const Text('Criar Cadastro'),
                ),
                const SizedBox(height: 16),

                // Login Link
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Já tem uma conta? Faça login'),
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
