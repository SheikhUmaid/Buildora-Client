import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../providers/auth.dart';
import '../../widgets/branding.dart';
import '../../widgets/common.dart';
import '../shared/account_screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Scaffold(body: LoadingView());
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            const PageHeader(title: 'Profile', showBack: false, trailing: NotificationBell()),
            const SizedBox(height: 8),
            Center(child: Avatar(name: user.name, size: 104)),
            const SizedBox(height: 16),
            Text(user.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            Text(user.phone.isNotEmpty ? user.phone : user.email, textAlign: TextAlign.center, style: AppText.muted),
            const SizedBox(height: 28),
            ActionTile(
              icon: Icons.edit_outlined,
              label: 'Edit profile',
              onTap: () => context.push('/profile/edit'),
            ),
            ActionTile(icon: Icons.key_outlined, label: 'Change password', onTap: () => context.push('/profile/password')),
            ActionTile(
              icon: Icons.notifications_none,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
              trailing: Switch(
                value: user.notificationsEnabled,
                onChanged: (v) => ref.read(authProvider.notifier).updateProfile({'notificationsEnabled': v}),
              ),
            ),
            ActionTile(icon: Icons.group_add_outlined, label: 'Join a project', onTap: () => context.push('/join')),
            ActionTile(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                if (await confirmDialog(context, title: 'Log out?', message: 'You can log back in any time.', confirmLabel: 'Log out')) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: 32),
            ActionTile(
              icon: Icons.delete_outline,
              label: 'Delete account',
              danger: true,
              onTap: () => showDeleteAccountDialog(
                context,
                ref,
                warning: 'This permanently deletes your account and your requests, and removes you from all projects.',
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: AppVersionText()),
          ],
        ),
      ),
    );
  }
}

/// Client edit profile: name and phone.
class ClientEditProfileScreen extends ConsumerWidget {
  const ClientEditProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authProvider).value;
    return EditProfileScreen(fields: [
      ('name', 'Full name', u?.name ?? '', TextInputType.name, 1),
      ('phone', 'Phone', u?.phone ?? '', TextInputType.phone, 1),
    ]);
  }
}
