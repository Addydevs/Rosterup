import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _latestBuildKey = 'latest_build';
  static const _minSupportedBuildKey = 'min_supported_build';
  static const _storeUrlKey = 'store_url';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: Duration(seconds: 10),
          minimumFetchInterval: Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final latestBuild = remoteConfig.getInt(_latestBuildKey);
      final minSupportedBuild = remoteConfig.getInt(_minSupportedBuildKey);
      final storeUrl = remoteConfig.getString(_storeUrlKey);

      final isForcedUpdate =
          minSupportedBuild != 0 && currentBuild < minSupportedBuild;
      final isOptionalUpdate =
          latestBuild != 0 && currentBuild < latestBuild;

      if (!isForcedUpdate && !isOptionalUpdate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You’re on the latest version of RosterUp.'),
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              isForcedUpdate ? 'Update required' : 'Update available',
            ),
            content: Text(
              isForcedUpdate
                  ? 'A newer version of RosterUp is required to continue using the app.'
                  : 'A newer version of RosterUp is available with improvements and fixes.',
            ),
            actions: [
              if (!isForcedUpdate)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Later'),
                ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  if (storeUrl.isEmpty) {
                    return;
                  }

                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not check for updates. Please try again later.'),
          ),
        );
      }
    }
  }
}

