import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/auth/auth_screen.dart';
import 'features/contractor/contractor_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/project/project_screen.dart';
import 'features/requests/requests_screen.dart';
import 'features/shared/account_screens.dart';
import 'features/shared/onboarding_view.dart';
import 'features/updates/update_detail_screen.dart';
import 'features/updates/updates_screen.dart';
import 'providers/auth.dart';
import 'providers/data.dart';
import 'widgets/common.dart';
import 'widgets/branding.dart';

/// Re-runs router redirects whenever auth or onboarding state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/onboarding', '/login', '/signup', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final seen = ref.read(onboardingSeenProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading || seen.isLoading) return loc == '/splash' ? null : '/splash';

      final loggedIn = auth.value != null;
      if (!loggedIn) {
        if (seen.value != true) return loc == '/onboarding' ? null : '/onboarding';
        // Onboarding finished (Skip / Get Started): move on to login.
        if (loc == '/onboarding' || loc == '/splash') return '/login';
        return _publicRoutes.contains(loc) ? null : '/login';
      }
      if (_publicRoutes.contains(loc) || loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/onboarding', builder: (_, _) => const _Onboarding()),
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const AuthScreen(signup: true)),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      StatefulShellRoute(
        // Tabs stay alive but cross-fade when switching (see FadingTabsContainer).
        navigatorContainerBuilder: (context, shell, children) => FadingTabsContainer(index: shell.currentIndex, children: children),
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/updates', builder: (_, _) => const UpdatesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/contractor', builder: (_, _) => const ContractorTab())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/join', builder: (_, _) => const JoinProjectScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const ClientEditProfileScreen()),
      GoRoute(path: '/profile/password', builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/projects/:id', builder: (_, s) => ProjectScreen(projectId: s.pathParameters['id']!)),
      GoRoute(
        path: '/projects/:id/updates',
        builder: (_, s) => UpdatesScreen(initialProjectId: s.pathParameters['id'], standalone: true),
      ),
      GoRoute(
        path: '/projects/:id/requests',
        builder: (_, s) => RequestsScreen(projectId: s.pathParameters['id']!, updateId: s.uri.queryParameters['updateId']),
      ),
      GoRoute(path: '/updates/:id', builder: (_, s) => UpdateDetailScreen(updateId: s.pathParameters['id']!)),
      GoRoute(path: '/requests/:id', builder: (_, s) => RequestDetailScreen(requestId: s.pathParameters['id']!)),
      GoRoute(path: '/contractor/:id', builder: (_, s) => ContractorScreen(engineerId: s.pathParameters['id']!)),
      GoRoute(
        path: '/contractor/:id/projects/:projectId',
        builder: (_, s) => CaseStudyScreen(engineerId: s.pathParameters['id']!, projectId: s.pathParameters['projectId']!),
      ),
    ],
  );
});

class _Splash extends ConsumerWidget {
  const _Splash();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.hasError) {
      // Server unreachable while restoring the session.
      return Scaffold(body: ErrorView(error: auth.error!, onRetry: () => ref.invalidate(authProvider)));
    }
    return const BrandSplash();
  }
}

class _Onboarding extends ConsumerWidget {
  const _Onboarding();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingView(
      onDone: () => ref.read(onboardingSeenProvider.notifier).markSeen(),
      slides: const [
        OnboardingSlide(
          title: 'Follow your build, every day',
          body: 'See what happened on site today without calling anyone.',
          art: OnboardingArtCard(),
        ),
        OnboardingSlide(
          title: 'Every photo, in order',
          body: 'A clear dated record of the work, from the first day to handover.',
          art: OnboardingArtTimeline(),
        ),
        OnboardingSlide(
          title: 'Ask or approve in one tap',
          body: 'Request a change or say it looks good. Your contractor sees it right away.',
          art: OnboardingArtActions(),
        ),
      ],
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        index: shell.currentIndex,
        badges: {3: unread},
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: const [
          NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
          NavItem(Icons.photo_library_outlined, Icons.photo_library, 'Updates'),
          NavItem(Icons.engineering_outlined, Icons.engineering, 'Contractor'),
          NavItem(Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }
}
