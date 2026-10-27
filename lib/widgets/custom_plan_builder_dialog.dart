import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds a non-binding request for a custom individual or chamber plan.
/// This dialog never writes entitlements or starts payment processing.
class CustomPlanBuilderDialog extends StatefulWidget {
  const CustomPlanBuilderDialog({
    super.key,
    required this.isTeam,
    required this.planName,
  });

  final bool isTeam;
  final String planName;

  @override
  State<CustomPlanBuilderDialog> createState() =>
      _CustomPlanBuilderDialogState();
}

class _CustomPlanBuilderDialogState extends State<CustomPlanBuilderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _members = TextEditingController(text: '1');
  final _caseTokens = TextEditingController(text: '500');
  final _jurisCredits = TextEditingController(text: '200');
  final _storageGb = TextEditingController(text: '50');
  String _period = 'Monthly';

  @override
  void dispose() {
    _members.dispose();
    _caseTokens.dispose();
    _jurisCredits.dispose();
    _storageGb.dispose();
    super.dispose();
  }

  String? _wholeNumber(String? raw, {required int min, required int max}) {
    final value = int.tryParse((raw ?? '').trim());
    if (value == null) return 'Enter a whole number';
    if (value < min || value > max) return 'Use $min–$max';
    return null;
  }

  Future<void> _copyRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final members = int.parse(_members.text.trim());
    final tokens = int.parse(_caseTokens.text.trim());
    final credits = int.parse(_jurisCredits.text.trim());
    final storage = int.parse(_storageGb.text.trim());
    final periodLabel = _period == 'Monthly' ? 'month' : 'year';
    final request = [
      "Lawyer's E-Diary — Custom Plan Request",
      'Plan: ${widget.planName}',
      'Type: ${widget.isTeam ? 'Chamber / firm' : 'Individual'}',
      if (widget.isTeam) 'Requested seats: $members',
      'Case Tokens: $tokens per $periodLabel',
      'JURIS Credits: $credits per $periodLabel',
      'Requested storage: $storage GB',
      'Status: draft only; not submitted, purchased, or activated.',
      'Storage is a requested quota only; shared file storage is not live.',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: request));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom plan request copied. Nothing was purchased.'),
      ),
    );
  }

  InputDecoration _decoration(String label, String suffix) => InputDecoration(
    labelText: label,
    suffixText: suffix,
    border: const OutlineInputBorder(),
    isDense: true,
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Build your ${widget.isTeam ? 'custom chamber' : 'custom individual'} plan',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure a request to review. These values are not an active subscription and do not change balances.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 18),
              if (widget.isTeam) ...[
                TextFormField(
                  controller: _members,
                  keyboardType: TextInputType.number,
                  decoration: _decoration('Team members', 'seats'),
                  validator: (v) => _wholeNumber(v, min: 1, max: 500),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _caseTokens,
                keyboardType: TextInputType.number,
                decoration: _decoration('Case Token allowance', 'tokens'),
                validator: (v) => _wholeNumber(v, min: 0, max: 1000000),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jurisCredits,
                keyboardType: TextInputType.number,
                decoration: _decoration('JURIS Credit allowance', 'credits'),
                validator: (v) => _wholeNumber(v, min: 0, max: 1000000),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storageGb,
                keyboardType: TextInputType.number,
                decoration: _decoration('Requested storage', 'GB'),
                validator: (v) => _wholeNumber(v, min: 0, max: 100000),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _period,
                decoration: const InputDecoration(
                  labelText: 'Allowance period',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Copying creates a request draft only. It is not submitted to a sales system. Pricing, availability, storage, and activation require written confirmation.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _copyRequest,
        icon: const Icon(Icons.copy_rounded, size: 18),
        label: const Text('Validate & copy request'),
      ),
    ],
  );
}
