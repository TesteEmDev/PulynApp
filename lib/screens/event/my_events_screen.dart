import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../utils/invite_code.dart';
import '../../utils/top_snackbar.dart';
import '../home/home_screen.dart' show childrenProvider, childrenRefreshProvider;

/// "Meus eventos": os eventos da conta (os adicionados pelo código de convite e os das crianças
/// vinculadas), passados e atuais. Tocar num evento mostra esse evento na home; o botão do topo
/// adiciona um evento novo digitando o código do convite.
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  Future<void> _adicionarEvento(BuildContext context, WidgetRef ref) async {
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulynColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AdicionarEventoSheet(),
    );
    if (resultado == null || !context.mounted) return;

    // O evento novo (e a criança, se o convite era dela) passam a aparecer em toda a app
    ref.invalidate(myEventsProvider);
    ref.invalidate(familyEventsProvider);
    ref.invalidate(activeEventProvider);
    ref.invalidate(childrenProvider);
    ref.read(childrenRefreshProvider.notifier).refresh();

    final evento = (resultado['evento'] as Map?)?['nome'] as String? ?? 'Evento';
    final crianca = (resultado['crianca'] as Map?)?['nome'] as String?;
    if (resultado['jaTinhaEvento'] == true && crianca == null) {
      showInfoSnackBar(context, '$evento já estava na sua conta');
    } else if (crianca != null) {
      showSuccessSnackBar(context, '$evento adicionado e $crianca vinculada');
    } else {
      showSuccessSnackBar(context, '$evento adicionado à sua conta');
    }
  }

  void _abrir(BuildContext context, WidgetRef ref, Map<String, dynamic> evento) {
    final criancas = (evento['criancas'] as List?) ?? const [];
    if (criancas.isEmpty) {
      // Sem criança neste evento a home não tem o que mostrar: explica como vincular
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: PulynColors.darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _SemCriancaSheet(nome: evento['nome'] as String? ?? 'Evento'),
      );
      return;
    }
    ref.read(selectedEventIdProvider.notifier).state = evento['id'] as String?;
    ref.invalidate(activeEventProvider);
    ref.invalidate(activeGameProvider);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventosAsync = ref.watch(myEventsProvider);
    final escolhido = ref.watch(selectedEventIdProvider);
    final ativo = ref.watch(activeEventProvider).value?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus eventos'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEventsProvider);
          await ref.read(myEventsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              key: const Key('adicionar-evento'),
              onPressed: () => _adicionarEvento(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar evento com código'),
            ),
            const SizedBox(height: 16),
            eventosAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (erro, _) => _Aviso(
                icone: Icons.error_outline,
                titulo: 'Não foi possível carregar seus eventos',
                texto: 'Puxe para atualizar ou tente de novo.',
                acao: TextButton(
                  onPressed: () => ref.invalidate(myEventsProvider),
                  child: const Text('Tentar de novo'),
                ),
              ),
              data: (eventos) {
                if (eventos.isEmpty) {
                  return const _Aviso(
                    icone: Icons.event_busy_outlined,
                    titulo: 'Você ainda não tem eventos',
                    texto: 'Toque em "Adicionar evento com código" e digite o código do convite que o buffet enviou.',
                  );
                }
                return Column(
                  children: [
                    for (final evento in eventos)
                      _CartaoEvento(
                        evento: evento,
                        exibindo: evento['id'] == (escolhido ?? ativo),
                        onTap: () => _abrir(context, ref, evento),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _formatarData(dynamic valor) {
  // A data do evento é um dia, sem hora: formata como veio, sem converter de fuso (que mostraria o dia anterior)
  final data = DateTime.tryParse('${valor ?? ''}');
  return data == null ? '' : DateFormat('dd/MM/yyyy').format(data);
}

class _CartaoEvento extends StatelessWidget {
  final Map<String, dynamic> evento;
  final bool exibindo;
  final VoidCallback onTap;

  const _CartaoEvento({required this.evento, required this.exibindo, required this.onTap});

  (String, Color) get _situacao {
    if (evento['encerrado'] == true) return ('Encerrado', PulynColors.textMuted);
    if ('${evento['status']}'.toLowerCase() == 'active') return ('Em andamento', PulynColors.success);
    return ('Próximo', PulynColors.accent);
  }

  @override
  Widget build(BuildContext context) {
    final criancas = ((evento['criancas'] as List?) ?? const []).whereType<Map>().toList();
    final data = _formatarData(evento['data']);
    final buffet = (evento['buffetNome'] as String?)?.trim() ?? '';
    final subtitulo = [if (data.isNotEmpty) data, if (buffet.isNotEmpty) buffet].join(' · ');
    final (rotulo, cor) = _situacao;

    return Card(
      key: Key('evento-${evento['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: exibindo ? PulynColors.primary : PulynColors.darkBorder, width: exibindo ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      evento['nome'] as String? ?? 'Evento',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Etiqueta(rotulo, cor),
                ],
              ),
              if (subtitulo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitulo, style: const TextStyle(fontSize: 13, color: PulynColors.textSecondary)),
              ],
              const SizedBox(height: 10),
              if (criancas.isEmpty)
                const Text(
                  'Nenhuma criança vinculada neste evento',
                  style: TextStyle(fontSize: 13, color: PulynColors.textMuted),
                )
              else
                for (final c in criancas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.child_care_rounded, size: 16, color: PulynColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (c['apelido'] as String?)?.isNotEmpty == true ? c['apelido'] as String : (c['nome'] as String? ?? ''),
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                        Text('${c['pontos'] ?? 0} pts', style: const TextStyle(fontSize: 13, color: PulynColors.textSecondary)),
                      ],
                    ),
                  ),
              if (exibindo || evento['adicionadoPorConvite'] == true) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (exibindo) const _Etiqueta('Exibindo na home', PulynColors.primary),
                    if (evento['adicionadoPorConvite'] == true) const _Etiqueta('Adicionado por código', PulynColors.textSecondary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Etiqueta(this.texto, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;
  const _Aviso({required this.icone, required this.titulo, required this.texto, this.acao});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(icone, size: 56, color: PulynColors.textMuted),
          const SizedBox(height: 12),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: PulynColors.textSecondary)),
          ?acao,
        ],
      ),
    );
  }
}

class _SemCriancaSheet extends StatelessWidget {
  final String nome;
  const _SemCriancaSheet({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
            'Você ainda não tem criança neste evento. Peça à recepção o QR Code da criança e leia na tela inicial do app para acompanhar a festa.',
            style: TextStyle(fontSize: 14, color: PulynColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendi')),
          ),
        ],
      ),
    );
  }
}

class _AdicionarEventoSheet extends ConsumerStatefulWidget {
  const _AdicionarEventoSheet();

  @override
  ConsumerState<_AdicionarEventoSheet> createState() => _AdicionarEventoSheetState();
}

class _AdicionarEventoSheetState extends ConsumerState<_AdicionarEventoSheet> {
  final _controller = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final codigo = extractInviteToken(_controller.text);
    if (codigo.isEmpty) {
      setState(() => _erro = 'Cole o link ou o código do convite');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      await api.init();
      final resultado = await api.joinEventWithInvite(codigo);
      if (mounted) Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adicionar evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          const Text(
            'Cole o código ou o link do convite que o buffet enviou.',
            style: TextStyle(fontSize: 13, color: PulynColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('codigo-convite'),
            controller: _controller,
            enabled: !_enviando,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _enviar(),
            decoration: InputDecoration(
              labelText: 'Código ou link do convite',
              errorText: _erro,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('confirmar-adicionar-evento'),
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Adicionar'),
            ),
          ),
        ],
      ),
    );
  }
}
