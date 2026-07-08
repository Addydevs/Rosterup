import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../models/game.dart';
import '../utils/app_colors.dart';
import '../utils/date_format_utils.dart';
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
  final VoidCallback? onGoToTeams;

  const GamesScreen({super.key, this.onGoToTeams});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _searchQuery = '';
  GamesFilter _filter = GamesFilter.all;

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final teamProvider = context.read<TeamProvider>();
    final gameProvider = context.read<GameProvider>();
    await teamProvider.loadUserTeams(user.uid);
    final teamIds = teamProvider.teams.map((t) => t.id).toList();
    await gameProvider.loadUpcomingGames(teamIds);
  }

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
    final uncachedIds = allConfirmedIds
        .where((id) => userProvider.getUserById(id) == null)
        .toList();
    if (uncachedIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<UserProvider>().loadUsersByIds(uncachedIds);
      });
    }

    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurfaceVariant;

    Game? nextGameNeedingStatus;
    if (currentUserId != null) {
      final cutoff = DateTime.now().add(const Duration(hours: 72));
      for (final game in games) {
        if (game.dateTime.isAfter(cutoff)) break; // games are sorted ascending
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
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Set your status for your next game.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
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
                    child: Text(
                      'Review',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
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
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: EmptyState(
                              icon: Icons.sports_soccer,
                              title: 'No games scheduled',
                              message:
                                  'Create or join a team to start organizing pickup games.',
                              primaryActionLabel: 'Go to Teams',
                              onPrimaryAction: widget.onGoToTeams,
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
                            final f = FormattedDate(date);
                            final weekday = f.weekday;
                            final month = f.month;
                            final day = f.day;
                            final hour = f.hour;
                            final minute = f.minute;
                            final period = f.period;

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
                                    color: Theme.of(context).colorScheme.outlineVariant,
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
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                              .withValues(
                                                                  alpha: 0.08),
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
                                                  Row(
                                                    children: [
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
                                                      ),
                                                      const SizedBox(width: 6),
                                                      GestureDetector(
                                                        onTap: () {
                                                          final team = matchingTeams.isNotEmpty ? matchingTeams.first : null;
                                                          final teamCode = team?.teamCode;
                                                          final accessCode = game.accessCode?.trim();
                                                          final hasAccessCode = !game.isPublic && (accessCode != null && accessCode.isNotEmpty);
                                                          final buffer = StringBuffer()
                                                            ..writeln('Join our game for $teamName on RosterUp!')
                                                            ..writeln()
                                                            ..writeln('Date: $weekday, $month $day at $hour:$minute $period')
                                                            ..writeln('Location: ${game.location.isEmpty ? 'TBD' : game.location}');
                                                          if (teamCode != null && teamCode.isNotEmpty) {
                                                            buffer.writeln('Team code: $teamCode');
                                                          }
                                                          if (hasAccessCode) {
                                                            buffer.writeln('Game access code: $accessCode');
                                                          }
                                                          buffer..writeln()..writeln('Download RosterUp: ${AppConstants.downloadUrl}');
                                                          SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Join our game on RosterUp'));
                                                        },
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.person_add,
                                                              size: 12,
                                                              color: Theme.of(context).colorScheme.primary,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'Invite',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 11,
                                                                color: Theme.of(context).colorScheme.primary,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
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
                                              selectedColor: AppColors.confirmed
                                                  .withValues(alpha: 0.18),
                                              backgroundColor: AppColors.confirmed
                                                  .withValues(alpha: 0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .confirmed
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: AppColors.confirmed,
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
                                                  .amber.withValues(alpha: 0.18),
                                              backgroundColor: Colors
                                                  .amber.withValues(alpha: 0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .maybe
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: AppColors.maybe,
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
                                                  AppColors.declined.withValues(alpha: 0.18),
                                              backgroundColor:
                                                  AppColors.declined.withValues(alpha: 0.06),
                                              labelStyle: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    currentStatus ==
                                                            ConfirmationStatus
                                                                .declined
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: AppColors.declined,
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
