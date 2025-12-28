import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../providers/team_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/ad_banner.dart';
import 'team_detail_screen.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  void _showCreateTeamSheet(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final customSportController = TextEditingController();
    Sport selectedSport = Sport.basketball;

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
                    'Create team',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Sport>(
                    value: selectedSport,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      border: OutlineInputBorder(),
                    ),
                    items: Sport.values.map((sport) {
                      return DropdownMenuItem(
                        value: sport,
                        child: Text('${sport.emoji} ${sport.label}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSport = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedSport == Sport.other)
                    TextField(
                      controller: customSportController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Activity name (e.g. Ultimate Frisbee, Yoga)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Location (city or field)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final location = locationController.text.trim();
                        final customSportName =
                            customSportController.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a team name'),
                            ),
                          );
                          return;
                        }

                        if (selectedSport == Sport.other &&
                            customSportName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an activity name'),
                            ),
                          );
                          return;
                        }

                        final auth = context.read<AuthProvider>();
                        final user = auth.user;

                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must be logged in to create a team'),
                            ),
                          );
                          return;
                        }

                        try {
                          await context.read<TeamProvider>().createTeam(
                                name: name,
                                sport: selectedSport,
                                adminId: user.uid,
                                location: location,
                                customSportName: selectedSport == Sport.other
                                    ? customSportName
                                    : null,
                              );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not create team. Please try again.'),
                              ),
                            );
                          }
                          return;
                        }

                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        'Create team',
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

  void _showJoinTeamSheet(BuildContext context) {
    final codeController = TextEditingController();

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
                    'Join team by code',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Team code',
                      hintText: 'e.g. WMH8KQ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final rawCode = codeController.text.trim();

                        if (rawCode.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a team code'),
                            ),
                          );
                          return;
                        }

                        final auth = context.read<AuthProvider>();
                        final user = auth.user;

                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must be logged in to join a team'),
                            ),
                          );
                          return;
                        }

                        final teamProvider = context.read<TeamProvider>();
                        final success = await teamProvider.joinTeam(
                          rawCode.toUpperCase(),
                          user.uid,
                        );

                        if (!context.mounted) return;

                        if (success) {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Joined team successfully'),
                            ),
                          );
                        } else {
                          final message =
                              teamProvider.error ?? 'Could not join team. Check the code and try again.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      },
                      child: Text(
                        'Join team',
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
    final colorScheme = Theme.of(context).colorScheme;
    final teamProvider = context.watch<TeamProvider>();
    final isLoading = teamProvider.isLoading;

    Future<void> _refresh() async {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user == null) return;
      await teamProvider.loadUserTeams(user.uid);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Teams',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join by code',
            onPressed: () => _showJoinTeamSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit_profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen(),
                  ),
                );
              } else if (value == 'sign_out') {
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit_profile',
                child: Text(
                  'Edit profile',
                  style: GoogleFonts.inter(),
                ),
              ),
              PopupMenuItem(
                value: 'sign_out',
                child: Text(
                  'Sign out',
                  style: GoogleFonts.inter(),
                ),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: Consumer<TeamProvider>(
                builder: (context, provider, _) {
                  final teams = provider.teams;

                  if (isLoading && teams.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (teams.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: EmptyState(
                          icon: Icons.group,
                          title: 'No teams joined',
                          message:
                              'Create or join a team to start organizing games with others.',
                          primaryActionLabel: 'Create team',
                          onPrimaryAction: () =>
                              _showCreateTeamSheet(context),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: teams.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      final sportLabel =
                          team.customSportName?.isNotEmpty == true
                              ? team.customSportName!
                              : team.sport.label;
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                colorScheme.primary.withOpacity(0.1),
                            child: Text(
                              team.sport.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            team.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '$sportLabel · ${team.location.isEmpty ? 'No location set' : team.location}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Code',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                team.teamCode,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TeamDetailScreen(teamId: team.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const AdBanner(),
          const SizedBox(height: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'teamsFab',
        onPressed: () => _showCreateTeamSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
