import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/logger.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/app_components.dart';
import '../../widgets/pulyn_logo.dart';

// Pré-cadastro: crianças que o responsável cadastrou e que ainda não entraram em nenhum evento.
// Usado pela home (seção "Aguardando o buffet") e pela tela de gerenciar crianças.
final preRegisteredChildrenProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      return apiService.getPreRegisteredChildren();
    });

/// Pré-cadastro: o responsável escolhe a festa (buffet) e cadastra a criança antes de ir ao buffet.
/// Volta `true` quando cadastra, para a lista atualizar.
class PreRegisterChildScreen extends ConsumerStatefulWidget {
  const PreRegisterChildScreen({super.key});

  @override
  ConsumerState<PreRegisterChildScreen> createState() =>
      _PreRegisterChildScreenState();
}

class _PreRegisterChildScreenState
    extends ConsumerState<PreRegisterChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _apelidoController = TextEditingController();
  final _nascimentoController = TextEditingController();
  DateTime? _nascimento;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _nascimentoController.dispose();
    super.dispose();
  }

  // A criança tem até 17 anos: a data mais antiga aceita é 17 anos atrás.
  Future<void> _escolherNascimento() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 6, hoje.month, hoje.day),
      firstDate: DateTime(hoje.year - 17, hoje.month, hoje.day),
      lastDate: hoje,
      helpText: 'Data de nascimento da criança',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      _nascimento = escolhida;
      _nascimentoController.text =
          '${escolhida.day.toString().padLeft(2, '0')}/${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}';
    });
  }

  static String _dataIso(DateTime data) =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

  static int _idadeAnos(DateTime nascimento) {
    final hoje = DateTime.now();
    var anos = hoje.year - nascimento.year;
    final aindaNaoFez = hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day);
    if (aindaNaoFez) anos -= 1;
    return anos;
  }

  Future<void> _salvar() async {
    log.i(
      '[PRE_REGISTER] Botão Cadastrar pressionado',
    );
    if (!_formKey.currentState!.validate()) {
      log.w('[PRE_REGISTER] Não enviado: formulário inválido');
      return;
    }

    setState(() => _salvando = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();

      // Antes de salvar: já existe um cadastro com esta criança, nascimento e responsável (feito na recepção, por exemplo)?
      final cadastroParecido = await apiService.buscarCadastroParecido(
        nome: _nomeController.text.trim(),
        dataNascimento: _dataIso(_nascimento!),
      );
      if (cadastroParecido != null) {
        if (!mounted) return;
        final continuar = await _avisarCadastroParecido(cadastroParecido);
        if (continuar != true) return;
      }
      log.i('[PRE_REGISTER] Enviando cadastro');
      await apiService.createPreRegisteredChild(
        nome: _nomeController.text.trim(),
        apelido: _apelidoController.text.trim().isEmpty
            ? null
            : _apelidoController.text.trim(),
        idade: _idadeAnos(_nascimento!),
        dataNascimento: _dataIso(_nascimento!),
      );
      log.i('[PRE_REGISTER] Cadastro criado com sucesso');
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Criança cadastrada! Leve-a ao buffet para pegar a pulseira.',
      );
      context.pop(true);
    } catch (e) {
      log.e('[PRE_REGISTER] Falha ao cadastrar: ${_detalheDeErro(e)}');
      if (mounted) showErrorSnackBar(context, _mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool?> _avisarCadastroParecido(String criadoEmIso) {
    final data = _dataCurta(criadoEmIso);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Já existe um cadastro parecido'),
        content: Text(
          'Já existe um cadastro bem parecido com as suas informações'
          '${data.isEmpty ? '' : ', criado em $data'}.\n\n'
          'Seu filho visitou algum evento${data.isEmpty ? '' : ' no dia $data'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cadastrar mesmo assim'),
          ),
        ],
      ),
    );
  }

  // Status e corpo da resposta do servidor (sem nome da criança, que é dado pessoal).
  String _detalheDeErro(Object erro) {
    if (erro is DioException) {
      return 'HTTP ${erro.response?.statusCode} ${erro.response?.data ?? erro.message}';
    }
    return erro.toString();
  }

  String _mensagemDeErro(Object erro) {
    if (erro is DioException && erro.response?.data is Map) {
      final mensagem = (erro.response!.data as Map)['error'];
      if (mensagem is String && mensagem.isNotEmpty) return mensagem;
    }
    return 'Não foi possível cadastrar a criança. Tente novamente.';
  }

  String _dataCurta(String? iso) {
    final data = DateTime.tryParse(iso ?? '');
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar criança'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: const [PulynAppBarLogo()],
      ),
      body: _formulario(),
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                _cabecalho(),
                const SizedBox(height: 24),
                _titulo('Dados da criança'),
                const SizedBox(height: 10),
                PulynTextField(
                  label: 'Nome completo',
                  controller: _nomeController,
                  prefixIcon: Icons.person_outline,
                  validator: (valor) => (valor == null || valor.trim().isEmpty)
                      ? 'Informe o nome'
                      : null,
                ),
                const SizedBox(height: 12),
                PulynTextField(
                  label: 'Apelido (opcional)',
                  hint: 'Como ela é chamada na festa',
                  controller: _apelidoController,
                  prefixIcon: Icons.face_outlined,
                ),
                const SizedBox(height: 12),
                // Toque abre o calendário; o campo em si não abre o teclado.
                GestureDetector(
                  onTap: _escolherNascimento,
                  child: AbsorbPointer(
                    child: PulynTextField(
                      label: 'Data de nascimento',
                      hint: 'Toque para escolher',
                      controller: _nascimentoController,
                      prefixIcon: Icons.cake_outlined,
                      validator: (valor) => _nascimento == null
                          ? 'Informe a data de nascimento'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PulynButton(
                label: 'Cadastrar criança',
                icon: Icons.person_add_alt_1_rounded,
                isLoading: _salvando,
                onPressed: _salvar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulynColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: PulynColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cadastre a criança antes de ir à festa. Na festa, ela se vincula ao evento pelo autoatendimento e aparece no seu app.',
              style: TextStyle(fontSize: 13, color: PulynColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto) {
    return Text(
      texto,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: PulynColors.textPrimary,
      ),
    );
  }
}
