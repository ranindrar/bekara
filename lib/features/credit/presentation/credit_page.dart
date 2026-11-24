import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/core_providers.dart';
import '../../finance/data/finance_service.dart';
import '../../finance/domain/finance_validation.dart';
import '../../importer/data/import_service.dart';
import '../../importer/domain/csv_import_parser.dart';
import '../data/credit_service.dart';

class CreditPage extends ConsumerStatefulWidget {
  const CreditPage({required this.householdId, this.onChanged, super.key});

  final String householdId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends ConsumerState<CreditPage> {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _wallets = const [];
  List<Map<String, dynamic>> _categories = const [];
  Object? _error;
  bool _loading = true;

  CreditService get _credit => CreditService(
    ref.read(supabaseClientProvider)!,
    ref.read(appDatabaseProvider),
  );

  FinanceService get _finance => FinanceService(
    ref.read(supabaseClientProvider)!,
    ref.read(appDatabaseProvider),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _credit.dashboard(widget.householdId),
        _credit.notifications(),
        _finance.wallets(),
        _finance.categories(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = values[0] as Map<String, dynamic>;
        _notifications = values[1] as List<Map<String, dynamic>>;
        _wallets = values[2] as List<Map<String, dynamic>>;
        _categories = values[3] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat ulang kredit'),
        ),
      );
    }
    final dashboard = _dashboard ?? const <String, dynamic>{};
    final accounts = (dashboard['accounts'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final forecast = Map<String, dynamic>.from(
      dashboard['forecast'] as Map? ?? const {},
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (dashboard['offline'] == true)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('Menampilkan cache akun kredit'),
                subtitle: Text('Pembayaran tetap memerlukan koneksi.'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Tagihan pribadi',
                  value: _money(forecast['personalDue']),
                ),
              ),
              Expanded(
                child: _MetricCard(
                  label: 'Reserve household',
                  value: _money(forecast['householdReserve']),
                ),
              ),
            ],
          ),
          if (dashboard['nearestDue'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Jatuh tempo terdekat: ${dashboard['nearestDue']}'),
            ),
          if (_notifications.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Pengingat', style: Theme.of(context).textTheme.titleMedium),
            for (final notification in _notifications)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(
                    '${notification['eventType']} · ${notification['accountName']}',
                  ),
                  subtitle: Text(
                    '${notification['dueDate']} · ${_money(notification['outstanding'])}',
                  ),
                  onTap: () {
                    final account = accounts
                        .cast<Map<String, dynamic>?>()
                        .firstWhere(
                          (item) => item?['id'] == notification['accountId'],
                          orElse: () => null,
                        );
                    if (account != null) _showDetails(account);
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _run(() async {
                      await _credit.markNotification(
                        notification['eventKey'] as String,
                        dismiss: value == 'dismiss',
                      );
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'read',
                        child: Text('Tandai dibaca'),
                      ),
                      PopupMenuItem(
                        value: 'dismiss',
                        child: Text('Abaikan pengingat'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Akun kredit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Impor CSV',
                onPressed: _showImport,
                icon: const Icon(Icons.upload_file),
              ),
              FilledButton.icon(
                onPressed: _showCreateAccount,
                icon: const Icon(Icons.add_card),
                label: const Text('Tambah'),
              ),
            ],
          ),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Belum ada kartu kredit atau PayLater.'),
              ),
            ),
          for (final account in accounts) _accountCard(account),
        ],
      ),
    );
  }

  Widget _accountCard(Map<String, dynamic> account) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              account['accountType'] == 'PAYLATER'
                  ? Icons.shopping_bag_outlined
                  : Icons.credit_card,
            ),
            title: Text('${account['accountName']}'),
            subtitle: Text(
              '${account['providerName']} · ${account['scope'] == 'HOUSEHOLD' ? 'Household' : 'Pribadi'}'
              '${account['lastFour'] == null ? '' : ' · •••• ${account['lastFour']}'}',
            ),
            trailing: Text('${account['status']}'),
          ),
          Text('Terpakai ${_money(account['outstanding'])}'),
          Text('Sisa limit ${_money(account['remainingLimit'])}'),
          if ((num.tryParse('${account['remainingLimit']}') ?? 0) < 0)
            const Text('Limit terlampaui', style: TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: account['status'] == 'ACTIVE'
                    ? () => _showPurchase(account)
                    : null,
                child: const Text('Belanja'),
              ),
              OutlinedButton(
                onPressed: account['status'] == 'ACTIVE'
                    ? () => _showPayment(account)
                    : null,
                child: const Text('Bayar'),
              ),
              TextButton(
                onPressed: () => _showDetails(account),
                child: const Text('Tagihan'),
              ),
              TextButton(
                onPressed: () => _showReconcile(account),
                child: const Text('Rekonsiliasi'),
              ),
              TextButton(
                onPressed: () => _showManageAccount(account),
                child: const Text('Kelola'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _showCreateAccount() async {
    final provider = TextEditingController();
    final name = TextEditingController();
    final lastFour = TextEditingController();
    final limit = TextEditingController();
    final opening = TextEditingController(text: '0');
    var type = 'PAYLATER';
    var scope = 'PRIVATE';
    var statementDay = 25;
    var dueDay = 10;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Tambah akun kredit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(
                      value: 'PAYLATER',
                      child: Text('PayLater pribadi'),
                    ),
                    DropdownMenuItem(
                      value: 'CREDIT_CARD',
                      child: Text('Kartu kredit'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    type = value!;
                    if (type == 'PAYLATER') scope = 'PRIVATE';
                  }),
                ),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Kepemilikan'),
                  items: const [
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                    DropdownMenuItem(
                      value: 'HOUSEHOLD',
                      child: Text('Household'),
                    ),
                  ],
                  onChanged: type == 'PAYLATER'
                      ? null
                      : (value) => scope = value!,
                ),
                TextField(
                  controller: provider,
                  decoration: const InputDecoration(labelText: 'Penyedia'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama akun'),
                ),
                TextField(
                  controller: lastFour,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '4 digit terakhir (opsional)',
                  ),
                ),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Limit'),
                ),
                TextField(
                  controller: opening,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tagihan awal'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _dayField(
                        'Cutoff',
                        statementDay,
                        (v) => statementDay = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dayField(
                        'Jatuh tempo',
                        dueDay,
                        (v) => dueDay = v,
                      ),
                    ),
                  ],
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
        () => _credit.createAccount(
          accountType: type,
          scope: scope,
          providerName: provider.text,
          accountName: name.text,
          lastFour: lastFour.text,
          creditLimit: limit.text,
          openingLiability: opening.text,
          statementDay: statementDay,
          dueDay: dueDay,
        ),
      );
    }
    provider.dispose();
    name.dispose();
    lastFour.dispose();
    limit.dispose();
    opening.dispose();
  }

  Widget _dayField(String label, int value, ValueChanged<int> onChanged) {
    final controller = TextEditingController(text: '$value');
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '$label (1–31)'),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  Future<void> _showManageAccount(Map<String, dynamic> account) async {
    final provider = TextEditingController(text: '${account['providerName']}');
    final name = TextEditingController(text: '${account['accountName']}');
    final lastFour = TextEditingController(
      text: '${account['lastFour'] ?? ''}',
    );
    final limit = TextEditingController(text: '${account['creditLimit']}');
    var statementDay = account['statementDay'] as int;
    var dueDay = account['dueDay'] as int;
    var archive = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Kelola ${account['accountName']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: provider,
                  decoration: const InputDecoration(labelText: 'Penyedia'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama akun'),
                ),
                TextField(
                  controller: lastFour,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '4 digit terakhir',
                  ),
                ),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Limit'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _dayField(
                        'Cutoff',
                        statementDay,
                        (v) => statementDay = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dayField(
                        'Jatuh tempo',
                        dueDay,
                        (v) => dueDay = v,
                      ),
                    ),
                  ],
                ),
                if (account['status'] == 'ACTIVE')
                  CheckboxListTile(
                    value: archive,
                    title: const Text('Arsipkan akun'),
                    subtitle: const Text(
                      'Hanya bisa jika kewajiban sudah nol.',
                    ),
                    onChanged: (value) =>
                        setDialogState(() => archive = value ?? false),
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
      await _run(() async {
        if (archive) {
          await _credit.archiveAccount(
            account['id'] as String,
            account['version'] as int,
          );
        } else {
          await _credit.updateAccount(
            accountId: account['id'] as String,
            expectedVersion: account['version'] as int,
            providerName: provider.text,
            accountName: name.text,
            lastFour: lastFour.text,
            creditLimit: limit.text,
            statementDay: statementDay,
            dueDay: dueDay,
          );
        }
      });
    }
    provider.dispose();
    name.dispose();
    lastFour.dispose();
    limit.dispose();
  }

  Future<void> _showPurchase(Map<String, dynamic> account) async {
    final expenses = _categories
        .where((c) => c['direction'] == 'EXPENSE')
        .toList();
    if (expenses.isEmpty) {
      return _message('Tambahkan kategori pengeluaran terlebih dahulu.');
    }
    final principal = TextEditingController();
    final fee = TextEditingController(text: '0');
    final description = TextEditingController();
    String? categoryId = expenses.first['id'] as String?;
    var scope = account['scope'] == 'HOUSEHOLD' ? 'HOUSEHOLD' : 'PRIVATE';
    var privacy = 'PRIVATE_FULL';
    var tenor = 1;
    var date = DateTime.now();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Belanja · ${account['accountName']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: principal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pokok'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Biaya pembiayaan diketahui',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    for (final c in expenses)
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text('${c['name']}'),
                      ),
                  ],
                  onChanged: (value) => categoryId = value,
                ),
                DropdownButtonFormField<int>(
                  initialValue: tenor,
                  decoration: const InputDecoration(labelText: 'Tenor'),
                  items: [
                    for (var i = 1; i <= 36; i++)
                      DropdownMenuItem(value: i, child: Text('$i bulan')),
                  ],
                  onChanged: (value) => setDialogState(() => tenor = value!),
                ),
                _InstallmentPreview(
                  principal: principal.text,
                  fee: fee.text,
                  tenor: tenor,
                ),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(
                    labelText: 'Cakupan transaksi',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                    DropdownMenuItem(
                      value: 'HOUSEHOLD',
                      child: Text('Household'),
                    ),
                  ],
                  onChanged: account['scope'] == 'HOUSEHOLD'
                      ? null
                      : (value) => setDialogState(() => scope = value!),
                ),
                if (scope == 'PRIVATE')
                  DropdownButtonFormField<String>(
                    initialValue: privacy,
                    decoration: const InputDecoration(labelText: 'Privasi'),
                    items: const [
                      DropdownMenuItem(
                        value: 'PRIVATE_FULL',
                        child: Text('Detail pribadi'),
                      ),
                      DropdownMenuItem(
                        value: 'PRIVATE_SUMMARY',
                        child: Text('Ringkasan pribadi'),
                      ),
                    ],
                    onChanged: (value) => privacy = value!,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal transaksi'),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(date),
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: date,
                    );
                    if (picked != null) setDialogState(() => date = picked);
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
              child: const Text('Catat'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && categoryId != null) {
      await _run(() async {
        final result = await _credit.postPurchase(
          accountId: account['id'] as String,
          categoryId: categoryId!,
          principal: principal.text,
          financingCost: fee.text,
          tenor: tenor,
          description: description.text,
          scope: scope,
          privacyMode: privacy,
          transactionDate: date,
        );
        if (result == FinancialMutationResult.queued) {
          _message('Pembelian disimpan dan menunggu sinkronisasi.');
        }
      });
    }
    principal.dispose();
    fee.dispose();
    description.dispose();
  }

  Future<void> _showPayment(Map<String, dynamic> account) async {
    if (_wallets.isEmpty) {
      return _message('Tambahkan dompet kas untuk membayar tagihan.');
    }
    final amount = TextEditingController(text: '${account['outstanding']}');
    final description = TextEditingController(
      text: 'Pembayaran ${account['accountName']}',
    );
    String? walletId = _wallets.first['id'] as String?;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bayar tagihan (online)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: walletId,
              decoration: const InputDecoration(labelText: 'Dompet kas'),
              items: [
                for (final w in _wallets)
                  DropdownMenuItem(
                    value: w['id'] as String,
                    child: Text('${w['name']} · ${_money(w['balance'])}'),
                  ),
              ],
              onChanged: (value) => walletId = value,
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Keterangan'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pembayaran dialokasikan ke tagihan tertua, lalu proporsional per scope.',
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
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
    if (accepted == true && walletId != null) {
      await _run(() async {
        await _credit.payBill(
          accountId: account['id'] as String,
          sourceWalletId: walletId!,
          amount: amount.text,
          description: description.text,
          paymentDate: DateTime.now(),
        );
      });
    }
    amount.dispose();
    description.dispose();
  }

  Future<void> _showDetails(Map<String, dynamic> account) async {
    try {
      final values = await Future.wait([
        _credit.bills(account['id'] as String, widget.householdId),
        _credit.installments(account['id'] as String, widget.householdId),
        _credit.payments(account['id'] as String),
      ]);
      if (!mounted) return;
      final bills = values[0];
      final installments = values[1];
      final payments = values[2];
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Tagihan · ${account['accountName']}'),
          content: SizedBox(
            width: 560,
            child: DefaultTabController(
              length: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Tagihan'),
                      Tab(text: 'Cicilan'),
                      Tab(text: 'Bayar'),
                    ],
                  ),
                  SizedBox(
                    height: 360,
                    child: TabBarView(
                      children: [
                        _detailList(
                          bills,
                          (x) => '${x['periodStart']}–${x['periodEnd']}',
                          (x) => '${x['status']} · ${_money(x['outstanding'])}',
                        ),
                        installments.isEmpty
                            ? const Center(child: Text('Belum ada data.'))
                            : ListView.builder(
                                itemCount: installments.length,
                                itemBuilder: (_, index) {
                                  final item = installments[index];
                                  return ListTile(
                                    title: Text(
                                      '${item['description'] ?? 'Cicilan'} #${item['installmentNumber']}',
                                    ),
                                    subtitle: Text(
                                      '${item['dueDate']} · ${_money(item['remaining'])} · ${item['scope']}',
                                    ),
                                    trailing:
                                        num.tryParse('${item['remaining']}') ==
                                            0
                                        ? null
                                        : IconButton(
                                            tooltip: 'Catat refund',
                                            onPressed: () => _showRefund(item),
                                            icon: const Icon(Icons.undo),
                                          ),
                                  );
                                },
                              ),
                        _detailList(
                          payments,
                          (x) => '${x['paymentDate']} · ${x['sourceWallet']}',
                          (x) => _money(x['amount']),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(FinanceValidation.friendlyError(error));
    }
  }

  Widget _detailList(
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic>) title,
    String Function(Map<String, dynamic>) subtitle,
  ) => rows.isEmpty
      ? const Center(child: Text('Belum ada data.'))
      : ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(title(rows[i])),
            subtitle: Text(subtitle(rows[i])),
          ),
        );

  Future<void> _showRefund(Map<String, dynamic> installment) async {
    final amount = TextEditingController(text: '${installment['remaining']}');
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catat refund kredit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal refund'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Alasan'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Refund mengurangi konsumsi dan kewajiban secara audited.',
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
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _run(
        () => _credit.refundPurchase(
          purchaseId: installment['purchaseId'] as String,
          amount: amount.text,
          reason: reason.text,
        ),
      );
    }
    amount.dispose();
    reason.dispose();
  }

  Future<void> _showReconcile(Map<String, dynamic> account) async {
    final actual = TextEditingController(text: '${account['outstanding']}');
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rekonsiliasi ${account['accountName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: actual,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kewajiban aktual'),
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
    if (accepted == true) {
      await _run(
        () => _credit.reconcile(
          accountId: account['id'] as String,
          actualLiability: actual.text,
          reason: reason.text,
        ),
      );
    }
    actual.dispose();
    reason.dispose();
  }

  Future<void> _showImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    CsvImportPreview preview;
    try {
      preview = CsvImportParser.parse(result.files.single.bytes!);
    } catch (error) {
      return _message(error.toString());
    }
    if (preview.rows.isEmpty || preview.issues.isNotEmpty) {
      return _message(
        '${preview.rows.length} valid, ${preview.issues.length} bermasalah. Perbaiki CSV sebelum commit.',
      );
    }
    final expenses = _categories
        .where((c) => c['direction'] == 'EXPENSE')
        .toList();
    final incomes = _categories
        .where((c) => c['direction'] == 'INCOME')
        .toList();
    if (_wallets.isEmpty || expenses.isEmpty || incomes.isEmpty) {
      return _message(
        'Impor memerlukan dompet, kategori pemasukan, dan kategori pengeluaran.',
      );
    }
    String? walletId = _wallets.first['id'] as String?;
    String? expenseId = expenses.first['id'] as String?;
    String? incomeId = incomes.first['id'] as String?;
    var scope = 'HOUSEHOLD';
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Impor ${preview.rows.length} baris'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final row in preview.rows.take(5))
                      ListTile(
                        dense: true,
                        title: Text(row.description),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(row.date)} · ${row.kind}',
                        ),
                        trailing: Text(_money(row.amount)),
                      ),
                    if (preview.rows.length > 5)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('+${preview.rows.length - 5} baris lain'),
                      ),
                  ],
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Dompet'),
                items: [
                  for (final w in _wallets)
                    DropdownMenuItem(
                      value: w['id'] as String,
                      child: Text('${w['name']}'),
                    ),
                ],
                onChanged: (v) => walletId = v,
              ),
              DropdownButtonFormField<String>(
                initialValue: expenseId,
                decoration: const InputDecoration(
                  labelText: 'Kategori pengeluaran',
                ),
                items: [
                  for (final c in expenses)
                    DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']}'),
                    ),
                ],
                onChanged: (v) => expenseId = v,
              ),
              DropdownButtonFormField<String>(
                initialValue: incomeId,
                decoration: const InputDecoration(
                  labelText: 'Kategori pemasukan',
                ),
                items: [
                  for (final c in incomes)
                    DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']}'),
                    ),
                ],
                onChanged: (v) => incomeId = v,
              ),
              DropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(
                  labelText: 'Scope seluruh baris',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'HOUSEHOLD',
                    child: Text('Household'),
                  ),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Pribadi')),
                ],
                onChanged: (v) => scope = v!,
              ),
              const SizedBox(height: 8),
              const Text(
                'Commit bersifat atomik dan file yang sama tidak akan diduplikasi.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Commit'),
          ),
        ],
      ),
    );
    if (accepted == true &&
        walletId != null &&
        expenseId != null &&
        incomeId != null) {
      await _run(() async {
        final committed = await ImportService(ref.read(supabaseClientProvider)!)
            .commit(
              fileName: result.files.single.name,
              preview: preview,
              walletId: walletId!,
              expenseCategoryId: expenseId!,
              incomeCategoryId: incomeId!,
              scope: scope,
              privacyMode: 'PRIVATE_FULL',
            );
        _message(
          committed['duplicate'] == true
              ? 'File ini sudah pernah diimpor; tidak ada duplikasi.'
              : '${committed['committedRows']} transaksi berhasil diimpor.',
        );
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      _message(FinanceValidation.friendlyError(error));
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}

class _InstallmentPreview extends StatelessWidget {
  const _InstallmentPreview({
    required this.principal,
    required this.fee,
    required this.tenor,
  });

  final String principal;
  final String fee;
  final int tenor;

  @override
  Widget build(BuildContext context) {
    final principalValue = _inputNumber(principal);
    final feeValue = _inputNumber(fee);
    if (principalValue <= 0 || feeValue < 0) return const SizedBox.shrink();
    final total = principalValue + feeValue;
    final principalRegular = (principalValue * 100 ~/ tenor) / 100;
    final feeRegular = (feeValue * 100 ~/ tenor) / 100;
    final regular = principalRegular + feeRegular;
    final last = total - (regular * (tenor - 1));
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          'Total ${_money(total)} · $tenor cicilan · '
          '${_money(regular)}${tenor == 1 ? '' : ', terakhir ${_money(last)}'}',
        ),
      ),
    );
  }
}

num _inputNumber(String value) {
  final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
  return num.tryParse(normalized) ?? -1;
}

String _money(dynamic value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(num.tryParse('$value') ?? 0);
