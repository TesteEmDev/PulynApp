import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import 'index.dart';

/// ✅ Provider para buscar evento próximo/atual do usuário
final currentEventProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  try {
    final event = await apiService.getActiveEvent();
    log.i('[EVENT_PROVIDER] ✅ Evento ativo obtido');
    return event;
  } catch (e) {
    log.e('[EVENT_PROVIDER] ❌ Erro ao buscar evento: $e');
    return null;
  }
});

/// ✅ Provider para listar eventos do mês/semana
final upcomingEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  try {
    // TODO: Implementar endpoint GET /api/family/events no backend
    // Por enquanto retorna lista vazia
    log.i('[EVENTS_PROVIDER] 📅 Buscando eventos próximos...');
    return [];
  } catch (e) {
    log.e('[EVENTS_PROVIDER] ❌ Erro ao listar eventos: $e');
    return [];
  }
});

/// ✅ Provider para detalhes de um evento específico
final eventDetailsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, eventId) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  try {
    // TODO: Implementar endpoint GET /api/family/events/:id no backend
    log.i('[EVENT_DETAIL_PROVIDER] 📋 Buscando detalhes do evento: $eventId');
    return null;
  } catch (e) {
    log.e('[EVENT_DETAIL_PROVIDER] ❌ Erro: $e');
    return null;
  }
});

/// ✅ Provider para resultado final do evento
final eventResultsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, eventId) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  try {
    // TODO: Implementar endpoint GET /api/family/events/:id/results no backend
    log.i('[EVENT_RESULTS_PROVIDER] 🏆 Buscando resultados: $eventId');
    return null;
  } catch (e) {
    log.e('[EVENT_RESULTS_PROVIDER] ❌ Erro: $e');
    return null;
  }
});

/// ✅ Provider para gerar certificado
final certificateProvider = FutureProvider.family.autoDispose<String?, String>((ref, eventId) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  try {
    // TODO: Implementar endpoint POST /api/family/events/:id/certificate no backend
    log.i('[CERTIFICATE_PROVIDER] 🎖️ Gerando certificado: $eventId');
    return null;
  } catch (e) {
    log.e('[CERTIFICATE_PROVIDER] ❌ Erro: $e');
    return null;
  }
});
