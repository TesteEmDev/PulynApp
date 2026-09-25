import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/api_config.dart';
import 'providers/index.dart';
import 'models/family_models.dart';
import 'utils/logger.dart';
import 'screens/auth/invite_entry_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/family_invite_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/child/child_detail_screen.dart';
import 'screens/ranking/ranking_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/family/linked_children_screen.dart';
import 'screens/family/manage_linked_children_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/event/pre_event_screen.dart';
import 'screens/event/event_result_screen.dart';

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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Aguarda a inicialização do auth ANTES de construir o router
    ref.watch(authInitProvider);
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

    return MaterialApp.router(
      title: 'Pulyn Family',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _buildRouter(authState, isFirstTimeAsync, ref),
      builder: (context, child) {
        return _GlobalBackButtonHandler(child: child ?? const SizedBox());
      },
    );
  }

  /// Constrói router baseado no estado de autenticação e primeira execução
  GoRouter _buildRouter(AsyncValue<User?> authState, AsyncValue<bool> isFirstTimeAsync, WidgetRef ref) {
    return authState.when(
      // 🔄 Carregando - mostra tela de splash
      loading: () => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _SplashScreen(),
          ),
        ],
      ),
      // ✅ Usuário autenticado - acesso às rotas da app
      data: (user) => GoRouter(
        initialLocation: user != null ? '/home' : _getInitialLocationForUnauth(isFirstTimeAsync),
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) {
              // Não precisa fazer redireção manual, o GoRouter cuida
              return user != null ? '/home' : _getInitialLocationForUnauth(isFirstTimeAsync);
            },
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
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
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
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
            path: '/notifications',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Notificações')),
              body: const Center(
                child: Text(
                  'Em desenvolvimento...',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
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
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
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

/// ✅ Widget global com Double Back to Exit
/// Requer 2 cliques no botão de voltar para sair do app
class _GlobalBackButtonHandler extends StatefulWidget {
  final Widget child;

  const _GlobalBackButtonHandler({required this.child});

  @override
  State<_GlobalBackButtonHandler> createState() =>
      _GlobalBackButtonHandlerState();
}

class _GlobalBackButtonHandlerState extends State<_GlobalBackButtonHandler> {
  DateTime? _lastBackPressTime;

  Future<bool> _handleBackPressed() async {
    // Se pode voltar para tela anterior, volta
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return false;
    }

    // Estamos na Home (raiz da navegação)
    // Verifique o último clique
    final now = DateTime.now();
    const timeDifference = Duration(seconds: 2);

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > timeDifference) {
      // Primeiro clique
      _lastBackPressTime = now;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clique novamente para sair do app'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      return false; // Não sai do app
    } else {
      // Segundo clique dentro de 2 segundos - sai do app
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await _handleBackPressed();
          if (shouldExit && mounted) {
            // Ignora o resultado e deixa sair (em desenvolvimento)
            // Em produção, use: SystemNavigator.pop()
          }
        }
      },
      child: widget.child,
    );
  }
}
