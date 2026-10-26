import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';
import 'windows_record_payment_screen.dart';

/// Windows desktop detail view for a single fee record.
///
/// Presents the agreed fee, the collected and outstanding balances, the
/// service line items and the payment ledger. Recording a payment uses the
/// same [FirestoreService] contract as the mobile flow, so the balances and
/// the ledger stay consistent across platforms.
class WindowsFeeDetailScreen extends StatefulWidget {
  const WindowsFeeDetailScreen({super.key, required this.fee});

  final FeeModel fee;

  @override
  State<WindowsFeeDetailScreen> createState() => _WindowsFeeDetailScreenState();
}

class _WindowsFeeDetailScreenState extends State<WindowsFeeDetailScreen> {
  final _service = FirestoreService();
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<FeeTransaction> _transactions = const [];
  bool _loadingTx = true;
  String? _txError;

  /// The record as it currently stands.
  ///
  /// The screen is opened with a snapshot of the record, so the balances are
  /// re-read after a payment is taken. Without this the header and the
  /// balance tiles would keep showing the pre-payment figures.
  late FeeModel _fee = widget.fee;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  /// Re-reads the record so the agreed, collected and outstanding figures
  /// match the ledger.
  Future<void> _refreshFee() async {
    try {
      final fees = await _service.watchFees().first;
      FeeModel? updated;
      for (final item in fees) {
        if (item.id == widget.fee.id) {
          updated = item;
          break;
        }
      }
      if (updated == null || !mounted) {
        return;
      }
      final refreshed = updated;
      setState(() {
        _fee = refreshed;
      });
    } catch (_) {
      // The balances fall back to the snapshot that was handed to the screen.
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final tx = await _service.fetchFeeTransactions(widget.fee.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = tx;
        _loadingTx = false;
        _txError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingTx = false;
        _txError = 'Could not load the payment history.';
      });
    }
  }

  Future<void> _openRecordPayment() async {
    final recorded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WindowsDesktopShell(
          activeRoute: '/fee',
          child: WindowsRecordPaymentScreen(fee: _fee),
        ),
      ),
    );
    if (recorded == true && mounted) {
      await _loadTransactions();
      await _refreshFee();
    }
  }

  Future<void> _deleteFee() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this fee record?',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'The record for ${widget.fee.clientName} and all of its recorded '
          'payments will be removed. This cannot be undone.',
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textMuted,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.statusDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete record'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _service.deleteFee(widget.fee.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fee = _fee;
    final settled = fee.status == FeeStatus.settled;

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(settled),
                    const SizedBox(height: 20),
                    _balances(fee),
                    const SizedBox(height: 16),
                    _services(fee),
                    if (fee.notes != null && fee.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _notes(fee.notes!),
                    ],
                    const SizedBox(height: 16),
                    _ledger(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool settled) {
    final fee = _fee;
    return WindowsPageHeader(
      eyebrow: 'PRACTICE FINANCES',
      title: fee.clientName,
      subtitle: fee.caseTitle,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to fees',
      ),
      actions: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!settled)
            FilledButton.icon(
              onPressed: _openRecordPayment,
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Record payment'),
              style: WindowsButtonStyles.primary(),
            ),
          IconButton(
            onPressed: _deleteFee,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppPalette.statusDanger,
            tooltip: 'Delete record',
          ),
        ],
      ),
    );
  }

  Widget _balances(FeeModel fee) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _balanceTile('AGREED', fee.agreedTotal, AppPalette.textPrimary),
        const SizedBox(width: 12),
        _balanceTile('COLLECTED', fee.collectedTotal, AppPalette.statusSuccess),
        const SizedBox(width: 12),
        _balanceTile(
          'OUTSTANDING',
          fee.pendingTotal,
          fee.pendingTotal > 0
              ? AppPalette.statusDanger
              : AppPalette.statusSuccess,
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STATUS',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: fee.status == FeeStatus.settled
                            ? AppPalette.statusSuccess
                            : AppPalette.statusWarning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fee.status.label,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _balanceTile(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
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

  Widget _services(FeeModel fee) {
    return _panel(
      'Services',
      fee.services.isEmpty
          ? const Text(
              'No service line items were recorded for this fee.',
              style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
            )
          : Column(
              children: [
                for (final service in fee.services)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.serviceName,
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹ ${_money.format(service.rate)} × ${service.quantity}',
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹ ${_money.format(service.subtotal)}',
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _notes(String notes) {
    return _panel(
      'Notes',
      Text(
        notes,
        style: const TextStyle(
          color: AppPalette.textMuted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _ledger() {
    return _panel(
      'Payment history',
      _loadingTx
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppPalette.primaryGreen,
                  ),
                ),
              ),
            )
          : _txError != null
          ? _ledgerMessage(Icons.error_outline_rounded, _txError!, danger: true)
          : _transactions.isEmpty
          ? _ledgerMessage(
              Icons.receipt_long_outlined,
              'No payments have been recorded against this fee yet.',
            )
          : Column(
              children: [
                for (final tx in _transactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppPalette.statusTile,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: AppPalette.primaryGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.receiptNumber == null ||
                                        tx.receiptNumber!.isEmpty
                                    ? tx.paymentMode
                                    : '${tx.paymentMode} · ${tx.receiptNumber}',
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateFmt.format(tx.paymentDate),
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹ ${_money.format(tx.amount)}',
                          style: const TextStyle(
                            color: AppPalette.primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _ledgerMessage(IconData icon, String message, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: danger ? AppPalette.statusDanger : AppPalette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: danger
                    ? AppPalette.statusDanger
                    : AppPalette.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
