import 'package:flutter/material.dart';
import '../../../core/models/route_arguments.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../summary/data/summary_repository_impl.dart';
import '../data/comments_repository_impl.dart';
import '../domain/models/story_detail.dart';
import '../../../core/widgets/curate_loader.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.hnId});

  final String hnId;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _repo = CommentsRepositoryImpl();
  final _summaryRepo = SummaryRepositoryImpl();
  Future<List<CommentPreview>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _repo.fetchComments(widget.hnId);
  }

  Future<void> _explainComment(CommentPreview comment) async {
    if (!AuthSession.instance.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to generate AI explanations.')),
        );
      }
      return;
    }
    await _summaryRepo.generateSummary(
      comment.commentHnId,
      SummaryTargetType.comment,
    );
    if (mounted) {
      Navigator.pushNamed(
        context,
        routeSummary,
        arguments: SummaryRouteArgs(
          hnId: comment.commentHnId,
          targetType: SummaryTargetType.comment,
        ),
      );
    }
  }

  // Flatten tree into a list of (comment, depth) tuples
  List<_CommentDisplayItem> _flatten(List<CommentPreview> roots) {
    final out = <_CommentDisplayItem>[];
    for (final root in roots) {
      _recurse(root, 0, out);
    }
    return out;
  }

  void _recurse(CommentPreview node, int depth, List<_CommentDisplayItem> out) {
    out.add(_CommentDisplayItem(node, depth));
    for (final child in node.children) {
      _recurse(child, depth + 1, out);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: GradientBackground(
        child: FutureBuilder<List<CommentPreview>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CurateLoader(label: 'Curating discussion...', size: 80),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load discussion.'),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _future = _repo.fetchComments(widget.hnId);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final roots = snapshot.data ?? const <CommentPreview>[];
            if (roots.isEmpty) {
              return const Center(child: Text('No comments yet.'));
            }

            final flatItems = _flatten(roots);

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              itemCount: flatItems.length,
              itemBuilder: (context, index) {
                final item = flatItems[index];
                final c = item.comment;
                final depth = item.depth;

                // Indentation logic: base padding only (thread columns handle depth)
                final double leftPadding = 12.0;

                return Padding(
                  padding: EdgeInsets.only(
                    left: leftPadding,
                    right: 16.0,
                    bottom: 12.0,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (depth > 0) ...[
                          ..._buildThreadColumns(depth),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4.0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.author ?? 'user',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.0,
                                        color: depth == 0
                                            ? Colors.black
                                            : Colors.grey[800],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (c.time != null)
                                      Text(
                                        _formatTime(c.time!),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  (c.text ?? '').trim(),
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    height: 1.4,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: InkWell(
                                    onTap: () => _explainComment(c),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CurateAvatar(size: 14),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Explain',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.deepPurple,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
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
}

class _CommentDisplayItem {
  final CommentPreview comment;
  final int depth;
  _CommentDisplayItem(this.comment, this.depth);
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

    // Small elbow to point at the comment card
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
