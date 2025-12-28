import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../models/user.dart';
import '../providers/team_provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/location_picker.dart';
import '../models/game.dart';
import 'game_detail_screen.dart';

class TeamDetailScreen extends StatelessWidget {
  final String teamId;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
  });

  Future<void> _createGamesFromSchedule(
    BuildContext context,
    Team team,
    Map<int, TimeOfDay> dayTimes,
  ) async {
    final gameProvider = context.read<GameProvider>();
    final existingGames = gameProvider.getGamesForTeam(team.id);
    final existingDates = existingGames
        .map((g) => g.dateTime.toIso8601String())
        .toSet();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 28)); // next 4 weeks

    for (int offset = 0;
        offset <= end.difference(start).inDays;
        offset++) {
      final date = start.add(Duration(days: offset));
      final dayIndex = date.weekday; // 1 = Monday
      final time = dayTimes[dayIndex];
      if (time == null) continue;

      final dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      if (!dateTime.isAfter(now)) continue;

      final key = dateTime.toIso8601String();
      if (existingDates.contains(key)) continue;

      await gameProvider.createGame(
        teamId: team.id,
        dateTime: dateTime,
        location: team.location,
        isRecurring: true,
        isPublic: true,
        accessCode: null,
      );

      existingDates.add(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamProvider = context.watch<TeamProvider>();
    final team = teamProvider.teams.firstWhere((t) => t.id == teamId);
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;
    final isAdmin = currentUserId != null && currentUserId == team.adminId;
    final gameProvider = context.watch<GameProvider>();
    final teamGames = gameProvider.getGamesForTeam(teamId);

    void showScheduleSheet() {
      final existingSchedule = team.recurringSchedule;
      final Map<int, TimeOfDay> dayTimes = {
        if (existingSchedule != null)
          for (final slot in existingSchedule.slots)
            slot.dayOfWeek: slot.time,
      };

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
                String formatTime(TimeOfDay time) {
                  final hour =
                      time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
                  final minute = time.minute.toString().padLeft(2, '0');
                  final period =
                      time.period == DayPeriod.am ? 'AM' : 'PM';
                  return '$hour:$minute $period';
                }

                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
                      'Schedule weekly game',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select the days your team usually plays and a start time. You can change this anytime.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(days.length, (index) {
                        final dayIndex = index + 1; // 1 = Monday
                        final time = dayTimes[dayIndex];
                        final isSelected = time != null;
                        final label = isSelected
                            ? '${days[index]} ${formatTime(time)}'
                            : days[index];

                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) async {
                            if (selected) {
                              final initialTime = time ??
                                  const TimeOfDay(hour: 19, minute: 0);
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initialTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  dayTimes[dayIndex] = picked;
                                });
                              }
                            } else {
                              setState(() {
                                dayTimes.remove(dayIndex);
                              });
                            }
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                      onPressed: () async {
                          if (dayTimes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Select at least one day of the week'),
                              ),
                            );
                            return;
                          }

                          await context.read<TeamProvider>().setRecurringSchedule(
                                teamId: team.id,
                                dayTimes: dayTimes,
                              );

                          await _createGamesFromSchedule(
                            context,
                            team,
                            dayTimes,
                          );

                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(
                          'Save schedule',
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          team.name,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!isAdmin && currentUserId != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'leave') {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Leave team'),
                          content: Text(
                            'Are you sure you want to leave ${team.name}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirmed) return;

                  final success = await context
                      .read<TeamProvider>()
                      .leaveTeam(teamId: team.id, userId: currentUserId);

                  if (!context.mounted) return;

                  if (success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You left ${team.name}'),
                      ),
                    );
                  } else {
                    final error =
                        context.read<TeamProvider>().error ?? 'Could not leave team.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave team'),
                ),
              ],
            )
          else if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  final controller = TextEditingController(text: team.name);
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Edit team name'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Team name',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(controller.text),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );

                  if (newName == null) return;

                  final trimmed = newName.trim();
                  if (trimmed.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Team name cannot be empty'),
                      ),
                    );
                    return;
                  }

                  final success = await context
                      .read<TeamProvider>()
                      .renameTeam(
                        teamId: team.id,
                        newName: trimmed,
                        requesterId: currentUserId!,
                      );

                  if (!context.mounted) return;

                  if (!success) {
                    final error = context.read<TeamProvider>().error ??
                        'Could not rename team.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Edit team name'),
                ),
              ],
            )
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      team.sport.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          team.customSportName?.isNotEmpty == true
                              ? team.customSportName!
                              : team.sport.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          team.location.isEmpty
                              ? 'No location set'
                              : team.location,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Code',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            team.teamCode,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 18,
                            ),
                            tooltip: 'Copy team code',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: team.teamCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Team code copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming games',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _showCreateGameSheet(context, teamId);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add game'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (team.recurringSchedule == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No weekly schedule yet.\nUse “Schedule game” to set your usual game days.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly games',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatScheduleSummary(team.recurringSchedule!),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (teamGames.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No individual games scheduled yet.\nUse “Add game” below to create one.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            Column(
              children: teamGames
                  .map((game) => _GameListTile(
                        game: game,
                      ))
                  .toList(),
            ),
          const SizedBox(height: 24),
          Text(
            'Roster',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _RosterSection(team: team),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'teamScheduleFab_$teamId',
              onPressed: showScheduleSheet,
              icon: const Icon(Icons.event),
              label: const Text('Schedule weekly games'),
            )
          : null,
    );
  }

  String _formatScheduleSummary(RecurringSchedule schedule) {
    const dayLabels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final sortedSlots = [...schedule.slots]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    String formatTime(TimeOfDay time) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }

    final parts = sortedSlots.map((slot) {
      final day = dayLabels[slot.dayOfWeek] ?? '';
      return '$day ${formatTime(slot.time)}';
    }).toList();

    return parts.join(', ');
  }

  Future<void> _showCreateGameSheet(BuildContext context, String teamId) async {
    final locationController = TextEditingController();
    final maxPlayersController = TextEditingController();
    double? selectedLatitude;
    double? selectedLongitude;
    DateTime? selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 19, minute: 0);
    bool isPublic = true;
    bool repeatWeekly = false;
    final accessCodeController = TextEditingController();

    await showModalBottomSheet(
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
              Future<void> pickDate() async {
                final now = DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 1),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                }
              }

              Future<void> pickTime() async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time;
                  });
                }
              }

              String formatDate(DateTime? date) {
                if (date == null) return 'Pick date';
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
                final weekdayNames = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                final weekday = weekdayNames[date.weekday - 1];
                final month = months[date.month - 1];
                return '$weekday, $month ${date.day}, ${date.year}';
              }

              String formatTime(TimeOfDay time) {
                final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
                final minute = time.minute.toString().padLeft(2, '0');
                final period = time.period == DayPeriod.am ? 'AM' : 'PM';
                return '$hour:$minute $period';
              }

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
                    'Schedule single game',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.event),
                          label: Text(formatDate(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(formatTime(selectedTime)),
                  ),
                  const SizedBox(height: 12),
                  LocationPicker(
                    controller: locationController,
                    onLocationSelected: (lat, lng) {
                      selectedLatitude = lat;
                      selectedLongitude = lng;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxPlayersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Player cap (optional)',
                      hintText: 'e.g. 12',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Repeat weekly',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Use this date and time every week.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: repeatWeekly,
                    onChanged: (value) {
                      setState(() {
                        repeatWeekly = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Public game',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isPublic
                          ? 'Anyone with the team can see this game.'
                          : 'Only people with the code can join.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: isPublic,
                    onChanged: (value) {
                      setState(() {
                        isPublic = value;
                      });
                    },
                  ),
                  if (!isPublic) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: accessCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Access code',
                        hintText: 'e.g. ABC123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please pick a date'),
                            ),
                          );
                          return;
                        }

                        final dateTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        if (!isPublic &&
                            accessCodeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please enter an access code for private games'),
                            ),
                          );
                          return;
                        }

                        int? maxPlayersIn;
                        final capText = maxPlayersController.text.trim();
                        if (capText.isNotEmpty) {
                          final parsed = int.tryParse(capText);
                          if (parsed != null && parsed > 0) {
                            maxPlayersIn = parsed;
                          }
                        }

                        try {
                          await context.read<GameProvider>().createGame(
                                teamId: teamId,
                                dateTime: dateTime,
                                location: locationController.text.trim(),
                                latitude: selectedLatitude,
                                longitude: selectedLongitude,
                                maxPlayersIn: maxPlayersIn,
                                isRecurring: repeatWeekly,
                                isPublic: isPublic,
                                accessCode: isPublic
                                    ? null
                                    : accessCodeController.text.trim(),
                              );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Could not create game. Please try again.'),
                              ),
                            );
                          }
                          return;
                        }

                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        'Add game',
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
}

class _RosterSection extends StatelessWidget {
  final Team team;

  const _RosterSection({required this.team});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final members = team.memberIds;

    userProvider.loadUsersByIds(members);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (members.isEmpty)
            Text(
              'No roster yet. Share your team code so teammates can join.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final memberId = members[index];
                final isAdmin = memberId == team.adminId;
                final appUser = userProvider.getUserById(memberId);
                final currentUser = userProvider.currentUser;
                final isCurrentUser =
                    currentUser != null && currentUser.id == memberId;
                final isCurrentUserAdmin =
                    auth.user?.uid == team.adminId;
                final isMuted = team.mutedMemberIds.contains(memberId);

                String displayName;
                if (appUser != null && appUser.name.isNotEmpty) {
                  displayName =
                      isCurrentUser ? '${appUser.name} (you)' : appUser.name;
                } else if (isCurrentUser && currentUser?.name.isNotEmpty == true) {
                  displayName = '${currentUser!.name} (you)';
                } else {
                  displayName = memberId;
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary.withOpacity(0.08),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isAdmin)
                            Text(
                              'Admin',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (!isAdmin && isMuted)
                            Text(
                              'Muted',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isCurrentUser)
                      IconButton(
                        icon: const Icon(Icons.flag_outlined),
                        color: Colors.grey,
                        tooltip: 'Report user',
                        onPressed: () {
                          _showReportUserDialog(
                            context,
                            memberId,
                            displayName,
                          );
                        },
                      ),
                    if (isCurrentUserAdmin && memberId != team.adminId) ...[
                      IconButton(
                        icon: Icon(
                          isMuted
                              ? Icons.volume_off
                              : Icons.volume_mute_outlined,
                        ),
                        color: isMuted ? Colors.redAccent : Colors.grey,
                        tooltip: isMuted ? 'Unmute in chat' : 'Mute in chat',
                        onPressed: () async {
                          final success = await context
                              .read<TeamProvider>()
                              .muteMember(
                                teamId: team.id,
                                memberId: memberId,
                                requesterId: auth.user!.uid,
                                muted: !isMuted,
                              );

                          if (!success) {
                            final error = context
                                    .read<TeamProvider>()
                                    .error ??
                                'Could not update mute status.';
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.redAccent,
                        tooltip: 'Remove from team',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove member'),
                                  content: Text(
                                    'Remove $displayName from this team?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (!confirmed) return;

                          final success = await context
                              .read<TeamProvider>()
                              .removeMember(
                                teamId: team.id,
                                memberId: memberId,
                                requesterId: auth.user!.uid,
                              );

                          if (!success) {
                            final error = context
                                    .read<TeamProvider>()
                                    .error ??
                                'Could not remove member. Please try again.';
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showReportUserDialog(
    BuildContext context,
    String reportedUserId,
    String displayName,
  ) async {
    final auth = context.read<AuthProvider>();
    final reporterId = auth.user?.uid;
    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to report users.'),
        ),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();
    final TextEditingController detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Report $displayName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final reason = reasonController.text.trim().isEmpty
        ? 'No reason provided'
        : reasonController.text.trim();
    final details = detailsController.text.trim().isEmpty
        ? null
        : detailsController.text.trim();

    final reportProvider = context.read<ReportProvider>();
    final success = await reportProvider.reportUser(
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: reason,
      additionalDetails: details,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. We have received your report.'),
        ),
      );
    } else {
      final error =
          reportProvider.error ?? 'Could not submit report. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}

class _GameListTile extends StatelessWidget {
  final Game game;

  const _GameListTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.uid;

    if (currentUserId == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final date = game.dateTime;
    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdayNames[date.weekday - 1];
    final month = _monthAbbrev(date.month);
    final day = date.day;
    final rawHour = date.hour;
    final hour = rawHour == 0 || rawHour == 12 ? 12 : rawHour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';

    final currentStatus = game.confirmations[currentUserId];
    final inCount = game.getConfirmedCount();
    final maybeCount = game.getMaybeCount();
    final outCount = game.getDeclinedCount();
    final maxPlayers = game.maxPlayersIn;
    final isFull = maxPlayers != null && inCount >= maxPlayers;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$month $day',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          '$hour:$minute $period',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.location.isEmpty ? 'No location set' : game.location,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  game.isPublic ? Icons.public : Icons.lock,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  game.isPublic ? 'Public' : 'Code required',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (maxPlayers != null) ...[
              const SizedBox(height: 4),
              Text(
                'In $inCount / $maxPlayers',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isFull ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (currentUserId != null)
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text("I'm in ($inCount)"),
                    selected: currentStatus == ConfirmationStatus.confirmed,
                    selectedColor: Colors.green.withOpacity(0.18),
                    backgroundColor: Colors.green.withOpacity(0.06),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: currentStatus == ConfirmationStatus.confirmed
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.green.shade800,
                    ),
                    onSelected: (_) {
                      final alreadyIn =
                          currentStatus == ConfirmationStatus.confirmed;
                      if (maxPlayers != null &&
                          inCount >= maxPlayers &&
                          !alreadyIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'This game is full (In $inCount / $maxPlayers).',
                            ),
                          ),
                        );
                        return;
                      }
                      context.read<GameProvider>().confirmAttendance(
                            gameId: game.id,
                            userId: currentUserId,
                            status: ConfirmationStatus.confirmed,
                          );
                    },
                  ),
                  ChoiceChip(
                    label: Text('Maybe ($maybeCount)'),
                    selected: currentStatus == ConfirmationStatus.maybe,
                    selectedColor: Colors.amber.withOpacity(0.18),
                    backgroundColor: Colors.amber.withOpacity(0.06),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: currentStatus == ConfirmationStatus.maybe
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.orange.shade800,
                    ),
                    onSelected: (_) {
                      context.read<GameProvider>().confirmAttendance(
                            gameId: game.id,
                            userId: currentUserId,
                            status: ConfirmationStatus.maybe,
                          );
                    },
                  ),
                  ChoiceChip(
                    label: Text("I'm out ($outCount)"),
                    selected: currentStatus == ConfirmationStatus.declined,
                    selectedColor: Colors.red.withOpacity(0.18),
                    backgroundColor: Colors.red.withOpacity(0.06),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: currentStatus == ConfirmationStatus.declined
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.red.shade800,
                    ),
                    onSelected: (_) {
                      context.read<GameProvider>().confirmAttendance(
                            gameId: game.id,
                            userId: currentUserId,
                            status: ConfirmationStatus.declined,
                          );
                    },
                  ),
                ],
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(gameId: game.id),
            ),
          );
        },
      ),
    );
  }

  String _monthAbbrev(int month) {
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
    return months[month - 1];
  }
}
