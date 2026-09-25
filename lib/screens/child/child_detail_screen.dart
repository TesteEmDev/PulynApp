import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/family_models.dart';
import '../../providers/index.dart';

class ChildDetailScreen extends ConsumerStatefulWidget {
  final String childId;

  const ChildDetailScreen({
    super.key,
    required this.childId,
  });

  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  Future<void> _refreshData() async {
    ref.invalidate(childDetailProvider(widget.childId));
    ref.invalidate(childAchievementsProvider(widget.childId));
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(childDetailProvider(widget.childId));
    final achievementsState = ref.watch(childAchievementsProvider(widget.childId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil da Criança'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        backgroundColor: PulynColors.darkCard,
        color: PulynColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Child Header
            childState.when(
              loading: () => _buildHeaderSkeleton(),
              error: (error, stack) => _buildErrorCard('Erro ao carregar perfil'),
              data: (child) {
                if (child == null) {
                  return _buildEmptyState(
                    'Criança não encontrada',
                    'O perfil desta criança não foi encontrado.',
                  );
                }
                return _buildChildHeaderCard(child);
              },
            ),
            const SizedBox(height: 24),

            // Stats Grid
            Text(
              'Estatísticas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            childState.when(
              loading: () => const SizedBox(height: 150),
              error: (_, _) => const SizedBox(),
              data: (child) {
                if (child == null) return const SizedBox();
                return _buildStatsCards(child);
              },
            ),
            const SizedBox(height: 24),

            // Achievements
            Text(
              'Conquistas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            achievementsState.when(
              loading: () => _buildLoadingList(),
              error: (error, stack) => _buildErrorCard('Erro ao carregar conquistas'),
              data: (achievements) {
                if (achievements.isEmpty) {
                  return _buildEmptyState(
                    'Nenhuma conquista ainda',
                    'As conquistas aparecerão aqui quando a criança conquistar!',
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    return _buildAchievementCard(achievements[index]);
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.danger, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error, color: PulynColors.danger, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: PulynColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String description) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: PulynColors.textMuted),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PulynColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: PulynColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PulynColors.darkBorder),
          ),
          padding: const EdgeInsets.all(16),
          height: 80,
        );
      },
    );
  }

  Widget _buildChildHeaderCard(Child child) {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(int.parse(
                '0xFF${child.teamColor.replaceFirst('#', '')}',
              )),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                child.nickname.isNotEmpty ? child.nickname[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.nickname.isNotEmpty ? child.nickname : child.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  child.teamName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: PulynColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: PulynColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${child.currentScore} pontos',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PulynColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Child child) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          title: 'Pontos',
          value: '${child.currentScore}',
          icon: Icons.star_outlined,
          color: PulynColors.primary,
        ),
        _buildStatCard(
          title: 'Time',
          value: child.teamName,
          icon: Icons.group_outlined,
          color: PulynColors.accent,
        ),
        _buildStatCard(
          title: 'Idade',
          value: '${child.age} anos',
          icon: Icons.cake_outlined,
          color: PulynColors.success,
        ),
        _buildStatCard(
          title: 'Status',
          value: 'Ativo',
          icon: Icons.check_circle_outlined,
          color: PulynColors.warning,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: PulynColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: PulynColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: PulynColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: PulynColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
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
    );
  }
}

// Providers
final childDetailProvider = FutureProvider.autoDispose
    .family<Child?, String>((ref, childId) async {
  final apiService = ref.watch(apiServiceProvider);
  await apiService.init();
  final children = await apiService.getChildren();
  try {
    return children.firstWhere((c) => c.id == childId);
  } catch (e) {
    return null;
  }
});

final childAchievementsProvider = FutureProvider.autoDispose
    .family<List<Achievement>, String>((ref, childId) async {
  final apiService = ref.watch(apiServiceProvider);
  await apiService.init();
  return await apiService.getChildAchievements(childId);
});
