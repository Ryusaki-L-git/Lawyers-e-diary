import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/team_model.dart';
import '../../services/team_service.dart';
import '../../services/token_service.dart';
import '../../services/payments_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';
import '../../widgets/windows_desktop_ui.dart';

/// Displays separate prepaid balances for JURIS AI Credits and eCourts Case Tokens.
class TokenBalanceScreen extends StatefulWidget {
  const TokenBalanceScreen({super.key});

  @override
  State<TokenBalanceScreen> createState() => _TokenBalanceScreenState();
}

class _TokenBalanceScreenState extends State<TokenBalanceScreen> {
  final _service = TokenService();
  final _payments = PaymentsService();
  List<PaymentPack> _paymentPacks = const [];
  bool _loadingPaymentPacks = false;
  bool _checkoutBusy = false;
  String? _paymentError;
  String? _pendingPaymentReference;
  String? _pendingPaymentLabel;
  TokenBalance? _balance;
  bool _loading = true;
  String? _error;
  String _selectedPriority = 'personal_first';
  String? _selectedTeamId;
  Map<String, dynamic>? _teamPool;
  String? _preferenceError;
  bool _savingPreferences = false;
  bool _loadingPool = false;
  bool _savingAllocation = false;
  String? _selectedMemberUid;
  String? _allocationError;
  final _caseLimitController = TextEditingController();
  final _jurisLimitController = TextEditingController();
  final _storageLimitController = TextEditingController();
  late final Stream<List<TeamModel>> _teamsStream;

  @override
  void initState() {
    super.initState();
    _teamsStream = TeamService.instance.watchUserTeams();
    _loadBalance();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(_loadPaymentPacks());
    }
  }

  @override
  void dispose() {
    _service.dispose();
    _payments.dispose();
    _caseLimitController.dispose();
    _jurisLimitController.dispose();
    _storageLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balance = await _service.fetchBalance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }
    try {
      final preferences = await _service.fetchBillingPreferences();
      if (!mounted) return;
      setState(() {
        _selectedPriority = preferences.usageDeductionPriority;
        _selectedTeamId = preferences.preferredTeamId;
        _preferenceError = null;
      });
      if (preferences.preferredTeamId != null) {
        await _loadTeamPool(preferences.preferredTeamId!);
      } else if (mounted) {
        setState(() => _teamPool = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _preferenceError = e.toString());
    }
  }

  Future<void> _loadTeamPool(String teamId) async {
    setState(() {
      _loadingPool = true;
      _teamPool = null;
    });
    try {
      final pool = await _service.fetchTeamPool(teamId);
      if (!mounted) return;
      setState(() {
        _teamPool = pool;
        _loadingPool = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamPool = null;
        _loadingPool = false;
        _preferenceError = e.toString();
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _savingPreferences = true);
    try {
      final saved = await _service.saveBillingPreferences(
        usageDeductionPriority: _selectedPriority,
        preferredTeamId: _selectedTeamId,
      );
      if (!mounted) return;
      setState(() {
        _selectedPriority = saved.usageDeductionPriority;
        _selectedTeamId = saved.preferredTeamId;
        _preferenceError = null;
        _savingPreferences = false;
      });
      if (saved.preferredTeamId != null) {
        await _loadTeamPool(saved.preferredTeamId!);
      } else {
        setState(() => _teamPool = null);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing preference saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preferenceError = e.toString();
        _savingPreferences = false;
      });
    }
  }

  static double _minorToUnits(dynamic value) =>
      value is num ? value.toDouble() / 100.0 : 0.0;

  static String _formatStorage(dynamic value) {
    final bytes = value is num ? value.toDouble() : 0.0;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${bytes.toInt()} bytes';
  }

  Widget _buildTeamPoolPanel() {
    if (_selectedTeamId == null) {
      return const WindowsPanel(
        child: Text('Choose a team to view its shared pool and your allocation.'),
      );
    }
    if (_loadingPool) {
      return const WindowsPanel(
        child: Center(child: CircularProgressIndicator(color: AppPalette.primaryGreen)),
      );
    }
    final pool = _teamPool;
    if (pool == null) {
      return const SizedBox.shrink();
    }
    final shared = pool['shared'] is Map<String, dynamic>
        ? pool['shared'] as Map<String, dynamic>
        : <String, dynamic>{};
    final personal = pool['personal'] is Map<String, dynamic>
        ? pool['personal'] as Map<String, dynamic>
        : <String, dynamic>{};
    final allocation = pool['allocation'] is Map<String, dynamic>
        ? pool['allocation'] as Map<String, dynamic>
        : <String, dynamic>{};
    return WindowsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pool['teamName'] ?? 'Team'} · Shared pool',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Personal balances stay separate. Team charges also require available shared funds and your allocation.',
            style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
          const SizedBox(height: 14),
          _poolLine('Personal Case Tokens', _minorToUnits(personal['caseTokensMinorUnits']).toStringAsFixed(2)),
          _poolLine('Your team Case Token allocation left', _minorToUnits(allocation['caseTokenAvailableMinorUnits']).toStringAsFixed(2)),
          _poolLine('Shared team Case Token pool', _minorToUnits(shared['caseTokensMinorUnits']).toStringAsFixed(2)),
          const Divider(height: 22),
          _poolLine('Personal JURIS Credits', _minorToUnits(personal['jurisCreditsMinorUnits']).toStringAsFixed(2)),
          _poolLine('Your team JURIS allocation left', _minorToUnits(allocation['jurisCreditAvailableMinorUnits']).toStringAsFixed(2)),
          _poolLine('Shared team JURIS pool', _minorToUnits(shared['jurisCreditsMinorUnits']).toStringAsFixed(2)),
          const Divider(height: 22),
          _poolLine('Configured member storage limit', _formatStorage(allocation['storageLimitBytes'])),
          _poolLine('Configured shared storage limit', _formatStorage(shared['storageLimitBytes'])),
          const SizedBox(height: 8),
          const Text(
            'These are saved limits only. Shared file uploads and downloads are not enabled yet.',
            style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationEditor(Map<String, dynamic> pool) {
    if (pool['isManager'] != true || _selectedTeamId == null) {
      return const SizedBox.shrink();
    }
    return WindowsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Member allocation limits',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set each member’s monthly usage allowance. These limits do not add money to the shared pool.',
            style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<TeamMembership>>(
            stream: TeamService.instance.watchMembers(_selectedTeamId!),
            builder: (context, snapshot) {
              final members = (snapshot.data ?? const <TeamMembership>[])
                  .where((member) => member.isActive && member.hasFirebaseIdentity && member.userId.isNotEmpty)
                  .toList();
              final selected = members.any((member) => member.userId == _selectedMemberUid)
                  ? _selectedMemberUid
                  : null;
              return DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Team member',
                  border: OutlineInputBorder(),
                ),
                items: members.map((member) => DropdownMenuItem<String>(
                  value: member.userId,
                  child: Text(
                    member.displayName.isNotEmpty ? member.displayName : member.email.isNotEmpty ? member.email : member.userId,
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: _savingAllocation ? null : (uid) {
                  setState(() {
                    _selectedMemberUid = uid;
                    _allocationError = null;
                  });
                },
                hint: const Text('Choose an authorised team member'),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _caseLimitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly Case Token limit (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _jurisLimitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly JURIS Credit limit (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _storageLimitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Member storage limit (GB)', border: OutlineInputBorder()),
          ),
          if (_allocationError != null) ...[
            const SizedBox(height: 8),
            Text(_allocationError!, style: const TextStyle(color: AppPalette.statusDanger, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingAllocation ? null : _saveAllocation,
            icon: _savingAllocation
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.tune_rounded),
            label: const Text('Save member limits'),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.primaryGreen, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllocation() async {
    final teamId = _selectedTeamId;
    final memberUid = _selectedMemberUid;
    if (teamId == null || memberUid == null) {
      setState(() => _allocationError = 'Choose a team member first.');
      return;
    }
    double parse(String value, String label) {
      final parsed = double.tryParse(value.trim());
      if (parsed == null || !parsed.isFinite || parsed < 0) {
        throw FormatException('Enter a valid non-negative $label.');
      }
      return parsed;
    }
    setState(() {
      _savingAllocation = true;
      _allocationError = null;
    });
    try {
      final caseLimit = (parse(_caseLimitController.text, 'Case Token limit') * 100).round();
      final jurisLimit = (parse(_jurisLimitController.text, 'JURIS Credit limit') * 100).round();
      final storageBytes = (parse(_storageLimitController.text, 'storage limit') * 1024 * 1024 * 1024).round();
      await _service.saveTeamMemberAllocation(
        teamId: teamId,
        memberUid: memberUid,
        caseTokenLimitMinorUnits: caseLimit,
        jurisCreditLimitMinorUnits: jurisLimit,
        storageLimitBytes: storageBytes,
      );
      if (!mounted) return;
      setState(() => _savingAllocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member allocation limits saved.')),
      );
      await _loadTeamPool(teamId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingAllocation = false;
        _allocationError = error is FormatException
            ? error.message.toString()
            : error.toString();
      });
    }
  }

  Future<void> _loadPaymentPacks() async {
    if (!mounted) return;
    setState(() {
      _loadingPaymentPacks = true;
      _paymentError = null;
    });
    try {
      final packs = await _payments.fetchPacks();
      if (!mounted) return;
      setState(() {
        _paymentPacks = packs;
        _loadingPaymentPacks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentError = error.toString();
        _loadingPaymentPacks = false;
      });
    }
  }

  Future<void> _buyPack(PaymentPack pack) async {
    if (_checkoutBusy) return;
    setState(() {
      _checkoutBusy = true;
      _paymentError = null;
    });
    try {
      final link = await _payments.createHostedLink(pack.id);
      if (!mounted) return;
      setState(() {
        _pendingPaymentReference = link.referenceId;
        _pendingPaymentLabel = pack.label;
      });
      await _payments.openCheckout(link.shortUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secure checkout opened. Complete payment in your browser, then check its status here.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _paymentError = error.toString());
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  Future<void> _checkPendingPayment() async {
    final reference = _pendingPaymentReference;
    if (reference == null || _checkoutBusy) return;
    setState(() {
      _checkoutBusy = true;
      _paymentError = null;
    });
    try {
      final result = await _payments.getHostedLinkStatus(reference);
      if (!mounted) return;
      if (result.status == 'paid') {
        setState(() {
          _pendingPaymentReference = null;
          _pendingPaymentLabel = null;
        });
        await _loadBalance();
        if (!mounted) return;
        final balanceName = result.tokenType == 'case'
            ? 'Case Tokens'
            : 'JURIS Credits';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.creditedUnits} ${balanceName} added after server confirmation.'),
          ),
        );
      } else {
        setState(() {
          _paymentError = 'Payment is not confirmed yet. Your balance has not changed; check again after checkout completes.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _paymentError = error.toString());
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  Widget _buildTopUpPanel() {
    return WindowsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top up balances',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Windows checkout uses a secure hosted payment page. LED adds funds only after the signed payment webhook confirms the transaction.',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingPaymentPacks)
            const WindowsLoadingPanel(label: 'Loading top-up options')
          else if (_paymentPacks.isEmpty)
            const Text(
              'Top-up options are unavailable until the LED payment service is configured.',
              style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
            )
          else ...[
            for (final type in const ['juris', 'case']) ...[
              Text(
                type == 'juris' ? 'JURIS Credits' : 'eCourts Case Tokens',
                style: const TextStyle(
                  color: AppPalette.primaryGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentPacks
                    .where((pack) => pack.tokenType == type)
                    .map(
                      (pack) => OutlinedButton(
                        onPressed: _checkoutBusy || _pendingPaymentReference != null
                            ? null
                            : () => _buyPack(pack),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.primaryGreen,
                          side: const BorderSide(color: AppPalette.borderLight),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                        ),
                        child: Text('${pack.label} · ${pack.amountLabel}'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
          ],
          if (_pendingPaymentReference != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Awaiting confirmation: ${_pendingPaymentLabel ?? 'checkout'}',
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _checkoutBusy ? null : _checkPendingPayment,
                  icon: _checkoutBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Check status'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (_paymentError != null)
            Text(
              _paymentError!,
              style: const TextStyle(
                color: AppPalette.statusDanger,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _poolLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppPalette.textMuted))),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppPalette.textPrimary)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: PlatformAppBar(
        title: 'Balances',
        eyebrow: 'SERVICE ACCOUNT',
        subtitle: 'Separate balances for JURIS AI and eCourts services.',
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        actions: [
          IconButton(
            onPressed: _loadBalance,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh balance',
            color: AppPalette.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppPalette.primaryGreen,
                  ),
                )
              else if (_error != null)
                WindowsMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your balance',
                  message: _error!,
                  isError: true,
                  action: FilledButton.icon(
                    onPressed: _loadBalance,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else if (_balance != null) ...[
                WindowsPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available JURIS Credits',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _balance!.creditsDisplay,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1 Credit = ₹1 · Usage-based Gemini AI billing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                WindowsPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available eCourts Case Tokens',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _balance!.caseTokensDisplay,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1 Case Token = ₹1 · eCourts/provider services',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                WindowsPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet deduction priority',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose which balance LED should use first. The other eligible wallet is used only if the first one cannot cover the charge.',
                        style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
                      ),
                      RadioGroup<String>(
                        groupValue: _selectedPriority,
                        onChanged: (value) {
                          if (_savingPreferences || value == null) return;
                          setState(() => _selectedPriority = value);
                        },
                        child: const Column(
                          children: [
                            RadioListTile<String>(
                              value: 'personal_first',
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppPalette.primaryGreen,
                              title: Text('Personal balance first'),
                              subtitle: Text('Use your own wallet before your team allocation.'),
                            ),
                            RadioListTile<String>(
                              value: 'team_first',
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppPalette.primaryGreen,
                              title: Text('Team allocation first'),
                              subtitle: Text('Use the selected team allocation before your personal wallet.'),
                            ),
                            RadioListTile<String>(
                              value: 'ask',
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppPalette.primaryGreen,
                              title: Text('Ask before each charge'),
                              subtitle: Text('Choose personal or team Credits for each AI request.'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<TeamModel>>(
                        stream: _teamsStream,
                        builder: (context, snapshot) {
                          final teams = snapshot.data ?? const <TeamModel>[];
                          final selected = teams.any((team) => team.id == _selectedTeamId)
                              ? _selectedTeamId
                              : null;
                          return DropdownButtonFormField<String>(
                            initialValue: selected,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Team pool to use',
                              border: OutlineInputBorder(),
                            ),
                            items: teams.map((team) => DropdownMenuItem<String>(
                              value: team.id,
                              child: Text(team.name, overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: _savingPreferences ? null : (value) {
                              setState(() {
                                _selectedTeamId = value;
                                _teamPool = null;
                              });
                              if (value != null) _loadTeamPool(value);
                            },
                            hint: const Text('Select an authorised team'),
                          );
                        },
                      ),
                      if (_preferenceError != null) ...[
                        const SizedBox(height: 8),
                        Text(_preferenceError!, style: const TextStyle(color: AppPalette.statusDanger, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _savingPreferences ? null : _savePreferences,
                          icon: _savingPreferences
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save deduction preference'),
                          style: FilledButton.styleFrom(backgroundColor: AppPalette.primaryGreen, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTeamPoolPanel(),
                const SizedBox(height: 16),
                if (_teamPool != null) _buildAllocationEditor(_teamPool!),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/usage_history'),
                  icon: const Icon(Icons.history),
                  label: const Text('View usage history'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                  ),
                ),
              ] else
                const WindowsMessageState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No balances yet',
                  message: 'Credits and Case Tokens appear here once your account has a balance.',
                ),
              if (defaultTargetPlatform == TargetPlatform.windows) ...[
                const SizedBox(height: 16),
                _buildTopUpPanel(),
              ],
              const SizedBox(height: 24),
              const Text(
                'Credits are for JURIS AI; Case Tokens are for eCourts. The balances are separate and cannot be exchanged.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
