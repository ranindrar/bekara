import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cash_flow/presentation/cash_flow_page.dart';
import '../../household/domain/household_context.dart';
import '../data/finance_service.dart';
import '../domain/finance_validation.dart';
import '../domain/transaction_selection.dart';

final financeServiceProvider = Provider<FinanceService>(
  (ref) => FinanceService(
    ref.watch(supabaseClientProvider)!,
    ref.watch(appDatabaseProvider),
  ),
);
final financeRefreshProvider = StateProvider<int>((ref) => 0);
final financeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(financeRefreshProvider);
  final service = ref.watch(financeServiceProvider);
  final values = await Future.wait([
    service.dashboard(),
    service.wallets(),
    service.transactions(),
    service.categoryReport(),
    service.pendingMutationCount(),
  ]);
  return {
    'dashboard': values[0],
    'wallets': values[1],
    'transactions': values[2],
    'report': values[3],
    'pendingCount': values[4],
  };
});

class FinanceHomePage extends ConsumerStatefulWidget {
  const FinanceHomePage({required this.contextData, super.key});
  final HouseholdContext contextData;

  @override
  ConsumerState<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends ConsumerState<FinanceHomePage> {
  int _index = 0;
  final _titles = const [
    'Ringkasan',
    'Transaksi',
    'Dompet',
    'Laporan',
    'Cash Flow',
  ];

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(financeDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'category') _showCategoryDialog();
              if (value == 'logout') ref.read(authServiceProvider)?.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'category', child: Text('Tambah kategori')),
              PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: _refresh,
            child: const Text('Coba lagi'),
          ),
        ),
        data: (value) {
          final dashboard = value['dashboard'] as Map<String, dynamic>;
          final wallets = value['wallets'] as List<Map<String, dynamic>>;
          final transactions =
              value['transactions'] as List<Map<String, dynamic>>;
          final report = value['report'] as List<Map<String, dynamic>>;
          final pendingCount = value['pendingCount'] as int;
          return Column(
            children: [
              if (pendingCount > 0)
                Material(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: Text(
                      '$pendingCount perubahan menunggu sinkronisasi',
                    ),
                    subtitle: const Text(
                      'Buka Cash Flow untuk mengirim data ke server.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _index = 4),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _DashboardTab(
                      contextData: widget.contextData,
                      dashboard: dashboard,
                      wallets: wallets,
                    ),
                    _TransactionsTab(
                      transactions: transactions,
                      onReverse: _correctTransaction,
                    ),
                    _WalletsTab(
                      wallets: wallets,
                      onReconcile: _reconcileWallet,
                    ),
                    _ReportTab(report: report),
                    CashFlowPage(
                      contextData: widget.contextData,
                      onSynchronized: _refresh,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: data.valueOrNull == null || ![1, 2].contains(_index)
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final wallets =
                    data.value!['wallets'] as List<Map<String, dynamic>>;
                if (_index == 2) {
                  _showWalletDialog();
                } else if (_index == 1) {
                  _showTransactionDialog(wallets);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(_index == 2 ? 'Dompet' : 'Catat'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Dompet',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Cash Flow',
          ),
        ],
      ),
    );
  }

  void _refresh() => ref.read(financeRefreshProvider.notifier).state++;

  Future<void> _showWalletDialog() async {
    final name = TextEditingController();
    final balance = TextEditingController(text: '0');
    var type = 'BANK_ACCOUNT';
    var shared = false;
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah dompet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              TextField(
                controller: balance,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Saldo awal'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(
                    value: 'BANK_ACCOUNT',
                    child: Text('Rekening bank'),
                  ),
                  DropdownMenuItem(value: 'CASH', child: Text('Tunai')),
                  DropdownMenuItem(value: 'E_WALLET', child: Text('E-Wallet')),
                  DropdownMenuItem(value: 'SAVING', child: Text('Tabungan')),
                ],
                onChanged: (value) => type = value!,
              ),
              SwitchListTile(
                value: shared,
                title: const Text('Dompet bersama'),
                onChanged: (value) => setDialogState(() => shared = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (submit == true && name.text.trim().isNotEmpty) {
      await _execute(
        () => ref
            .read(financeServiceProvider)
            .createWallet(
              name: name.text,
              type: type,
              openingBalance: balance.text,
              shared: shared,
            ),
      );
    }
    name.dispose();
    balance.dispose();
  }

  Future<void> _showCategoryDialog() async {
    final name = TextEditingController();
    var direction = 'EXPENSE';
    var scope = 'HOUSEHOLD';
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah kategori'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              DropdownButtonFormField(
                initialValue: direction,
                items: const [
                  DropdownMenuItem(
                    value: 'EXPENSE',
                    child: Text('Pengeluaran'),
                  ),
                  DropdownMenuItem(value: 'INCOME', child: Text('Pemasukan')),
                ],
                onChanged: (value) => direction = value!,
              ),
              DropdownButtonFormField(
                initialValue: scope,
                items: const [
                  DropdownMenuItem(value: 'HOUSEHOLD', child: Text('Keluarga')),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                ],
                onChanged: (value) => scope = value!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (submit == true && name.text.trim().isNotEmpty) {
      await _execute(
        () => ref
            .read(financeServiceProvider)
            .createCategory(
              name: name.text,
              direction: direction,
              scope: scope,
            ),
      );
    }
    name.dispose();
  }

  Future<void> _showTransactionDialog(
    List<Map<String, dynamic>> wallets,
  ) async {
    final userId = ref.read(supabaseClientProvider)?.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FinanceValidation.friendlyError(Exception('UNAUTHENTICATED')),
          ),
        ),
      );
      return;
    }
    final transactionWallets = TransactionSelection.transactionWallets(
      wallets,
      userId,
    );
    if (transactionWallets.isEmpty) {
      setState(() => _index = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tambahkan dompet aktif milik Anda atau gunakan dompet bersama.',
          ),
        ),
      );
      return;
    }
    late final List<Map<String, dynamic>> allCategories;
    try {
      allCategories = await ref.read(financeServiceProvider).categories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceValidation.friendlyError(error))),
      );
      return;
    }
    if (!mounted) return;
    final amount = TextEditingController();
    final description = TextEditingController();
    var transactionDate = DateTime.now();
    var kind = 'EXPENSE';
    var scope = 'HOUSEHOLD';
    var privacyMode = 'PRIVATE_FULL';
    String? walletId = TransactionSelection.firstId(transactionWallets);
    var transfer = false;
    String? destinationId;
    String? validationMessage;
    String? categoryId = TransactionSelection.firstId(
      TransactionSelection.categories(allCategories, kind, scope),
    );
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectableWallets = transfer
              ? TransactionSelection.transferSources(wallets, userId)
              : transactionWallets;
          final destinations = TransactionSelection.transferDestinations(
            wallets,
            userId,
            walletId,
          );
          final categories = TransactionSelection.categories(
            allCategories,
            kind,
            scope,
          );
          return AlertDialog(
            title: const Text('Catat transaksi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    value: transfer,
                    title: const Text('Transfer internal'),
                    onChanged: (value) => setDialogState(() {
                      transfer = value;
                      final nextWallets = transfer
                          ? TransactionSelection.transferSources(
                              wallets,
                              userId,
                            )
                          : transactionWallets;
                      if (!nextWallets.any(
                        (wallet) => wallet['id'] == walletId,
                      )) {
                        walletId = TransactionSelection.firstId(nextWallets);
                      }
                      destinationId = null;
                      validationMessage = null;
                    }),
                  ),
                  if (!transfer)
                    DropdownButtonFormField<String>(
                      key: ValueKey('kind-$kind'),
                      initialValue: kind,
                      decoration: const InputDecoration(
                        labelText: 'Jenis transaksi',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'EXPENSE',
                          child: Text('Pengeluaran'),
                        ),
                        DropdownMenuItem(
                          value: 'INCOME',
                          child: Text('Pemasukan'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        kind = value!;
                        categoryId = TransactionSelection.firstId(
                          TransactionSelection.categories(
                            allCategories,
                            kind,
                            scope,
                          ),
                        );
                        validationMessage = null;
                      }),
                    ),
                  if (selectableWallets.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('wallet-$transfer-$walletId'),
                      initialValue: walletId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Dompet'),
                      items: selectableWallets
                          .map(
                            (wallet) => DropdownMenuItem(
                              value: wallet['id'] as String,
                              child: Text(
                                '${wallet['name']} - ${_money(wallet['availableBalance'] ?? wallet['balance'])} tersedia',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        walletId = value;
                        destinationId = null;
                        validationMessage = null;
                      }),
                    )
                  else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_amber),
                      title: Text('Tidak ada dompet yang dapat digunakan.'),
                    ),
                  if (transfer && destinations.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('destination-$walletId-$destinationId'),
                      initialValue: destinationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Dompet tujuan',
                      ),
                      items: destinations
                          .map(
                            (wallet) => DropdownMenuItem(
                              value: wallet['id'] as String,
                              child: Text(
                                wallet['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        destinationId = value;
                        validationMessage = null;
                      }),
                    )
                  else if (transfer)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text('Tidak ada dompet tujuan yang tersedia.'),
                    ),
                  if (!transfer && categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('category-$kind-$scope-$categoryId'),
                      initialValue: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category['id'] as String,
                              child: Text(
                                category['scope'] == 'PRIVATE'
                                    ? '${category['name']} (Pribadi)'
                                    : category['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        categoryId = value;
                        validationMessage = null;
                      }),
                    )
                  else if (!transfer)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text(
                        'Belum ada kategori untuk jenis dan cakupan ini.',
                      ),
                    ),
                  if (!transfer)
                    DropdownButtonFormField<String>(
                      key: ValueKey('scope-$scope'),
                      initialValue: scope,
                      decoration: const InputDecoration(labelText: 'Cakupan'),
                      items: const [
                        DropdownMenuItem(
                          value: 'HOUSEHOLD',
                          child: Text('Keluarga'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text('Pribadi'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        scope = value!;
                        categoryId = TransactionSelection.firstId(
                          TransactionSelection.categories(
                            allCategories,
                            kind,
                            scope,
                          ),
                        );
                        validationMessage = null;
                      }),
                    ),
                  if (!transfer && scope == 'PRIVATE')
                    DropdownButtonFormField<String>(
                      initialValue: privacyMode,
                      decoration: const InputDecoration(labelText: 'Privasi'),
                      items: const [
                        DropdownMenuItem(
                          value: 'PRIVATE_FULL',
                          child: Text('Penuh — hanya saya'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE_SUMMARY',
                          child: Text('Ringkasan — nominal & tanggal'),
                        ),
                        DropdownMenuItem(
                          value: 'HOUSEHOLD_VISIBLE',
                          child: Text('Terlihat lengkap'),
                        ),
                      ],
                      onChanged: (value) => privacyMode = value!,
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nominal'),
                    onChanged: (_) =>
                        setDialogState(() => validationMessage = null),
                  ),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal transaksi'),
                    subtitle: Text(
                      DateFormat(
                        'dd MMMM yyyy',
                        'id_ID',
                      ).format(transactionDate),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: transactionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && context.mounted) {
                        setDialogState(() => transactionDate = picked);
                      }
                    },
                  ),
                  if (validationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        validationMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  String? error;
                  try {
                    FinanceValidation.normalizeAmount(amount.text);
                  } on FormatException catch (exception) {
                    error = exception.message.toString();
                  }
                  if (error == null && walletId == null) {
                    error = 'Pilih dompet yang dapat digunakan.';
                  } else if (error == null && transfer) {
                    if (destinationId == null) {
                      error = 'Pilih dompet tujuan.';
                    } else if (!destinations.any(
                      (wallet) => wallet['id'] == destinationId,
                    )) {
                      error = 'Dompet tujuan sudah tidak tersedia.';
                    }
                  } else if (error == null && !transfer) {
                    if (categoryId == null) {
                      error = 'Pilih atau tambahkan kategori terlebih dahulu.';
                    } else if (!categories.any(
                      (category) => category['id'] == categoryId,
                    )) {
                      error = 'Kategori tidak sesuai dengan transaksi.';
                    }
                  }
                  if (error != null) {
                    setDialogState(() => validationMessage = error);
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
    if (submit == true) {
      if (transfer) {
        await _executeFinancial(
          () => ref
              .read(financeServiceProvider)
              .postTransfer(
                sourceWalletId: walletId!,
                destinationWalletId: destinationId!,
                amount: amount.text,
                description: description.text,
                transactionDate: transactionDate,
              ),
        );
      } else {
        await _executeFinancial(
          () => ref
              .read(financeServiceProvider)
              .postTransaction(
                walletId: walletId!,
                categoryId: categoryId!,
                kind: kind,
                amount: amount.text,
                description: description.text,
                scope: scope,
                privacyMode: privacyMode,
                transactionDate: transactionDate,
              ),
        );
      }
    }
    amount.dispose();
    description.dispose();
  }

  Future<void> _executeFinancial(
    Future<FinancialMutationResult> Function() action,
  ) async {
    try {
      final result = await action();
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == FinancialMutationResult.queued
                ? 'Koneksi belum tersedia. Transaksi disimpan dan menunggu sinkronisasi.'
                : 'Transaksi berhasil disimpan.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceValidation.friendlyError(error))),
      );
    }
  }

  Future<void> _execute(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FinanceValidation.friendlyError(error))),
        );
      }
    }
  }

  Future<void> _correctTransaction(Map<String, dynamic> transaction) async {
    final canCorrect =
        transaction['is_owner'] == true || transaction['scope'] == 'HOUSEHOLD';
    if (!canCorrect || transaction['status'] != 'POSTED') {
      return;
    }
    final reason = TextEditingController();
    final amount = TextEditingController(
      text: transaction['amount'].toString(),
    );
    final description = TextEditingController(
      text: transaction['description'] as String? ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Koreksi transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal benar (0 untuk batalkan)',
              ),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Keterangan benar'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Alasan koreksi'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transaksi asli tidak dihapus. Sistem membuat reversal dan pengganti yang dapat diaudit.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan koreksi'),
          ),
        ],
      ),
    );
    if (confirmed == true && reason.text.trim().isNotEmpty) {
      await _execute(
        () => ref
            .read(cashFlowServiceProvider)
            .correctTransaction(
              transactionId: transaction['id'] as String,
              correctedAmount: FinanceValidation.normalizeAmount(
                amount.text,
                allowZero: true,
              ),
              reason: FinanceValidation.requiredText(
                reason.text,
                'Alasan',
                minLength: 3,
              ),
              description: description.text,
              correctionDate: DateTime.now(),
            ),
      );
    }
    reason.dispose();
    amount.dispose();
    description.dispose();
  }

  Future<void> _reconcileWallet(Map<String, dynamic> wallet) async {
    final balance = TextEditingController(text: wallet['balance'].toString());
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rekonsiliasi ${wallet['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Saldo aktual'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Alasan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sesuaikan'),
          ),
        ],
      ),
    );
    if (confirmed == true && reason.text.trim().isNotEmpty) {
      await _execute(
        () => ref
            .read(financeServiceProvider)
            .reconcileWallet(wallet['id'] as String, balance.text, reason.text),
      );
    }
    balance.dispose();
    reason.dispose();
  }
}

String _money(dynamic value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(num.tryParse('$value') ?? 0);

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.contextData,
    required this.dashboard,
    required this.wallets,
  });
  final HouseholdContext contextData;
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> wallets;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Halo, ${contextData.displayName}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(contextData.householdName ?? ''),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total saldo keluarga'),
              const SizedBox(height: 8),
              Text(
                _money(dashboard['totalBalance']),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'Pemasukan bulan ini',
              value: _money(dashboard['monthlyIncome']),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: 'Pengeluaran bulan ini',
              value: _money(dashboard['monthlyExpense']),
              color: Colors.orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        'Dompet aktif (${wallets.length})',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    ),
  );
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({required this.transactions, required this.onReverse});
  final List<Map<String, dynamic>> transactions;
  final ValueChanged<Map<String, dynamic>> onReverse;
  @override
  Widget build(BuildContext context) => transactions.isEmpty
      ? const Center(child: Text('Belum ada transaksi.'))
      : ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (_, i) {
            final t = transactions[i];
            return ListTile(
              onLongPress: () => onReverse(t),
              leading: Icon(
                t['kind'] == 'INCOME'
                    ? Icons.south_west
                    : t['kind'] == 'TRANSFER'
                    ? Icons.swap_horiz
                    : Icons.north_east,
              ),
              title: Text(
                t['description'] as String? ??
                    t['category_name'] as String? ??
                    t['kind'] as String,
              ),
              subtitle: Text('${t['wallet_name']} • ${t['transaction_date']}'),
              trailing: Text(_money(t['amount'])),
            );
          },
        );
}

class _WalletsTab extends StatelessWidget {
  const _WalletsTab({required this.wallets, required this.onReconcile});
  final List<Map<String, dynamic>> wallets;
  final ValueChanged<Map<String, dynamic>> onReconcile;
  @override
  Widget build(BuildContext context) => wallets.isEmpty
      ? const Center(child: Text('Tambahkan dompet pertama Anda.'))
      : ListView.builder(
          itemCount: wallets.length,
          itemBuilder: (_, i) {
            final w = wallets[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                onLongPress: () => onReconcile(w),
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(w['name'] as String),
                subtitle: Text(w['walletType'] as String),
                trailing: Text(_money(w['balance'])),
              ),
            );
          },
        );
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({required this.report});
  final List<Map<String, dynamic>> report;
  @override
  Widget build(BuildContext context) => report.isEmpty
      ? const Center(child: Text('Belum ada pengeluaran bulan ini.'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: report.length,
          itemBuilder: (_, i) {
            final r = report[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(r['category'] as String),
              trailing: Text(_money(r['amount'])),
            );
          },
        );
}
