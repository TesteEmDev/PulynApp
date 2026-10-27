import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/top_snackbar.dart';
import '../../widgets/pulyn_logo.dart';

/// Pré-cadastro: o responsável escolhe o evento (buffet) e cadastra a criança antes de ir ao buffet.
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
  late final Future<List<Map<String, dynamic>>> _eventos;
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
    await apiService.init();
    return apiService.getOpenEvents();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate() || _eventoId == null) return;

    setState(() => _salvando = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      await apiService.createPreRegisteredChild(
        eventoId: _eventoId!,
        nome: _nomeController.text.trim(),
        apelido: _apelidoController.text.trim().isEmpty
            ? null
            : _apelidoController.text.trim(),
        idade: int.parse(_idadeController.text.trim()),
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Criança cadastrada! Leve-a ao buffet para pegar a pulseira.',
      );
      context.pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, _mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
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
            return const Center(
              child: Text('Não foi possível carregar os eventos.'),
            );
          }
          final eventos = snapshot.data ?? const [];
          if (eventos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não há eventos abertos no momento. Tente de novo quando o buffet abrir a festa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PulynColors.textMuted),
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _eventoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Festa / buffet',
                  ),
                  items: [
                    for (final evento in eventos)
                      DropdownMenuItem<String>(
                        value: evento['eventoId'] as String,
                        child: Text(
                          '${evento['nome']} · ${evento['buffetNome']} · ${_dataCurta(evento['data'] as String?)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _salvando
                      ? null
                      : (valor) => setState(() => _eventoId = valor),
                  validator: (valor) =>
                      valor == null ? 'Escolha a festa' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo da criança',
                  ),
                  validator: (valor) => (valor == null || valor.trim().isEmpty)
                      ? 'Informe o nome'
                      : null,
                ),
                TextFormField(
                  controller: _apelidoController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Apelido (opcional)',
                  ),
                ),
                TextFormField(
                  controller: _idadeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Idade'),
                  validator: (valor) {
                    final idade = int.tryParse(valor?.trim() ?? '');
                    return (idade == null || idade < 0)
                        ? 'Informe a idade'
                        : null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cadastrar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
