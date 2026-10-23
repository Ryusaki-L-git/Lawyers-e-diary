import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_model.dart';
import '../screens/fees/add_fee_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';
import 'windows_fee_detail_screen.dart';

/// Windows desktop register of fee records and their balances.
///
/// The figures come from the shared [FirestoreService] contract, so the
/// desktop register and the mobile ledger never drift apart. The screen only
/// presents the agreed, collected and outstanding balances and links through
/// to the record and payment surfaces.
class WindowsFeesScreen extends StatefulWidget {
  const WindowsFeesScreen({super.key});

  @override
  State<WindowsFeesScreen> createState() => _WindowsFeesScreenState();
}

class _WindowsFeesScreenState extends State<WindowsFeesScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');

  int _retryToken = 0;

  void _retry() {
    setState(() => _retryToken++);
  }

  void _openNewFee() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/fee',
          child: AddFeeScreen(),
        ),
      ),
    );
  }

  void _openDetail(FeeModel fee) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WindowsDesktopShell(
          activeRoute: '/fee',
          child: WindowsFeeDetailScreen(fee: fee),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'PRACTICE FINANCES',
                title: 'Fees & transactions',
                subtitle: 'Track agreed fees, received payments and outstanding balances.',
                actions: FilledButton.icon(
                  onPressed: _openNewFee,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New fee record'),
                  style: WindowsButtonStyles.primary(),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: StreamBuilder<List<FeeModel>>(
                  key: ValueKey<int>(_retryToken),
                  stream: _service.watchFees(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load fee records',
                        message: snapshot.error.toString(),
                        isError: true,
                        action: OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const WindowsLoadingPanel();
                    }
                    final fees = snapshot.data ?? const <FeeModel>[];
                    final agreed = fees.fold<double>(
                      0,
                      (s, f) => s + f.agreedTotal,
                    );
                    final collected = fees.fold<double>(
                      0,
                      (s, f) => s + f.collectedTotal,
                    );
                    final pending = fees.fold<double>(
                      0,
                      (s, f) => s + f.pendingTotal,
                    );
                    if (fees.isEmpty) {
                      return Column(
                        children: [
                          _summary(agreed, collected, pending),
                          const Expanded(
                            child: WindowsMessageState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'No fee records yet',
                              message: 'Create a fee record to begin tracking payments.',
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _summary(agreed, collected, pending),
                        const SizedBox(height: 17),
                        Expanded(child: _register(fees)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(double agreed, double collected, double pending) {
    return Row(
      children: [
        _stat('Total agreed', agreed, AppPalette.primaryGreen),
        const SizedBox(width: 12),
        _stat('Collected', collected, AppPalette.statusSuccess),
        const SizedBox(width: 12),
        _stat('Outstanding', pending, AppPalette.statusDanger),
      ],
    );
  }

  Widget _stat(String label, double amount, Color color) {
    return Expanded(
      child: WindowsPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WindowsSectionHeading(label),
            const SizedBox(height: 9),
            Text(
              '₹ ${_money.format(amount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _register(List<FeeModel> fees) {
    return WindowsPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppPalette.borderLight)),
            ),
            child: Row(
              children: [
                WindowsColumnLabel('Client / matter · ${fees.length}', flex: 4),
                WindowsColumnLabel('Agreed', flex: 2),
                WindowsColumnLabel('Collected', flex: 2),
                WindowsColumnLabel('Outstanding', flex: 2),
                const SizedBox(width: 105),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: fees.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppPalette.borderLight),
              itemBuilder: (context, index) => _row(fees[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(FeeModel fee) {
    final statusColor = fee.status == FeeStatus.settled
        ? AppPalette.statusSuccess
        : fee.status == FeeStatus.partiallyPaid
        ? AppPalette.statusWarning
        : AppPalette.textMuted;
    return InkWell(
      onTap: () => _openDetail(fee),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fee.clientName,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fee.caseTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WindowsStatusChip(
                    label: fee.status.label,
                    color: statusColor,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹ ${_money.format(fee.agreedTotal)}',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹ ${_money.format(fee.collectedTotal)}',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹ ${_money.format(fee.pendingTotal)}',
                style: TextStyle(
                  color: fee.pendingTotal > 0
                      ? AppPalette.statusDanger
                      : AppPalette.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 105,
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _openDetail(fee),
                  style: WindowsButtonStyles.secondary(),
                  child: const Text('Details'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
