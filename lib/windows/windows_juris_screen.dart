import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/juris_service.dart';
import '../services/token_service.dart';
import '../widgets/app_palette.dart';

class WindowsJurisScreen extends StatefulWidget {
  const WindowsJurisScreen({super.key, this.caseId, this.caseTitle});
  final String? caseId;
  final String? caseTitle;
  @override
  State<WindowsJurisScreen> createState() => _WindowsJurisScreenState();
}

class _WindowsJurisScreenState extends State<WindowsJurisScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _service = JurisService();
  final _tokenService = TokenService();
  final List<_JurisConversation> _history = [];
  bool _historyLoaded = false;
  String? _currentTitle;
  late String? _activeCaseId = widget.caseId;
  late String? _activeCaseTitle = widget.caseTitle;
  // The session id identifies this conversation with the JURIS backend. It is
  // regenerated whenever the user starts a new conversation so the backend
  // does not continue the previous thread.
  String _sessionId = _newSessionId();
  final List<_JurisMessage> _messages = [
    const _JurisMessage(
      false,
      'Welcome to JURIS. Ask a legal research or case-analysis question. Verify important conclusions against the original statute, judgment, and official source.',
    ),
  ];
  bool _busy = false;
  _PendingConfirmation? _pendingConfirmation;
  TokenBalance? _balance;
  bool _loadingBalance = false;
  String? _balanceError;

  static String _newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadHistory();
  }

  String get _historyKey => 'led_juris_history_v1_${FirebaseAuth.instance.currentUser?.uid ?? 'signed_out'}';
  Future<void> _loadHistory() async {
    try { final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString(_historyKey); if (raw != null && raw.isNotEmpty) { final decoded = jsonDecode(raw); if (decoded is List) { _history..clear()..addAll(decoded.whereType<Map>().map((item) => _JurisConversation.fromJson(Map<String, dynamic>.from(item)))); } } } catch (_) {}
    if (mounted) setState(() => _historyLoaded = true);
  }
  Future<void> _persistCurrentConversation() async {
    final prompts = _messages.where((m) => m.user); if (prompts.isEmpty) return;
    final title = (_currentTitle ?? prompts.first.text).trim();
    final item = _JurisConversation(id: _sessionId, title: title.isEmpty ? 'Legal research' : title, updatedAt: DateTime.now().toIso8601String(), messages: _messages.map((m) => _JurisStoredMessage(m.user, m.text)).toList(), caseId: widget.caseId, caseTitle: widget.caseTitle);
    final index = _history.indexWhere((entry) => entry.id == _sessionId); if (index >= 0) { _history[index] = item; } else { _history.insert(0, item); }
    _history.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); if (_history.length > 40) _history.removeRange(40, _history.length);
    try { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_historyKey, jsonEncode(_history.map((entry) => entry.toJson()).toList())); } catch (_) {}
    if (mounted) setState(() {});
  }
  Future<void> _startNewConversation() async {
    if (_busy) return; await _persistCurrentConversation(); if (!mounted) return;
    setState(() { _sessionId = _newSessionId(); _currentTitle = null; _pendingConfirmation = null; _messages..clear()..add(const _JurisMessage(false, 'Welcome to JURIS. Ask a legal research or case-analysis question. Verify important conclusions against the original statute, judgment, and official source.')); });
  }
  Future<void> _openConversation(_JurisConversation item) async {
    if (_busy) return; await _persistCurrentConversation(); if (!mounted) return;
    setState(() { _sessionId = item.id; _currentTitle = item.title; _pendingConfirmation = null; _messages..clear()..addAll(item.messages.map((m) => _JurisMessage(m.user, m.text))); }); _scrollEnd();
  }
  Future<void> _showHistoryDialog() async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: AppPalette.cardBackground,
      title: const Text('Recent JURIS conversations'),
      content: SizedBox(width: 420, height: 460, child: _history.isEmpty
        ? const Center(child: Text('Your conversations will appear here as you research.'))
        : ListView.separated(itemCount: _history.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
            final item = _history[index];
            return ListTile(leading: const Icon(Icons.forum_outlined, color: AppPalette.primaryGreen), title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${item.messages.where((m) => m.user).length} prompts'), onTap: () { Navigator.of(dialogContext).pop(); _openConversation(item); }, trailing: IconButton(tooltip: 'Delete conversation', icon: const Icon(Icons.delete_outline_rounded), onPressed: () { Navigator.of(dialogContext).pop(); _deleteConversation(item); }));
          })),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
    ));
  }

  Future<void> _deleteConversation(_JurisConversation item) async {
    _history.removeWhere((entry) => entry.id == item.id);
    try { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_historyKey, jsonEncode(_history.map((entry) => entry.toJson()).toList())); } catch (_) {}
    if (item.id == _sessionId) { setState(() { _sessionId = _newSessionId(); _currentTitle = null; _pendingConfirmation = null; _messages..clear()..add(const _JurisMessage(false, 'Welcome to JURIS. Start a new legal research conversation.')); }); } else if (mounted) { setState(() {}); }
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loadingBalance = true;
      _balanceError = null;
    });
    try {
      final balance = await _tokenService.fetchBalance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _balanceError = null;
      });
    } catch (_) {
      // The balance is unavailable. The reason is reported in the header
      // rather than being swallowed, so the user is never left with a
      // silent "Case Tokens: --".
      if (!mounted) return;
      setState(() {
        _balanceError = 'The case token balance could not be loaded.';
      });
    }
    if (mounted) setState(() => _loadingBalance = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _service.dispose();
    _tokenService.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _sendPrompt(text);
  }

  /// Sends [text] as a user message without requiring the composer to be
  /// pre-filled. Used by the suggestion prompts, which previously invoked
  /// [_send] with an empty composer and therefore sent nothing.
  Future<void> _sendPrompt(String text) async {
    if (_busy) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(_JurisMessage(true, trimmed));
      _currentTitle ??= trimmed.length > 54 ? '${trimmed.substring(0, 51)}…' : trimmed;
      _busy = true;
      _controller.clear();
    });
    _scrollEnd();
    try {
      final response = await _service.sendMessage(
        message: trimmed,
        sessionId: _sessionId,
        activeCaseId: _activeCaseId,
        activeCaseTitle: _activeCaseTitle,
      );
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      if (response.status == 'confirmation_required') {
        final sa = response.suggestedAction;
        if (sa != null && sa['type'] == 'confirm_action') {
          final actionId = sa['action_id'] as String?;
          final tool = sa['tool'] as String?;
          final args = sa['arguments'];
          if (actionId != null && tool != null) {
            setState(
              () => _pendingConfirmation = _PendingConfirmation(
                message: trimmed,
                actionId: actionId,
                tool: tool,
                arguments: args is Map<String, dynamic>
                    ? Map<String, dynamic>.from(args)
                    : <String, dynamic>{},
              ),
            );
            _scrollEnd();
            return;
          }
        }
        setState(() => _messages.add(_JurisMessage(false, response.reply)));
      } else {
        setState(() => _messages.add(_JurisMessage(false, response.reply)));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _messages.add(
            _JurisMessage(false, 'I could not complete that request. $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollEnd();
        await _persistCurrentConversation();
      }
    }
  }

  Future<void> _approveConfirmation() async {
    if (_busy || _pendingConfirmation == null) return;
    final pc = _pendingConfirmation!;
    setState(() => _busy = true);
    try {
      final response = await _service.sendMessage(
        message: pc.message,
        sessionId: _sessionId,
        activeCaseId: widget.caseId,
        activeCaseTitle: widget.caseTitle,
        confirmedActionIds: [pc.actionId],
      );
      if (mounted) setState(() => _pendingConfirmation = null);
      if (!mounted) return;
      setState(() => _messages.add(_JurisMessage(false, response.reply)));
    } catch (e) {
      if (mounted) {
        setState(
          () => _messages.add(
            _JurisMessage(false, 'I could not complete that request. $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollEnd();
        await _persistCurrentConversation();
      }
    }
  }

  void _cancelConfirmation() {
    if (_busy) return;
    setState(() => _pendingConfirmation = null);
  }

  void _scrollEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppPalette.primaryGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.balance_rounded,
                    color: AppPalette.accentGold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LEGAL INTELLIGENCE',
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'JURIS',
                        style: TextStyle(
                          fontFamily: AppTypography.heading,
                          color: AppPalette.primaryGreen,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        widget.caseId == null
                            ? 'Research and reasoning for your legal workflow.'
                            : 'Case context attached: ${widget.caseTitle ?? 'Selected case'}',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Case Token balance display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _balanceError == null
                        ? AppPalette.canvas
                        : AppPalette.errorFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _balanceError == null
                          ? AppPalette.borderLight
                          : AppPalette.statusDanger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token_rounded,
                        color: _balanceError == null
                            ? AppPalette.accentGold
                            : AppPalette.statusDanger,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _loadingBalance
                            ? 'Loading...'
                            : _balanceError != null
                            ? 'Tokens unavailable'
                            : (_balance != null
                                  ? 'Case Tokens: ${_balance!.caseTokensDisplay}'
                                  : 'Case Tokens: --'),
                        style: TextStyle(
                          color: _balanceError == null
                              ? AppPalette.textPrimary
                              : AppPalette.statusDangerDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_balanceError != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _loadBalance,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: AppPalette.statusDangerDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                IconButton(
                  tooltip: 'Recent conversations',
                  onPressed: _busy ? null : _showHistoryDialog,
                  icon: const Icon(Icons.history_rounded),
                  color: AppPalette.primaryGreen,
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _startNewConversation,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New conversation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.primaryGreen,
                    side: const BorderSide(color: AppPalette.borderLight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppPalette.statusTile,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.tileBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: AppPalette.primaryGreen,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Legal accuracy matters. Confirm citations and legal propositions against official sources. JURIS responses are assistance, not a replacement for professional judgment.',
                      style: TextStyle(
                        color: AppPalette.primaryGreen,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The suggestion rail and the confirmation card are fixed
                  // width, so on a narrow window they would squeeze the
                  // conversation down to an unreadable column. The rail
                  // moves underneath the conversation and the confirmation
                  // card spans the full width instead.
                  final width = constraints.maxWidth;
                  final showRail = width >= 780;
                  final showHistory = width >= 1200;
                  final railWidth = width >= 1040 ? 250.0 : 220.0;

                  return Column(
                    children: [
                      if (_pendingConfirmation != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _confirmationCard(
                            fullWidth: !showRail,
                          ),
                        ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showHistory) ...[
                              SizedBox(width: 220, child: _historyPanel()),
                              const SizedBox(width: 14),
                            ],
                            Expanded(flex: 7, child: _chatPanel()),
                            if (showRail) ...[
                              const SizedBox(width: 16),
                              SizedBox(
                                width: railWidth,
                                child: _suggestionRail(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!showRail) ...[
                        const SizedBox(height: 14),
                        SizedBox(height: 132, child: _suggestionStrip()),
                      ],
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

  Widget _historyPanel() => Container(
    decoration: BoxDecoration(color: AppPalette.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppPalette.borderLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 14, 8, 10), child: Row(children: [const Expanded(child: Text('RECENT HISTORY', style: TextStyle(color: AppPalette.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1))), IconButton(tooltip: 'New conversation', visualDensity: VisualDensity.compact, onPressed: _busy ? null : _startNewConversation, icon: const Icon(Icons.add_rounded, size: 19))])),
      const Divider(height: 1, color: AppPalette.borderLight),
      Expanded(child: !_historyLoaded ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : _history.isEmpty ? const Padding(padding: EdgeInsets.all(15), child: Text('Your conversations will appear here as you research.', style: TextStyle(color: AppPalette.textMuted, fontSize: 11, height: 1.5))) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _history.length, itemBuilder: (context, index) {
        final item = _history[index]; final selected = item.id == _sessionId;
        return Padding(padding: const EdgeInsets.only(bottom: 5), child: Material(color: selected ? AppPalette.statusTile : Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: _busy ? null : () => _openConversation(item), child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 4, 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.forum_outlined, size: 16, color: selected ? AppPalette.primaryGreen : AppPalette.textMuted), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppPalette.textPrimary, fontSize: 11, height: 1.35, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)), const SizedBox(height: 4), Text('${item.messages.where((m) => m.user).length} prompts', style: const TextStyle(color: AppPalette.textMuted, fontSize: 9))])),
          PopupMenuButton<String>(tooltip: 'Conversation options', padding: EdgeInsets.zero, iconSize: 16, onSelected: (value) { if (value == 'delete') _deleteConversation(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete history'))]),
        ])))));
      })),
    ]),
  );

  /// The conversation panel: the transcript and the composer.
  Widget _chatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(22),
              itemCount: _messages.length + (_busy ? 1 : 0),
              itemBuilder: (context, index) {
                if (_busy && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.accentGold,
                        ),
                      ),
                    ),
                  );
                }
                final m = _messages[index];
                return Align(
                  alignment: m.user
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 13),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: m.user
                            ? AppPalette.primaryGreen
                            : AppPalette.canvas,
                        borderRadius: BorderRadius.circular(13),
                        border: m.user
                            ? null
                            : Border.all(color: AppPalette.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.user ? 'YOU' : 'JURIS',
                            style: TextStyle(
                              color: m.user
                                  ? AppPalette.accentGold
                                  : AppPalette.primaryGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            m.text,
                            style: TextStyle(
                              color: m.user
                                  ? Colors.white
                                  : AppPalette.textPrimary,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
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
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask JURIS about a legal issue…',
                      filled: true,
                      fillColor: AppPalette.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppPalette.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppPalette.borderLight,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy ? null : () => _send(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryGreen,
                    padding: const EdgeInsets.all(17),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The task rail shown beside the conversation on a wide window.
  Widget _suggestionRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'START WITH A TASK',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in _suggestionEntries)
          _suggestion(
            entry.$1,
            entry.$2,
            entry.$3,
            () => _sendPrompt(entry.$4),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.cardBackground,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppPalette.borderLight),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: AppPalette.accentGold,
                size: 22,
              ),
              SizedBox(height: 10),
              Text(
                'Accuracy over fluency',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Check case names, citations, dates and current legal status against primary sources.',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The task rail shown underneath the conversation on a narrow window.
  Widget _suggestionStrip() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _suggestionEntries.length,
      separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (context, index) {
        final entry = _suggestionEntries[index];
        return SizedBox(
          width: 236,
          child: _suggestion(
            entry.$1,
            entry.$2,
            entry.$3,
            () => _sendPrompt(entry.$4),
          ),
        );
      },
    );
  }

  /// The starting tasks offered on the workspace.
  ///
  /// Each entry carries the prompt that is sent, so the suggestion and the
  /// message it produces can never drift apart.
  List<(IconData, String, String, String)> get _suggestionEntries => [
    (
      Icons.policy_outlined,
      'Research a legal issue',
      'Summarize the legal framework and identify official sources to verify.',
      'Summarize the legal framework for this issue and identify the official sources I should verify.',
    ),
    (
      Icons.account_balance_outlined,
      'Analyze a judgment',
      'Extract the holding, reasoning, and issues that need verification.',
      'Analyze this judgment: extract the holding, the reasoning, and the issues that need verification.',
    ),
    (
      Icons.edit_document,
      'Structure a draft',
      'Create an outline from facts and relief sought, flagging missing information.',
      'Structure a draft outline from the facts and the relief sought, and flag the information that is missing.',
    ),
  ];

  Widget _confirmationCard({bool fullWidth = false}) {
    final pc = _pendingConfirmation!;
    return SizedBox(
      width: fullWidth ? double.infinity : 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIRMATION REQUIRED',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.cardBackground,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppPalette.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppPalette.statusWarning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Confirmation required',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'JURIS proposes to execute a write action. Review before approving.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tool: ${pc.tool}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Action ID: ${pc.actionId}',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Arguments:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _formatArgs(pc.arguments),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
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
          ),
        ],
      ),
    );
  }

  String _formatArgs(Map<String, dynamic> args) {
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }

  Widget _suggestion(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: AppPalette.cardBackground,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppPalette.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppPalette.accentGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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

class _JurisMessage {
  const _JurisMessage(this.user, this.text);
  final bool user;
  final String text;
}

class _JurisStoredMessage {
  const _JurisStoredMessage(this.user, this.text);
  final bool user; final String text;
  Map<String, dynamic> toJson() => {'user': user, 'text': text};
  factory _JurisStoredMessage.fromJson(Map<String, dynamic> json) => _JurisStoredMessage(json['user'] == true, json['text'] as String? ?? '');
}
class _JurisConversation {
  const _JurisConversation({required this.id, required this.title, required this.updatedAt, required this.messages, this.caseId, this.caseTitle});
  final String id; final String title; final String updatedAt; final List<_JurisStoredMessage> messages; final String? caseId; final String? caseTitle;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'updatedAt': updatedAt, 'messages': messages.map((m) => m.toJson()).toList(), if (caseId != null) 'caseId': caseId, if (caseTitle != null) 'caseTitle': caseTitle};
  factory _JurisConversation.fromJson(Map<String, dynamic> json) { final raw = json['messages']; return _JurisConversation(id: json['id'] as String? ?? '', title: json['title'] as String? ?? 'Legal research', updatedAt: json['updatedAt'] as String? ?? '', messages: raw is List ? raw.whereType<Map>().map((m) => _JurisStoredMessage.fromJson(Map<String, dynamic>.from(m))).toList() : const [], caseId: json['caseId'] as String?, caseTitle: json['caseTitle'] as String?); }
}

