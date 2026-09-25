import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 🎯 FASE 2: PRÉ-FESTA SCREEN
/// Mostra quando: Evento tem status 'scheduled' (antes de iniciar)
/// Objetivo: Check-in, vincular filhos, aguardar início do evento

class PreEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const PreEventScreen({
    super.key,
    required this.event,
  });

  @override
  State<PreEventScreen> createState() => _PreEventScreenState();
}

class _PreEventScreenState extends State<PreEventScreen> {
  late DateTime _eventStartTime;
  Duration? _timeUntilStart;

  @override
  void initState() {
    super.initState();
    _eventStartTime = DateTime.parse(widget.event['startTime'] as String? ?? '');
    _updateCountdown();
    
    // Atualiza contador a cada segundo
    _countdownTimer = Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _updateCountdown());
      }
      return true;
    });
  }

  late Future<void> _countdownTimer;
  
  Map<String, dynamic> get event => widget.event;

  void _updateCountdown() {
    final now = DateTime.now();
    final difference = _eventStartTime.difference(now);
    
    if (difference.isNegative) {
      _timeUntilStart = Duration.zero;
    } else {
      _timeUntilStart = difference;
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration == Duration.zero) {
      return 'Começando agora!';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min $seconds s';
  }

  @override
  void dispose() {
    _countdownTimer.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = (event['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final eventName = event['name'] as String? ?? 'Evento';
    final location = event['location'] as String? ?? 'Local desconhecido';
    final userArrived = event['userArrived'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Festa'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card principal do evento
              _EventHeaderCard(
                eventName: eventName,
                location: location,
                timeUntilStart: _timeUntilStart ?? Duration.zero,
                formatCountdown: _formatCountdown,
              ),
              const SizedBox(height: 24),

              // Status de chegada
              if (!userArrived)
                _ArrivalWarning()
              else
                _ArrivalConfirmed(),
              const SizedBox(height: 24),

              // Seção de filhos
              Text(
                '👥 SEUS FILHOS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              if (children.isEmpty)
                _EmptyChildrenMessage()
              else
                ...children.map((child) => _ChildCard(
                  child: child,
                  key: ValueKey(child['id']),
                )),

              const SizedBox(height: 24),

              // Botões de ação
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/qr-scan');
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Vincular Mais Filhos'),
                ),
              ),
              const SizedBox(height: 12),

              if (userArrived)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Vai para Event Live Map (Fase 3)
                      context.pushReplacement('/event-map');
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Entrar na Festa'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget para header do evento
class _EventHeaderCard extends StatelessWidget {
  final String eventName;
  final String location;
  final Duration timeUntilStart;
  final String Function(Duration) formatCountdown;

  const _EventHeaderCard({
    required this.eventName,
    required this.location,
    required this.timeUntilStart,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            eventName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Localização
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Contador regressivo
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Começa em: ${formatCountdown(timeUntilStart)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget indicando que usuário chegou
class _ArrivalConfirmed extends StatelessWidget {
  const _ArrivalConfirmed();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ Você chegou!',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pronto para a festa começar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
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

/// Widget alertando que usuário não chegou
class _ArrivalWarning extends StatelessWidget {
  const _ArrivalWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.location_searching, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 Ainda não chegou',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chegue perto da festa para continuar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
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

/// Card com informações do filho
class _ChildCard extends StatelessWidget {
  final Map<String, dynamic> child;

  const _ChildCard({
    required this.child,
    required Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = child['name'] as String? ?? 'Criança';
    final age = child['age'] as int? ?? 0;
    final team = child['team'] as Map<String, dynamic>? ?? {};
    final teamName = team['name'] as String? ?? 'Sem time';
    final teamColor = team['color'] as String?;
    final status = child['status'] as String? ?? 'unknown';

    final statusIcon = status == 'ready' ? '✅' : '⏳';
    final statusText = status == 'ready' ? 'Pronto' : 'Aguardando';
    final statusColor = status == 'ready' ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: teamColor != null ? Color(int.parse('0xff${teamColor.replaceFirst('#', '')}')).withValues(alpha: 0.2) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('👦', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          const SizedBox(width: 12),

          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$age anos • Time $teamName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),

          // Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusIcon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mensagem quando não há filhos vinculados
class _EmptyChildrenMessage extends StatelessWidget {
  const _EmptyChildrenMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '👶',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum filho vinculado',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escaneie o QR code da criança para vinculá-la',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
