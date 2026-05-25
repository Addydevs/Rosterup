import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../utils/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../widgets/ad_banner.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  Future<List<Game>>? _future;
  List<String> _lastTeamIds = [];

  void _loadGames(List<String> teamIds) {
    if (teamIds.isEmpty) {
      setState(() {
        _future = Future.value([]);
        _lastTeamIds = teamIds;
      });
      return;
    }
    final gameProvider = context.read<GameProvider>();
    setState(() {
      _future = gameProvider.fetchPastGames(teamIds);
      _lastTeamIds = teamIds;
    });
  }

  Future<void> _refresh() async {
    final teamProvider = context.read<TeamProvider>();
    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    _loadGames(teamIds);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    // Load (or re-load when team membership changes) lazily.
    if (_future == null || teamIds.join(',') != _lastTeamIds.join(',')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadGames(teamIds);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Game history',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: teamIds.isEmpty
            ? Center(
                child: Text(
                  'Join a team to see past games.',
                  style: GoogleFonts.inter(color: onSurfaceColor),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Game>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load past games.',
                          style: GoogleFonts.inter(color: onSurfaceColor),
                        ),
                      );
                    }
                    final games = snapshot.data ?? [];
                    if (games.isEmpty) {
                      return Center(
                        child: Text(
                          'No past games yet.',
                          style: GoogleFonts.inter(color: onSurfaceColor),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      final team = teamProvider.teams
                          .where((t) => t.id == game.teamId)
                          .toList()
                          .cast()
                          .firstOrNull;
                      final teamName = team?.name ?? 'Unknown team';

                      final date = game.dateTime;
                      final f = FormattedDate(date);
                      final weekday = f.weekday;
                      final month = f.month;
                      final day = f.day;
                      final hour = f.hour;
                      final minute = f.minute;
                      final period = f.period;

                      final inCount = game.getConfirmedCount();
                      final maybeCount = game.getMaybeCount();
                      final outCount = game.getDeclinedCount();

                      return Card(
                        elevation: 0,
                        margin:
                            const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$weekday, $month $day · $hour:$minute $period',
                                        style:
                                            GoogleFonts.inter(
                                          fontSize: 13,
                                          color: onSurfaceColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        teamName,
                                        style:
                                            GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${game.getConfirmedCount()} going',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.confirmed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                game.location.isEmpty
                                    ? 'No location set'
                                    : game.location,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: onSurfaceColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Attendance: in $inCount · maybe $maybeCount · out $outCount',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: onSurfaceColor,
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
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
