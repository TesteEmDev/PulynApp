import 'dart:math' as math;

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
  final _idadeController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _eventos;
  String? _eventoId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _eventos = _carregarEventos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _idadeController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _carregarEventos() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.init();
      final eventos = await apiService.getOpenEvents();
      log.i(
        '[PRE_REGISTER] ${eventos.length} evento(s) aberto(s) carregado(s)',
      );
      return eventos;
    } catch (e) {
      log.e('[PRE_REGISTER] Erro ao carregar eventos: ${_detalheDeErro(e)}');
      rethrow;
    }
  }

  void _recarregar() {
    setState(() => _eventos = _carregarEventos());
  }

  Future<void> _salvar() async {
    log.i(
      '[PRE_REGISTER] Botão Cadastrar pressionado (festa escolhida: ${_eventoId != null})',
    );
    // A festa também é validada pelo próprio dropdown (mostra "Escolha a festa" embaixo dele).
    if (!_formKey.currentState!.validate() || _eventoId == null) {
      log.w(
        '[PRE_REGISTER] Não enviado: formulário inválido ou festa não escolhida',
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      log.i('[PRE_REGISTER] Enviando cadastro para o evento $_eventoId');
      await apiService.createPreRegisteredChild(
        eventoId: _eventoId!,
        nome: _nomeController.text.trim(),
        apelido: _apelidoController.text.trim().isEmpty
            ? null
            : _apelidoController.text.trim(),
        idade: int.parse(_idadeController.text.trim()),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventos,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _estadoVazio(
              icon: Icons.cloud_off_rounded,
              titulo: 'Não foi possível carregar as festas',
              texto: 'Verifique sua conexão e tente de novo.',
              acao: TextButton.icon(
                onPressed: _recarregar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar de novo'),
              ),
            );
          }
          final eventos = snapshot.data ?? const [];
          if (eventos.isEmpty) {
            return _estadoVazio(
              icon: Icons.celebration_outlined,
              titulo: 'Nenhuma festa aberta',
              texto: 'Quando o buffet abrir a festa, ela aparece aqui.',
            );
          }
          return _formulario(eventos);
        },
      ),
    );
  }

  Widget _formulario(List<Map<String, dynamic>> eventos) {
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
                _titulo('1. Escolha a festa'),
                const SizedBox(height: 10),
                _campoFestas(eventos),
                const SizedBox(height: 24),
                _titulo('2. Dados da criança'),
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
                PulynTextField(
                  label: 'Idade',
                  controller: _idadeController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake_outlined,
                  validator: (valor) {
                    final idade = int.tryParse(valor?.trim() ?? '');
                    return (idade == null || idade < 0)
                        ? 'Informe a idade'
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
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: PulynColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cadastre a criança antes de ir à festa. Na recepção ela recebe a pulseira e aparece no seu app.',
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
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: PulynColors.textPrimary,
      ),
    );
  }

  // Campo de festa: o menu abre sempre logo abaixo do campo (ver _CampoFesta).
  // O FormField mantém o valor e o erro de validação, como um DropdownButtonFormField.
  Widget _campoFestas(List<Map<String, dynamic>> eventos) {
    return FormField<String>(
      initialValue: _eventoId,
      validator: (valor) => valor == null ? 'Escolha a festa' : null,
      builder: (campo) => _CampoFesta(
        eventos: eventos,
        valor: campo.value,
        erro: campo.errorText,
        desabilitado: _salvando,
        textoDaFesta: _textoFesta,
        onSelecionado: (id) {
          campo.didChange(id);
          setState(() => _eventoId = id);
        },
      ),
    );
  }

  // Nome da festa em destaque, com buffet, cidade e data embaixo (uma linha no campo fechado).
  Widget _textoFesta(Map<String, dynamic> evento, {bool compacto = false}) {
    final cidade = evento['buffetCidade'] as String?;
    final detalhes = [
      evento['buffetNome'] as String? ?? '',
      if (cidade != null && cidade.isNotEmpty) cidade,
      _dataCurta(evento['data'] as String?),
    ].where((parte) => parte.isNotEmpty).join(' · ');

    final nome = Text(
      evento['nome'] as String? ?? 'Festa',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: PulynColors.textPrimary,
      ),
    );
    final info = Text(
      detalhes,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: PulynColors.textSecondary),
    );

    if (compacto) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Flexible(child: nome),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                detalhes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: PulynColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [nome, const SizedBox(height: 2), info],
    );
  }

  Widget _estadoVazio({
    required IconData icon,
    required String titulo,
    required String texto,
    Widget? acao,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: PulynColors.textMuted),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: PulynColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PulynColors.textMuted),
            ),
            if (acao != null) ...[const SizedBox(height: 16), acao],
          ],
        ),
      ),
    );
  }
}

/// Campo de festa com menu que abre sempre logo abaixo do campo. O DropdownButton do Flutter
/// troca para cima quando calcula que não cabe embaixo; aqui a posição é fixa. Toque fora fecha.
class _CampoFesta extends StatefulWidget {
  final List<Map<String, dynamic>> eventos;
  final String? valor;
  final String? erro;
  final bool desabilitado;
  final Widget Function(Map<String, dynamic>, {bool compacto}) textoDaFesta;
  final ValueChanged<String> onSelecionado;

  const _CampoFesta({
    required this.eventos,
    required this.valor,
    required this.erro,
    required this.desabilitado,
    required this.textoDaFesta,
    required this.onSelecionado,
  });

  @override
  State<_CampoFesta> createState() => _CampoFestaState();
}

class _CampoFestaState extends State<_CampoFesta> {
  final _campoKey = GlobalKey();
  OverlayEntry? _menu;

  @override
  void dispose() {
    _menu?.remove();
    _menu = null;
    super.dispose();
  }

  void _alternarMenu() {
    if (_menu != null) {
      _fecharMenu();
    } else {
      _abrirMenu();
    }
  }

  void _abrirMenu() {
    final caixa = _campoKey.currentContext!.findRenderObject()! as RenderBox;
    final origem = caixa.localToGlobal(Offset.zero);
    final topo = origem.dy + caixa.size.height + 6;
    final alturaDisponivel = MediaQuery.sizeOf(context).height -
        topo -
        MediaQuery.paddingOf(context).bottom -
        12;

    _menu = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _fecharMenu,
            ),
          ),
          Positioned(
            left: origem.dx,
            top: topo,
            width: caixa.size.width,
            child: _painel(math.max(160, math.min(340, alturaDisponivel))),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_menu!);
    setState(() {});
  }

  void _fecharMenu() {
    _menu?.remove();
    _menu = null;
    if (mounted) setState(() {});
  }

  Widget _painel(double alturaMaxima) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        decoration: BoxDecoration(
          color: PulynColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PulynColors.darkBorder),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          itemCount: widget.eventos.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: PulynColors.darkBorder),
          itemBuilder: (context, indice) {
            final evento = widget.eventos[indice];
            final id = evento['eventoId'] as String;
            final selecionada = id == widget.valor;
            return InkWell(
              onTap: () {
                widget.onSelecionado(id);
                _fecharMenu();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: widget.textoDaFesta(evento)),
                    if (selecionada)
                      const Icon(Icons.check_rounded, color: PulynColors.primary),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selecionada;
    for (final evento in widget.eventos) {
      if (evento['eventoId'] == widget.valor) selecionada = evento;
    }
    OutlineInputBorder borda(Color cor, double largura) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cor, width: largura),
        );

    return GestureDetector(
      key: _campoKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.desabilitado ? null : _alternarMenu,
      child: InputDecorator(
        isEmpty: selecionada == null,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.celebration_rounded, color: PulynColors.primary),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: PulynColors.primary),
          filled: true,
          fillColor: PulynColors.darkCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: borda(PulynColors.darkBorder, 1),
          enabledBorder: borda(PulynColors.darkBorder, 1),
          focusedBorder: borda(PulynColors.primary, 2),
          errorBorder: borda(PulynColors.danger, 1),
          focusedErrorBorder: borda(PulynColors.danger, 2),
          errorText: widget.erro,
        ),
        child: selecionada == null
            ? const Text(
                'Toque para escolher a festa',
                style: TextStyle(color: PulynColors.textMuted),
              )
            : widget.textoDaFesta(selecionada, compacto: true),
      ),
    );
  }
}
