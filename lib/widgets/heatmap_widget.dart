import 'package:flutter/material.dart';
import '../models/family_models.dart';
import '../config/theme.dart';
import '../utils/logger.dart';

/// 🔥 Widget de Mapa de Calor - Mostra checkpoints conquistados
class CheckpointHeatmapWidget extends StatelessWidget {
  final Child child;

  const CheckpointHeatmapWidget({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data de checkpoints
    final mockCheckpoints = _getMockCheckpoints();
    
    // Filtra checkpoints conquistados
    final conqueredCheckpointNames = child.achievements
        .map((ach) => ach.title)
        .toSet();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${conqueredCheckpointNames.length}/${mockCheckpoints.length} conquistados',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PulynColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: conqueredCheckpointNames.length / mockCheckpoints.length,
                        minHeight: 6,
                        backgroundColor: PulynColors.darkBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(PulynColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Grid de Checkpoints (3 colunas)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: mockCheckpoints.length,
            itemBuilder: (context, index) {
              final checkpoint = mockCheckpoints[index];
              final isConquered = conqueredCheckpointNames.contains(checkpoint['name']);
              
              return _buildCheckpointCard(
                checkpoint: checkpoint,
                isConquered: isConquered,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Constrói card individual do checkpoint
  Widget _buildCheckpointCard({
    required Map<String, dynamic> checkpoint,
    required bool isConquered,
  }) {
    final name = checkpoint['name'] as String;
    final emoji = checkpoint['emoji'] as String;
    
    return Container(
      decoration: BoxDecoration(
        color: isConquered
            ? PulynColors.success.withValues(alpha: 0.2)
            : PulynColors.darkBorder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConquered ? PulynColors.success : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          log.i('[HEATMAP] Tap em checkpoint: $name (Conquistado: $isConquered)');
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isConquered ? PulynColors.success : PulynColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mock de checkpoints (em produção virá do backend)
  List<Map<String, dynamic>> _getMockCheckpoints() {
    return [
      {'name': 'Torre', 'emoji': '🏰'},
      {'name': 'Caverna', 'emoji': '🕳️'},
      {'name': 'Jardim', 'emoji': '🌻'},
      {'name': 'Castelo', 'emoji': '👑'},
      {'name': 'Floresta', 'emoji': '🌲'},
      {'name': 'Praia', 'emoji': '🏖️'},
      {'name': 'Montanha', 'emoji': '⛰️'},
      {'name': 'Rio', 'emoji': '💧'},
      {'name': 'Ponte', 'emoji': '🌉'},
    ];
  }
}
