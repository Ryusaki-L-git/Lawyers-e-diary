import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/juris_service.dart';
import '../../services/token_service.dart';
import '../../widgets/app_palette.dart';

class JurisChatScreen extends StatefulWidget {
  const JurisChatScreen({super.key});
  @override
  State<JurisChatScreen> createState() => _JurisChatScreenState();
}

class _JurisChatScreenState extends State<JurisChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _service = JurisService();
  final _tokenService = TokenService();
  final _sessionId = _createSessionId();
  final List<_ChatEntry> _entries = [
    const _ChatEntry(
      false,
      'I am JURIS, the legal AI assistant for Lawyer’s E-Diary. I can help with research and analysis when the configured backend and authorized sources are available. Please verify important legal conclusions against the original sources.',
    ),
  ];
  bool _busy = false;
  _PendingConfirmation? _pendingConfirmation;
  TokenBalance? _balance;
  String? _selectedModel = 'gemini-3.8-flash';
  bool _loadingBalance = false;

  static const _models = <String, String>{
    'gemini-3.8-flash': 'Gemini 3.8',
    'gemini-3.1-flash-lite': 'Gemini 3.1 Lite',
    'gemini-2.5-flash-lite': 'Gemini 2.5 Lite',
    'gemini-2.5-flash': 'Gemini 2.5',
  };

  static String _createSessionId() {
    final random = math.Random.secure();
    final hex = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _loadingBalance = true);
    try {
      final balance = await _tokenService.fetchBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        _balance = balance;
        _loadingBalance = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingBalance = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _service.dispose();
    _tokenService.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    final message = _controller.text.trim();
    if (message.isEmpty) {
      return;
    }
    setState(() {
      _entries.add(_ChatEntry(true, message));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();
    String? billingSource;
    try {
      final preferences = await _tokenService.fetchBillingPreferences();
      if (preferences.usageDeductionPriority == 'ask' &&
          preferences.preferredTeamId != null) {
        billingSource = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Choose a balance'),
            content: const Text(
              'Choose the wallet before JURIS estimates usage. Personal Credits and team allocation remain separate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('personal'),
                child: const Text('Personal JURIS Credits'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('team'),
                child: const Text('Team allocation'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (billingSource == null) {
          setState(() {
            _entries.add(const _ChatEntry(
              false,
              'No balance was selected, so I did not run the AI request.',
            ));
            _busy = false;
          });
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries.add(const _ChatEntry(
          false,
          'I could not verify your billing preference. No AI request was sent; please retry.',
        ));
        _busy = false;
      });
      return;
    }
    await _sendToJuris(message: message, billingSource: billingSource);
  }

  Future<void> _sendToJuris({
    required String message,
    List<String>? confirmedActionIds,
    String? billingConfirmationToken,
    String? billingSource,
  }) async {
    try {
      final result = await _service.sendMessage(
        message: message,
        sessionId: _sessionId,
        confirmedActionIds: confirmedActionIds,
        selectedModel: _selectedModel,
        billingConfirmationToken: billingConfirmationToken,
        billingSource: billingSource,
      );
      if (!mounted) {
        return;
      }
      setState(() => _pendingConfirmation = null);
      if (result.status != 'confirmation_required') {
        unawaited(_loadBalance());
      }
      if (result.status == 'billing_source_required') {
        // A server-side preference change can race the preflight read. The
        // prior quote may already have been consumed, so select the wallet
        // and request a fresh estimate rather than reusing that quote token.
        final selectedSource = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Choose a balance'),
            content: const Text(
              'Choose which wallet should pay. JURIS will show a fresh estimate before any AI work starts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('personal'),
                child: const Text('Personal JURIS Credits'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('team'),
                child: const Text('Team allocation'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (selectedSource == null) {
          setState(() => _entries.add(const _ChatEntry(
            false,
            'No balance was selected, so I did not run the AI request.',
          )));
          return;
        }
        await _sendToJuris(
          message: message,
          confirmedActionIds: confirmedActionIds,
          billingSource: selectedSource,
        );
        return;
      }
      if (result.status == 'confirmation_required') {
        final sa = result.suggestedAction;
        if (sa != null && sa['type'] == 'confirm_ai_usage') {
          final quoteToken = sa['quote_token'] as String?;
          final credits = sa['max_credits'] is num
              ? (sa['max_credits'] as num).toDouble()
              : (sa['estimated_credits'] is num
                    ? (sa['estimated_credits'] as num).toDouble()
                    : 0.0);
          if (quoteToken != null && quoteToken.isNotEmpty) {
            setState(() {
              _pendingConfirmation = _PendingConfirmation(
                message: message,
                actionId: '',
                tool: 'JURIS AI usage',
                arguments: const <String, dynamic>{},
                billingQuoteToken: quoteToken,
                estimatedCredits: credits,
                confirmedActionIds: confirmedActionIds ?? const <String>[],
                billingSource: billingSource,
              );
            });
            return;
          }
        }
        if (sa != null && sa['type'] == 'confirm_action') {
          final actionId = sa['action_id'] as String?;
          final tool = sa['tool'] as String?;
          final args = sa['arguments'];
          if (actionId != null && tool != null) {
            setState(() {
              _pendingConfirmation = _PendingConfirmation(
                message: message,
                actionId: actionId,
                tool: tool,
                arguments: args is Map<String, dynamic>
                    ? Map<String, dynamic>.from(args)
                    : <String, dynamic>{},
                billingSource: billingSource,
              );
            });
            return;
          }
        }
        setState(() => _entries.add(_ChatEntry(false, result.reply)));
      } else {
        setState(() => _entries.add(_ChatEntry(false, result.reply)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingConfirmation = null;
        final message = error is JurisServiceException
            ? error.message
            : 'JURIS could not complete that request. Please try again.';
        _entries.add(_ChatEntry(false, message));
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _approveConfirmation() async {
    if (_busy || _pendingConfirmation == null) {
      return;
    }
    final pc = _pendingConfirmation!;
    setState(() => _busy = true);
    if (pc.billingQuoteToken != null) {
      await _sendToJuris(
        message: pc.message,
        confirmedActionIds: pc.confirmedActionIds,
        billingConfirmationToken: pc.billingQuoteToken,
        billingSource: pc.billingSource,
      );
    } else {
      await _sendToJuris(
        message: pc.message,
        confirmedActionIds: [pc.actionId],
        billingSource: pc.billingSource,
      );
    }
  }

  void _cancelConfirmation() {
    if (_busy) {
      return;
    }
    setState(() => _pendingConfirmation = null);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatArgs(Map<String, dynamic> args) {
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.balance_rounded, color: AppPalette.accentGold),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JURIS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Legal intelligence',
                  style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.borderLight),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 19,
                    color: AppPalette.primaryGreen,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use verified sources for legal research. Do not treat AI output as a substitute for checking the original law or judgment.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // JURIS Credit balance and model selector
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.borderLight),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.token_rounded,
                    size: 18,
                    color: AppPalette.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _loadingBalance
                        ? 'Loading...'
                        : (_balance != null
                              ? 'JURIS Credits: ${_balance!.creditsDisplay}'
                              : 'JURIS Credits: --'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _selectedModel,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: _models.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedModel = v),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.history, size: 18),
                    tooltip: 'Usage history',
                    onPressed: () =>
                        Navigator.pushNamed(context, '/usage_history'),
                  ),
                ],
              ),
            ),
            if (_pendingConfirmation != null) _buildConfirmationCard(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount:
                    _entries.length +
                    (_busy && _pendingConfirmation == null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_busy &&
                      _pendingConfirmation == null &&
                      index == _entries.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (index == _entries.length) return const SizedBox.shrink();
                  final entry = _entries[index];
                  return Align(
                    alignment: entry.user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: entry.user
                            ? AppPalette.primaryGreen
                            : AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: entry.user
                            ? null
                            : Border.all(color: AppPalette.borderLight),
                      ),
                      child: SelectableText(
                        entry.text,
                        style: TextStyle(
                          height: 1.4,
                          color: entry.user
                              ? Colors.white
                              : AppPalette.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: AppPalette.cardBackground,
                border: Border(top: BorderSide(color: AppPalette.borderLight)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Ask JURIS…',
                        filled: true,
                        fillColor: AppPalette.canvas,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppPalette.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: 'Send to JURIS',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard() {
    final pc = _pendingConfirmation!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.accentGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppPalette.accentGold,
              ),
              SizedBox(width: 8),
              Text(
                'Confirmation required',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pc.billingQuoteToken != null
                ? 'JURIS has estimated the maximum Credit budget for this request. No AI work starts until you continue.'
                : 'JURIS proposes to execute a write action. Review before approving.',
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppPalette.borderLight),
            ),
            child: pc.billingQuoteToken != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated maximum charge',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(pc.estimatedCredits ?? 0).toStringAsFixed(2)} JURIS Credits',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The final charge is based on actual reported usage and will not exceed this approved budget. The estimate expires after 5 minutes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tool: ${pc.tool}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Action ID: ${pc.actionId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Arguments:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _formatArgs(pc.arguments),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _cancelConfirmation,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _busy ? null : _approveConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text(pc.billingQuoteToken != null ? 'Continue' : 'Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatEntry {
  const _ChatEntry(this.user, this.text);
  final bool user;
  final String text;
}

class _PendingConfirmation {
  const _PendingConfirmation({
    required this.message,
    required this.actionId,
    required this.tool,
    required this.arguments,
    this.billingQuoteToken,
    this.estimatedCredits,
    this.confirmedActionIds = const <String>[],
    this.billingSource,
  });
  final String message;
  final String actionId;
  final String tool;
  final Map<String, dynamic> arguments;
  final String? billingQuoteToken;
  final double? estimatedCredits;
  final List<String> confirmedActionIds;
  final String? billingSource;
}
