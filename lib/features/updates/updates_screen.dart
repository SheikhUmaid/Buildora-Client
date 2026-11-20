import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';

/// Timeline of updates with project / work type / month filters and search.
/// Used as the "Updates" tab and as "View all updates" for one project.
class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key, this.initialProjectId, this.standalone = false});
  final String? initialProjectId;
  final bool standalone; // pushed page with back button

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  late String? _projectId = widget.initialProjectId;
  String? _workType;
  String? _month; // yyyy-MM
  String _query = '';
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  FeedQuery get _feedQuery => (projectId: _projectId, month: null, workType: _workType, q: _query.isEmpty ? null : _query, mine: false);

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final workTypes = ref.watch(metaProvider).value?['workTypes'] ?? const <String>[];
    final feed = ref.watch(updatesFeedProvider(_feedQuery));
    final selectedProject = projects.where((p) => p.id == _projectId).firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (widget.standalone) ...[const BackCircle(), const SizedBox(width: 12)],
                  Expanded(
                    child: _searching
                        ? TextField(
                            controller: _search,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(hintText: 'Search notes…', border: InputBorder.none),
                            onSubmitted: (v) => setState(() => _query = v.trim()),
                          )
                        : const Text('Updates', style: AppText.h1),
                  ),
                  CircleIconButton(
                    icon: _searching ? Icons.close : Icons.search,
                    tooltip: _searching ? 'Close search' : 'Search',
                    onTap: () => setState(() {
                      if (_searching) {
                        _search.clear();
                        _query = '';
                      }
                      _searching = !_searching;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _Dropdown(
                    label: selectedProject?.name ?? 'All projects',
                    dark: true,
                    options: [('', 'All projects'), for (final p in projects) (p.id, p.name)],
                    onSelected: (v) => setState(() => _projectId = v.isEmpty ? null : v),
                  ),
                  const SizedBox(width: 8),
                  _Dropdown(
                    label: _workType ?? 'All work',
                    options: [('', 'All work'), for (final w in workTypes) (w, w)],
                    onSelected: (v) => setState(() => _workType = v.isEmpty ? null : v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncBody(loading: Skeleton.updates(), 
                value: feed,
                onRetry: () => ref.invalidate(updatesFeedProvider(_feedQuery)),
                data: (updates) {
                  // Month chips come from the data itself.
                  final months = <String, DateTime>{};
                  for (final u in updates) {
                    months.putIfAbsent(Fmt.monthKey(u.date), () => u.date);
                  }
                  final keys = months.keys.toList();
                  final filtered = _month == null ? updates : updates.where((u) => Fmt.monthKey(u.date) == _month).toList();
                  return Column(
                    children: [
                      if (keys.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ChipFilterBar(
                            options: ['All', for (final k in keys) Fmt.month(months[k]!)],
                            selected: _month == null ? 0 : keys.indexOf(_month!) + 1,
                            onSelected: (i) => setState(() => _month = i == 0 ? null : keys[i - 1]),
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => ref.refresh(updatesFeedProvider(_feedQuery).future),
                          child: filtered.isEmpty
                              ? ListView(children: const [
                                  SizedBox(height: 60),
                                  EmptyState(icon: Icons.photo_library_outlined, title: 'No updates yet', message: 'Daily site photos from your contractor will appear here.'),
                                ])
                              : UpdatesTimeline(updates: filtered, showProject: _projectId == null && projects.length > 1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Groups updates by day and renders them on a vertical timeline.
class UpdatesTimeline extends StatelessWidget {
  const UpdatesTimeline({super.key, required this.updates, this.showProject = false, this.bottomPadding = 120});
  final List<SiteUpdate> updates;
  final bool showProject;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<SiteUpdate>>{};
    for (final u in updates) {
      days.putIfAbsent(DateTime(u.date.year, u.date.month, u.date.day), () => []).add(u);
    }
    final entries = days.entries.toList();
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return TimelineEntry(
          label: i == 0 ? '${Fmt.day(e.key)} · Latest' : Fmt.day(e.key),
          highlight: i == 0,
          isLast: i == entries.length - 1,
          child: Column(
            children: [
              for (final u in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: UpdateCard(update: u, showProject: showProject, onTap: () => context.push('/updates/${u.id}')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.options, required this.onSelected, this.dark = false});
  final String label;
  final List<(String, String)> options;
  final ValueChanged<String> onSelected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o.$1, child: Text(o.$2))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: dark ? AppColors.black : AppColors.surfaceDark, borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: dark ? Colors.white : AppColors.text),
          ],
        ),
      ),
    );
  }
}
