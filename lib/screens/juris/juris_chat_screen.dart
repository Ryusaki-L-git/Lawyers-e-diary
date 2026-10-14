import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../services/juris_service.dart';
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
  final _sessionId = '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';
  final List<_ChatEntry> _entries = [
    const _ChatEntry(false, 'I am JURIS, the legal AI assistant for Lawyer’s E-Diary. I can help with research and analysis when the configured backend and authorized sources are available. Please verify important legal conclusions against the original sources.'),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() {
      _entries.add(_ChatEntry(true, message));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();
    try {
      final result = await _service.sendMessage(message: message, sessionId: _sessionId);
      if (!mounted) return;
      setState(() => _entries.add(_ChatEntry(false, result.reply)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _entries.add(_ChatEntry(false, 'I could not complete that request. $error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.balance_rounded, color: AppPalette.accentGold),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('JURIS', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            Text('Legal intelligence', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ]),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppPalette.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppPalette.borderLight)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_user_outlined, size: 19, color: AppPalette.primaryGreen),
              SizedBox(width: 8),
              Expanded(child: Text('Use verified sources for legal research. Do not treat AI output as a substitute for checking the original law or judgment.', style: TextStyle(fontSize: 12, color: AppPalette.textMuted))),
            ]),
          ),
          Expanded(child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _entries.length + (_busy ? 1 : 0),
            itemBuilder: (context, index) {
              if (_busy && index == _entries.length) {
                return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final entry = _entries[index];
              return Align(
                alignment: entry.user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: entry.user ? AppPalette.primaryGreen : AppPalette.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: entry.user ? null : Border.all(color: AppPalette.borderLight),
                  ),
                  child: SelectableText(entry.text, style: TextStyle(height: 1.4, color: entry.user ? Colors.white : AppPalette.textPrimary)),
                ),
              );
            },
          )),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(color: AppPalette.cardBackground, border: Border(top: BorderSide(color: AppPalette.borderLight))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask JURIS…',
                  filled: true,
                  fillColor: AppPalette.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy ? null : _send,
                style: IconButton.styleFrom(backgroundColor: AppPalette.primaryGreen, foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Send to JURIS',
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ChatEntry {
  const _ChatEntry(this.user, this.text);
  final bool user;
  final String text;
}
