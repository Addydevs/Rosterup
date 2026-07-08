import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../utils/app_colors.dart';
import '../utils/theme_colors.dart';

/// Shows the current user's participation stats — games played, current
/// streak, and attendance rate — to reinforce the habit of showing up.
class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key});

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  bool _loading = true;
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    final teamProvider = context.read<TeamProvider>();
    final gameProvider = context.read<GameProvider>();

    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    if (teamProvider.teams.isEmpty) {
      await teamProvider.loadUserTeams(uid);
    }
    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    final pastGames = await gameProvider.fetchPastGames(teamIds);

    if (!mounted) return;
    setState(() {
      _stats = _computeStats(pastGames, uid, teamIds.length);
      _loading = false;
    });
  }

  _Stats _computeStats(List<Game> pastGames, String uid, int teamCount) {
    // Most recent first.
    final games = [...pastGames]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    int played = 0; // games the user confirmed for
    int missed = 0; // games the user declined or never responded to
    int currentStreak = 0;
    int longestStreak = 0;
    int runningStreak = 0;
    bool streakOpen = true; // current streak still counting from most recent

    for (final g in games) {
      final status = g.confirmations[uid];
      final wasIn = status == ConfirmationStatus.confirmed;

      if (wasIn) {
        played++;
        runningStreak++;
        if (runningStreak > longestStreak) longestStreak = runningStreak;
        if (streakOpen) currentStreak++;
      } else {
        missed++;
        runningStreak = 0;
        streakOpen = false;
      }
    }

    final totalRsvpd = played + missed;
    final attendanceRate =
        totalRsvpd == 0 ? 0 : ((played / totalRsvpd) * 100).round();

    return _Stats(
      gamesPlayed: played,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      attendanceRate: attendanceRate,
      totalGames: totalRsvpd,
      teamCount: teamCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your stats',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final stats = _stats;
    if (stats == null || stats.totalGames == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No stats yet',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play in a few games and your streak, attendance, '
                'and games played will show up here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stats.currentStreak >= 2)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  '${stats.currentStreak}-game streak',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You've shown up ${stats.currentStreak} games in a row. "
                  "Keep it going!",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _statTile(
                context,
                value: '${stats.gamesPlayed}',
                label: 'Games played',
                icon: Icons.sports_soccer,
                color: AppColors.confirmed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                context,
                value: '${stats.attendanceRate}%',
                label: 'Attendance',
                icon: Icons.check_circle_outline,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statTile(
                context,
                value: '${stats.currentStreak}',
                label: 'Current streak',
                icon: Icons.local_fire_department_outlined,
                color: AppColors.maybe,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                context,
                value: '${stats.longestStreak}',
                label: 'Best streak',
                icon: Icons.emoji_events_outlined,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statTile(
          context,
          value: '${stats.teamCount}',
          label: stats.teamCount == 1 ? 'Team' : 'Teams',
          icon: Icons.group_outlined,
          color: AppColors.info,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats {
  final int gamesPlayed;
  final int currentStreak;
  final int longestStreak;
  final int attendanceRate;
  final int totalGames;
  final int teamCount;

  _Stats({
    required this.gamesPlayed,
    required this.currentStreak,
    required this.longestStreak,
    required this.attendanceRate,
    required this.totalGames,
    required this.teamCount,
  });
}
