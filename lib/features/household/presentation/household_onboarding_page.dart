import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'household_gate.dart';

class HouseholdOnboardingPage extends ConsumerStatefulWidget {
  const HouseholdOnboardingPage({super.key});

  @override
  ConsumerState<HouseholdOnboardingPage> createState() =>
      _HouseholdOnboardingPageState();
}

class _HouseholdOnboardingPageState
    extends ConsumerState<HouseholdOnboardingPage> {
  final _name = TextEditingController();
  final _token = TextEditingController();
  int _startDay = 25;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mulai bersama Bekara')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Buat keluarga baru',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Atur ruang keuangan keluarga. Pasangan dapat diundang setelah ruang dibuat.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Nama keluarga'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _startDay,
            decoration: const InputDecoration(
              labelText: 'Tanggal awal periode laporan',
            ),
            items: List.generate(31, (index) => index + 1)
                .map(
                  (day) =>
                      DropdownMenuItem(value: day, child: Text('Tanggal $day')),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _startDay = value ?? 25),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: const Text('Buat keluarga'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('atau'),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          Text(
            'Gabung dengan pasangan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Kode undangan'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: const Text('Gabung keluarga'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) {
      return _message('Nama keluarga minimal 2 karakter.');
    }
    await _run(
      () => ref
          .read(householdServiceProvider)
          .createHousehold(_name.text, _startDay),
    );
  }

  Future<void> _join() async {
    if (_token.text.trim().isEmpty) return _message('Masukkan kode undangan.');
    await _run(
      () => ref.read(householdServiceProvider).acceptInvitation(_token.text),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(householdContextProvider);
    } catch (_) {
      _message('Proses belum berhasil. Periksa data dan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
