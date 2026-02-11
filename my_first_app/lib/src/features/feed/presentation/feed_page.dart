import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/string_util.dart';
import '../../../core/models/route_arguments.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/state/app_state.dart';
import '../domain/models/feed_item.dart';
import '../data/feed_repository_impl.dart';
import '../data/search_repository_impl.dart';
import '../../../core/widgets/curate_loader.dart';

enum FeedMode { interest, top, search }

// Feed page (read-only). Consumes backend feed API and navigates to Story Detail.

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.mode = FeedMode.interest});

  final FeedMode mode;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  final _repo = FeedRepositoryImpl();
  final _searchRepo = SearchRepositoryImpl();
  final _searchController = TextEditingController();
  late Future<List<FeedItem>> _future;
  bool _searchMode = false;
  bool _allowSearch = true;
  final Set<int> _seenIds = <int>{};
  final List<int> _pendingSeen = <int>[];
  final List<String> _keywords = [];
  Timer? _seenFlushTimer;
  bool _searchExpanded = false;
  final Set<String> _selectedFilters = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchMode = widget.mode == FeedMode.search;
    _allowSearch = widget.mode != FeedMode.top;
    _future = _initialFuture();

    // Eagerly fetch Top 50 IDs to show badges in Interest/Search feeds
    if (AppState.instance.topStoryIds.value.isEmpty) {
      _fetchTopIdsOnly();
    }

    // Refresh feed when auth state changes
    AuthSession.instance.token.addListener(_onAuthChanged);
    AppState.instance.feedResetTrigger.addListener(_onGlobalReset);
  }

  Future<void> _fetchTopIdsOnly() async {
    try {
      final top = await _repo.fetchTopStories(limit: 50);
      AppState.instance.topStoryIds.value = top.map((e) => e.hnId).toSet();
    } catch (_) {}
  }

  void _onAuthChanged() {
    if (mounted) {
      _reload();
    }
  }

  void _onGlobalReset() {
    if (!mounted) return;
    setState(() {
      _searchExpanded = false;
      _searchMode = false;
      _keywords.clear();
      _selectedFilters.clear();
      _searchController.clear();
      _reload();
    });
  }

  @override
  void dispose() {
    AuthSession.instance.token.removeListener(_onAuthChanged);
    AppState.instance.feedResetTrigger.removeListener(_onGlobalReset);
    _seenFlushTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _searchMode
          ? _searchRepo.search(_searchController.text.trim())
          : _fetchPrimaryFeed();
    });
    await _future;
  }

  void _toggleFilter(String interest) {
    setState(() {
      if (_selectedFilters.contains(interest)) {
        _selectedFilters.remove(interest);
      } else {
        _selectedFilters.add(interest);
      }
    });
  }

  void _addKeyword(String val) {
    final clean = val.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (_keywords.contains(clean)) return;
    if (_keywords.length >= 5) return;
    setState(() {
      _keywords.add(clean);
      // Removed _applySearch() to only fetch on explicit search tap
    });
  }

  void _removeKeyword(String val) {
    setState(() {
      _keywords.remove(val);
      // Removed _applySearch() to only fetch on explicit search tap
    });
  }

  void _applySearch() {
    if (!_allowSearch) {
      return;
    }
    final currentText = _searchController.text.trim();
    final allTerms = [..._keywords];
    if (currentText.isNotEmpty && allTerms.length < 5) {
      allTerms.add(currentText);
    }

    setState(() {
      _searchMode = allTerms.isNotEmpty;
      if (_searchMode) {
        final query = allTerms.join(' ');
        _future = _searchRepo.search(query);
      } else {
        // Essential: If searching is cleared, we MUST revert to primary feed
        _future = _fetchPrimaryFeed();
      }
    });
  }

  Future<List<FeedItem>> _initialFuture() {
    if (_searchMode) {
      return Future.value(const <FeedItem>[]);
    }
    return _fetchPrimaryFeed();
  }

  Future<List<FeedItem>> _fetchPrimaryFeed() async {
    debugPrint('FeedPage: _fetchPrimaryFeed started, mode=${widget.mode}');
    try {
      if (widget.mode == FeedMode.top) {
        debugPrint('FeedPage: Fetching top stories');
        final result = await _repo.fetchTopStories();
        AppState.instance.topStoryIds.value = result.map((e) => e.hnId).toSet();
        debugPrint('FeedPage: Found ${result.length} top stories');
        return result;
      } else {
        // Interest feed logic
        debugPrint(
          'FeedPage: Fetching interest feed. LoggedIn=${AuthSession.instance.isLoggedIn}',
        );
        if (!AuthSession.instance.isLoggedIn) {
          debugPrint('FeedPage: Not logged in, falling back to top stories');
          return await _repo.fetchTopStories();
        }

        final result = await _repo.fetchInterestFeed();
        debugPrint('FeedPage: Found ${result.length} interest stories');

        // Ensure topStoryIds is populated for badges if this is Home page
        if (AppState.instance.topStoryIds.value.isEmpty) {
          debugPrint('FeedPage: Fetching top IDs for badges');
          _fetchTopIdsOnly();
        }

        return result;
      }
    } catch (e) {
      debugPrint('FeedPage: ERROR in _fetchPrimaryFeed: $e');
      // Fallback to top stories only for completely disconnected or unauthenticated Home feed
      if (widget.mode == FeedMode.interest &&
          !AuthSession.instance.isLoggedIn) {
        return await _repo.fetchTopStories();
      }
      rethrow;
    }
  }

  String _title() {
    switch (widget.mode) {
      case FeedMode.search:
        return 'Search';
      case FeedMode.top:
        return 'Top 50';
      case FeedMode.interest:
        return 'Home';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: _searchExpanded
            ? _buildAppBarSearchField()
            : Row(
                children: [
                  Text(_title()),
                  if (widget.mode == FeedMode.top) ...[
                    const SizedBox(width: 8),
                    _buildTopBadge(),
                  ],
                ],
              ),
        actions: [
          if (_allowSearch)
            IconButton(
              onPressed: () {
                setState(() {
                  _searchExpanded = !_searchExpanded;
                  if (!_searchExpanded) {
                    _keywords.clear();
                    _searchController.clear();
                    _applySearch();
                  }
                });
              },
              icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              tooltip: 'Search',
            ),
        ],
      ),
      body: GradientBackground(
        child: FutureBuilder<List<FeedItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CurateLoader(
                  label: _searchMode
                      ? 'Searching Discussions'
                      : 'Curating your feed',
                  size: 100,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load feed.'),
                    const SizedBox(height: 8.0),
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              );
            }

            final allItems = snapshot.data ?? const <FeedItem>[];
            final items = _selectedFilters.isEmpty
                ? allItems
                : allItems.where((item) {
                    final tags = item.tags ?? [];
                    return tags.any((tag) => _selectedFilters.contains(tag));
                  }).toList();

            return Column(
              children: [
                if (widget.mode == FeedMode.interest)
                  ValueListenableBuilder<List<String>>(
                    valueListenable: AppState.instance.interests,
                    builder: (context, interests, _) {
                      if (interests.isEmpty) return const SizedBox.shrink();
                      return Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: interests.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final interest = interests[i];
                            final isSelected = _selectedFilters.contains(
                              interest,
                            );
                            return FilterChip(
                              label: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) => _toggleFilter(interest),
                              showCheckmark: false,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.5,
                              ),
                              selectedColor: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _selectedFilters.isNotEmpty
                                  ? 'No stories match your filters.'
                                  : 'No stories found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: items.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final title = (item.title ?? '').trim();
                              final isNavigable = item.hnId.trim().isNotEmpty;
                              final score = item.score ?? 0;
                              final time = item.time ?? 0;

                              return InkWell(
                                onTap: isNavigable
                                    ? () {
                                        Navigator.pushNamed(
                                          context,
                                          routeStoryDetail,
                                          arguments: StoryDetailRouteArgs(
                                            hnId: item.hnId,
                                            title: item.title,
                                            source: item.url,
                                          ),
                                        );
                                      }
                                    : null,
                                child: VisibilityDetector(
                                  key: Key(
                                    'feed-${widget.mode.name}-${item.hnId}',
                                  ),
                                  onVisibilityChanged: (info) {
                                    if (info.visibleFraction >= 0.4) {
                                      _queueSeen(item);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 10.0,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.isEmpty
                                              ? 'Untitled story'
                                              : StringUtil.clean(title),
                                          style: TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w600,
                                            color: item.isRead
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ValueListenableBuilder<Set<String>>(
                                          valueListenable:
                                              AppState.instance.topStoryIds,
                                          builder: (context, topIds, _) {
                                            final isTop = topIds.contains(
                                              item.hnId,
                                            );
                                            return Row(
                                              children: [
                                                if (isTop &&
                                                    widget.mode !=
                                                        FeedMode.top) ...[
                                                  _buildTopBadge(),
                                                  const SizedBox(width: 8.0),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    'Score $score • ${_formatUnix(time)}',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 12.0,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Not interested',
                                                  icon: const Icon(
                                                    Icons.thumb_down_alt_outlined,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () async {
                                                    await _dismissStory(item);
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBarSearchField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChipWidth = constraints.maxWidth * 0.6;
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              if (_keywords.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _keywords
                          .map((k) => _buildInlineKeywordChip(k))
                          .toList(),
                    ),
                  ),
                ),
              if (_keywords.isNotEmpty) const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _handleKeywordInput,
                  decoration: InputDecoration(
                    hintText: _keywords.isEmpty
                        ? 'Search keywords using commas...'
                        : 'Add keyword…',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle:
                        const TextStyle(fontSize: 16, color: Color(0xFF7A7A7A)),
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleKeywordInput(String val) {
    if (!val.contains(',')) return;
    final parts = val.split(',');
    if (parts.length <= 1) return;
    for (int i = 0; i < parts.length - 1; i++) {
      _addKeyword(parts[i]);
    }
    final remainder = parts.last;
    final newText = remainder.trimLeft();
    _searchController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  Widget _buildInlineKeywordChip(String k) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(k, style: const TextStyle(fontSize: 12)),
        onDeleted: () => _removeKeyword(k),
        backgroundColor: const Color(0xFFF0F0F0),
        deleteIcon: const Icon(Icons.cancel, size: 14),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _formatUnix(int time) {
    if (time == 0) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _queueSeen(FeedItem item) {
    if (widget.mode != FeedMode.interest) return;
    if (!AuthSession.instance.isLoggedIn) return;
    final id = int.tryParse(item.hnId);
    if (id == null) return;
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);
    _pendingSeen.add(id);
    _scheduleSeenFlush();
  }

  void _scheduleSeenFlush() {
    if (_seenFlushTimer != null) return;
    _seenFlushTimer = Timer(const Duration(seconds: 1), () async {
      _seenFlushTimer = null;
      if (_pendingSeen.isEmpty) return;
      final batch = List<int>.from(_pendingSeen);
      _pendingSeen.clear();
      try {
        await _repo.markSeen(batch.map((e) => e.toString()).toList());
      } catch (_) {
        // best-effort
      }
    });
  }

  Future<void> _dismissStory(FeedItem item) async {
    if (widget.mode != FeedMode.interest) return;
    if (!AuthSession.instance.isLoggedIn) return;
    try {
      await _repo.dismissStory(item.hnId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story dismissed')),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to dismiss story')),
      );
    }
  }
}
