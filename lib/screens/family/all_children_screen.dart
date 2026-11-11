import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/index.dart';
import '../../widgets/child_avatar.dart';

// Todas as crianças do responsável, com ou sem pulseira vinculada. Busca de novo sempre que a tela abre.
final allChildrenProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final apiService = ref.read(apiServiceProvider);
      await apiService.init();
      return apiService.getAllChildren();
    });

class AllChildrenScreen extends ConsumerWidget {
  const AllChildrenScreen({super.key});

  static String _dataCurta(String? iso) {
    final data = DateTime.tryParse(iso ?? '');
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criancas = ref.watch(allChildrenProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todas as crianças'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: criancas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: PulynColors.textMuted,
                ),
                const SizedBox(height: 12),
                const Text('Não foi possível carregar as crianças.'),
                TextButton(
                  onPressed: () => ref.invalidate(allChildrenProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma criança cadastrada ainda.',
                style: TextStyle(color: PulynColors.textMuted),
              ),
            );
          }
          final comPulseira = lista
              .where((c) => c['situacao'] == 'com_pulseira')
              .length;
          final total = lista.length;
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(allChildrenProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '$total ${total == 1 ? 'criança' : 'crianças'} no total · $comPulseira com pulseira',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final c in lista) _linha(c),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linha(Map<String, dynamic> c) {
    final apelido = (c['apelido'] as String?) ?? '';
    final nome = (c['nome'] as String?) ?? '';
    final titulo = apelido.isNotEmpty ? apelido : nome;
    final situacao = c['situacao'] as String? ?? 'aguardando';
    final (rotulo, cor) = switch (situacao) {
      'com_pulseira' => ('Com pulseira', PulynColors.success),
      'no_evento' => ('Sem pulseira', PulynColors.warning),
      _ => ('Aguardando o buffet', PulynColors.textMuted),
    };
    final evento = (c['ultimoEventoNome'] as String?) ?? '';
    final dataEvento = _dataCurta(c['ultimoEventoData'] as String?);
    final idade = c['idade'];
    final ultimo = evento.isEmpty
        ? 'Nenhum evento ainda'
        : 'Último evento: $evento${dataEvento.isEmpty ? '' : ' ($dataEvento)'}';
    final detalhes = [if (idade != null) '$idade anos', ultimo].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ChildAvatar(
          avatarId: c['avatar'] as String?,
          inicial: titulo.isEmpty ? '?' : titulo[0].toUpperCase(),
          cor: cor,
        ),
        title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detalhes, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            rotulo,
            style: TextStyle(
              color: cor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
