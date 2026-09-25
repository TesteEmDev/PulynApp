import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/index.dart';
import '../../utils/logger.dart';
import '../onboarding/onboarding_screen.dart';
import '../event/pre_event_screen.dart';
import '../event/event_result_screen.dart';
import 'home_screen.dart';

/// 🎯 EVENT PHASE ROUTER
/// 
/// Detecta automaticamente em qual fase do evento o usuário está
/// e renderiza a tela apropriada:
/// 
/// FASE 1: Sem evento → Onboarding (primeira vez)
/// FASE 2: status='scheduled' → Pre-Event Screen
/// FASE 3: status='active' → Event Live Map (existente)
/// FASE 4: status='completed' → Event Result Screen

class EventPhaseRouter extends ConsumerWidget {
  final bool isFirstTime;

  const EventPhaseRouter({
    super.key,
    this.isFirstTime = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(currentEventProvider);

    return eventAsync.when(
      // 🔄 Carregando
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),

      // ❌ Erro
      error: (error, stack) {
        log.e('[EVENT_PHASE_ROUTER] ❌ Erro: $error');
        return Scaffold(
          body: Center(
            child: Text('Erro: $error'),
          ),
        );
      },

      // ✅ Dados carregados - detectar fase
      data: (event) {
        // FASE 1: Primeira vez / Sem evento
        if (event == null && isFirstTime) {
          log.i('[EVENT_PHASE_ROUTER] 📍 FASE 1: ONBOARDING (primeira vez)');
          return const OnboardingScreen();
        }

        // Sem evento - Home
        if (event == null) {
          log.i('[EVENT_PHASE_ROUTER] 📍 HOME (sem evento)');
          return const HomeScreen();
        }

        // Detectar status do evento
        final status = event['status'] as String? ?? 'unknown';
        log.i('[EVENT_PHASE_ROUTER] 📊 Status do evento: $status');

        switch (status) {
          // FASE 2: Evento agendado
          case 'scheduled':
            log.i('[EVENT_PHASE_ROUTER] 📍 FASE 2: PRÉ-FESTA (scheduled)');
            return PreEventScreen(event: event);

          // FASE 3: Evento ativo
          case 'active':
            log.i('[EVENT_PHASE_ROUTER] 📍 FASE 3: DURANTE A FESTA (active)');
            // Ir para Event Live Map (já existe)
            // Usar context.go para navegação
            Future.microtask(() {
              context.go('/event-map');
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

          // FASE 4: Evento encerrado
          case 'completed':
            log.i('[EVENT_PHASE_ROUTER] 📍 FASE 4: PÓS-FESTA (completed)');
            return EventResultScreen(event: event);

          // Default
          default:
            log.w('[EVENT_PHASE_ROUTER] ⚠️ Status desconhecido: $status');
            return const HomeScreen();
        }
      },
    );
  }
}

/// Widget wrapper que detecta primeira execução
class EventPhaseRouterWrapper extends ConsumerWidget {
  const EventPhaseRouterWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const isFirstTime = false;

    return EventPhaseRouter(isFirstTime: isFirstTime);
  }
}
