import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class BootstrapPage extends ConsumerWidget {
  const BootstrapPage({super.key});

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
              'Fondasi aplikasi siap',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
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
