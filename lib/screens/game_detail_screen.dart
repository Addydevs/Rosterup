import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/game.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../providers/user_provider.dart';

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

    final currentUserId = auth.user?.uid;
    final currentStatus = currentUserId != null
        ? game.confirmations[currentUserId]
        : null;

    final inPlayers = game.getPlayersWithStatus(ConfirmationStatus.confirmed);
    final maybePlayers = game.getPlayersWithStatus(ConfirmationStatus.maybe);
    final outPlayers = game.getPlayersWithStatus(ConfirmationStatus.declined);
    final noResponsePlayers =
        game.getPlayersWithStatus(ConfirmationStatus.noResponse);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Game vs pickup',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          game.location.isEmpty
                              ? 'No location set'
                              : game.location,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade700,
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
                        game.isPublic ? 'Public game' : 'Code required',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (!game.isPublic &&
                          (game.accessCode?.isNotEmpty ?? false)) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Code: ${game.accessCode}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                            color: Colors.grey.shade600,
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
                    await context.read<GameProvider>().confirmAttendance(
                          gameId: game.id,
                          userId: currentUserId,
                          status: ConfirmationStatus.declined,
                        );
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
            const SizedBox(height: 24),
          ],
          if (game.maxPlayersIn != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'In ${inPlayers.length} / ${game.maxPlayersIn}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: (game.maxPlayersIn != null &&
                          inPlayers.length >= game.maxPlayersIn!)
                      ? Colors.red
                      : Colors.grey.shade700,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              _summaryChip(
                context: context,
                label: "In (${inPlayers.length})",
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
          _statusSection(
            context: context,
            title: "I'm out",
            color: Colors.red,
            users: outPlayers,
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
                  color: Colors.grey.shade600,
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
    final background = isSelected ? color.withOpacity(0.1) : Colors.grey.shade100;
    final borderColor = isSelected ? color : Colors.grey.shade300;
    final textColor = isSelected ? color : Colors.grey.shade800;

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
