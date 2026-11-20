import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data.dart';
import '../../widgets/common.dart';
import '../../widgets/contact.dart';
import '../../widgets/media.dart';
import '../shared/case_study_view.dart';

/// Contractor tab: picks the contractor(s) from the client's projects.
class ContractorTab extends ConsumerStatefulWidget {
  const ContractorTab({super.key});
  @override
  ConsumerState<ContractorTab> createState() => _ContractorTabState();
}

class _ContractorTabState extends ConsumerState<ContractorTab> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncBody(loading: Skeleton.profile(), 
          value: projects,
          onRetry: () => ref.invalidate(projectsProvider),
          data: (list) {
            final engineers = <String, AppUser>{};
            for (final p in list) {
              if (p.engineer != null) engineers[p.engineer!.id] = p.engineer!;
            }
            if (engineers.isEmpty) {
              return EmptyState(
                icon: Icons.engineering_outlined,
                title: 'No contractor yet',
                message: 'Join a project to see your contractor here.',
                action: AppButton(label: 'Join a project', expand: false, onPressed: () => context.push('/join')),
              );
            }
            final id = engineers.containsKey(_selected) ? _selected! : engineers.keys.first;
            return Column(
              children: [
                const PageHeader(title: 'Contractor', showBack: false),
                if (engineers.length > 1)
                  ChipFilterBar(
                    options: [for (final e in engineers.values) e.name],
                    selected: engineers.keys.toList().indexOf(id),
                    onSelected: (i) => setState(() => _selected = engineers.keys.elementAt(i)),
                  ),
                Expanded(child: ContractorView(engineerId: id, bottomPadding: 120)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pushed contractor page (from a project).
class ContractorScreen extends StatelessWidget {
  const ContractorScreen({super.key, required this.engineerId});
  final String engineerId;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [const PageHeader(title: 'Contractor'), Expanded(child: ContractorView(engineerId: engineerId))]),
        ),
      );
}

class ContractorView extends ConsumerWidget {
  const ContractorView({super.key, required this.engineerId, this.bottomPadding = 32});
  final String engineerId;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(contractorProvider(engineerId));
    return AsyncBody(loading: Skeleton.profile(), 
      value: value,
      onRetry: () => ref.invalidate(contractorProvider(engineerId)),
      data: (c) {
        final e = c.engineer;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(contractorProvider(engineerId).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
            children: [
              Center(child: Avatar(name: e.name, size: 96)),
              const SizedBox(height: 16),
              Text(e.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              if (e.subtitle.isNotEmpty) Text(e.subtitle, textAlign: TextAlign.center, style: AppText.muted),
              if (e.company.isNotEmpty) Text(e.company, textAlign: TextAlign.center, style: AppText.small),
              if (e.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(e.bio, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (e.yearsExperience > 0) _Pill('${e.yearsExperience} yrs experience'),
                  _Pill('${c.stats['projects'] ?? 0} projects'),
                  _Pill('${c.stats['updates'] ?? 0} updates'),
                ],
              ),
              const SizedBox(height: 20),
              if (e.phone.isNotEmpty)
                _ContactRow(icon: Icons.call_outlined, label: 'Phone', value: e.phone, onTap: () => callPhone(context, e.phone)),
              if (e.email.isNotEmpty)
                _ContactRow(icon: Icons.mail_outline, label: 'Email', value: e.email, onTap: () => sendEmail(context, e.email)),
              if (e.location.isNotEmpty) _ContactRow(icon: Icons.location_on_outlined, label: 'Location', value: e.location),
              if (e.phone.isNotEmpty) ...[const SizedBox(height: 4), ContactButtons(phone: e.phone)],
              const SectionTitle('Projects with you'),
              for (final p in c.projectsWithYou)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/projects/${p.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                    child: Row(children: [Expanded(child: Text(p.name, style: const TextStyle(fontSize: 16))), StatusBadge(p.status, small: true)]),
                  ),
                ),
              if (c.completed.isNotEmpty) ...[
                const SectionTitle('Other completed projects'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: c.completed.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.8),
                  itemBuilder: (_, i) {
                    final p = c.completed[i];
                    return SurfaceCard(
                      padding: const EdgeInsets.all(8),
                      onTap: () => context.push('/contractor/${e.id}/projects/${p.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: NetImage(p.coverImage, radius: 12, width: double.infinity)),
                          const SizedBox(height: 8),
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                          Text(
                            [if (p.location.isNotEmpty) p.location.split(',').first, if (p.completedAt != null) Fmt.year(p.completedAt)].join(' · '),
                            maxLines: 1,
                            style: AppText.small,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: AppText.small),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label, style: AppText.small), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))],
              ),
            ),
            IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy_outlined, size: 18), onPressed: () => copyText(context, value, label: '$label copied')),
          ],
        ),
      ),
    );
  }
}

/// Read-only case study of a contractor's completed project.
class CaseStudyScreen extends ConsumerWidget {
  const CaseStudyScreen({super.key, required this.engineerId, required this.projectId});
  final String engineerId;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(publicCaseStudyProvider((engineerId, projectId)));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Case study'),
            Expanded(
              child: AsyncBody(loading: Skeleton.detail(), 
                value: value,
                onRetry: () => ref.invalidate(publicCaseStudyProvider((engineerId, projectId))),
                data: (s) => CaseStudyBody(study: s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
