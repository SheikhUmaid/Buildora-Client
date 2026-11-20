import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth.dart';
import '../../providers/data.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../shared/account_screens.dart';
import '../../widgets/branding.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _filter = 0; // All, In progress, Completed

  Future<void> _refresh() async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(notificationsProvider);
    final _ = await ref.refresh(projectsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final projects = ref.watch(projectsProvider);
    final dash = ref.watch(dashboardProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(
                children: [
                  const BuildoraLogo(size: 22),
                  const Spacer(),
                  const NotificationBell(),
                  const SizedBox(width: 8),
                  Tappable(radius: 10, scale: 0.9, onTap: () => context.go('/profile'), child: Avatar(name: user?.name ?? '', size: 40, square: true)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Welcome back', style: AppText.label),
              Text(user?.name.split(' ').first ?? '', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Your projects', style: AppText.h1)),
                  AppChip(label: 'Join', dense: true, trailing: const Icon(Icons.add, size: 16), onTap: () => context.push('/join')),
                ],
              ),
              const SizedBox(height: 16),
              StatStrip(items: [
                (Fmt.pad2((dash?['activeProjects'] as num?)?.toInt() ?? 0), 'Active projects'),
                ('${(dash?['totalUpdates'] as num?)?.toInt() ?? 0}', 'Total updates'),
                ('${(dash?['openRequests'] as num?)?.toInt() ?? 0}', 'Open requests'),
              ]),
              const SizedBox(height: 20),
              ChipFilterBar(
                padding: EdgeInsets.zero,
                options: const ['All', 'In progress', 'Completed'],
                selected: _filter,
                onSelected: (i) => setState(() => _filter = i),
              ),
              const SizedBox(height: 16),
              projects.when(
                skipLoadingOnRefresh: true,
                loading: () => LoadingView(skeleton: Skeleton.projects(padding: EdgeInsets.zero)),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(projectsProvider)),
                data: (all) {
                  if (all.isEmpty) {
                    return EmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'No projects yet',
                      message: 'Ask your contractor for the 6-character invite code to start following your build.',
                      action: AppButton(label: 'Join a project', expand: false, onPressed: () => context.push('/join')),
                    );
                  }
                  final list = switch (_filter) {
                    1 => all.where((p) => !p.isCompleted).toList(),
                    2 => all.where((p) => p.isCompleted).toList(),
                    _ => all,
                  };
                  if (list.isEmpty) {
                    return const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'Nothing here', message: 'No projects match this filter.');
                  }
                  return Column(
                    children: [
                      for (final p in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ProjectCard(project: p, onTap: () => context.push('/projects/${p.id}')),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enter an invite code to join an engineer's project.
class JoinProjectScreen extends ConsumerStatefulWidget {
  const JoinProjectScreen({super.key});
  @override
  ConsumerState<JoinProjectScreen> createState() => _JoinProjectScreenState();
}

class _JoinProjectScreenState extends ConsumerState<JoinProjectScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 6) return showSnack(context, 'Invite codes are 6 characters', error: true);
    setState(() => _busy = true);
    try {
      final project = await ref.read(repoProvider).joinProject(code);
      if (!mounted) return;
      showSnack(context, 'You joined ${project.name}');
      context.pushReplacement('/projects/${project.id}');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BackCircle()),
            const SizedBox(height: 32),
            const Text('Invite code', style: AppText.label),
            const SizedBox(height: 4),
            const Text('Join your project', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            const Text('Your contractor shares a 6-character code from the Buildora On-site app.', style: AppText.muted),
            const SizedBox(height: 32),
            TextField(
              controller: _code,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 30, letterSpacing: 10, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: const TextStyle(color: AppColors.textFaint, letterSpacing: 10),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 22),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 32),
            AppButton(label: 'Join project', orangeArrow: true, loading: _busy, onPressed: _join),
          ],
        ),
      ),
    );
  }
}
