import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../household/domain/household_context.dart';
import '../../household/presentation/household_gate.dart';

class BootstrapPage extends ConsumerWidget {
  const BootstrapPage({super.key, this.householdContext});

  final HouseholdContext? householdContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bekara')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              householdContext == null
                  ? 'Fondasi aplikasi siap'
                  : 'Halo, ${householdContext!.displayName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            if (householdContext != null) ...[
              Text('Keluarga ${householdContext!.householdName} sudah aktif.'),
              const SizedBox(height: 12),
              if (householdContext!.isOwner)
                OutlinedButton.icon(
                  onPressed: () => _showInvitationDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Undang pasangan'),
                ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Aplikasi akan membantu suami dan istri melihat kondisi keuangan pribadi dan keluarga tanpa menghitung transfer internal sebagai pengeluaran.',
            ),
            const SizedBox(height: 24),
            _StatusCard(
              icon: Icons.phone_android,
              title: 'Database offline',
              description:
                  'Drift/SQLite aktif untuk cache dan antrean sinkronisasi.',
              ready: true,
            ),
            const SizedBox(height: 12),
            _StatusCard(
              icon: Icons.cloud_outlined,
              title: 'Supabase',
              description: environment.hasSupabaseConfiguration
                  ? 'Konfigurasi Supabase ditemukan.'
                  : 'Belum dikonfigurasi. Aplikasi tetap dapat dibuka secara lokal.',
              ready: environment.hasSupabaseConfiguration,
            ),
            const SizedBox(height: 24),
            const Text(
              'Langkah berikutnya: autentikasi dan pembuatan household.',
            ),
            if (environment.hasSupabaseConfiguration) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.read(authServiceProvider)?.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showInvitationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final email = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undang pasangan'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email pasangan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buat undangan'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) {
      email.dispose();
      return;
    }
    try {
      final invitation = await ref
          .read(householdServiceProvider)
          .createInvitation(email.text);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kode undangan dibuat'),
          content: SelectableText(
            'Bagikan kode berikut kepada ${invitation['email']}:\n\n${invitation['token']}\n\nKode berlaku selama 7 hari.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Undangan gagal dibuat.')));
      }
    } finally {
      email.dispose();
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.ready,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: Icon(
          ready ? Icons.check_circle : Icons.info_outline,
          color: ready ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}
