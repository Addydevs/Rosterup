import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../widgets/ad_banner.dart';

class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final gameProvider = context.read<GameProvider>();
    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

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
            : FutureBuilder<List<Game>>(
                future: gameProvider.fetchPastGames(teamIds),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load past games.',
                        style:
                            GoogleFonts.inter(color: onSurfaceColor),
                      ),
                    );
                  }
                  final games = snapshot.data ?? [];
                  if (games.isEmpty) {
                    return Center(
                      child: Text(
                        'No past games yet.',
                        style:
                            GoogleFonts.inter(color: onSurfaceColor),
                      ),
                    );
                  }

                  return ListView.builder(
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
                      final weekdayNames = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      const months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];

                      final weekday =
                          weekdayNames[date.weekday - 1];
                      final month = months[date.month - 1];
                      final day = date.day;
                      final rawHour = date.hour;
                      final hour = rawHour == 0 || rawHour == 12
                          ? 12
                          : rawHour % 12;
                      final minute =
                          date.minute.toString().padLeft(2, '0');
                      final period =
                          date.hour < 12 ? 'AM' : 'PM';

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
                              color: Colors.grey.shade200),
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
                                      color: Colors.green,
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
      bottomNavigationBar: const AdBanner(),
    );
  }
}
