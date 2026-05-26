import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/team_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/date_format_utils.dart';
import '../widgets/ad_banner.dart';
import 'team_chat_screen.dart';

/// Returns "Today", "Yesterday", a weekday name, or a short date depending on age.
String _formatChatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(msgDay).inDays;
  if (diff == 0) {
    final f = FormattedDate(dt);
    return f.time; // "11:30 AM"
  } else if (diff == 1) {
    return 'Yesterday';
  } else if (diff < 7) {
    return FormattedDate(dt).weekday; // "Mon"
  } else {
    final f = FormattedDate(dt);
    return '${f.month} ${f.day}'; // "Jan 5"
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final teams = teamProvider.teams;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Chat',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurfaceColor,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: teams.isEmpty
                  ? Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Join or create a team to start chatting.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams[index];
                        final messages =
                            chatProvider.messagesForTeam(team.id);
                        final lastMessage =
                            messages.isNotEmpty ? messages.last : null;
                        final unread =
                            chatProvider.unreadCountForTeam(team.id);

                        return ListTile(
                          leading: Badge(
                            isLabelVisible: unread > 0,
                            label: Text('$unread'),
                            child: CircleAvatar(
                              child: Text(
                                team.sport.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          title: Text(
                            team.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: onSurfaceColor,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage?.text ?? 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: onSurfaceColor,
                            ),
                          ),
                          trailing: lastMessage != null
                              ? Text(
                                  _formatChatTime(lastMessage.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: unread > 0
                                        ? Theme.of(context).colorScheme.primary
                                        : onSurfaceColor,
                                    fontWeight: unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TeamChatScreen(teamId: team.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
