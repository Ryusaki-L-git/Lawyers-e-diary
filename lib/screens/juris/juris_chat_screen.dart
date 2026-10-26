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
  String _sessionId = _newSessionId();

  static String _newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';
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
  String? _balanceError;

  static const _models = <String, String>{
    'gemini-3.8-flash': 'Gemini 3.8',
    'gemini-3.5-flash-lite': 'Gemini 3.5 Lite',
    'gemini-2.5-flash-lite': 'Gemini 2.5 Lite',
    'gemini-2.5-flash': 'Gemini 2.5',
  };

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loadingBalance = true;
      _balanceError = null;
    });
    try {
      final balance = await _tokenService.fetchBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        _balance = balance;
        _loadingBalance = false;
        _balanceError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBalance = false;
        _balanceError = 'Could not load token balance.';
      });
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
    if (_busy || _pendingConfirmation != null) {
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
    await _sendToJuris(message: message);
  }

  Future<void> _sendToJuris({
    required String message,
    List<String>? confirmedActionIds,
  }) async {
    try {
      final result = await _service.sendMessage(
        message: message,
        sessionId: _sessionId,
        confirmedActionIds: confirmedActionIds,
        model: _selectedModel,
      );
      if (!mounted) {
        return;
      }
      setState(() => _pendingConfirmation = null);
      if (result.status == 'confirmation_required') {
        final sa = result.suggestedAction;
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
        _entries.add(
          _ChatEntry(false, 'I could not complete that request. $error'),
        );
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
    await _sendToJuris(message: pc.message, confirmedActionIds: [pc.actionId]);
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
        actions: [
          IconButton(
            tooltip: 'New conversation',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _sessionId = _newSessionId();
                    _pendingConfirmation = null;
                    _entries
                      ..clear()
                      ..add(
                        const _ChatEntry(
                          false,
                          'New conversation. Ask a legal research or case-analysis question. Verify important conclusions against original sources.',
                        ),
                      );
                  }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
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
            // Case Token balance and model selector
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
                        : _balanceError != null
                        ? 'Tokens unavailable'
                        : (_balance != null
                              ? 'Case Tokens: ${_balance!.caseTokensDisplay}'
                              : 'Case Tokens: --'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _balanceError == null
                          ? AppPalette.textPrimary
                          : Colors.red.shade700,
                    ),
                  ),
                  if (_balanceError != null)
                    IconButton(
                      tooltip: 'Retry token balance',
                      onPressed: _loadingBalance ? null : _loadBalance,
                      icon: const Icon(Icons.refresh, size: 18),
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
                      enabled: _pendingConfirmation == null,
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
                    onPressed: _busy || _pendingConfirmation != null ? null : _send,
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
          const Text(
            'JURIS proposes to execute a write action. Review before approving.',
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
            child: Column(
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
                child: const Text('Approve'),
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
  });
  final String message;
  final String actionId;
  final String tool;
  final Map<String, dynamic> arguments;
}
