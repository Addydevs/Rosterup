import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/update_service.dart';
import '../widgets/ad_banner.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';
import 'faq_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final appUser = userProvider.currentUser;

    final prefs = Map<String, dynamic>.from(appUser?.preferences ?? {});
    final notificationsEnabled = (prefs['notificationsEnabled'] as bool?) ?? true;
    final gameRemindersEnabled =
        (prefs['notificationsGameReminders'] as bool?) ?? true;
    final chatMessagesEnabled =
        (prefs['notificationsChatMessages'] as bool?) ?? true;
    final teamAnnouncementsEnabled =
        (prefs['notificationsTeamAnnouncements'] as bool?) ?? true;
    var theme = (prefs['theme'] as String?) ?? 'light';
    if (theme != 'light' && theme != 'dark') {
      theme = 'light';
    }
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final bottomSafePadding =
        MediaQuery.of(context).padding.bottom + 16.0;

    Future<void> updatePrefs(Map<String, dynamic> updates) async {
      final merged = {...prefs, ...updates};
      await userProvider.updatePreferences(merged);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(appUser?.initials ?? 'U'),
              ),
              title: Text(
                appUser?.name.isNotEmpty == true
                    ? appUser!.name
                    : 'Your profile',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                auth.user?.email ?? '',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: onSurfaceColor,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Notifications',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Enable notifications',
                style: GoogleFonts.inter(),
              ),
              value: notificationsEnabled,
              onChanged: (value) =>
                  updatePrefs({'notificationsEnabled': value}),
            ),
            if (notificationsEnabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Game reminders',
                  style: GoogleFonts.inter(),
                ),
                subtitle: Text(
                  'Get reminders before games you\'re going to.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: onSurfaceColor,
                  ),
                ),
                value: gameRemindersEnabled,
                onChanged: (value) =>
                    updatePrefs({'notificationsGameReminders': value}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'New chat messages',
                  style: GoogleFonts.inter(),
                ),
                value: chatMessagesEnabled,
                onChanged: (value) =>
                    updatePrefs({'notificationsChatMessages': value}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Team announcements',
                  style: GoogleFonts.inter(),
                ),
                subtitle: Text(
                  'Includes new games and attendance updates.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: onSurfaceColor,
                  ),
                ),
                value: teamAnnouncementsEnabled,
                onChanged: (value) =>
                    updatePrefs({'notificationsTeamAnnouncements': value}),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: theme,
              decoration: const InputDecoration(
                labelText: 'Theme',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) {
                  updatePrefs({'theme': value});
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Help',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text(
                'FAQ & help',
                style: GoogleFonts.inter(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FaqScreen(),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.system_update),
              title: Text(
                'Check for updates',
                style: GoogleFonts.inter(),
              ),
              onTap: () => UpdateService.checkForUpdates(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: Text(
                'Contact & feedback',
                style: GoogleFonts.inter(),
              ),
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'rosterupapp@gmail.com',
                  queryParameters: {
                    'subject': 'RosterUp feedback',
                  },
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open email app. Please email rosterupapp@gmail.com.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                const message =
                    'Check out RosterUp – coordinate pickup games with your team. Search “RosterUp” in the app store to download.';
                Share.share(message, subject: 'Try RosterUp');
              },
              icon: const Icon(Icons.ios_share),
              label: Text(
                'Share app',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: Text(
                'Sign out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete account'),
                        content: const Text(
                          'This will delete your account and profile data. '
                          'You will be signed out and cannot undo this.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (!confirmed) return;

                final authProvider = context.read<AuthProvider>();
                final user = authProvider.user;
                if (user == null) return;

                final userProvider = context.read<UserProvider>();

                // Delete Firestore user data
                final dataDeleted =
                    await userProvider.deleteAccountData(user.uid);
                if (!dataDeleted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not delete account data. Please try again.',
                        ),
                      ),
                    );
                  }
                  return;
                }

                // Delete auth account
                try {
                  await user.delete();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please sign in again, then delete your account.',
                        ),
                      ),
                    );
                  }
                  return;
                }

                // Sign out locally and go to login
                await authProvider.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Text(
                'Delete account',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: bottomSafePadding),
          ],
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
