import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      _busy = true;
      _controller.clear();
    });
    _scrollEnd();
    try {
      final response = await _service.sendMessage(
        message: trimmed,
        sessionId: _sessionId,
        activeCaseId: widget.caseId,
        activeCaseTitle: widget.caseTitle,
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
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sessionId = _newSessionId();
                          _pendingConfirmation = null;
                          _messages
                            ..clear()
                            ..add(
                              const _JurisMessage(
                                false,
                                'New conversation. Ask a legal research or case-analysis question. Verify important conclusions against original sources.',
                              ),
                            );
                        }),
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
                  final railWidth = width >= 1040 ? 270.0 : 236.0;

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
