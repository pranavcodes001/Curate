import 'package:flutter/material.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/saved_threads_repository_impl.dart';
import '../domain/models/saved_thread.dart';
import '../../../core/utils/string_util.dart';
import '../../../core/widgets/curate_loader.dart';
import '../../../core/widgets/aesthetic_web_viewer.dart';

class SavedThreadDetailPage extends StatefulWidget {
  const SavedThreadDetailPage({super.key, required this.threadId});

  final int threadId;

  @override
  State<SavedThreadDetailPage> createState() => _SavedThreadDetailPageState();
}

class _SavedThreadDetailPageState extends State<SavedThreadDetailPage> {
  final _repo = SavedThreadsRepositoryImpl();
  Future<SavedThread>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _repo.getThread(widget.threadId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved thread')),
      body: GradientBackground(
        child: FutureBuilder<SavedThread>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CurateLoader(label: 'Opening Thread', size: 80),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load thread.'));
            }
            final thread = snapshot.data;
            if (thread == null) {
              return const Center(child: Text('Thread not found.'));
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  StringUtil.clean(thread.title ?? 'Untitled story'),
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((thread.url ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  InkWell(
                    onTap: () => AestheticWebViewer.show(context, thread.url!),
                    child: Text(
                      'Open Original Story',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24.0),
                for (final item in thread.items) ...[
                  _buildItem(item),
                  const SizedBox(height: 16.0),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(SavedThreadItem item) {
    final summary = item.aiSummary ?? const <String, dynamic>{};
    final tldr = summary['tldr']?.toString() ?? '';
    final keyPoints = summary['key_points'];
    final points = <String>[];
    if (keyPoints is List) {
      for (final p in keyPoints) {
        if (p != null) points.add(p.toString());
      }
    }

    final hasSummary = tldr.isNotEmpty || points.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemType == 'story' ? 'STORY TEXT' : 'COMMENT',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10.0,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((item.rawText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    StringUtil.clean(item.rawText!).trim(),
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (hasSummary)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reveal AI Summary (Opt-in)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                expandedAlignment: Alignment.topLeft,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tldr.isNotEmpty)
                          Text(
                            tldr,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF333333),
                            ),
                          ),
                        if (points.isNotEmpty) ...[
                          const SizedBox(height: 12.0),
                          for (final p in points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
