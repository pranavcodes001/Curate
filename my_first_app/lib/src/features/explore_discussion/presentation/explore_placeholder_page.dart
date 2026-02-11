import 'package:flutter/material.dart';
import '../../../core/models/route_arguments.dart';
import '../../../core/navigation/route_guard.dart';
import '../../../core/navigation/consent_dialog.dart';
import '../../summary/data/summary_repository_impl.dart';
import '../../summary/domain/models/summary.dart';
import '../../../core/widgets/curate_loader.dart';

// Explore Discussion shell (v1)
// Responsibility: Show summary as first step and mocked guided options.
// No AI logic, no guided question computation.
//
// Gating note: the Explore flow must not be accessible without consent. To be
// robust against direct route navigation, we verify consent on page entry and
// re-run the consent flow if needed. If the user declines, we return them to
// the previous screen.

class ExplorePlaceholderPage extends StatefulWidget {
  const ExplorePlaceholderPage({super.key});

  @override
  State<ExplorePlaceholderPage> createState() => _ExplorePlaceholderPageState();
}

class _ExplorePlaceholderPageState extends State<ExplorePlaceholderPage> {
  final _repo = SummaryRepositoryImpl();
  late ExploreDiscussionRouteArgs _args;
  Future<Summary?>? _future;
  bool _initialized = false;
  String? _activeNodeId;

  static const _guidedNodes = [
    GuidedNodeConfig(
      id: 'technical_analysis',
      title: 'Technical analysis',
      description: 'Focus on technical claims and mechanisms.',
      v1Label: 'Guided analysis (v1)',
      suggestedNextId: 'community_sentiment',
      isActive: true,
    ),
    GuidedNodeConfig(
      id: 'disagreement',
      title: 'What are people disagreeing about?',
      description: 'Identify key disagreements and perspectives.',
      v1Label: 'Guided analysis (v1)',
      isActive: false,
    ),
    GuidedNodeConfig(
      id: 'community_sentiment',
      title: 'Community sentiment & viewpoints',
      description: 'What people generally agree or disagree on',
      v1Label: 'Guided analysis (v1)',
      suggestedNextId: 'verification',
      isActive: true,
    ),
    GuidedNodeConfig(
      id: 'verification',
      title: 'Verification & sources',
      description: 'Show sources and verification points.',
      v1Label: 'Guided analysis (v1)',
      isActive: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Post-frame: check consent and prompt if missing.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ConsentService.instance.consentGiven) {
        final accepted = await showExploreConsentDialog(context);
        if (!accepted) {
          // user declined; go back to Story Detail
          if (mounted) Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _args =
        ModalRoute.of(context)!.settings.arguments
            as ExploreDiscussionRouteArgs;
    _future = _repo.fetchSummary(_args.hnId, SummaryTargetType.story);
    _initialized = true;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.fetchSummary(_args.hnId, SummaryTargetType.story);
    });
    await _future;
  }

  void _showPlaceholderMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This guided analysis will be available soon.'),
      ),
    );
  }

  void _openNode(String nodeId) {
    setState(() {
      _activeNodeId = nodeId;
    });
  }

  void _closeNode() {
    setState(() {
      _activeNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CurateLoader(label: 'Curating exploration', size: 100),
        ),
      );
    }

    final title = (_args.title ?? '').trim();
    final storyTitle = title.isEmpty ? 'Story ${_args.hnId}' : title;

    return Scaffold(
      appBar: AppBar(title: const Text('Explore discussion')),
      body: FutureBuilder<Summary?>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CurateLoader(label: 'Finding focus', size: 100),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load summary.'),
                  const SizedBox(height: 8.0),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            );
          }

          final summary = snapshot.data;
          final modelVersion = summary?.modelVersion;
          final modelName = summary?.modelName;

          final provenanceParts = <String>[
            'Backend summary',
            if (modelVersion != null && modelVersion.isNotEmpty)
              'model v$modelVersion',
            if (modelName != null && modelName.isNotEmpty) modelName,
          ];
          final provenance = provenanceParts.join(' • ');

          if (_activeNodeId != null) {
            final node = _guidedNodes.firstWhere((n) => n.id == _activeNodeId);
            return _buildGuidedNode(summary, node);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                storyTitle,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12.0),
              const Text(
                'Step 1 — Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              if (summary == null) ...[
                Text('Summary not available for story ${_args.hnId}.'),
                const SizedBox(height: 8.0),
              ] else ...[
                if ((summary.tldr ?? '').trim().isNotEmpty) ...[
                  Text(summary.tldr!.trim()),
                  const SizedBox(height: 12.0),
                ],
                if (summary.keyPoints.isNotEmpty) ...[
                  const Text(
                    'Key points',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6.0),
                  for (final point in summary.keyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text('• $point'),
                    ),
                  const SizedBox(height: 12.0),
                ],
                if (summary.consensus?.trim() case final consensus?
                    when consensus.isNotEmpty) ...[
                  const Text(
                    'Consensus',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6.0),
                  Text(consensus),
                  const SizedBox(height: 12.0),
                ],
              ],
              Text(
                provenance,
                style: const TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
              const SizedBox(height: 20.0),
              const Text(
                'Next — Guided options',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              for (final node in _guidedNodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(node.title),
                  subtitle: node.description == null
                      ? null
                      : Text(node.description!),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: node.isActive,
                  onTap: node.isActive
                      ? () => _openNode(node.id)
                      : _showPlaceholderMessage,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGuidedNode(Summary? summary, GuidedNodeConfig node) {
    final title = (_args.title ?? '').trim();
    final storyTitle = title.isEmpty ? 'Story ${_args.hnId}' : title;

    final content = _buildNodeContent(summary, node);
    final provenance = _buildProvenance(node, storyTitle, summary);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _closeNode,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8.0),
            Text(
              node.title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        if (node.v1Label case final v1Label?)
          Text(
            v1Label,
            style: const TextStyle(fontSize: 12.0, color: Colors.grey),
          ),
        const SizedBox(height: 12.0),
        ...content,
        const SizedBox(height: 16.0),
        _buildSuggestedNext(node),
        const SizedBox(height: 12.0),
        Text(
          provenance,
          style: const TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
      ],
    );
  }

  String _buildProvenance(
    GuidedNodeConfig node,
    String storyTitle,
    Summary? summary,
  ) {
    final parts = <String>[
      node.v1Label ?? 'Guided analysis',
      'Based on backend summary',
    ];

    final modelName = summary?.modelName?.trim();
    if (modelName != null && modelName.isNotEmpty) {
      parts.add(modelName);
    }

    final modelVersion = summary?.modelVersion?.trim();
    if (modelVersion != null && modelVersion.isNotEmpty) {
      parts.add('model v$modelVersion');
    }

    parts.add('Story metadata: $storyTitle');
    return parts.join(' • ');
  }

  Widget _buildSuggestedNext(GuidedNodeConfig node) {
    if (node.suggestedNextId == null) {
      return const SizedBox.shrink();
    }

    final next = _guidedNodes.firstWhere((n) => n.id == node.suggestedNextId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested next',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(next.title),
          subtitle: next.description == null ? null : Text(next.description!),
          trailing: const Icon(Icons.chevron_right),
          enabled: next.isActive,
          onTap: next.isActive
              ? () => _openNode(next.id)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This guided analysis is coming soon.'),
                    ),
                  );
                },
        ),
      ],
    );
  }

  List<Widget> _buildNodeContent(Summary? summary, GuidedNodeConfig node) {
    if (node.id == 'community_sentiment') {
      return _buildCommunitySentiment(summary);
    }
    return _buildTechnicalAnalysis(summary);
  }

  List<Widget> _buildTechnicalAnalysis(Summary? summary) {
    final bullets = <String>[];
    if (summary != null && summary.keyPoints.isNotEmpty) {
      for (final point in summary.keyPoints) {
        if (bullets.length >= 5) break;
        final cleaned = point.trim();
        if (cleaned.isNotEmpty) bullets.add(cleaned);
      }
    }

    final tldr = summary?.tldr?.trim();
    final explanation = (tldr != null && tldr.isNotEmpty)
        ? tldr
        : 'Summary is not available for this story yet.';

    final consensus = summary?.consensus?.trim() ?? '';

    final widgets = <Widget>[Text(explanation)];
    if (summary != null && bullets.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 12.0),
        const Text('Key points', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6.0),
        for (final point in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text('• $point'),
          ),
      ]);
    }
    if (summary != null && consensus.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 12.0),
        const Text('Consensus', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6.0),
        Text(consensus),
      ]);
    }
    return widgets;
  }

  List<Widget> _buildCommunitySentiment(Summary? summary) {
    if (summary == null) {
      return const [Text('Summary is not available for this story yet.')];
    }

    final widgets = <Widget>[];
    final consensus = (summary.consensus ?? '').trim();
    if (consensus.isNotEmpty) {
      widgets.addAll([
        const Text('Consensus', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6.0),
        Text(consensus),
        const SizedBox(height: 12.0),
      ]);
    }

    final viewpoints = <String>[];
    if (summary.keyPoints.isNotEmpty) {
      for (final point in summary.keyPoints) {
        if (viewpoints.length >= 3) break;
        final cleaned = point.trim();
        if (cleaned.isNotEmpty) viewpoints.add(cleaned);
      }
    }

    if (viewpoints.isNotEmpty) {
      widgets.addAll([
        const Text(
          'Representative viewpoints',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6.0),
        for (final point in viewpoints)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text('• $point'),
          ),
      ]);
    } else if (consensus.isEmpty) {
      widgets.add(const Text('Summary is not available for this story yet.'));
    }

    return widgets;
  }
}

class GuidedNodeConfig {
  final String id;
  final String title;
  final String? description;
  final String? v1Label;
  final String? suggestedNextId;
  final bool isActive;

  const GuidedNodeConfig({
    required this.id,
    required this.title,
    this.description,
    this.v1Label,
    this.suggestedNextId,
    required this.isActive,
  });
}
