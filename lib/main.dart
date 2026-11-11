import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/tema_provider.dart';
import 'config/api_config.dart';
import 'providers/index.dart';
import 'models/family_models.dart';
import 'utils/logger.dart';
import 'screens/auth/invite_entry_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/esqueci_senha_screen.dart';
import 'screens/profile/confirmar_email_screen.dart';
import 'screens/profile/alterar_senha_screen.dart';
import 'screens/auth/confirmar_cadastro_screen.dart';
import 'screens/legal/politica_privacidade_screen.dart';
import 'screens/auth/family_invite_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/child/child_detail_screen.dart';
import 'screens/ranking/ranking_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/family/linked_children_screen.dart';
import 'screens/family/manage_linked_children_screen.dart';
import 'screens/family/pre_register_child_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/event/pre_event_screen.dart';
import 'screens/event/my_events_screen.dart';
import 'screens/event/event_result_screen.dart';
import 'widgets/duplo_voltar_para_sair.dart';

// ✅ Provider para detectar primeira execução
final isFirstTimeProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;
  
  if (isFirstTime) {
    log.i('[App] Primeira execução detectada!');
    // Marca que não é mais primeira vez
    await prefs.setBool('isFirstTime', false);
  }
  
  return isFirstTime;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class _AppComTema extends ConsumerWidget {
  final GoRouter router;

  const _AppComTema({required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(temaClaroProvider);
    return MaterialApp.router(
      title: 'Pulyn Family',
      theme: construirTema(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Aguarda a inicialização do auth ANTES de construir o router
    ref.watch(authInitProvider);
    // E-mail de cadastro pendente: o roteador abre a confirmação (sem depender de navegação feita antes).
    ref.watch(cadastroPendenteProvider);
    final authState = ref.watch(authProvider);
    final isFirstTimeAsync = ref.watch(isFirstTimeProvider);

    // ✅ Conecta WebSocket quando usuário faz login
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          log.i('[App] Usuário logado, conectando WebSocket...');
          ref.read(webSocketConnectionProvider.notifier).reconnect();
        } else {
          log.i('[App] Usuário deslogado, desconectando WebSocket...');
          ref.read(webSocketConnectionProvider.notifier).disconnect();
        }
      });
    });

    // O roteador só é recriado quando a sessão muda. A troca de tema fica no widget de dentro,
    // que reconstrói o MaterialApp com o mesmo roteador e não volta para a tela inicial.
    return _AppComTema(router: _buildRouter(authState, isFirstTimeAsync, ref));
  }

  /// Constrói router baseado no estado de autenticação e primeira execução
  GoRouter _buildRouter(AsyncValue<User?> authState, AsyncValue<bool> isFirstTimeAsync, WidgetRef ref) {
    GoRouter roteadorSplash() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _SplashScreen(),
        ),
      ],
    );

    // Sem sessão, a rota inicial depende de "é a primeira vez?". Na primeira abertura essa leitura
    // grava no disco antes de responder e termina depois da sessão. Se o roteador fosse montado antes,
    // ele nasceria em /login e seria trocado por outro em /onboarding logo em seguida; duas trocas
    // seguidas deixavam a tela vazia até fechar e abrir o app. Por isso o splash segue até a resposta.
    final semSessao = !authState.hasError && !authState.isLoading && authState.valueOrNull == null;
    if (semSessao && isFirstTimeAsync.isLoading) return roteadorSplash();

    return authState.when(
      // 🔄 Carregando - mostra tela de splash
      loading: roteadorSplash,
      // ✅ Usuário autenticado - acesso às rotas da app
      data: (user) => GoRouter(
        initialLocation: user != null ? '/home' : _localInicialSemSessao(isFirstTimeAsync, ref),
        redirect: (context, state) {
          if (user != null) return null;
          final pendente = ref.read(cadastroPendenteProvider);
          if (pendente == null || state.uri.path == '/confirmar-cadastro') return null;
          return '/confirmar-cadastro?email=${Uri.encodeComponent(pendente)}';
        },
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) {
              // Não precisa fazer redireção manual, o GoRouter cuida
              return user != null ? '/home' : _localInicialSemSessao(isFirstTimeAsync, ref);
            },
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const DuploVoltarParaSair(child: LoginScreen()),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/esqueci-senha',
            builder: (context, state) => const EsqueciSenhaScreen(),
          ),
          GoRoute(
            path: '/confirmar-email',
            builder: (context, state) => const ConfirmarEmailScreen(),
          ),
          GoRoute(
            path: '/confirmar-cadastro',
            builder: (context, state) => ConfirmarCadastroScreen(
              email: state.uri.queryParameters['email'] ?? (state.extra as String?) ?? '',
              codigoInicial: state.uri.queryParameters['codigo'],
            ),
          ),
          GoRoute(
            path: '/politica-privacidade',
            builder: (context, state) => const PoliticaPrivacidadeScreen(),
          ),
          GoRoute(
            path: '/alterar-senha',
            builder: (context, state) => const AlterarSenhaScreen(),
          ),
          GoRoute(
            path: '/invite',
            builder: (context, state) => const InviteEntryScreen(),
          ),
          GoRoute(
            path: '/family/invite/:token',
            builder: (context, state) {
              var token = state.pathParameters['token'];
              log.i('[FamilyInvite] Token recebido (bruto): $token');
              
              // ✅ Se o token contém URL completa, extrai apenas o token
              if (token != null && token.contains('/family/invite/')) {
                token = token.split('/family/invite/').last;
                log.i('[FamilyInvite] Token extraído de URL completa: $token');
              }
              
              if (token == null || token.isEmpty) {
                log.w('[FamilyInvite] Token vazio, voltando para login');
                return const InviteEntryScreen();
              }
              
              return FamilyInviteScreen(token: token);
            },
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const DuploVoltarParaSair(child: OnboardingScreen()),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const DuploVoltarParaSair(child: HomeScreen()),
          ),
          GoRoute(
            path: '/child/:id',
            builder: (context, state) {
              final childId = state.pathParameters['id'];
              
              // ✅ Valida se childId existe
              if (childId == null || childId.isEmpty) {
                // Redireciona para home se ID está faltando
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.go('/home');
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              return ChildDetailScreen(childId: childId);
            },
          ),
          GoRoute(
            path: '/ranking',
            builder: (context, state) => const RankingScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/linked-children',
            builder: (context, state) {
              return LinkedChildrenScreen(
                apiUrl: ApiConfig.getApiBaseUrl(),
              );
            },
          ),
          GoRoute(
            path: '/manage-children',
            builder: (context, state) {
              return const ManageLinkedChildrenScreen();
            },
          ),
          GoRoute(
            path: '/pre-register-child',
            builder: (context, state) => const PreRegisterChildScreen(),
          ),
          GoRoute(
            path: '/my-events',
            builder: (context, state) => const MyEventsScreen(),
          ),
          GoRoute(
            path: '/pre-event',
            builder: (context, state) {
              final event = state.extra as Map<String, dynamic>?;
              if (event == null) {
                return const HomeScreen();
              }
              return PreEventScreen(event: event);
            },
          ),
          GoRoute(
            path: '/event-result',
            builder: (context, state) {
              final event = state.extra as Map<String, dynamic>?;
              if (event == null) {
                return const HomeScreen();
              }
              return EventResultScreen(event: event);
            },
          ),
        ],
      ),
      // ❌ Erro ou sem autenticação - tela de login
      error: (error, stack) => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) => '/login',
            builder: (context, state) => const DuploVoltarParaSair(child: LoginScreen()),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const DuploVoltarParaSair(child: LoginScreen()),
          ),
          GoRoute(
            path: '/invite',
            builder: (context, state) => const InviteEntryScreen(),
          ),
        ],
      ),
    );
  }

  /// Determina a rota inicial para usuário não autenticado
  String _localInicialSemSessao(AsyncValue<bool> isFirstTimeAsync, WidgetRef ref) {
    final pendente = ref.read(cadastroPendenteProvider);
    if (pendente != null) return '/confirmar-cadastro?email=${Uri.encodeComponent(pendente)}';
    return _getInitialLocationForUnauth(isFirstTimeAsync);
  }

  String _getInitialLocationForUnauth(AsyncValue<bool> isFirstTimeAsync) {
    return isFirstTimeAsync.when(
      data: (isFirstTime) => isFirstTime ? '/onboarding' : '/login',
      loading: () => '/login',
      error: (_, _) => '/login',
    );
  }
}

/// Tela de carregamento (splash)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo-pulyn.png',
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'Pulyn Family',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
