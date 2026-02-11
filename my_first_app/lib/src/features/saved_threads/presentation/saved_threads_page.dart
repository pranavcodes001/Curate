import 'package:flutter/material.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/saved_threads_repository_impl.dart';
import '../domain/models/saved_thread.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/curate_loader.dart';

class SavedThreadsPage extends StatefulWidget {
  const SavedThreadsPage({super.key});

  @override
  State<SavedThreadsPage> createState() => _SavedThreadsPageState();
}

class _SavedThreadsPageState extends State<SavedThreadsPage> {
  final _repo = SavedThreadsRepositoryImpl();
  Future<List<SavedThread>>? _future;

  @override
  void initState() {
    super.initState();
    AppState.instance.savedThreadsRefreshTrigger.addListener(_reload);
  }

  @override
  void dispose() {
    AppState.instance.savedThreadsRefreshTrigger.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _repo.listThreads();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.listThreads());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved threads')),
      body: GradientBackground(
        child: ValueListenableBuilder<String?>(
          valueListenable: AuthSession.instance.token,
          builder: (context, token, _) {
            final isLoggedIn = token != null && token.isNotEmpty;
            if (!isLoggedIn) {
              return const Center(
                child: Text('Sign in to view saved threads.'),
              );
            }

            // Re-fetch when token changes
            _future ??= _repo.listThreads();

            return FutureBuilder<List<SavedThread>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CurateLoader(label: 'Opening Library', size: 80),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Error loading saved threads:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8.0),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? const <SavedThread>[];
                if (items.isEmpty) {
                  return const Center(child: Text('No saved threads yet.'));
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 20.0),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.title ?? 'Untitled story'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((item.url ?? '').isNotEmpty)
                              Text(
                                item.url!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blue.shade300,
                                  fontSize: 11,
                                ),
                              ),
                            Text(
                              'Saved ${item.items.length} items • ${item.createdAt.split('T')[0]}',
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/saved_threads/${item.id}',
                            arguments: item.id,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
