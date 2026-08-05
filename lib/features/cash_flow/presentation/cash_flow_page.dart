import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/sync/sync_service.dart';
import '../../finance/data/finance_service.dart';
import '../../finance/domain/finance_validation.dart';
import '../../household/domain/household_context.dart';
import '../data/cash_flow_service.dart';

final cashFlowServiceProvider = Provider<CashFlowService>(
  (ref) => CashFlowService(ref.watch(supabaseClientProvider)!),
);
final cashFlowRefreshProvider = StateProvider<int>((ref) => 0);
final cashFlowDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(cashFlowRefreshProvider);
  final service = ref.watch(cashFlowServiceProvider);
  final finance = FinanceService(
    ref.watch(supabaseClientProvider)!,
    ref.watch(appDatabaseProvider),
  );
  final values = await Future.wait([
    service.periods(),
    service.forecast(),
    service.lockedFunds(),
    service.obligations(),
    finance.wallets(),
    finance.categories('EXPENSE'),
  ]);
  final periods = values[0] as List<Map<String, dynamic>>;
  final today = DateTime.now();
  bool isCurrent(Map<String, dynamic>? period, String type) {
    if (period == null || period['type'] != type) return false;
    final start = DateTime.parse(period['startDate'] as String);
    final end = DateTime.parse(period['endDate'] as String);
    final date = DateTime(today.year, today.month, today.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  final activeHousehold = periods.cast<Map<String, dynamic>?>().firstWhere(
    (period) => isCurrent(period, 'HOUSEHOLD'),
    orElse: () => null,
  );
  final activePersonal = periods.cast<Map<String, dynamic>?>().firstWhere(
    (period) => isCurrent(period, 'PERSONAL'),
    orElse: () => null,
  );
  int periodGroup(Map<String, dynamic> period) {
    if (isCurrent(period, period['type'] as String)) return 0;
    final end = DateTime.parse(period['endDate'] as String);
    return end.isBefore(DateTime(today.year, today.month, today.day)) ? 1 : 2;
  }

  periods.sort((left, right) {
    final leftGroup = periodGroup(left);
    final rightGroup = periodGroup(right);
    if (leftGroup != rightGroup) return leftGroup.compareTo(rightGroup);
    final leftStart = DateTime.parse(left['startDate'] as String);
    final rightStart = DateTime.parse(right['startDate'] as String);
    return leftGroup == 1
        ? rightStart.compareTo(leftStart)
        : leftStart.compareTo(rightStart);
  });
  final budgetGroups = await Future.wait([
    if (activeHousehold != null)
      service.budgets(activeHousehold['id'] as String),
    if (activePersonal != null) service.budgets(activePersonal['id'] as String),
  ]);
  final budgets = budgetGroups.expand((group) => group).toList();
  return {
    'periods': periods,
    'forecast': values[1],
    'funds': values[2],
    'obligations': values[3],
    'wallets': values[4],
    'categories': values[5],
    'budgets': budgets,
    'activeHouseholdPeriod': activeHousehold,
    'activePersonalPeriod': activePersonal,
  };
});

class CashFlowPage extends ConsumerStatefulWidget {
  const CashFlowPage({required this.contextData, super.key});

  final HouseholdContext contextData;

  @override
  ConsumerState<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends ConsumerState<CashFlowPage> {
  @override
  Widget build(BuildContext context) {
    return ref
        .watch(cashFlowDataProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: FilledButton(
              onPressed: _refresh,
              child: const Text('Muat ulang Cash Flow'),
            ),
          ),
          data: (data) {
            final forecast = data['forecast'] as Map<String, dynamic>;
            final periods = data['periods'] as List<Map<String, dynamic>>;
            final budgets = data['budgets'] as List<Map<String, dynamic>>;
            final funds = data['funds'] as List<Map<String, dynamic>>;
            final obligations =
                data['obligations'] as List<Map<String, dynamic>>;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ForecastCard(forecast: forecast),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showBudgetDialog(data),
                        icon: const Icon(Icons.savings_outlined),
                        label: const Text('Budget'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showFundDialog(data),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Kunci dana'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showObligationDialog(data),
                        icon: const Icon(Icons.event_repeat),
                        label: const Text('Tagihan rutin'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _synchronize,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sinkronkan'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showBackup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Backup/CSV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Periode',
                    action: TextButton(
                      onPressed: _showStartDayDialog,
                      child: const Text('Atur tanggal mulai'),
                    ),
                  ),
                  ...periods
                      .take(8)
                      .map(
                        (period) => Card(
                          child: ListTile(
                            leading: Icon(
                              period['status'] == 'LOCKED'
                                  ? Icons.lock
                                  : period['status'] == 'REVIEWED'
                                  ? Icons.fact_check
                                  : Icons.calendar_month,
                            ),
                            title: Text(
                              '${period['type'] == 'HOUSEHOLD' ? 'Keluarga' : 'Pribadi'} · ${period['status']}',
                            ),
                            subtitle: Text(
                              '${period['startDate']} – ${period['endDate']}\nAuto-lock ${period['autoLockOn']}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) =>
                                  _periodAction(period, action),
                              itemBuilder: (_) => [
                                if (period['status'] == 'OPEN')
                                  const PopupMenuItem(
                                    value: 'review',
                                    child: Text('Tandai sudah direview'),
                                  ),
                                if (period['status'] == 'REVIEWED')
                                  const PopupMenuItem(
                                    value: 'lock',
                                    child: Text('Tutup dan kunci'),
                                  ),
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('Lihat laporan koreksi'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const _SectionTitle(title: 'Budget periode aktif'),
                  if (budgets.isEmpty) const Text('Belum ada budget.'),
                  ...budgets.map(
                    (budget) => ListTile(
                      leading: CircleAvatar(
                        child: Text('${budget['percentage']}%'),
                      ),
                      title: Text(budget['category'] as String),
                      subtitle: Text(
                        '${_money(budget['spent'])} dari ${_money(budget['amount'])} · ${budget['status']}',
                      ),
                      trailing: Text(
                        'Sisa\n${_money(budget['remaining'])}',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                  const _SectionTitle(title: 'Dana terkunci (soft lock)'),
                  if (funds.isEmpty) const Text('Belum ada alokasi terkunci.'),
                  ...funds.map(
                    (fund) => ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(fund['label'] as String),
                      subtitle: Text(fund['wallet'] as String),
                      trailing: Text(_money(fund['amount'])),
                      onLongPress: () => _releaseFund(fund),
                    ),
                  ),
                  const _SectionTitle(title: 'Tagihan rutin'),
                  if (obligations.isEmpty)
                    const Text('Belum ada tagihan rutin.'),
                  ...obligations
                      .take(20)
                      .map(
                        (item) => Card(
                          child: ListTile(
                            leading: Icon(
                              item['status'] == 'PAID'
                                  ? Icons.check_circle
                                  : Icons.schedule,
                            ),
                            title: Text(item['name'] as String),
                            subtitle: Text(
                              '${item['dueDate']} · ${item['frequency']} · ${item['status']}',
                            ),
                            trailing: Text(
                              _money(
                                item['actualAmount'] ?? item['estimatedAmount'],
                              ),
                            ),
                            onTap: item['status'] == 'PENDING'
                                ? () => _resolveOccurrence(item)
                                : null,
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        );
  }

  void _refresh() {
    ref.read(cashFlowRefreshProvider.notifier).state++;
    ref.read(cashFlowDataProvider.future);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceValidation.friendlyError(error))),
      );
    }
  }

  Future<void> _periodAction(Map<String, dynamic> period, String action) async {
    final service = ref.read(cashFlowServiceProvider);
    if (action == 'report') {
      final report = await service.periodReport(period['id'] as String);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Laporan setelah penutupan'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Total saat ditutup:\n${report['closedSummary'] ?? 'Belum ditutup'}\n\n'
              'Kondisi saat ini:\n${report['currentSummary']}\n\n'
              'Koreksi setelah ditutup:\n${report['corrections']}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRestoreDialog();
              },
              child: const Text('Restore cache'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }
    await _run(
      () => action == 'review'
          ? service.reviewPeriod(period['id'] as String)
          : service.lockPeriod(period['id'] as String),
    );
  }

  Future<void> _showStartDayDialog() async {
    var day = 25;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Awal periode pribadi'),
        content: DropdownButtonFormField<int>(
          initialValue: day,
          items: List.generate(
            31,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('Tanggal ${index + 1}'),
            ),
          ),
          onChanged: (value) => day = value!,
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
    );
    if (accepted == true) {
      await _run(
        () => ref.read(cashFlowServiceProvider).setPersonalStartDay(day),
      );
    }
  }

  Future<void> _showBudgetDialog(Map<String, dynamic> data) async {
    final householdPeriod =
        data['activeHouseholdPeriod'] as Map<String, dynamic>?;
    final personalPeriod =
        data['activePersonalPeriod'] as Map<String, dynamic>?;
    final categories = data['categories'] as List<Map<String, dynamic>>;
    if (householdPeriod == null ||
        personalPeriod == null ||
        categories.isEmpty) {
      return;
    }
    var categoryId = categories.first['id'] as String;
    var scope = 'HOUSEHOLD';
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: scope,
                items: const [
                  DropdownMenuItem(value: 'HOUSEHOLD', child: Text('Keluarga')),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                ],
                onChanged: (value) => setState(() => scope = value!),
              ),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                items: categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item['id'] as String,
                        child: Text(item['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) => categoryId = value!,
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Batas budget'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await _run(
        () => ref
            .read(cashFlowServiceProvider)
            .saveBudget(
              periodId:
                  (scope == 'HOUSEHOLD'
                          ? householdPeriod
                          : personalPeriod)['id']
                      as String,
              categoryId: categoryId,
              scope: scope,
              amount: FinanceValidation.normalizeAmount(amount.text),
            ),
      );
    }
    amount.dispose();
  }

  Future<void> _showFundDialog(Map<String, dynamic> data) async {
    final wallets = data['wallets'] as List<Map<String, dynamic>>;
    if (wallets.isEmpty) return;
    var walletId = wallets.first['id'] as String;
    final label = TextEditingController();
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kunci sebagian saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: walletId,
              items: wallets
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(
                        '${item['name']} · tersedia ${_money(item['availableBalance'])}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => walletId = value!,
            ),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Tujuan dana'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal'),
            ),
            const Text(
              'Soft lock tidak memblokir rekening bank. Penggunaan dana memerlukan pelepasan alokasi.',
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
            child: const Text('Kunci'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _run(
        () => ref
            .read(cashFlowServiceProvider)
            .saveLockedFund(
              walletId: walletId,
              label: FinanceValidation.requiredText(
                label.text,
                'Tujuan dana',
                minLength: 2,
              ),
              amount: FinanceValidation.normalizeAmount(amount.text),
            ),
      );
    }
    label.dispose();
    amount.dispose();
  }

  Future<void> _releaseFund(Map<String, dynamic> fund) async {
    await _run(
      () => ref
          .read(cashFlowServiceProvider)
          .releaseLockedFund(fund['id'] as String, fund['version'] as int),
    );
  }

  Future<void> _showObligationDialog(Map<String, dynamic> data) async {
    final wallets = data['wallets'] as List<Map<String, dynamic>>;
    final categories = data['categories'] as List<Map<String, dynamic>>;
    if (wallets.isEmpty || categories.isEmpty) return;
    var walletId = wallets.first['id'] as String;
    var categoryId = categories.first['id'] as String;
    var frequency = 'MONTHLY';
    var scope = 'HOUSEHOLD';
    var dueDate = DateTime.now();
    final name = TextEditingController();
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah tagihan rutin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama tagihan'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimasi'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: walletId,
                  items: wallets
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(item['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => walletId = value!,
                ),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(item['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => categoryId = value!,
                ),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  items: const [
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Bulanan')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Mingguan')),
                  ],
                  onChanged: (value) => frequency = value!,
                ),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  items: const [
                    DropdownMenuItem(
                      value: 'HOUSEHOLD',
                      child: Text('Keluarga'),
                    ),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                  ],
                  onChanged: (value) => scope = value!,
                ),
                ListTile(
                  title: const Text('Jatuh tempo pertama'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(dueDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 31),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 366)),
                    );
                    if (picked != null) setState(() => dueDate = picked);
                  },
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await _run(
        () => ref
            .read(cashFlowServiceProvider)
            .saveObligation(
              name: FinanceValidation.requiredText(
                name.text,
                'Nama tagihan',
                minLength: 2,
              ),
              walletId: walletId,
              categoryId: categoryId,
              scope: scope,
              frequency: frequency,
              estimatedAmount: FinanceValidation.normalizeAmount(amount.text),
              nextDueDate: dueDate,
            ),
      );
    }
    name.dispose();
    amount.dispose();
  }

  Future<void> _resolveOccurrence(Map<String, dynamic> item) async {
    final amount = TextEditingController(
      text: item['estimatedAmount'].toString(),
    );
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] as String),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nominal aktual'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Lewati'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reschedule'),
            child: const Text('Jadwal ulang'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'pay'),
            child: const Text('Sudah dibayar'),
          ),
        ],
      ),
    );
    if (action == 'pay') {
      await _run(
        () => ref
            .read(cashFlowServiceProvider)
            .confirmObligation(
              occurrenceId: item['occurrenceId'] as String,
              actualAmount: FinanceValidation.normalizeAmount(amount.text),
              transactionDate: DateTime.now(),
            ),
      );
    } else if (action == 'skip') {
      await _run(
        () => ref
            .read(cashFlowServiceProvider)
            .resolveObligation(
              occurrenceId: item['occurrenceId'] as String,
              action: 'SKIP',
            ),
      );
    } else if (action == 'reschedule' && mounted) {
      final selected = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 366)),
      );
      if (selected != null) {
        await _run(
          () => ref
              .read(cashFlowServiceProvider)
              .resolveObligation(
                occurrenceId: item['occurrenceId'] as String,
                action: 'RESCHEDULE',
                rescheduledDate: selected,
              ),
        );
      }
    }
    amount.dispose();
  }

  Future<void> _synchronize() async {
    final householdId = widget.contextData.householdId;
    if (householdId == null) return;
    await _run(() async {
      final result = await SyncService(
        ref.read(supabaseClientProvider)!,
        ref.read(appDatabaseProvider),
      ).synchronize(householdId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sinkron: ${result.pushed} dikirim, ${result.pulled} diterima, ${result.conflicts} konflik.',
          ),
        ),
      );
    });
  }

  Future<void> _showBackup() async {
    await _run(() async {
      final remote = await ref.read(cashFlowServiceProvider).exportRemoteData();
      final backup = BackupService(ref.read(appDatabaseProvider));
      final json = await backup.createBackup(remote);
      final csv = backup.transactionsCsv(remote);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup dan export'),
          content: const Text(
            'Backup JSON memiliki checksum dan dapat direstore secara idempotent. CSV tidak menyertakan deskripsi transaksi private.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
              },
              child: const Text('Salin CSV'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
              },
              child: const Text('Salin JSON'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showRestoreDialog() async {
    final source = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore cache dari JSON'),
        content: TextField(
          controller: source,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Backup JSON',
            helperText: 'Checksum dan versi schema akan diverifikasi.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (accepted == true && source.text.trim().isNotEmpty) {
      await _run(
        () => BackupService(
          ref.read(appDatabaseProvider),
        ).restoreLocalBackup(source.text),
      );
    }
    source.dispose();
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});
  final Map<String, dynamic> forecast;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Batas aman harian')),
              Chip(label: Text(forecast['health']?.toString() ?? '—')),
            ],
          ),
          Text(
            _money(forecast['safeDailyLimit']),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Divider(),
          Text('Saldo kas ${_money(forecast['cashBalance'])}'),
          Text('Dana terkunci −${_money(forecast['lockedFunds'])}'),
          Text('Kebutuhan rutin −${_money(forecast['routineNeeds'])}'),
          Text(
            'Saldo bebas ${_money(forecast['availableCash'])} untuk ${forecast['remainingDays']} hari',
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );
}

String _money(dynamic value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(num.tryParse('$value') ?? 0);
