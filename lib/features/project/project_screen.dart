import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import '../shared/case_study_view.dart';

/// Client view of one project (design: "Project").
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.projectId});
  final String projectId;

  Future<void> _leave(BuildContext context, WidgetRef ref, Project p) async {
    final ok = await confirmDialog(context,
        title: 'Leave ${p.name}?', message: 'You will stop seeing updates for this project. You can rejoin with the invite code.', confirmLabel: 'Leave', destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await ref.read(repoProvider).leaveProject(p.id);
      if (context.mounted) context.go('/home');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(projectId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Project',
              trailing: detail.value == null
                  ? null
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (_) => _leave(context, ref, detail.value!.project),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave project'))],
                    ),
            ),
            Expanded(
              child: AsyncBody(
                value: detail,
                onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
                data: (d) => RefreshIndicator(
                  onRefresh: () => ref.refresh(projectDetailProvider(projectId).future),
                  child: _Body(detail: d),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final ProjectDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = detail.project;
    final latest = detail.latestUpdate;
    final photos = [...?latest?.photos];
    if (photos.isEmpty && p.coverImage.isNotEmpty) photos.add(p.coverImage);
    final engineer = p.engineer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        PhotoCarousel(photos: photos, height: 230, showArrows: photos.length > 1),
        const SizedBox(height: 20),
        Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        if (p.location.isNotEmpty) ...[const SizedBox(height: 6), LocationText(p.location, size: 14)],
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: StatusBadge(p.status)),
        const SizedBox(height: 18),
        ProgressRow(progress: p.progress),
        const SizedBox(height: 14),
        Text(p.lastUpdateAt == null ? 'No updates yet' : 'Last update: ${Fmt.dateShort(p.lastUpdateAt)}', style: AppText.muted),
        const SizedBox(height: 20),
        InfoRow(label: 'Start date', value: Fmt.date(p.startDate)),
        InfoRow(label: p.isCompleted ? 'Completed' : 'Expected finish', value: p.isCompleted ? Fmt.date(p.completedAt) : Fmt.monthYear(p.expectedFinish)),
        if (p.budget != null) InfoRow(label: 'Budget', value: Fmt.budget(p.budget), divider: false),
        if (p.address.isNotEmpty) InfoRow(label: 'Address', value: p.address, divider: false),
        if (engineer != null) ...[
          const SizedBox(height: 20),
          const Text('Your contractor', style: AppText.muted),
          const SizedBox(height: 10),
          SurfaceCard(
            onTap: () => context.push('/contractor/${engineer.id}'),
            child: Row(
              children: [
                Avatar(name: engineer.name, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(engineer.name, style: const TextStyle(fontSize: 16)),
                      if (engineer.subtitle.isNotEmpty) Text(engineer.subtitle, style: AppText.small),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SurfaceCard(
          onTap: () => context.push('/projects/${p.id}/requests'),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 20),
              const SizedBox(width: 14),
              const Expanded(child: Text('Requests', style: TextStyle(fontSize: 16))),
              if (p.openRequests > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(20)),
                  child: Text('${p.openRequests} open', style: const TextStyle(color: AppColors.orange, fontSize: 13)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        if (p.isCompleted) ...[
          const SizedBox(height: 12),
          _RateCard(project: p),
        ],
        const SectionTitle('Latest update'),
        if (latest == null)
          const SurfaceCard(child: Text('Your contractor has not posted an update yet.', style: AppText.muted))
        else
          SurfaceCard(
            onTap: () => context.push('/updates/${latest.id}'),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.day(latest.date), style: AppText.muted),
                const SizedBox(height: 10),
                Text(latest.note.isEmpty ? latest.summary : latest.note, style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        AppButton(label: 'View all updates', alignStart: true, trailingArrow: true, onPressed: () => context.push('/projects/${p.id}/updates')),
      ],
    );
  }
}

class _RateCard extends ConsumerWidget {
  const _RateCard({required this.project});
  final Project project;

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final text = TextEditingController();
    final submitted = await showAppSheet<bool>(
      context,
      title: 'Rate your build',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('How was working with your contractor?', style: AppText.muted),
            const SizedBox(height: 16),
            Center(child: StarRow(rating: rating, size: 40, onChanged: (r) => setState(() => rating = r))),
            const SizedBox(height: 20),
            AppTextField(label: 'Your review (optional)', controller: text, maxLines: 4, maxLength: 600),
            const SizedBox(height: 24),
            AppButton(label: 'Submit review', onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    final review = text.text;
    text.dispose();
    if (submitted != true || !context.mounted) return;
    try {
      await ref.read(repoProvider).sendFeedback(project.id, rating, review);
      if (context.mounted) showSnack(context, 'Thanks for your review!');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      color: AppColors.greenSoft,
      onTap: () => _rate(context, ref),
      child: const Row(
        children: [
          Icon(Icons.celebration_outlined, color: AppColors.green),
          SizedBox(width: 14),
          Expanded(child: Text('Your build is complete! Leave a review', style: TextStyle(fontSize: 15, color: AppColors.green))),
          Icon(Icons.chevron_right, color: AppColors.green),
        ],
      ),
    );
  }
}
