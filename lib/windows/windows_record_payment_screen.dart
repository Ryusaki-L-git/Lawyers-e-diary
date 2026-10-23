import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/fee_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Windows desktop payment capture screen for an existing fee record.
///
/// Records the payment through the shared [FirestoreService] contract, so the
/// ledger, the collected total and the fee status are updated by exactly the
/// same rules as the mobile flow. The screen only supplies the desktop
/// presentation, the validation and the honest success/failure feedback.
class WindowsRecordPaymentScreen extends StatefulWidget {
  const WindowsRecordPaymentScreen({super.key, required this.fee});

  final FeeModel fee;

  @override
  State<WindowsRecordPaymentScreen> createState() =>
      _WindowsRecordPaymentScreenState();
}

class _WindowsRecordPaymentScreenState
    extends State<WindowsRecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _receiptController = TextEditingController();
  final _service = FirestoreService();
  final _money = NumberFormat('#,##0.00', 'en_US');

  bool _isSaving = false;
  String _paymentMode = 'Cash';

  static const _paymentModes = <String>[
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Online',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  /// The collected total that will be persisted for the entered amount.
  ///
  /// This mirrors the clamp used by the mobile flow so both platforms write
  /// identical totals, and it is surfaced to the user before saving so a
  /// capped overpayment is never silent.
  double get _projectedCollected => (widget.fee.collectedTotal + _enteredAmount)
      .clamp(0.0, widget.fee.agreedTotal * 2);

  double get _projectedPending => (widget.fee.agreedTotal - _projectedCollected)
      .clamp(0.0, double.infinity);

  /// True when the entered amount exceeds what the agreed total can absorb.
  bool get _isCapped =>
      _enteredAmount > 0 &&
      _projectedCollected < widget.fee.collectedTotal + _enteredAmount;

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _enteredAmount;
    if (amount <= 0) {
      _notify('Enter a valid payment amount.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.recordFeePayment(
        feeId: widget.fee.id,
        amount: amount,
        newCollectedTotal: _projectedCollected,
        agreedTotal: widget.fee.agreedTotal,
        paymentMode: _paymentMode,
        receiptNumber: _receiptController.text.trim().isEmpty
            ? null
            : _receiptController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _notify(
        'The payment could not be recorded. Please check your connection and try again.',
      );
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 760;
                        final form = _form();
                        final summary = _summary();
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: form),
                              const SizedBox(width: 16),
                              Expanded(child: summary),
                            ],
                          );
                        }
                        return Column(
                          children: [form, const SizedBox(height: 14), summary],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return WindowsPageHeader(
      eyebrow: 'PRACTICE FINANCES',
      title: 'Record a payment',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to fee record',
      ),
      actions: _isSaving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppPalette.accentGold,
              ),
            )
          : FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 19),
              label: const Text('Confirm payment'),
              style: WindowsButtonStyles.primary(),
            ),
    );
  }

  Widget _form() {
    return WindowsPanel(
      title: 'Payment details',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WindowsFieldLabel('Payment amount (Rs)'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
              decoration: WindowsFieldDecoration(
                hint:
                    'e.g. ${widget.fee.pendingTotal > 0 ? _money.format(widget.fee.pendingTotal / 2) : '0'}',
              ).build(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Amount is required';
                }
                final d = double.tryParse(v.trim());
                if (d == null) return 'Enter a numeric amount';
                if (d <= 0) return 'Amount must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 18),
            const WindowsFieldLabel('Payment mode'),
            const SizedBox(height: 7),
            WindowsFilterBar(
              options: [for (final mode in _paymentModes) (mode, mode)],
              selected: _paymentMode,
              onChanged: (mode) => setState(() => _paymentMode = mode),
            ),
            const SizedBox(height: 18),
            const WindowsFieldLabel('Receipt / reference number (optional)'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _receiptController,
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: const WindowsFieldDecoration(
                hint: 'e.g. RCT-2024-001',
              ).build(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final projected = _projectedCollected;
    final pending = _projectedPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindowsPanel(
          title: 'Outstanding balance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.fee.clientName,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.fee.caseTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              _amountRow(
                'Agreed',
                widget.fee.agreedTotal,
                AppPalette.textPrimary,
              ),
              const SizedBox(height: 9),
              _amountRow(
                'Already collected',
                widget.fee.collectedTotal,
                AppPalette.textPrimary,
              ),
              const SizedBox(height: 9),
              _amountRow(
                'Currently outstanding',
                widget.fee.pendingTotal,
                widget.fee.pendingTotal > 0
                    ? AppPalette.statusDanger
                    : AppPalette.statusSuccess,
              ),
              const SizedBox(height: 13),
              const Divider(height: 1, color: AppPalette.borderLight),
              const SizedBox(height: 13),
              _amountRow(
                'Collected after saving',
                projected,
                AppPalette.primaryGreen,
                emphasise: true,
              ),
              const SizedBox(height: 9),
              _amountRow(
                'Outstanding after saving',
                pending,
                pending > 0
                    ? AppPalette.statusWarning
                    : AppPalette.statusSuccess,
                emphasise: true,
              ),
            ],
          ),
        ),
        if (_isCapped) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.noteFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.noteBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppPalette.statusWarning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This amount is above the agreed fee. The collected total is '
                    'capped at twice the agreed value, so the recorded balance '
                    'will differ from the amount entered.',
                    style: TextStyle(
                      color: AppPalette.textPrimary.withValues(alpha: 0.78),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _amountRow(
    String label,
    double amount,
    Color color, {
    bool emphasise = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: emphasise ? 12 : 11,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          '₹ ${_money.format(amount)}',
          style: TextStyle(
            color: color,
            fontSize: emphasise ? 15 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
