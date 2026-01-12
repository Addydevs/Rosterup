import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/ad_banner.dart';
import 'discover_games_screen.dart';
import 'game_detail_screen.dart';
import 'game_history_screen.dart';

enum GamesFilter {
  all,
  needingResponse,
  imIn,
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _searchQuery = '';
  GamesFilter _filter = GamesFilter.all;

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final teamProvider = context.watch<TeamProvider>();
    final userProvider = context.watch<UserProvider>();
    final games = gameProvider.getUpcomingGames();
    final isLoading = gameProvider.isLoading;

    // Preload confirmed users so we can show names.
    final allConfirmedIds = <String>{};
    for (final game in games) {
      allConfirmedIds
          .addAll(game.getPlayersWithStatus(ConfirmationStatus.confirmed));
    }
    userProvider.loadUsersByIds(allConfirmedIds.toList());

    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    Game? nextGameNeedingStatus;
    if (currentUserId != null) {
      for (final game in games) {
        final status = game.confirmations[currentUserId];
        if (status == null || status == ConfirmationStatus.noResponse) {
          nextGameNeedingStatus = game;
          break;
        }
      }
    }

    // Apply filters and search to games list.
    var filteredGames = [...games];
    if (currentUserId != null) {
      filteredGames = filteredGames.where((game) {
        final status = game.confirmations[currentUserId];
        switch (_filter) {
          case GamesFilter.all:
            return true;
          case GamesFilter.needingResponse:
            return status == null ||
                status == ConfirmationStatus.noResponse;
          case GamesFilter.imIn:
            return status == ConfirmationStatus.confirmed;
        }
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredGames = filteredGames.where((game) {
        final matchingTeams = teamProvider.teams
            .where((t) => t.id == game.teamId)
            .toList();
        final teamName =
            matchingTeams.isNotEmpty ? matchingTeams.first.name : '';
        final haystack =
            ('$teamName ${game.location}').toLowerCase();
        return haystack.contains(_searchQuery);
      }).toList();
    }

    Future<void> _refresh() async {
      final user = auth.user;
      if (user == null) return;
      await teamProvider.loadUserTeams(user.uid);
      final teamIds = teamProvider.teams.map((t) => t.id).toList();
      await gameProvider.loadUpcomingGames(teamIds);
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Games',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.public),
              tooltip: 'Discover public games',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DiscoverGamesScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Game history',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GameHistoryScreen(),
                  ),
                );
              },
            ),
          ],
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
          if (nextGameNeedingStatus != null)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Set your status for your next game.',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(
                            gameId: nextGameNeedingStatus!.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search games by team or location',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == GamesFilter.all,
                      onSelected: (_) {
                        setState(() {
                          _filter = GamesFilter.all;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Need response'),
                      selected: _filter == GamesFilter.needingResponse,
                      onSelected: (_) {
                        setState(() {
                          _filter = GamesFilter.needingResponse;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("I'm in"),
                      selected: _filter == GamesFilter.imIn,
                      onSelected: (_) {
                        setState(() {
                          _filter = GamesFilter.imIn;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: isLoading && games.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : games.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: EmptyState(
                              icon: Icons.sports_soccer,
                              title: 'No games scheduled',
                              message:
                                  'Create or join a team to start organizing pickup games.',
                            ),
                          ),
                        )
                      : filteredGames.isEmpty
                          ? const Center(
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 32),
                                child: EmptyState(
                                  icon: Icons.sports_soccer,
                                  title: 'No games match your filters',
                                  message:
                                      'Try clearing the search or filters to see more games.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: filteredGames.length,
                              itemBuilder: (context, index) {
                            final game = filteredGames[index];
                            final matchingTeams = teamProvider.teams
                                .where((t) => t.id == game.teamId)
                                .toList();
                            final teamName = matchingTeams.isNotEmpty
                                ? matchingTeams.first.name
                                : 'Unknown team';

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

                            final weekday = weekdayNames[date.weekday - 1];
                            final month = months[date.month - 1];
                            final day = date.day;
                            final rawHour = date.hour;
                            final hour =
                                rawHour == 0 || rawHour == 12 ? 12 : rawHour % 12;
                            final minute =
                                date.minute.toString().padLeft(2, '0');
                            final period = date.hour < 12 ? 'AM' : 'PM';

                            final currentUserId = auth.user?.uid;
                            final currentStatus = currentUserId != null
                                ? game.confirmations[currentUserId]
                                : null;
                            final inCount = game.getConfirmedCount();
                            final maybeCount = game.getMaybeCount();
                            final outCount = game.getDeclinedCount();
                            final maxPlayers = game.maxPlayersIn;
                            final totalGuests = game.getTotalGuestCount();
                            final totalInIncludingGuests =
                                inCount + totalGuests;
                            final isFull = maxPlayers != null &&
                                totalInIncludingGuests >= maxPlayers;

                            final confirmedIds = game.getPlayersWithStatus(
                              ConfirmationStatus.confirmed,
                            );
                            final confirmedNames = confirmedIds
                                .map(
                                  (id) =>
                                      userProvider.getUserById(id)?.name ??
                                      (id == currentUserId ? 'You' : 'Player'),
                                )
                                .toList();

                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GameDetailScreen(gameId: game.id),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
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
                                                '$weekday, $month $day',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: onSurfaceColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$hour:$minute $period',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            teamName,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            game.isPublic
                                                ? Icons.public
                                                : Icons.lock,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            game.isPublic
                                                ? 'Public'
                                                : 'Code required',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: onSurfaceColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (maxPlayers != null) ...[
                                        const SizedBox(height: 4),
                                        Builder(
                                          builder: (context) {
                                            final spotsLeft = maxPlayers -
                                                totalInIncludingGuests;
                                            final occupancyPercent =
                                                (totalInIncludingGuests /
                                                        maxPlayers *
                                                        100)
                                                    .round();
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'In $totalInIncludingGuests / $maxPlayers',
                                                      style:
                                                          GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: isFull
                                                            ? Colors.red
                                                            : onSurfaceColor,
                                                      ),
                                                    ),
                                                    if (isFull) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red
                                                              .withOpacity(
                                                                  0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          'Full',
                                                          style: GoogleFonts
                                                              .inter(
                                                            fontSize: 11,
                                                            color: Colors.red,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (!isFull && spotsLeft <= 3)
                                                  Text(
                                                    spotsLeft == 1
                                                        ? 'Only 1 spot left'
                                                        : 'Only $spotsLeft spots left',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  )
                                                else if (!isFull &&
                                                    occupancyPercent >= 70)
                                                  Text(
                                                    'Game is $occupancyPercent% full',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: onSurfaceColor,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      if (confirmedIds.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4),
                                          child: Text(
                                            confirmedNames.length == 1
                                                ? 'In: ${confirmedNames.first}'
                                                : 'In: ${confirmedNames.first} and ${confirmedNames.length - 1} others',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: onSurfaceColor,
                                            ),
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (currentUserId != null)
                                            ChoiceChip(
                                              label: Text("I'm in ($inCount)"),
                                              selected: currentStatus ==
                                                  ConfirmationStatus.confirmed,
                                              selectedColor: Colors.green
                                                  .withOpacity(0.18),
                                              backgroundColor: Colors.green
                                                  .withOpacity(0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .confirmed
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: Colors.green.shade800,
                                              ),
                                              onSelected: (_) {
                                                final alreadyIn =
                                                    currentStatus ==
                                                        ConfirmationStatus
                                                            .confirmed;
                                                if (maxPlayers != null &&
                                                    inCount >= maxPlayers &&
                                                    !alreadyIn) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'This game is full (In $inCount / $maxPlayers).',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                context
                                                    .read<GameProvider>()
                                                    .confirmAttendance(
                                                      gameId: game.id,
                                                      userId: currentUserId,
                                                      status:
                                                          ConfirmationStatus
                                                              .confirmed,
                                                    );
                                              },
                                            ),
                                          if (currentUserId != null)
                                            ChoiceChip(
                                              label:
                                                  Text('Maybe ($maybeCount)'),
                                              selected: currentStatus ==
                                                  ConfirmationStatus.maybe,
                                              selectedColor: Colors
                                                  .amber.withOpacity(0.18),
                                              backgroundColor: Colors
                                                  .amber.withOpacity(0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .maybe
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: Colors.orange.shade800,
                                              ),
                                              onSelected: (_) {
                                                context
                                                    .read<GameProvider>()
                                                    .confirmAttendance(
                                                      gameId: game.id,
                                                      userId: currentUserId,
                                                      status:
                                                          ConfirmationStatus
                                                              .maybe,
                                                    );
                                              },
                                            ),
                                          if (currentUserId != null)
                                            ChoiceChip(
                                              label:
                                                  Text("I'm out ($outCount)"),
                                              selected: currentStatus ==
                                                  ConfirmationStatus.declined,
                                              selectedColor:
                                                  Colors.red.withOpacity(0.18),
                                              backgroundColor:
                                                  Colors.red.withOpacity(0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .declined
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: Colors.red.shade800,
                                              ),
                                              onSelected: (_) {
                                                context
                                                    .read<GameProvider>()
                                                    .confirmAttendance(
                                                      gameId: game.id,
                                                      userId: currentUserId,
                                                      status:
                                                          ConfirmationStatus
                                                              .declined,
                                                    );
                                              },
                                            ),
                                        ],
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
      ),
      bottomNavigationBar: const AdBanner(),
    ),
  );
  }
}
