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
import '../../widgets/thread.dart';

/// Client's requests for a project (optionally one update): All / Open / Done.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key, required this.projectId, this.updateId});
  final String projectId;
  final String? updateId;

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final query = (status: const [null, 'open', 'done'][_tab], projectId: widget.projectId, updateId: widget.updateId);
    final value = ref.watch(requestsProvider(query));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(title: widget.updateId == null ? 'Requests' : 'Requests on update'),
            ChipFilterBar(options: const ['All', 'Open', 'Done'], selected: _tab, onSelected: (i) => setState(() => _tab = i)),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncBody(
                value: value,
                onRetry: () => ref.invalidate(requestsProvider(query)),
                data: (res) {
                  if (res.requests.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No requests',
                      message: 'Open an update and tap "Message Contractor" to ask a question or request a change.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(requestsProvider(query).future),
                    child: GroupedRequestList(
                      requests: res.requests,
                      onTap: (r) => context.push('/requests/${r.id}'),
                    ),
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

/// Client request thread: original message, attachments, replies and a follow-up box.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).reply(widget.requestId, _reply.text.trim());
      _reply.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(ClientRequest r) async {
    final ok = await confirmDialog(context, title: 'Withdraw request?', message: 'Your contractor will no longer see it.', confirmLabel: 'Withdraw', destructive: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(repoProvider).withdrawRequest(r.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(requestDetailProvider(widget.requestId));
    return Scaffold(
      body: SafeArea(
        child: AsyncBody(
          value: value,
          onRetry: () => ref.invalidate(requestDetailProvider(widget.requestId)),
          data: (r) => Column(
            children: [
              PageHeader(
                title: Fmt.requestType(r.type),
                trailing: (r.isNew || r.type == 'approval')
                    ? CircleIconButton(icon: Icons.delete_outline, tooltip: 'Withdraw', onTap: () => _withdraw(r))
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Row(
                      children: [
                        Text('${r.projectName} · ${Fmt.day(r.createdAt)} · ${Fmt.time(r.createdAt)}', style: AppText.small),
                        const Spacer(),
                        if (r.urgent) const StatusBadge('urgent', small: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(r.message, style: const TextStyle(fontSize: 18, height: 1.4)),
                    if (r.photos.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (var i = 0; i < r.photos.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(onTap: () => openPhotoViewer(context, r.photos, i), child: SizedBox(width: 90, child: NetImage(r.photos[i], radius: 12))),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (r.voiceNoteUrl.isNotEmpty) ...[const SizedBox(height: 12), VoiceNotePlayer(source: r.voiceNoteUrl)],
                    if (r.updateId != null) ...[
                      const SizedBox(height: 16),
                      SurfaceCard(
                        onTap: () => context.push('/updates/${r.updateId}'),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (r.updatePhoto != null) SizedBox(width: 48, height: 48, child: NetImage(r.updatePhoto, radius: 10)),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Update · ${Fmt.day(r.updateDate)}', style: const TextStyle(fontSize: 15))),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    RequestStatusLine(request: r),
                    const SizedBox(height: 20),
                    if (r.replies.isNotEmpty) const Text('Conversation', style: AppText.muted),
                    for (final reply in r.replies) ReplyBubble(reply: reply, mine: reply.authorRole == 'client'),
                  ],
                ),
              ),
              if (r.type != 'approval')
                ReplyComposer(controller: _reply, busy: _busy, onSend: _send, hint: 'Write a follow-up…'),
            ],
          ),
        ),
      ),
    );
  }
}

