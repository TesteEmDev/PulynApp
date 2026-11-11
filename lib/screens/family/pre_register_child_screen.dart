import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
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
  /// Cadastro a editar (perfilCriancaId, nome, apelido, dataNascimento). Sem ele, é um cadastro novo.
  final Map<String, dynamic>? perfil;

  const PreRegisterChildScreen({super.key, this.perfil});

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

  bool get _editando => widget.perfil != null;

  @override
  void initState() {
    super.initState();
    final perfil = widget.perfil;
    if (perfil != null) {
      _nomeController.text = (perfil['nome'] as String?) ?? '';
      _apelidoController.text = (perfil['apelido'] as String?) ?? '';
      final nascimento = DateTime.tryParse(
        (perfil['dataNascimento'] as String?) ?? '',
      );
      if (nascimento != null) {
        _nascimento = nascimento;
        _nascimentoController.text =
            '${nascimento.day.toString().padLeft(2, '0')}/${nascimento.month.toString().padLeft(2, '0')}/${nascimento.year}';
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _nascimentoController.dispose();
    super.dispose();
  }

  // Sem limite de idade: só não vale data futura nem anterior a 1900.
  Future<void> _escolherNascimento() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 6, hoje.month, hoje.day),
      firstDate: DateTime(1900),
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

  // Digitando DD/MM/AAAA: só vale uma data que existe e que não é futura.
  void _aoDigitarNascimento(String texto) {
    DateTime? data;
    final partes = texto.split('/');
    if (partes.length == 3 && partes[2].length == 4) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final ano = int.tryParse(partes[2]);
      if (dia != null && mes != null && ano != null) {
        final candidata = DateTime(ano, mes, dia);
        final hoje = DateTime.now();
        final maisAntiga = DateTime(1900);
        final existe = candidata.day == dia && candidata.month == mes;
        if (existe &&
            !candidata.isAfter(hoje) &&
            !candidata.isBefore(maisAntiga)) {
          data = candidata;
        }
      }
    }
    setState(() => _nascimento = data);
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

      if (_editando) {
        await apiService.updatePreRegisteredChild(
          perfilCriancaId: widget.perfil!['perfilCriancaId'] as String,
          nome: _nomeController.text.trim(),
          apelido: _apelidoController.text.trim().isEmpty
              ? null
              : _apelidoController.text.trim(),
          dataNascimento: _dataIso(_nascimento!),
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Cadastro atualizado.');
        context.pop(true);
        return;
      }

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

  Future<bool?> _avisarCadastroParecido(Map<String, String> cadastro) {
    final data = _dataCurta(cadastro['criadoEm']);
    final crianca = cadastro['crianca'] ?? '';
    final responsavel = cadastro['responsavel'] ?? '';
    // Nomes abreviados pelo servidor (privacidade): "Guilherme G. C."
    final quem = [
      if (crianca.isNotEmpty) 'Criança: $crianca',
      if (responsavel.isNotEmpty) 'Responsável: $responsavel',
    ].join('\n');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Já existe um cadastro parecido'),
        content: Text(
          'Já existe um cadastro bem parecido com as suas informações'
          '${data.isEmpty ? '' : ', criado em $data'}.\n\n'
          '${quem.isEmpty ? '' : '$quem\n\n'}'
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
        title: Text(_editando ? 'Editar criança' : 'Cadastrar criança'),
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
                // Dá para digitar (DD/MM/AAAA) ou abrir o calendário pelo ícone.
                PulynTextField(
                  label: 'Data de nascimento',
                  hint: 'DD/MM/AAAA',
                  controller: _nascimentoController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake_outlined,
                  inputFormatters: [_MascaraData()],
                  onChanged: _aoDigitarNascimento,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    tooltip: 'Abrir calendário',
                    onPressed: _escolherNascimento,
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Informe a data de nascimento';
                    }
                    return _nascimento == null
                        ? 'Data inválida'
                        : null;
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PulynButton(
                label: _editando ? 'Salvar alterações' : 'Cadastrar criança',
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

/// Máscara DD/MM/AAAA: só números, com as barras entrando sozinhas.
class _MascaraData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final digitos = novo.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limitado = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final buffer = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(limitado[i]);
    }
    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Menu de editar/excluir de um cadastro que ainda não entrou em nenhum evento.
/// Chame `onMudou` para a tela recarregar a lista depois de editar ou excluir.
class MenuCadastroPendente extends ConsumerWidget {
  final Map<String, dynamic> perfil;
  final VoidCallback onMudou;

  const MenuCadastroPendente({
    super.key,
    required this.perfil,
    required this.onMudou,
  });

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final apelido = (perfil['apelido'] as String?) ?? '';
    final nome = apelido.isNotEmpty ? apelido : (perfil['nome'] as String? ?? '');
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cadastro?'),
        content: Text(
          'O cadastro de $nome será apagado. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir', style: TextStyle(color: PulynColors.danger)),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      await apiService.deletePreRegisteredChild(
        perfil['perfilCriancaId'] as String,
      );
      if (!context.mounted) return;
      showSuccessSnackBar(context, 'Cadastro excluído.');
      onMudou();
    } catch (e) {
      log.e('[PRE_REGISTER] Falha ao excluir: $e');
      if (!context.mounted) return;
      String mensagem = 'Não foi possível excluir. Tente novamente.';
      if (e is DioException && e.response?.data is Map) {
        final erro = (e.response!.data as Map)['error'];
        if (erro is String && erro.isNotEmpty) mensagem = erro;
      }
      showErrorSnackBar(context, mensagem);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Opções',
      onSelected: (acao) async {
        if (acao == 'editar') {
          final mudou = await context.push<bool>(
            '/pre-register-child',
            extra: perfil,
          );
          if (mudou == true) onMudou();
        } else {
          await _excluir(context, ref);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'editar', child: Text('Editar')),
        PopupMenuItem(value: 'excluir', child: Text('Excluir')),
      ],
    );
  }
}
