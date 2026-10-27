import 'package:flutter/material.dart';
import '../../utils/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../utils/logger.dart';
import '../../providers/index.dart';

// autoDispose: a lista é buscada de novo sempre que a tela abre. Sem isso, o cache fica
// vivo com a sessão e uma criança vinculada depois (pela Home) não aparece aqui.
final linkedChildrenProvider = FutureProvider.autoDispose<List<Child>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  return await apiService.getChildren();
});

// Pré-cadastro: crianças que o responsável cadastrou e que ainda não entraram em nenhum evento.
final preRegisteredChildrenProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  return await apiService.getPreRegisteredChildren();
});

class ManageLinkedChildrenScreen extends ConsumerStatefulWidget {
  const ManageLinkedChildrenScreen({super.key});

  @override
  ConsumerState<ManageLinkedChildrenScreen> createState() =>
      _ManageLinkedChildrenScreenState();
}

class _ManageLinkedChildrenScreenState
    extends ConsumerState<ManageLinkedChildrenScreen> {
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  Future<void> _unlinkChild(Child child) async {
    try {
      await _apiService.init();
      await _apiService.dio.delete(
        '/family/children/${child.id}/unlink',
      );

      if (mounted) {
        showSuccessSnackBar(context, '${child.apelido} desvinculada com sucesso');
      }

      // Atualizar lista
      ref.invalidate(linkedChildrenProvider);
    } catch (e) {
      log.e('Erro ao desvincular: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Erro ao desvincular: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsyncValue = ref.watch(linkedChildrenProvider);

    return Scaffold(
         appBar: AppBar(
        title: const Text('Gerenciar Crianças Vinculadas'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Se a tela foi aberta com context.go() não há rota anterior para
          // dar pop — nesse caso volta pra home em vez de não fazer nada.
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          const _PreRegisteredSection(),
          Expanded(
            child: childrenAsyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar: $error'),
            ],
          ),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline,
                      size: 64, color: PulynColors.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma criança vinculada',
                    style: TextStyle(
                      fontSize: 16,
                      color: PulynColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                '0xFF${child.teamColor.replaceFirst('#', '')}',
                              )),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                child.apelido.isNotEmpty
                                    ? child.apelido[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.apelido.isNotEmpty
                                      ? child.apelido
                                      : child.nome,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${child.idade} anos • ${child.teamName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PulynColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PulynColors.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pontuação: ${child.currentScore} pontos',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ranking: #${child.rank}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: PulynColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PulynColors.primary,
                              ),
                              onPressed: () {
                                // Navegar para detalhes da criança
                              },
                              child: const Text('Ver Detalhes'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Desvincular?'),
                                  content: Text(
                                    'Deseja desvincular ${child.apelido.isNotEmpty ? child.apelido : child.nome}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _unlinkChild(child);
                                      },
                                      child: const Text(
                                        'Desvincular',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(Icons.delete, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar criança'),
        onPressed: () async {
          final cadastrou = await context.push<bool>('/pre-register-child');
          if (cadastrou == true) {
            ref.invalidate(preRegisteredChildrenProvider);
          }
        },
      ),
    );
  }
}

/// Crianças pré-cadastradas pelo responsável que ainda não têm pulseira (não entraram no buffet).
class _PreRegisteredSection extends ConsumerWidget {
  const _PreRegisteredSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` relança o erro do provider (ex.: 404 de rota ainda não publicada) e derrubaria a tela.
    // Com `when`, erro ou carregamento simplesmente escondem a seção.
    final perfis = ref.watch(preRegisteredChildrenProvider).when(
          data: (lista) => lista,
          loading: () => const <Map<String, dynamic>>[],
          error: (_, _) => const <Map<String, dynamic>>[],
        );
    if (perfis.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aguardando o buffet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cadastradas, mas ainda sem pulseira. Leve a criança à recepção do buffet.',
                style: TextStyle(color: PulynColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final perfil in perfis)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hourglass_empty, color: PulynColors.textMuted),
                  title: Text((perfil['apelido'] as String?)?.isNotEmpty == true
                      ? perfil['apelido'] as String
                      : perfil['nome'] as String),
                  subtitle: Text(perfil['buffetNome'] as String? ?? ''),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
