import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/state/app_state.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/login_page.dart';
import '../../../core/widgets/curate_loader.dart';

class _InterestItem {
  _InterestItem({
    required this.id,
    required this.group,
    required this.name,
    required this.keywords,
  });

  final int id;
  final String group;
  final String name;
  final List<String> keywords;
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _index = 0;
  final _selectedIds = <int>{};
  final _selectedNames = <String>{};
  String? _error;
  bool _loadingInterests = false;
  List<_InterestItem> _interests = const [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
    _checkExistingSync();
  }

  Future<void> _checkExistingSync() async {
    if (!AuthSession.instance.isLoggedIn) return;

    setState(() => _syncing = true);
    try {
      final api = ApiClient();
      final resp = await api.get('/v1/interests/me', auth: true);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final selectedNames = (data['selected'] as List)
            .map((e) => e['name'] as String)
            .toList();

        if (selectedNames.isNotEmpty) {
          // Sync found, complete immediately
          await AppState.instance.completeOnboarding(selectedNames);
          return;
        }
      }
    } catch (_) {
      // Best effort
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _next() {
    if (_index < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    if (_selectedIds.length < 5 || _selectedIds.length > 10) {
      setState(() => _error = 'Pick 5 to 10 interests.');
      return;
    }

    if (!AuthSession.instance.isLoggedIn) {
      setState(() => _error = 'Please sign in to finish.');
      return;
    }

    _submitInterests();
  }

  Future<void> _loadInterests() async {
    setState(() {
      _loadingInterests = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final resp = await api.get('/v1/interests');
      if (resp.statusCode != 200) {
        throw Exception('Failed: ${resp.statusCode}');
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw Exception('Invalid response');
      }
      final items = <_InterestItem>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'];
        final group = item['group'];
        final name = item['name'];
        final keywords = item['keywords'];
        if (id is! int || group is! String || name is! String) continue;
        final kw = <String>[];
        if (keywords is List) {
          for (final k in keywords) {
            if (k is String) kw.add(k);
          }
        }
        items.add(
          _InterestItem(id: id, group: group, name: name, keywords: kw),
        );
      }
      items.sort((a, b) {
        final g = a.group.compareTo(b.group);
        return g != 0 ? g : a.name.compareTo(b.name);
      });
      setState(() {
        _interests = items;
        _loadingInterests = false;
      });
    } catch (_) {
      setState(() {
        _loadingInterests = false;
        _error = 'Failed to load interests. Tap to retry.';
      });
    }
  }

  Map<String, List<_InterestItem>> _grouped() {
    final map = <String, List<_InterestItem>>{};
    for (final item in _interests) {
      map.putIfAbsent(item.group, () => []).add(item);
    }
    return map;
  }

  Future<void> _submitInterests() async {
    setState(() => _error = null);
    try {
      final api = ApiClient();
      final resp = await api.post(
        '/v1/interests/selection',
        auth: true,
        body: {'interest_ids': _selectedIds.toList()},
      );
      if (resp.statusCode != 200) {
        throw Exception('Failed: ${resp.statusCode}');
      }
      await AppState.instance.completeOnboarding(_selectedNames.toList());
    } catch (_) {
      setState(() => _error = 'Failed to save interests. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncing) {
      return const Scaffold(
        body: Center(
          child: CurateLoader(label: 'Syncing your curation', size: 100),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: SafeArea(
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          children: [_buildWelcome(), _buildAuthGate(), _buildInterests()],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CurateAvatar(size: 120),
          const SizedBox(height: 32),
          const Text(
            'We don’t just show news.\nWe host the world’s most meaningful discussions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 80),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _next,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A1A1A),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthGate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_rounded, size: 60, color: Colors.blueAccent),
          const SizedBox(height: 32),
          const Text(
            'Secure Your Journey',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create an account to save threads across devices and personalize your feed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF7A7A7A)),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(isModal: true),
                  ),
                );
                if (AuthSession.instance.isLoggedIn) {
                  _next();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Sign Up / Sign In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterests() {
    Widget interestBody;
    if (_loadingInterests) {
      interestBody = const Center(
        child: CurateLoader(label: 'Curating interests...', size: 80),
      );
    } else if (_interests.isEmpty) {
      interestBody = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'No categories found.',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadInterests, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      interestBody = ListView(
        padding: const EdgeInsets.only(top: 16),
        children: _grouped().entries.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.key.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: group.value.map((item) {
                    final selected = _selectedIds.contains(item.id);
                    return FilterChip(
                      label: Text(
                        item.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            if (_selectedIds.length >= 10) {
                              _error = 'Max 10 interests allowed.';
                              return;
                            }
                            _selectedIds.add(item.id);
                            _selectedNames.add(item.name);
                          } else {
                            _selectedIds.remove(item.id);
                            _selectedNames.remove(item.name);
                          }
                          _error = null;
                        });
                      },
                      selectedColor: Colors.white.withValues(alpha: 0.6),
                      checkmarkColor: const Color(0xFF1A1A1A),
                      labelStyle: TextStyle(
                        color: selected ? const Color(0xFF1A1A1A) : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF1A1A1A)
                              : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personalize Your Shelf',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select 5 to 10 topics to curate your Home feed.',
            style: TextStyle(color: Color(0xFF7A7A7A)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: interestBody),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Complete Onboarding',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
