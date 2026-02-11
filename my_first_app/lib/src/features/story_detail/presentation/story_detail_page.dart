import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../core/models/route_arguments.dart';
import '../../../core/auth/auth_session.dart';
import '../data/story_detail_repository_impl.dart';
import '../data/comments_repository_impl.dart';
import '../domain/models/story_detail.dart';
import '../../saved_threads/data/saved_threads_repository_impl.dart';
import '../../summary/data/summary_repository_impl.dart';
import '../../summary/domain/models/summary.dart';
import '../../../core/utils/string_util.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/curate_loader.dart';
import '../../../core/widgets/aesthetic_web_viewer.dart';

// Story Detail (v1) — Minimal implementation aligned with current scope.
// Responsibilities:
// - Show raw story metadata (from backend).
// - Show collapsed comments preview (not the full thread by default).
// - Expose "Show summary" and "Save thread" actions.

class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({super.key});

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final _repo = StoryDetailRepositoryImpl();
  final _commentsRepo = CommentsRepositoryImpl();
  final _savedRepo = SavedThreadsRepositoryImpl();
  final _summaryRepo = SummaryRepositoryImpl();
  Future<StoryDetail>? _future;
  bool _expandedComments = false;
  bool _fullCommentsLoading = false;
  List<CommentPreview>? _fullThreadRoots;
  String? _fullCommentsStoryId;
  Summary? _summary;
  bool _summaryLoading = false;

  // Cache for comment summaries: commentId -> Summary/Loading state
  final Map<String, Summary> _commentSummaries = {};
  final Set<String> _loadingComments = {};

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as StoryDetailRouteArgs;
    _future ??= _repo.fetchDetail(args.hnId);

    return Scaffold(
      appBar: AppBar(title: Text(args.title ?? 'Story')),
      body: GradientBackground(
        child: FutureBuilder<StoryDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CurateLoader(label: 'Curating details', size: 80),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load story.'));
            }
            final story = snapshot.data;
            if (story == null) {
              return const Center(child: Text('Story not found.'));
            }
            if (_fullCommentsStoryId != story.hnId) {
              _fullThreadRoots = null;
              _fullCommentsStoryId = story.hnId;
              if (!_fullCommentsLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadFullComments(story.hnId);
                });
              }
            }

            final comments = story.commentPreview;
            final threadedComments = _fullThreadRoots ?? comments;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Score ${story.score ?? 0}',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: AppState.instance.topStoryIds,
                        builder: (context, topIds, _) {
                          if (topIds.contains(story.hnId)) {
                            return _buildTopBadge();
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    StringUtil.clean(story.title ?? 'Untitled story'),
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  _buildStoryBody(story),
                  const SizedBox(height: 24.0),

                  Row(
                    children: [
                      const Text(
                        'Discussion',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: comments.isEmpty
                            ? null
                            : () {
                                if (_expandedComments) {
                                  setState(() => _expandedComments = false);
                                } else {
                                  setState(() => _expandedComments = true);
                                  if (_fullThreadRoots == null && !_fullCommentsLoading) {
                                    _loadFullComments(story.hnId);
                                  }
                                }
                              },
                        child: Text(
                          _expandedComments ? 'Show Less' : 'Expand All',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  if (threadedComments.isEmpty)
                    const Text('No comments yet.')
                  else
                    ..._buildThreadedComments(
                      threadedComments,
                      _expandedComments,
                    ),

                  const SizedBox(height: 24.0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!AuthSession.instance.isLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sign in to save threads.'),
                            ),
                          );
                          return;
                        }
                        try {
                          final commentIds = story.commentPreview
                              .map((c) => c.commentHnId)
                              .toList();
                          await _savedRepo.createThread(story.hnId, commentIds);
                          // Small delay to ensure backend has synced before we trigger a refresh
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                          AppState.instance.savedThreadsRefreshTrigger.value++;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved thread queued'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to save thread'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Discussion Thread'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildThreadedComments(
    List<CommentPreview> comments,
    bool showAll,
  ) {
    final hasChildren = comments.any((c) => c.children.isNotEmpty);
    if (hasChildren) {
      final displayList = showAll
          ? comments
          : (comments.length > 2 ? comments.sublist(0, 2) : comments);
      return displayList.map((c) => _buildThreadedItemTree(c, 0)).toList();
    }

    final map = <String?, List<CommentPreview>>{};
    for (final c in comments) {
      map.putIfAbsent(c.parentHnId, () => []).add(c);
    }

    final allIds = comments.map((e) => e.commentHnId).toSet();
    final topLevel = comments
        .where((c) => !allIds.contains(c.parentHnId))
        .toList();

    final result = <Widget>[];
    final displayList = showAll
        ? topLevel
        : (topLevel.length > 2 ? topLevel.sublist(0, 2) : topLevel);

    for (final root in displayList) {
      result.add(_buildThreadedItem(root, map, 0));
    }

    return result;
  }

  Widget _buildThreadedItemTree(
    CommentPreview comment,
    int depth,
  ) {
    final children = comment.children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThreadedRow(comment, depth),
        if (children.isNotEmpty)
          ...children.map(
            (child) => _buildThreadedItemTree(child, depth + 1),
          ),
      ],
    );
  }

  Widget _buildThreadedItem(
    CommentPreview comment,
    Map<String?, List<CommentPreview>> childrenMap,
    int depth,
  ) {
    final children = childrenMap[comment.commentHnId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThreadedRow(comment, depth),

        // Recursive children
        if (children.isNotEmpty)
          ...children.map(
            (child) => _buildThreadedItem(child, childrenMap, depth + 1),
          ),
      ],
    );
  }

  Widget _buildThreadedRow(CommentPreview comment, int depth) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (depth > 0) ...[
            ..._buildThreadColumns(depth),
            const SizedBox(width: 6),
          ],

          // Comment content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            comment.author ?? 'user',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.0,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildCommentSummaryTrigger(comment.commentHnId),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    Html(
                      data: comment.text ?? '',
                      style: {
                        "body": Style(
                          fontSize: FontSize(14.0),
                          color: const Color(0xFF1F1F1F),
                          lineHeight: LineHeight(1.5),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        "a": Style(
                          color: Colors.blueAccent,
                          textDecoration: TextDecoration.none,
                        ),
                      },
                      onLinkTap: (url, attributes, element) {
                        if (url != null) _openUrl(url);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildThreadColumns(int depth) {
    final color = Colors.grey.shade500;
    return List.generate(depth, (i) {
      final isElbow = i == depth - 1;
      return SizedBox(
        width: 12,
        child: CustomPaint(
          painter: _ThreadLinePainter(
            color: color,
            showElbow: isElbow,
          ),
        ),
      );
    });
  }

  Widget _buildStoryBody(StoryDetail story) {
    final text = (story.text ?? '').trim();
    if (text.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Html(
              data: text,
              onLinkTap: (url, _, _) {
                if (url != null) _openUrl(url);
              },
            ),
            const Divider(),
            _buildStorySummaryTrigger(story.hnId),
            if (_summaryLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_summary != null) _buildInlineSummaryCard(_summary!),
          ],
        ),
      );
    }

    if ((story.url ?? '').trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _openUrl(story.url!),
                child: Text(
                  'View full story',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildStorySummaryTrigger(story.hnId),
            ],
          ),
          if (_summaryLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_summary != null) ...[
            const SizedBox(height: 12),
            _buildInlineSummaryCard(_summary!),
          ],
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No story content available.'),
        const SizedBox(height: 8),
        _buildStorySummaryTrigger(story.hnId),
        if (_summaryLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_summary != null) ...[
          const SizedBox(height: 12),
          _buildInlineSummaryCard(_summary!),
        ],
      ],
    );
  }

  Widget _buildStorySummaryTrigger(String hnId) {
    if (_summaryLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton.icon(
      onPressed: () => _handleSummaryRequest(hnId, SummaryTargetType.story),
      icon: _summary == null
          ? const CurateAvatar(size: 16)
          : const Icon(Icons.check_circle, size: 16, color: Colors.green),
      label: Text(
        _summary == null ? 'AI ✨' : 'AI Summary',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCommentSummaryTrigger(String hnId) {
    if (_loadingComments.contains(hnId)) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final existing = _commentSummaries[hnId];
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _handleSummaryRequest(hnId, SummaryTargetType.comment),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              existing != null
                  ? const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    )
                  : const CurateAvatar(size: 14),
              const SizedBox(width: 4),
              Text(
                existing != null ? 'View Summary' : 'AI ✨',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSummaryRequest(
    String hnId,
    SummaryTargetType type,
  ) async {
    if (type == SummaryTargetType.story) {
      if (_summary != null) {
        return;
      }
      await _generateSummary(hnId, type);
      return;
    } else {
      if (_commentSummaries.containsKey(hnId)) {
        _showSummarySheet(_commentSummaries[hnId]!);
        return;
      }
      await _generateSummary(hnId, type);
      if (mounted && _commentSummaries.containsKey(hnId)) {
        _showSummarySheet(_commentSummaries[hnId]!);
      }
    }
  }

  void _showSummarySheet(Summary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  CurateAvatar(size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Executive Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if ((summary.tldr ?? '').trim().isNotEmpty) ...[
                Text(
                  summary.tldr!.trim(),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 20),
              ],
              if (summary.keyPoints.isNotEmpty) ...[
                const Text(
                  'Key Takeaways',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                for (final point in summary.keyPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(point)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if ((summary.consensus ?? '').trim().isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Community Consensus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.consensus!.trim(),
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineSummaryCard(Summary summary) {
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CurateAvatar(size: 18),
              SizedBox(width: 6),
              Text(
                'AI Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if ((summary.tldr ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary.tldr!.trim(),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          if (summary.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Key Takeaways',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final point in summary.keyPoints)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
          ],
          if ((summary.consensus ?? '').trim().isNotEmpty) ...[
            const Divider(height: 20),
            const Text(
              'Community Consensus',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary.consensus!.trim(),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateSummary(String hnId, SummaryTargetType type) async {
    if (!AuthSession.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to generate summaries.')),
      );
      return;
    }

    setState(() {
      if (type == SummaryTargetType.story) {
        _summaryLoading = true;
      } else {
        _loadingComments.add(hnId);
      }
    });

    try {
      final existing = await _summaryRepo.fetchSummary(hnId, type);
      if (existing != null) {
        setState(() {
          if (type == SummaryTargetType.story) {
            _summary = existing;
            _summaryLoading = false;
          } else {
            _commentSummaries[hnId] = existing;
            _loadingComments.remove(hnId);
          }
        });
        return;
      }
      final generated = await _summaryRepo.generateSummary(hnId, type);
      setState(() {
        if (type == SummaryTargetType.story) {
          _summary = generated;
          _summaryLoading = false;
        } else {
          _commentSummaries[hnId] = generated;
          _loadingComments.remove(hnId);
        }
      });
    } catch (_) {
      setState(() {
        if (type == SummaryTargetType.story) {
          _summaryLoading = false;
        } else {
          _loadingComments.remove(hnId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate summary.')),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Use the Aesthetic In-App Sheet Viewer (Option 1)
    await AestheticWebViewer.show(context, url);
  }

  Future<void> _loadFullComments(String hnId) async {
    setState(() {
      _fullCommentsLoading = true;
    });
    try {
      final roots = await _commentsRepo.fetchComments(hnId);
      if (!mounted) return;
      setState(() {
        _fullThreadRoots = roots;
        _fullCommentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fullCommentsLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load full discussion.')),
      );
    }
  }

  Widget _buildTopBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Top 50',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThreadLinePainter extends CustomPainter {
  final Color color;
  final bool showElbow;
  const _ThreadLinePainter({required this.color, this.showElbow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;

    final x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

    if (showElbow) {
      const y = 16.0;
      canvas.drawLine(Offset(x, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.showElbow != showElbow;
  }
}
