import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/team.dart';
import '../providers/game_provider.dart';
import '../providers/team_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/empty_state.dart';
import 'game_detail_screen.dart';

class DiscoverGamesScreen extends StatefulWidget {
  const DiscoverGamesScreen({super.key});

  @override
  State<DiscoverGamesScreen> createState() => _DiscoverGamesScreenState();
}

class _DiscoverGamesScreenState extends State<DiscoverGamesScreen> {
  Sport? _selectedSport;
  bool _useLocation = false;
  double _radiusKm = 25;
  Position? _position;
  bool _requestedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await context.read<GameProvider>().loadPublicUpcomingGames();
    });
  }

  double? _distanceKm(Game game) {
    if (_position == null || game.latitude == null || game.longitude == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    final dLat =
        _deg2rad(game.latitude! - _position!.latitude);
    final dLon =
        _deg2rad(game.longitude! - _position!.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(_position!.latitude)) *
            math.cos(_deg2rad(game.latitude!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  Future<void> _ensureLocation() async {
    if (_position != null || _requestedOnce) return;
    _requestedOnce = true;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied. Radius filter disabled.'),
        ),
      );
      setState(() {
        _useLocation = false;
      });
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    setState(() {
      _position = pos;
    });
  }

  void _showJoinWithAccessCode() {
    final teamCodeController = TextEditingController();
    final accessCodeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Join game with access code',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: teamCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Team code',
                      hintText: 'e.g. WMH8KQ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accessCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Game access code',
                      hintText: 'e.g. ABC123',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final teamCode = teamCodeController.text.trim();
                        final accessCode = accessCodeController.text.trim();

                        if (teamCode.isEmpty || accessCode.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Enter both team code and game access code'),
                            ),
                          );
                          return;
                        }

                        final auth = context.read<AuthProvider>();
                        final user = auth.user;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must be logged in to join a game'),
                            ),
                          );
                          return;
                        }

                        final teamProvider = context.read<TeamProvider>();
                        Team? team =
                            await teamProvider.findTeamByCode(teamCode);
                        if (team == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Team not found for that code'),
                            ),
                          );
                          return;
                        }

                        if (!team.memberIds.contains(user.uid)) {
                          final joined = await teamProvider.joinTeam(
                            teamCode,
                            user.uid,
                          );
                          if (!joined) {
                            final msg = teamProvider.error ??
                                'Could not join team for this game.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                            return;
                          }
                        }

                        final gameProvider = context.read<GameProvider>();
                        final game =
                            await gameProvider.findFirstGameByAccessCode(
                          teamId: team.id,
                          accessCode: accessCode,
                        );

                        if (game == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No game found with that access code'),
                            ),
                          );
                          return;
                        }

                        if (!mounted) return;
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameDetailScreen(gameId: game.id),
                          ),
                        );
                      },
                      child: Text(
                        'Find game',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final teamProvider = context.watch<TeamProvider>();
    final userProvider = context.watch<UserProvider>();
    final publicGames = gameProvider.publicGames;
    final isLoading = gameProvider.isLoading;

    var games = [...publicGames];

    if (_selectedSport != null) {
      games = games
          .where((g) =>
              teamProvider.teams
                  .where((t) => t.id == g.teamId)
                  .any((t) => t.sport == _selectedSport))
          .toList();
    }

    if (_useLocation && _position != null) {
      games = games.where((g) {
        final d = _distanceKm(g);
        return d == null || d <= _radiusKm;
      }).toList();
    }

    // Preload names for confirmed players in public games.
    final allConfirmedIds = <String>{};
    for (final game in games) {
      allConfirmedIds
          .addAll(game.getPlayersWithStatus(ConfirmationStatus.confirmed));
    }
    userProvider.loadUsersByIds(allConfirmedIds.toList());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover games',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Join with access code',
            onPressed: _showJoinWithAccessCode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Sport>(
                        value: _selectedSport,
                        decoration: const InputDecoration(
                          labelText: 'Sport',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Sport?>(
                            value: null,
                            child: Text('All sports'),
                          ),
                          ...Sport.values.map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.emoji} ${s.label}'),
                            ),
                          ),
                        ].whereType<DropdownMenuItem<Sport>>().toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSport = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Filter by distance',
                    style: GoogleFonts.inter(),
                  ),
                  value: _useLocation,
                  onChanged: (value) async {
                    setState(() {
                      _useLocation = value;
                    });
                    if (value) {
                      await _ensureLocation();
                    }
                  },
                ),
                if (_useLocation)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radius: ${_radiusKm.toStringAsFixed(0)} km',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      Slider(
                        min: 5,
                        max: 100,
                        value: _radiusKm,
                        divisions: 19,
                        label: '${_radiusKm.toStringAsFixed(0)} km',
                        onChanged: (value) {
                          setState(() {
                            _radiusKm = value;
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading && games.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : games.isEmpty
                    ? const Center(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 32),
                          child: EmptyState(
                            icon: Icons.public,
                            title: 'No public games nearby',
                            message:
                                'Check back later or create a game with your team.',
                          ),
                        ),
                      )
                    : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                      final weekday = weekdayNames[date.weekday - 1];
                      final month = months[date.month - 1];
                      final day = date.day;
                      final rawHour = date.hour;
                      final hour =
                          rawHour == 0 || rawHour == 12 ? 12 : rawHour % 12;
                      final minute =
                          date.minute.toString().padLeft(2, '0');
                      final period = date.hour < 12 ? 'AM' : 'PM';

                      final distance = _distanceKm(game);
                      final inCount = game.getConfirmedCount();
                      final maxPlayers = game.maxPlayersIn;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GameDetailScreen(gameId: game.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: Colors.grey.shade600,
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          teamName,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (distance != null)
                                          Text(
                                            '${distance.toStringAsFixed(1)} km away',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
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
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sports_soccer,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      team?.sport.label ?? 'Pickup',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  maxPlayers != null
                                      ? 'In $inCount / $maxPlayers'
                                      : 'In $inCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
