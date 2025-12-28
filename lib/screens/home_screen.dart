import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/team_provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import 'games_screen.dart';
import 'teams_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _initialized = false;

  final List<Widget> _screens = const [
    GamesScreen(),
    TeamsScreen(),
    ChatScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to auth changes so we only initialize
    // once a real Firebase user is available.
    final auth = Provider.of<AuthProvider>(context);
    if (!_initialized && auth.user != null) {
      _initialized = true;
      _loadInitialData();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
