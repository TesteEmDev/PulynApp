import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../utils/logger.dart';
import '../../providers/index.dart';

final linkedChildrenProvider = FutureProvider<List<Child>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  return await apiService.getChildren();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${child.nickname} desvinculada com sucesso'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Atualizar lista
      ref.invalidate(linkedChildrenProvider);
    } catch (e) {
      log.e('Erro ao desvincullar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao desvincullar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsyncValue = ref.watch(linkedChildrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Crianças'),
        centerTitle: true,
      ),
      body: childrenAsyncValue.when(
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
                                child.nickname.isNotEmpty
                                    ? child.nickname[0].toUpperCase()
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
                                  child.nickname.isNotEmpty
                                      ? child.nickname
                                      : child.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${child.age} anos • ${child.teamName}',
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
                                  title: const Text('Desvincullar?'),
                                  content: Text(
                                    'Deseja desvincullar ${child.nickname.isNotEmpty ? child.nickname : child.name}?',
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
                                        'Desvincullar',
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
    );
  }
}
