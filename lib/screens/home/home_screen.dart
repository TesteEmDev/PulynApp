import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../models/family_models.dart';
import '../../config/theme.dart';
import '../qr_scan/qr_scanner_screen.dart';
import '../../widgets/event_map_widget.dart';
import '../../utils/logger.dart';

// ✅ Notifier para trigger manual de refresh
class ChildrenRefreshNotifier extends StateNotifier<int> {
  ChildrenRefreshNotifier() : super(0);
  
  void refresh() {
    state++;
  }
}

final childrenRefreshProvider = StateNotifierProvider((ref) {
  return ChildrenRefreshNotifier();
});

// ✅ StreamProvider com polling automático - SOLUÇÃO REALTIME!
final childrenProvider = StreamProvider.autoDispose<List<Child>>((ref) async* {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  // ✅ Watch o refresh notifier para refetch quando necessário
  ref.watch(childrenRefreshProvider);
  
  // ✅ Carrega dados INICIALMENTE
  try {
    final children = await apiService.getChildren();
    yield children;
  } catch (e) {
    yield [];
  }
  
  // ✅ Polling automático a cada 10 segundos para verificar mudanças
  while (true) {
    await Future.delayed(const Duration(seconds: 10));
    try {
      final children = await apiService.getChildren();
      yield children;
    } catch (e) {
      // Silencioso
    }
  }
});

// ✅ StreamProvider para ranking
final childrenRankingProvider = StreamProvider.autoDispose<List<Child>>((ref) async* {
  final apiService = ref.watch(apiServiceProvider);
  await apiService.init();
  
  ref.watch(childrenRefreshProvider);
  
  try {
    final children = await apiService.getChildren();
    yield children;
  } catch (e) {
    yield [];
  }
  
  // ✅ Polling automático para ranking
  while (true) {
    await Future.delayed(const Duration(seconds: 10));
    try {
      final children = await apiService.getChildren();
      yield children;
    } catch (e) {
      // Silencioso
    }
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // ✅ Setup para trigger refresh quando WebSocket envia eventos
    Future.microtask(() {
      ref.read(webSocketServiceProvider).on('SCORE_UPDATE', (data) {
        ref.read(childrenRefreshProvider.notifier).refresh();
      });
      
      ref.read(webSocketServiceProvider).on('TERRITORY_CONQUERED', (data) {
        ref.read(childrenRefreshProvider.notifier).refresh();
      });
      
      ref.read(webSocketServiceProvider).on('RANKING_UPDATE', (data) {
        ref.read(childrenRefreshProvider.notifier).refresh();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          // Página 0: Home
          _buildHomeTab(context, ref),
          // Página 1: Ranking
          _buildRankingTab(),
          // Página 2: Profile
          _buildProfileTab(context, ref),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_outlined),
            label: 'Ranking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'Perfil',
          ),
        ],
        onTap: _onNavTap,
      ),
    );
  }

  // ===== HOME TAB =====
  Widget _buildHomeTab(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: null,
        elevation: 0,
        actions: [
          // Removed notifications button - feature not implemented
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(context, ref),
              const SizedBox(height: 16),
              _buildEventMapSection(context, ref),
              const SizedBox(height: 20),
              _buildChildrenListFromAPI(context, ref),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===== RANKING TAB =====
  Widget _buildRankingTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        elevation: 0,
      ),
      body: _buildRankingContent(),
    );
  }

  Widget _buildRankingContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Crianças', icon: Icon(Icons.person_outline)),
              Tab(text: 'Times', icon: Icon(Icons.people_outline)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildChildrenRankingTab(),
                _buildTeamsRankingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenRankingTab() {
    final childrenState = ref.watch(childrenRankingProvider);

    return childrenState.when(
      loading: () => _buildLoadingList(),
      error: (_, _) => _buildErrorRanking('Erro ao carregar ranking'),
      data: (children) {
        if (children.isEmpty) {
          return _buildEmptyState('Sem dados');
        }
        final sorted = [...children]..sort((a, b) => b.currentScore.compareTo(a.currentScore));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final child = sorted[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRankingCard(
                position: index + 1,
                name: child.nickname.isNotEmpty ? child.nickname : child.name,
                score: child.currentScore,
                teamColor: child.teamColor,
                medal: _getMedalForPosition(index),
                isTop: index < 3,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsRankingTab() {
    final childrenState = ref.watch(childrenRankingProvider);

    return childrenState.when(
      loading: () => _buildLoadingList(),
      error: (_, _) => _buildErrorRanking('Erro ao carregar times'),
      data: (children) {
        final teamsMap = <String, (String, int, String)>{};
        for (final child in children) {
          if (teamsMap.containsKey(child.teamName)) {
            final (name, score, color) = teamsMap[child.teamName]!;
            teamsMap[child.teamName] = (name, score + child.currentScore, color);
          } else {
            teamsMap[child.teamName] = (child.teamName, child.currentScore, child.teamColor);
          }
        }

        if (teamsMap.isEmpty) {
          return _buildEmptyState('Sem times');
        }

        final sorted = teamsMap.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final (teamName, totalScore, teamColor) = sorted[index].value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTeamRankingCard(
                position: index + 1,
                name: teamName,
                score: totalScore,
                teamColor: teamColor,
                medal: _getMedalForPosition(index),
                isTop: index < 3,
              ),
            );
          },
        );
      },
    );
  }

  // ===== PROFILE TAB =====
  Widget _buildProfileTab(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        elevation: 0,
      ),
      body: Center(
        child: authState.when(
          data: (user) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: PulynColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    user?.name[0].toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  user?.name ?? 'Usuário',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PulynColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => context.go('/manage-children'),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Gerenciar Crianças'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulynColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('Erro ao carregar perfil'),
        ),
      ),
    );
  }

  /// 🗺️ Event Map Section - Mostra o mapa do buffet com territórios
  Widget _buildEventMapSection(BuildContext context, WidgetRef ref) {
    final childrenAsyncValue = ref.watch(childrenProvider);
    final activeEventAsync = ref.watch(activeEventProvider);
    final activeGameAsync = ref.watch(activeGameProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mapa do Buffet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        childrenAsyncValue.when(
          loading: () => _buildMapLoadingState(),
          error: (error, _) => _buildMapErrorState(),
          data: (children) {
            // ✅ Log crítico: quantas crianças foram carregadas?
            log.i('📍 [HOME_SCREEN] _buildEventMapSection - Crianças carregadas: ${children.length}');
            if (children.isNotEmpty) {
              for (var child in children) {
                log.i('   - ${child.nickname}: evento_id=${child.evento_id}');
              }
            }
            
            if (children.isEmpty) {
              return _buildMapEmptyState();
            }

            final activeEvent = activeEventAsync.value;
            final activeGame = activeGameAsync.value;

            return EventMapWidget(
              childrenList: children,
              eventoId: activeEvent?['id'],
              activeGame: activeGame,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapLoadingState() {
    return Container(
      height: 380, // Altura reduzida após remoção dos filtros
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMapErrorState() {
    return Container(
      height: 380, // Altura reduzida após remoção dos filtros
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.danger),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: PulynColors.danger, size: 48),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar mapa',
              style: TextStyle(color: PulynColors.danger),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapEmptyState() {
    return Container(
      height: 380, // Altura reduzida após remoção dos filtros
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: PulynColors.textMuted, size: 48),
            SizedBox(height: 16),
            Text(
              'Mapa aparecerá quando você vincular filhos',
              style: TextStyle(color: PulynColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== HELPER WIDGETS =====
  
  /// 📱 Welcome Card Compacto
  Widget _buildWelcomeCard(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PulynColors.primary, PulynColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: PulynColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: authState.when(
              data: (user) => Text(
                'Olá, ${(user?.name ?? 'Usuário').split(' ').first}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              error: (_, _) => const Text(
                'Olá! 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              loading: () => const Text(
                'Carregando...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Icon(
            Icons.family_restroom,
            color: Colors.white70,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenListFromAPI(BuildContext context, WidgetRef ref) {
    final childrenAsyncValue = ref.watch(childrenProvider);

    return childrenAsyncValue.when(
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorHome(error),
      data: (children) => _buildChildrenCards(context, children),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seus Filhos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorHome(Object error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seus Filhos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: PulynColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PulynColors.danger, width: 2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: PulynColors.danger, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Erro ao carregar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: PulynColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenCards(BuildContext context, List<Child> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seus Filhos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.95,
                    child: QRScannerScreen(
                      apiUrl: 'http://localhost:3001',
                      onChildLinked: (child) {
                        Navigator.pop(context);
                        Future.microtask(() {
                          // ✅ Triggerupdates ao adicionar filho
                          ref.read(childrenRefreshProvider.notifier).refresh();
                        });
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Vincular'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PulynColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: PulynColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PulynColors.darkBorder),
            ),
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.person_outline, size: 56, color: PulynColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum filho vinculado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PulynColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.95,
                          child: QRScannerScreen(
                            apiUrl: 'http://localhost:3001',
                            onChildLinked: (child) {
                              Navigator.pop(context);
                              Future.microtask(() {
                                // ✅ Triggerupdates ao adicionar filho
                                ref.read(childrenRefreshProvider.notifier).refresh();
                              });
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Escanear QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulynColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: children
                .map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildChildCard(context, child),
                    ))
                .toList(),
          ),
      ],
    );
  }

  /// 🎨 Child Card Compacto
  Widget _buildChildCard(BuildContext context, Child child) {
    final teamColor = Color(int.parse('0xFF${child.teamColor.replaceFirst('#', '')}'));
    
    return GestureDetector(
      onTap: () => context.go('/child/${child.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PulynColors.darkCard,
              PulynColors.darkCard.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PulynColors.darkBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            /// Avatar Menor
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    teamColor,
                    teamColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: teamColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  child.nickname.isNotEmpty ? child.nickname[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            /// Info Compacta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    child.nickname.isNotEmpty ? child.nickname : child.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PulynColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${child.age} anos • ${child.teamName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PulynColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            /// Score Badge Compacto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PulynColors.accent.withValues(alpha: 0.2),
                    PulynColors.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PulynColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${child.currentScore}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PulynColors.accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'pts',
                    style: TextStyle(
                      fontSize: 10,
                      color: PulynColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: PulynColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _getMedalForPosition(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '${index + 1}';
    }
  }

  Widget _buildRankingCard({
    required int position,
    required String name,
    required int score,
    required String teamColor,
    required String medal,
    required bool isTop,
  }) {
    final color = Color(int.parse('0xFF${teamColor.replaceFirst('#', '')}'));
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTop
              ? [
                  PulynColors.darkSurface,
                  PulynColors.darkSurface.withValues(alpha: 0.8),
                ]
              : [
                  PulynColors.darkCard,
                  PulynColors.darkCard.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop ? PulynColors.primary : PulynColors.darkBorder,
          width: isTop ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isTop ? PulynColors.primary : Colors.black)
                .withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                )
              ],
            ),
            child: Center(
              child: Text(
                medal,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Posição #$position',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PulynColors.primary.withValues(alpha: 0.2),
                  PulynColors.primary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PulynColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.primary,
                  ),
                ),
                const Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildTeamRankingCard({
    required int position,
    required String name,
    required int score,
    required String teamColor,
    required String medal,
    required bool isTop,
  }) {
    final color = Color(int.parse('0xFF${teamColor.replaceFirst('#', '')}'));
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTop
              ? [
                  PulynColors.darkSurface,
                  PulynColors.darkSurface.withValues(alpha: 0.8),
                ]
              : [
                  PulynColors.darkCard,
                  PulynColors.darkCard.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop ? PulynColors.primary : PulynColors.darkBorder,
          width: isTop ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isTop ? PulynColors.primary : Colors.black)
                .withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                )
              ],
            ),
            child: Center(
              child: Text(
                medal,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Pontos totais',
                  style: TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PulynColors.accent,
                ),
              ),
              const Text(
                'pontos',
                style: TextStyle(
                  fontSize: 11,
                  color: PulynColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: PulynColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PulynColors.darkBorder),
          ),
          height: 80,
        ),
      ),
    );
  }

  Widget _buildErrorRanking(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: PulynColors.danger),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: PulynColors.textMuted),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
