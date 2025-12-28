import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final appUser = userProvider.currentUser;

    final prefs = Map<String, dynamic>.from(appUser?.preferences ?? {});
    final notificationsEnabled = (prefs['notificationsEnabled'] as bool?) ?? true;
    final theme = (prefs['theme'] as String?) ?? 'system';
    final language = (prefs['language'] as String?) ?? 'en';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(appUser?.initials ?? 'U'),
            ),
            title: Text(
              appUser?.name.isNotEmpty == true ? appUser!.name : 'Your profile',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              auth.user?.email ?? '',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
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
              'Game & team notifications',
              style: GoogleFonts.inter(),
            ),
            value: notificationsEnabled,
            onChanged: (value) => updatePrefs({'notificationsEnabled': value}),
          ),
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
              DropdownMenuItem(value: 'system', child: Text('System default')),
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
            'Language',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: language,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'es', child: Text('Spanish (beta)')),
            ],
            onChanged: (value) {
              if (value != null) {
                updatePrefs({'language': value});
              }
            },
          ),
          const SizedBox(height: 24),
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
                      content:
                          Text('Could not delete account data. Please try again.'),
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
        ],
      ),
    );
  }
}
