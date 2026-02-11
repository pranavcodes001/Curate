import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/core/state/app_state.dart';
import 'src/features/onboarding/presentation/onboarding_flow.dart';
import 'src/features/feed/presentation/feed_page.dart';
import 'src/features/story_detail/presentation/story_detail_page.dart';
import 'src/features/story_detail/presentation/comments_page.dart';
import 'src/features/summary/presentation/summary_page.dart';
import 'src/features/auth/presentation/login_page.dart';
import 'src/features/profile/presentation/profile_page.dart';
import 'src/features/saved_threads/presentation/saved_threads_page.dart';
import 'src/features/saved_threads/presentation/saved_thread_detail_page.dart';
import 'src/core/navigation/app_routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState.instance.isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Curate',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A1A1A),
              surface: const Color(0xFFF6F3EE),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.ibmPlexSansTextTheme(),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF6F3EE),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF6F3EE),
              foregroundColor: Color(0xFF1A1A1A),
              elevation: 0,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFFF6F3EE),
              selectedItemColor: Color(0xFF1A1A1A),
              unselectedItemColor: Color(0xFF7A7A7A),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              surface: const Color(0xFF121212),
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.ibmPlexSansTextTheme(
              ThemeData.dark().textTheme,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF121212),
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
          ),
          routes: {
            routeFeed: (context) => const FeedPage(),
            routeStoryDetail: (context) => const StoryDetailPage(),
            routeSummary: (context) => const SummaryPage(),
            routeLogin: (context) => const LoginPage(),
            routeSavedThreads: (context) => const SavedThreadsPage(),
          },
          home: ValueListenableBuilder<bool>(
            valueListenable: AppState.instance.onboardingComplete,
            builder: (context, done, _) {
              return done ? const _MainShell() : const OnboardingFlow();
            },
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/story/comments') {
              final hnId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => CommentsPage(hnId: hnId),
              );
            }
            if (settings.name != null &&
                settings.name!.startsWith('/saved_threads/')) {
              final id = int.tryParse(settings.name!.split('/').last) ?? 0;
              return MaterialPageRoute(
                builder: (_) => SavedThreadDetailPage(threadId: id),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          FeedPage(),
          FeedPage(mode: FeedMode.top),
          SavedThreadsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == _index && (i == 0 || i == 1)) {
            AppState.instance.feedResetTrigger.value++;
          }
          setState(() => _index = i);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            activeIcon: Icon(Icons.trending_up_rounded),
            label: 'Top 50',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
