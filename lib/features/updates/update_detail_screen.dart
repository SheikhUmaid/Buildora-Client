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
import '../../widgets/thread.dart';

/// One site update with photo carousel, the contractor note, and the client actions.
class UpdateDetailScreen extends ConsumerWidget {
  const UpdateDetailScreen({super.key, required this.updateId});
  final String updateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(updateDetailProvider(updateId));
    return Scaffold(
      body: SafeArea(
        child: AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(updateDetailProvider(updateId)),
          data: (d) => _Content(detail: d),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.detail});
  final UpdateDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = detail.update;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const BackCircle(arrow: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.day(u.date), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                    Text('${detail.position} of ${detail.total}', style: AppText.small),
                  ],
                ),
              ),
              // Older / newer updates of the same project.
              CircleIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Older update',
                onTap: detail.prevId == null ? null : () => context.pushReplacement('/updates/${detail.prevId}'),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.chevron_right,
                dark: detail.nextId != null,
                tooltip: 'Newer update',
                onTap: detail.nextId == null ? null : () => context.pushReplacement('/updates/${detail.nextId}'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (u.photos.isNotEmpty) ...[PhotoCarousel(photos: u.photos, height: 280), const SizedBox(height: 20)],
              UpdateNoteCard(update: u),
              if (u.approvedByMe) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 18, color: AppColors.green),
                    SizedBox(width: 8),
                    Text('You approved this update', style: TextStyle(color: AppColors.green)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            children: [
              if (u.requestCount > 0)
                TextButton(
                  onPressed: () => context.push('/projects/${u.projectId}/requests?updateId=${u.id}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${Fmt.plural(u.requestCount, 'request')} on this update', style: const TextStyle(color: AppColors.text, fontSize: 15)),
                      const Icon(Icons.chevron_right, color: AppColors.text),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              AppButton(label: 'Message Contractor', alignStart: true, trailingArrow: true, onPressed: () => showNeedSheet(context, ref, u)),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================= Client action sheets

/// "What do you need?" sheet.
Future<void> showNeedSheet(BuildContext context, WidgetRef ref, SiteUpdate update) async {
  final choice = await showAppSheet<String>(
    context,
    title: 'What do you need?',
    builder: (ctx) => Column(
      children: [
        _NeedTile(icon: Icons.help_outline, title: 'Ask a question', subtitle: 'Not clear about this update', onTap: () => Navigator.pop(ctx, 'question')),
        _NeedTile(icon: Icons.edit_outlined, title: 'Request a change', subtitle: 'Something should be done differently', onTap: () => Navigator.pop(ctx, 'change')),
        _NeedTile(
          icon: Icons.thumb_up_alt_outlined,
          title: update.approvedByMe ? 'Already approved' : 'Looks good',
          subtitle: 'Approve this update',
          onTap: update.approvedByMe ? null : () => Navigator.pop(ctx, 'approval'),
        ),
        _NeedTile(icon: Icons.call_outlined, title: 'Need a call', subtitle: 'Talk to your contractor', onTap: () => Navigator.pop(ctx, 'call')),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final repo = ref.read(repoProvider);
  switch (choice) {
    case 'question':
    case 'change':
      await showComposeRequestSheet(context, ref, projectId: update.projectId, updateId: update.id, type: choice);
    case 'approval':
      try {
        await repo.createRequest(projectId: update.projectId, updateId: update.id, type: 'approval');
        if (context.mounted) showSnack(context, 'Approved. Your contractor has been notified.');
      } catch (e) {
        if (context.mounted) showSnack(context, errorText(e), error: true);
      }
    case 'call':
      try {
        await repo.createRequest(projectId: update.projectId, updateId: update.id, type: 'call');
        final detail = await ref.read(projectDetailProvider(update.projectId).future);
        final phone = detail.project.engineer?.phone ?? '';
        if (!context.mounted) return;
        if (phone.isNotEmpty) {
          await callPhone(context, phone);
        } else {
          showSnack(context, 'Call request sent. Your contractor will call you back.');
        }
      } catch (e) {
        if (context.mounted) showSnack(context, errorText(e), error: true);
      }
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: SurfaceCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ask a question" / "Request a change" composer.
Future<void> showComposeRequestSheet(BuildContext context, WidgetRef ref, {required String projectId, String? updateId, required String type}) {
  return showAppSheet<void>(
    context,
    title: type == 'change' ? 'Request a change' : 'Ask a question',
    builder: (ctx) => _ComposeRequest(projectId: projectId, updateId: updateId, type: type),
  );
}

class _ComposeRequest extends ConsumerStatefulWidget {
  const _ComposeRequest({required this.projectId, required this.updateId, required this.type});
  final String projectId;
  final String? updateId;
  final String type;

  @override
  ConsumerState<_ComposeRequest> createState() => _ComposeRequestState();
}

class _ComposeRequestState extends ConsumerState<_ComposeRequest> {
  final _message = TextEditingController();
  List<String> _photos = [];
  String? _voice;
  bool _urgent = false;
  bool _busy = false;

  List<String> get _suggestions => widget.type == 'change'
      ? const ['Use a different material', 'Change the layout', 'Please redo this', 'Discuss before continuing']
      : const ['Why this delay?', 'Share more photos', 'What is planned next?', 'Is this as per drawing?'];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty && _photos.isEmpty && _voice == null) {
      return showSnack(context, 'Write a message or attach a photo / voice note', error: true);
    }
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).createRequest(
            projectId: widget.projectId,
            updateId: widget.updateId,
            type: widget.type,
            message: _message.text.trim(),
            urgent: _urgent,
            photos: _photos,
            voicePath: _voice,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Request sent to your contractor');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPhotos(bool camera) async {
    final picked = await pickPhotos(context, camera: camera, max: 5 - _photos.length);
    if (picked.isNotEmpty) setState(() => _photos = [..._photos, ...picked].take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => AppChip(
              label: _suggestions[i],
              onTap: () => setState(() {
                _message.text = _suggestions[i];
                _message.selection = TextSelection.collapsed(offset: _message.text.length);
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder(
          valueListenable: _message,
          builder: (_, v, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppTextField(label: 'Your message', controller: _message, maxLines: 5, minLines: 4, maxLength: 300),
              const SizedBox(height: 6),
              Text('${v.text.length} / 300', style: AppText.small),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AppButton(label: 'Camera', icon: Icons.photo_camera_outlined, style: AppButtonStyle.outline, expand: false, height: 50, onPressed: _photos.length >= 5 ? null : () => _addPhotos(true)),
            const SizedBox(width: 8),
            AppButton(label: 'Gallery', icon: Icons.photo_outlined, style: AppButtonStyle.outline, expand: false, height: 50, onPressed: _photos.length >= 5 ? null : () => _addPhotos(false)),
            const SizedBox(width: 8),
            VoiceRecorder(compact: true, path: _voice, onRecorded: (p) => setState(() => _voice = p)),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in _photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress: () => setState(() => _photos = [..._photos]..remove(p)),
                      child: SizedBox(width: 72, child: AnyImage(p, radius: 12)),
                    ),
                  ),
              ],
            ),
          ),
          const Text('Long-press a photo to remove it', style: AppText.small),
        ],
        if (_voice != null) ...[
          const SizedBox(height: 12),
          VoiceRecorder(path: _voice, onRecorded: (p) => setState(() => _voice = p)),
        ],
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _urgent = !_urgent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Urgent', style: TextStyle(fontSize: 16))),
                Icon(_urgent ? Icons.check_circle : Icons.circle_outlined, color: _urgent ? AppColors.orange : AppColors.text),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Send request', alignStart: true, trailingArrow: true, loading: _busy, onPressed: _send),
      ],
    );
  }
}
