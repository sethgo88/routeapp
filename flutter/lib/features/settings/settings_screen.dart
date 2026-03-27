import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/map_layers.dart';
import '../../state/settings_provider.dart';
import '../../state/auth_provider.dart';
import '../../features/sync/sync_service.dart';
import '../auth/sign_in_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final authUser = ref.watch(authUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('< back'),
        ),
        leadingWidth: 80,
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Units ──────────────────────────────────────────────────
            _SectionHeader('Units'),
            ListTile(
              title: const Text('Distance & elevation'),
              subtitle: Text(settings.isImperial ? 'Imperial (mi / ft)' : 'Metric (km / m)'),
              trailing: Switch(
                value: settings.isImperial,
                onChanged: (imperial) async {
                  await ref
                      .read(settingsProvider.notifier)
                      .setUnitSystem(imperial ? 'imperial' : 'metric');
                },
              ),
            ),

            // ── Map Layer ──────────────────────────────────────────────
            _SectionHeader('Default Map Layer'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonFormField<MapLayer>(
                value: settings.defaultLayer,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: MapLayer.values
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l.label),
                        ))
                    .toList(),
                onChanged: (layer) async {
                  if (layer == null) return;
                  await ref
                      .read(settingsProvider.notifier)
                      .setDefaultLayer(layer);
                  // Also update the active session layer.
                  ref.read(activeLayerProvider.notifier).state = layer;
                },
              ),
            ),

            // ── Account ───────────────────────────────────────────────
            _SectionHeader('Account'),
            authUser.when(
              loading: () => const ListTile(
                title: Text('Checking auth…'),
              ),
              error: (_, __) => ListTile(
                title: const Text('Sign in'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSignIn(context, ref),
              ),
              data: (user) => user == null
                  ? ListTile(
                      title: const Text('Sign in'),
                      subtitle: const Text('Sync routes to the cloud'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSignIn(context, ref),
                    )
                  : _SignedInTile(user: user),
            ),

            // ── Downloaded Regions ─────────────────────────────────────
            _SectionHeader('Offline Maps'),
            ListTile(
              title: const Text('Downloaded Regions'),
              subtitle: const Text('Manage offline tile regions'),
              trailing: const Icon(Icons.chevron_right),
              // Pop with 'offline' so MapScreen knows to open the sheet.
              onTap: () => Navigator.of(context).pop('offline'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSignIn(BuildContext context, WidgetRef ref) async {
    final signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignInSheet(),
    );
    if (signedIn == true) {
      // Trigger cloud sync after successful sign-in.
      await syncService.sync();
    }
  }
}

class _SignedInTile extends ConsumerWidget {
  final User user;
  const _SignedInTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(user.email ?? 'Signed in'),
          subtitle: const Text('Cloud sync enabled'),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync now'),
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Syncing…')),
            );
            await syncService.sync();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync complete')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
