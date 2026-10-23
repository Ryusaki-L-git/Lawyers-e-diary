import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// The desktop form that registers a new matter in the local case register.
class WindowsAddCaseScreen extends StatefulWidget {
  const WindowsAddCaseScreen({super.key});
  @override
  State<WindowsAddCaseScreen> createState() => _WindowsAddCaseScreenState();
}

class _WindowsAddCaseScreenState extends State<WindowsAddCaseScreen> {
  final _form = GlobalKey<FormState>();
  final _repo = CaseRepository(database: AppDatabase.instance);
  final _title = TextEditingController(),
      _number = TextEditingController(),
      _client = TextEditingController(),
      _opponent = TextEditingController(),
      _court = TextEditingController(),
      _phone = TextEditingController(),
      _handler = TextEditingController(),
      _notes = TextEditingController();
  String _type = 'Civil Case', _status = 'active';
  DateTime? _hearing;
  bool _saving = false;
  @override
  void dispose() {
    for (final c in [
      _title,
      _number,
      _client,
      _opponent,
      _court,
      _phone,
      _handler,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WindowsPageHeader(
                    eyebrow: 'MASTER DOCKET',
                    title: 'Register a case',
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    actions: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppPalette.accentGold,
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save case'),
                            style: WindowsButtonStyles.primary(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 800;
                      final left = Column(
                        children: [
                          _panel('Matter details', [
                            _field(
                              'Case title *',
                              _title,
                              'Enter the matter title',
                            ),
                            _field(
                              'Case / CNR number',
                              _number,
                              'Enter official case number',
                            ),
                            _dropdown('Case type', _type, const [
                              'Civil Case',
                              'Criminal',
                              'Corporate',
                              'Family',
                              'Constitutional',
                              'Tax',
                              'Labor',
                              'Appellate',
                            ], (v) => setState(() => _type = v)),
                            _dropdown('Status', _status, const [
                              'active',
                              'upcoming',
                              'urgent',
                            ], (v) => setState(() => _status = v)),
                          ]),
                          const SizedBox(height: 15),
                          _panel('Court & hearing', [
                            _field(
                              'Court / forum',
                              _court,
                              'Court or tribunal name',
                            ),
                            _dateField(),
                            _field(
                              'Handled by',
                              _handler,
                              'Advocate or assigned handler',
                            ),
                          ]),
                        ],
                      );
                      final right = Column(
                        children: [
                          _panel('Parties & contact', [
                            _field(
                              'Client name *',
                              _client,
                              'Client or entity name',
                            ),
                            _field(
                              'Opposing party',
                              _opponent,
                              'Opposing party name',
                              isRequired: false,
                            ),
                            _field(
                              'Client phone',
                              _phone,
                              'Contact number',
                              isRequired: false,
                              type: TextInputType.phone,
                            ),
                          ]),
                          const SizedBox(height: 15),
                          _panel('Initial notes', [
                            _field(
                              'Notes',
                              _notes,
                              'Key facts, next steps or preparation notes',
                              isRequired: false,
                              maxLines: 6,
                            ),
                          ]),
                        ],
                      );
                      if (!wide) {
                        return Column(
                          children: [left, const SizedBox(height: 15), right],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 16),
                          Expanded(child: right),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'New cases are saved through the existing authenticated local case repository.',
                    style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _panel(String title, List<Widget> fields) => WindowsPanel(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    ),
  );
  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    bool isRequired = true,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindowsFieldLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: type,
          decoration: WindowsFieldDecoration(hint: hint).build(),
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null
              : null,
        ),
      ],
    ),
  );
  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindowsFieldLabel(label),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const WindowsFieldDecoration(hint: 'Select an option')
              .build(),
          items: options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) changed(v);
          },
        ),
      ],
    ),
  );
  Widget _dateField() => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WindowsFieldLabel('Next hearing date'),
        const SizedBox(height: 7),
        InkWell(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppPalette.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppPalette.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hearing == null
                        ? 'Select a date'
                        : '${_hearing!.day.toString().padLeft(2, '0')}/${_hearing!.month.toString().padLeft(2, '0')}/${_hearing!.year}',
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_hearing != null)
                  IconButton(
                    onPressed: () => setState(() => _hearing = null),
                    icon: const Icon(Icons.close_rounded, size: 17),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _hearing ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null && mounted) setState(() => _hearing = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.createCase(
        caseTitle: _title.text.trim(),
        caseNumber: _number.text.trim(),
        clientName: _client.text.trim(),
        opponentName: _opponent.text.trim(),
        courtName: _court.text.trim(),
        caseType: _type,
        status: _status,
        handledBy: _handler.text.trim().isEmpty
            ? 'Counsel'
            : _handler.text.trim(),
        clientPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        nextHearingDate: _hearing,
        notes: _notes.text.trim().isEmpty
            ? const []
            : _notes.text.trim().split('\n'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case saved to your docket.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save case: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
