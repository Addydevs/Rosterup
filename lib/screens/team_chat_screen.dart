import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/team_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/ad_banner.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;

  const TeamChatScreen({super.key, required this.teamId});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_subscribed) {
      _subscribed = true;
      context.read<ChatProvider>().subscribeToTeam(widget.teamId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;
    final currentUserName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (auth.user?.email ?? 'You');
    final currentUserId = auth.user?.uid;

    final teamProvider = context.watch<TeamProvider>();
    final team = teamProvider.teams.firstWhere((t) => t.id == widget.teamId);
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messagesForTeam(widget.teamId);

    // Mark this team's messages as read when viewing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatProvider.markTeamAsRead(widget.teamId);
    });
    final isMuted = currentUserId != null &&
        team.mutedMemberIds.contains(currentUserId);
    final isAdmin =
        currentUserId != null && currentUserId == team.adminId;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${team.name} chat',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: onSurfaceColor,
          ),
        ),
        foregroundColor: onSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Broadcast to all members',
              onPressed: () => _showBroadcastDialog(
                context,
                team,
                chatProvider,
                currentUserId,
                currentUserName,
              ),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                        child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No messages yet.\nBe the first to say hello 👋',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      reverse: false,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == currentUserId;

                        if (message.isBroadcast) {
                          return GestureDetector(
                            onLongPress: isAdmin
                                ? () => _showMessageActions(
                                      context,
                                      message,
                                      isMine: isMine,
                                      isAdmin: isAdmin,
                                    )
                                : null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.campaign,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${message.senderName} · Announcement',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message.text,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          onLongPress: () => _showMessageActions(
                            context,
                            message,
                            isMine: isMine,
                            isAdmin: isAdmin,
                          ),
                          child: Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context)
                                        .size
                                        .width *
                                    0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Text(
                                      message.senderName,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: onSurfaceColor,
                                      ),
                                    ),
                                  if (!isMine)
                                    const SizedBox(height: 2),
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
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
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization:
                            TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: isMuted
                              ? 'You are muted by the admin'
                              : 'Message ${team.name}',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: onSurfaceColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        readOnly: isMuted,
                        onSubmitted: (_) =>
                            _sendMessage(currentUserName),
                      ),
                    ),
                    const SizedBox(height: 0, width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color:
                          Theme.of(context).colorScheme.primary,
                      onPressed: isMuted
                          ? null
                          : () => _sendMessage(currentUserName),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }

  void _showBroadcastDialog(
    BuildContext context,
    dynamic team,
    ChatProvider chatProvider,
    String? currentUserId,
    String currentUserName,
  ) {
    final controller = TextEditingController();
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.campaign, color: Colors.amber),
                SizedBox(width: 8),
                Text('Broadcast'),
              ],
            ),
            content: TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Type your announcement...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSending
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) return;
                        setDialogState(() => isSending = true);
                        await chatProvider.sendBroadcast(
                          teamId: team.id as String,
                          senderId: currentUserId ?? '',
                          senderName: currentUserName,
                          text: controller.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send to all'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMessageActions(
    BuildContext context,
    ChatMessage message, {
    required bool isMine,
    required bool isAdmin,
  }) async {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.uid;
    if (currentUserId == null) {
      return;
    }

    final teamProvider = context.read<TeamProvider>();
    final team =
        teamProvider.teams.firstWhere((t) => t.id == widget.teamId);
    final isSenderMuted = team.mutedMemberIds.contains(message.senderId);

    // Non-admins can only report other users' messages.
    if (!isAdmin && !isMine) {
      await _showReportMessageDialog(context, message);
      return;
    }

    if (!isAdmin) {
      // No actions for non-admin on own messages for now.
      return;
    }

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Message actions',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete message'),
                          content: const Text(
                            'Remove this message from the chat for everyone?',
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
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirmed) return;

                  final success = await context
                      .read<ChatProvider>()
                      .deleteMessage(
                        teamId: widget.teamId,
                        messageId: message.id,
                      );

                  if (!mounted) return;

                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not delete message. Please try again.',
                        ),
                      ),
                    );
                  }
                },
              ),
                if (message.senderId != team.adminId)
                  ListTile(
                    leading: Icon(
                      isSenderMuted
                          ? Icons.volume_off
                          : Icons.volume_mute_outlined,
                    ),
                    title: Text(
                      isSenderMuted
                          ? 'Unmute user in chat'
                          : 'Mute user in chat',
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();

                      final success = await context
                          .read<TeamProvider>()
                          .muteMember(
                            teamId: widget.teamId,
                            memberId: message.senderId,
                            requesterId: currentUserId,
                            muted: !isSenderMuted,
                          );

                      if (!mounted) return;

                      if (!success) {
                        final error = context
                                .read<TeamProvider>()
                                .error ??
                            'Could not update mute status.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    },
                  ),
                if (!isMine)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Report message'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showReportMessageDialog(context, message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportMessageDialog(
      BuildContext context, ChatMessage message) async {
    final auth = context.read<AuthProvider>();
    final reporterId = auth.user?.uid;
    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to report messages.'),
        ),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();
    final TextEditingController detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Report message'),
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
    final success = await reportProvider.reportMessage(
      reporterId: reporterId,
      reportedUserId: message.senderId,
      teamId: widget.teamId,
      messageId: message.id,
      messageText: message.text,
      reason: reason,
      additionalDetails: details,
    );

    if (!mounted) return;

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
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  void _sendMessage(String currentUserName) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.uid;
    if (currentUserId == null) return;

    final teamProvider = context.read<TeamProvider>();
    final team =
        teamProvider.teams.firstWhere((t) => t.id == widget.teamId);
    if (team.mutedMemberIds.contains(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are muted and cannot send messages.'),
        ),
      );
      return;
    }

    context.read<ChatProvider>().sendMessage(
          teamId: widget.teamId,
          senderId: currentUserId,
          senderName: currentUserName,
          text: text,
        );
    _controller.clear();
  }
}
