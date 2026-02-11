import 'package:flutter/material.dart';
import '../../../core/models/route_arguments.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/summary_repository_impl.dart';
import '../domain/models/summary.dart';
import '../../../core/widgets/curate_loader.dart';

// Summary page (read-only)
// Responsibility: Present the backend-provided summary and provenance metadata.

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final _repo = SummaryRepositoryImpl();
  late SummaryRouteArgs _args;
  Summary? _summary;
  bool _loading = false;
  String? _error;
  String? _status;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _args = ModalRoute.of(context)!.settings.arguments as SummaryRouteArgs;
    _loadSummary();
    _initialized = true;
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading summary...';
    });
    try {
      final existing = await _repo.fetchSummary(_args.hnId, _args.targetType);
      if (existing != null) {
        setState(() {
          _summary = existing;
          _loading = false;
          _status = null;
        });
        return;
      }

      if (!AuthSession.instance.isLoggedIn) {
        setState(() {
          _summary = null;
          _loading = false;
          _error = 'Sign in to generate a summary.';
          _status = null;
        });
        return;
      }

      setState(() => _status = 'Generating summary...');
      final generated = await _repo.generateSummary(
        _args.hnId,
        _args.targetType,
      );
      setState(() {
        _summary = generated;
        _loading = false;
        _status = null;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load summary.';
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary (read-only)')),
      body: GradientBackground(
        child: Builder(
          builder: (context) {
            if (_loading) {
              return Center(
                child: CurateLoader(label: _status ?? 'Curating', size: 100),
              );
            }

            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 8.0),
                    TextButton(
                      onPressed: _loadSummary,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final summary = _summary;
            if (summary == null) {
              return Center(
                child: Text('Summary not available for ${_args.hnId}.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if ((summary.tldr ?? '').trim().isNotEmpty) ...[
                  const Text(
                    'TL;DR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6.0),
                  Text(summary.tldr!.trim()),
                  const SizedBox(height: 16.0),
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
                  const SizedBox(height: 16.0),
                ],
                if ((summary.consensus ?? '').trim().isNotEmpty) ...[
                  const Text(
                    'Consensus',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6.0),
                  Text(summary.consensus!.trim()),
                  const SizedBox(height: 16.0),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
