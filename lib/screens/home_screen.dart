import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/team_provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import 'games_screen.dart';
import 'teams_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialJoinTeamCode;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialJoinTeamCode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  bool _initialized = false;
  bool _showTour = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _screens = [
      const GamesScreen(),
      TeamsScreen(initialJoinCode: widget.initialJoinTeamCode),
      const ChatScreen(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to auth changes so we only initialize
    // once a real Firebase user is available.
    final auth = Provider.of<AuthProvider>(context);
    if (!_initialized && auth.user != null) {
      _initialized = true;
      _loadInitialData();
      _maybeShowTour();
    }
  }

  Future<void> _loadInitialData() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final teamProvider = context.read<TeamProvider>();
    final gameProvider = context.read<GameProvider>();
    final userProvider = context.read<UserProvider>();

    await teamProvider.loadUserTeams(user.uid);

    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    await gameProvider.loadUpcomingGames(teamIds);

    // Initialize notifications and store FCM token for this user.
    final notificationService = NotificationService();
    await notificationService.initialize();
    final token = await notificationService.getFcmToken();
    if (token != null) {
      await userProvider.addFcmToken(user.uid, token);
    }
  }

  Future<void> _maybeShowTour() async {
    final userProvider = context.read<UserProvider>();
    final appUser = userProvider.currentUser;

    // If we don't have user data yet, skip the tour to avoid flicker.
    if (appUser == null) return;

    final prefs = Map<String, dynamic>.from(appUser.preferences);
    final hasSeenTour = prefs['hasSeenHomeTour'] == true;
    if (hasSeenTour) return;

    setState(() {
      _showTour = true;
    });

    prefs['hasSeenHomeTour'] = true;
    await userProvider.updatePreferences(prefs);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            if (_showTour)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                            'Welcome to your dashboard',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Games: see upcoming games and RSVP.\n'
                            '• Teams: create or join teams, then open a team and tap “Add game” to schedule.\n'
                            '• Chat: coordinate with your team in real time.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _showTour = false;
                                  });
                                },
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          final tab = switch (index) {
            0 => 'games',
            1 => 'teams',
            2 => 'chat',
            _ => 'unknown',
          };
          AnalyticsService.logHomeTabViewed(tab: tab);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer_outlined),
            activeIcon: Icon(Icons.sports_soccer),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Teams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
