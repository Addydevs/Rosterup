import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../models/game.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/ad_banner.dart';
import '../services/analytics_service.dart';

class GameDetailScreen extends StatelessWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final teamProvider = context.watch<TeamProvider>();
    final userProvider = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final game = gameProvider.getGameById(gameId);

    if (game == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Game details'),
        ),
        body: const Center(
          child: Text('Game not found'),
        ),
      );
    }

    final team = teamProvider.teams
        .where((t) => t.id == game.teamId)
        .toList()
        .cast()
        .firstOrNull;
    final teamName = team?.name ?? 'Unknown team';

    final date = game.dateTime;
    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final hour = rawHour == 0 || rawHour == 12 ? 12 : rawHour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    final locationText =
        game.location.isEmpty ? 'No location set' : game.location;

    final teamCode = team?.teamCode;
    final accessCode = game.accessCode?.trim();
    final hasAccessCode =
        !game.isPublic && (accessCode != null && accessCode.isNotEmpty);

    final String shareMessage = () {
      final buffer = StringBuffer()
        ..writeln('Join our game for $teamName on RosterUp.')
        ..writeln()
        ..writeln('Date: $weekday, $month $day at $hour:$minute $period')
        ..writeln('Location: $locationText');

      if (teamCode != null && teamCode.isNotEmpty) {
        buffer.writeln('Team code: $teamCode');
      }
      if (hasAccessCode) {
        buffer.writeln('Game access code: $accessCode');
      }

      if (teamCode != null && teamCode.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('How to join:')
          ..writeln(
            '- Open RosterUp and create an account.',
          )
          ..writeln(
            '- Go to Teams → Join by code and enter $teamCode.',
          );

        if (hasAccessCode) {
          buffer.writeln(
            '- Then go to Games → Discover (globe icon) → "Join with access code" and enter $accessCode.',
          );
        }
      }

      return buffer.toString();
    }();

    final currentUserId = auth.user?.uid;
    final currentStatus = currentUserId != null
        ? game.confirmations[currentUserId]
        : null;

    final inPlayers = game.getPlayersWithStatus(ConfirmationStatus.confirmed);
    final maybePlayers = game.getPlayersWithStatus(ConfirmationStatus.maybe);
    final outPlayers = game.getPlayersWithStatus(ConfirmationStatus.declined);
    final noResponsePlayers =
        game.getPlayersWithStatus(ConfirmationStatus.noResponse);

    final totalGuests = game.getTotalGuestCount();
    final hasGuests = totalGuests > 0;
    final totalInIncludingGuests = inPlayers.length + totalGuests;

    final allUserIds = <String>{
      ...inPlayers,
      ...maybePlayers,
      ...outPlayers,
      ...noResponsePlayers,
    }.where((id) => id.isNotEmpty).toList();
    userProvider.loadUsersByIds(allUserIds);

    String _displayName(String userId) {
      final user = userProvider.getUserById(userId);
      if (user != null && user.name.isNotEmpty) {
        final current = userProvider.currentUser;
        if (current != null && current.id == userId) {
          return '${user.name} (you)';
        }
        return user.name;
      }
      return userId;
    }

    Future<String?> _loadStreakLabel() async {
      final pastGames =
          await gameProvider.fetchPastGames([game.teamId]);
      final now = DateTime.now();
      final relevant = pastGames
          .where((g) => g.dateTime.isBefore(now))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (relevant.isEmpty || currentUserId == null) return null;

      int streak = 0;
      DateTime? firstGameInStreak;

      for (final g in relevant) {
        final status = g.confirmations[currentUserId];
        if (status == ConfirmationStatus.confirmed) {
          streak += 1;
          firstGameInStreak ??= g.dateTime;
        } else {
          break;
        }
      }

      if (streak <= 1 || firstGameInStreak == null) return null;

      final weeks = now.difference(firstGameInStreak).inDays ~/ 7 + 1;
      if (weeks >= 3) {
        return '$streak‑game streak over $weeks weeks';
      }
      return 'You’ve made $streak games in a row';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          teamName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share game',
            onPressed: () {
              AnalyticsService.logGameShare(
                gameId: game.id,
                teamId: game.teamId,
                isPublic: game.isPublic,
                hasAccessCode: hasAccessCode,
              );
              Share.share(
                shareMessage,
                subject: 'Join our game on RosterUp',
              );
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // Primary game info card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$weekday, $month $day · $hour:$minute $period',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationText,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        game.isPublic ? Icons.public : Icons.lock,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        game.isPublic
                            ? 'Public game'
                            : 'Private game · code required',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (hasAccessCode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game access code',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  accessCode!,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (teamCode != null &&
                                    teamCode.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Team code: $teamCode',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Copy access code',
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: accessCode),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Game access code copied',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Share game',
                                icon: const Icon(Icons.ios_share, size: 20),
                                onPressed: () {
                                  AnalyticsService.logGameShare(
                                    gameId: game.id,
                                    teamId: game.teamId,
                                    isPublic: game.isPublic,
                                    hasAccessCode: hasAccessCode,
                                  );
                                  Share.share(
                                    shareMessage,
                                    subject:
                                        'Join our game on RosterUp',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (game.isRecurring) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.repeat, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Repeats weekly',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (currentUserId != null)
            FutureBuilder<String?>(
              future: _loadStreakLabel(),
              builder: (context, snapshot) {
                final label = snapshot.data;
                if (snapshot.connectionState ==
                        ConnectionState.waiting ||
                    label == null) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Colors.blue.withOpacity(0.04),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (currentUserId != null) ...[
            Text(
              'Your status',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusButton(
                  context: context,
                  label: "I'm in",
                  color: Colors.green,
                  isSelected: currentStatus == ConfirmationStatus.confirmed,
                  onPressed: () async {
                    await context.read<GameProvider>().confirmAttendance(
                          gameId: game.id,
                          userId: currentUserId,
                          status: ConfirmationStatus.confirmed,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status set to In'),
                      ),
                    );
                  },
                ),
                _statusButton(
                  context: context,
                  label: 'Maybe',
                  color: Colors.orange,
                  isSelected: currentStatus == ConfirmationStatus.maybe,
                  onPressed: () async {
                    await context.read<GameProvider>().confirmAttendance(
                          gameId: game.id,
                          userId: currentUserId,
                          status: ConfirmationStatus.maybe,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status set to Maybe'),
                      ),
                    );
                  },
                ),
                _statusButton(
                  context: context,
                  label: "I'm out",
                  color: Colors.red,
                  isSelected: currentStatus == ConfirmationStatus.declined,
                  onPressed: () async {
                    // Ask for a quick reason when going Out.
                    final reasonCode =
                        await _showOutReasonSheet(context);

                    await context.read<GameProvider>().confirmAttendance(
                          gameId: game.id,
                          userId: currentUserId,
                          status: ConfirmationStatus.declined,
                        );

                    if (reasonCode != null && reasonCode.isNotEmpty) {
                      await context.read<GameProvider>().setDeclineReason(
                            gameId: game.id,
                            userId: currentUserId,
                            reasonCode: reasonCode,
                          );
                    }

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status set to Out'),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (currentStatus == ConfirmationStatus.confirmed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value:
                        (game.guestCounts[currentUserId] ?? 0) > 0,
                    onChanged: (value) async {
                      final newCount =
                          (value ?? false) ? 1 : 0;
                      await context
                          .read<GameProvider>()
                          .setGuestCount(
                            gameId: game.id,
                            userId: currentUserId,
                            guestCount: newCount,
                          );
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Bringing a plus one',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
          if (game.maxPlayersIn != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'In $totalInIncludingGuests / ${game.maxPlayersIn}'
                '${hasGuests ? ' (including guests)' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: (game.maxPlayersIn != null &&
                          totalInIncludingGuests >=
                              game.maxPlayersIn!)
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          if (game.maxPlayersIn != null) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final maxPlayers = game.maxPlayersIn!;
                final spotsLeft = maxPlayers - totalInIncludingGuests;
                final occupancyPercent =
                    (totalInIncludingGuests / maxPlayers * 100).round();
                if (spotsLeft > 0 && spotsLeft <= 3) {
                  return Text(
                    spotsLeft == 1
                        ? 'Only 1 spot left – invite a teammate'
                        : 'Only $spotsLeft spots left – invite more players',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                } else if (spotsLeft <= 0) {
                  return const SizedBox.shrink();
                } else if (occupancyPercent >= 70) {
                  return Text(
                    'This game is $occupancyPercent% full',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              _summaryChip(
                context: context,
                label: hasGuests
                    ? "In (${inPlayers.length} + $totalGuests guests)"
                    : "In (${inPlayers.length})",
                color: Colors.green,
              ),
              _summaryChip(
                context: context,
                label: "Maybe (${maybePlayers.length})",
                color: Colors.orange,
              ),
              _summaryChip(
                context: context,
                label: "Out (${outPlayers.length})",
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (game.latitude != null && game.longitude != null)
            _LocationMapSection(game: game),
          if (game.latitude != null && game.longitude != null)
            const SizedBox(height: 24),
          _statusSection(
            context: context,
            title: "I'm in",
            color: Colors.green,
            users: inPlayers,
            displayName: _displayName,
          ),
          const SizedBox(height: 16),
          _statusSection(
            context: context,
            title: 'Maybe',
            color: Colors.orange,
            users: maybePlayers,
            displayName: _displayName,
          ),
          const SizedBox(height: 16),
          _outStatusSection(
            context: context,
            users: outPlayers,
            game: game,
            displayName: _displayName,
          ),
          const SizedBox(height: 16),
          _statusSection(
            context: context,
            title: 'No response',
            color: Colors.grey,
            users: noResponsePlayers,
            displayName: _displayName,
          ),
        ],
      ),
    ),
  );
  }

  Future<String?> _showOutReasonSheet(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Why are you out?',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.healing),
                title: const Text('Injured'),
                onTap: () => Navigator.of(sheetContext).pop('injured'),
              ),
              ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: const Text('Out of town'),
                onTap: () => Navigator.of(sheetContext).pop('travel'),
              ),
              ListTile(
                leading: const Icon(Icons.event_busy),
                title: const Text('Schedule conflict'),
                onTap: () => Navigator.of(sheetContext).pop('conflict'),
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz),
                title: const Text('Other'),
                onTap: () => Navigator.of(sheetContext).pop('other'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _statusSection({
    required BuildContext context,
    required String title,
    required Color color,
    required List<String> users,
    required String Function(String) displayName,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${users.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (users.isEmpty)
              Text(
                'No one here yet.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: users
                    .map(
                      (u) => Chip(
                        label: Text(
                          displayName(u),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _outStatusSection({
    required BuildContext context,
    required List<String> users,
    required Game game,
    required String Function(String) displayName,
  }) {
    String reasonLabel(String userId) {
      final code = game.declineReasons[userId] ?? '';
      switch (code) {
        case 'injured':
          return 'Injured';
        case 'travel':
          return 'Out of town';
        case 'conflict':
          return 'Schedule conflict';
        case 'other':
          return 'Other';
        default:
          return '';
      }
    }

    IconData? reasonIcon(String userId) {
      final code = game.declineReasons[userId] ?? '';
      switch (code) {
        case 'injured':
          return Icons.healing;
        case 'travel':
          return Icons.flight_takeoff;
        case 'conflict':
          return Icons.event_busy;
        case 'other':
          return Icons.info_outline;
        default:
          return null;
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "I'm out",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${users.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (users.isEmpty)
              Text(
                'No one here yet.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: users.map((u) {
                  final label = reasonLabel(u);
                  final icon = reasonIcon(u);
                  return Chip(
                    avatar: icon != null
                        ? Icon(
                            icon,
                            size: 16,
                          )
                        : null,
                    label: Text(
                      label.isEmpty
                          ? displayName(u)
                          : '${displayName(u)} · $label',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({
    required BuildContext context,
    required String label,
    required Color color,
  }) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _statusButton({
    required BuildContext context,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final background =
        isSelected ? color.withOpacity(0.1) : Colors.grey.shade100;
    final borderColor = isSelected ? color : Colors.grey.shade300;
    final textColor = isSelected
        ? color
        : Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}

class _LocationMapSection extends StatelessWidget {
  final Game game;

  const _LocationMapSection({required this.game});

  @override
  Widget build(BuildContext context) {
    final lat = game.latitude;
    final lng = game.longitude;
    if (lat == null || lng == null) {
      return const SizedBox.shrink();
    }

    final position = LatLng(lat, lng);

    Future<void> _openDirections() async {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('game_location'),
                    position: position,
                    infoWindow: InfoWindow(title: game.location),
                  ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _openDirections,
            icon: const Icon(Icons.directions),
            label: const Text('Get directions'),
          ),
        ],
      ),
    );
  }
}
