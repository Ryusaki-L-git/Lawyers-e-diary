import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/subscription_service.dart';
import 'windows_desktop_shell.dart';

class WindowsCloudStorageScreen extends StatefulWidget {
  const WindowsCloudStorageScreen({super.key});
  @override
  State<WindowsCloudStorageScreen> createState() => _WindowsCloudStorageScreenState();
}
class _WindowsCloudStorageScreenState extends State<WindowsCloudStorageScreen> {
  bool _recording = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WindowsDesktopShell.canvas,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
      child: StreamBuilder<SubscriptionInfo>(
        stream: SubscriptionService.instance.watchSubscription(),
        builder: (context, snapshot) {
          final sub = snapshot.data ?? SubscriptionInfo.defaultFree;
          return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACCOUNT & DATA', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 7), const Text('Cloud & storage', style: TextStyle(fontFamily: 'Georgia', color: WindowsDesktopShell.forest, fontSize: 29, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5), const Text('Review the subscription information currently stored for your account.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 13)),
            const SizedBox(height: 22),
            Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: WindowsDesktopShell.forest, borderRadius: BorderRadius.circular(17)), child: Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(15)), child: Icon(sub.isCloud ? Icons.cloud_done_outlined : Icons.devices_outlined, color: WindowsDesktopShell.gold, size: 29)),
              const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sub.isCloud ? 'Cloud Subscriber' : 'Free / local-first plan', style: const TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6), Text(sub.isCloud ? 'Cloud subscription metadata is present.' : 'Your account currently reports the free tier.', style: const TextStyle(color: Color(0xFFD8E1D9), fontSize: 12)),
              ])),
              if (sub.isFree) OutlinedButton(onPressed: () => Navigator.of(context).pushNamed('/upgrade'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF))), child: const Text('View plans')),
            ])),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              final cards = [
                _InfoCard(icon: Icons.storage_outlined, label: 'STORAGE USAGE', value: sub.storageUsedFormatted, detail: 'Value recorded in subscription metadata'),
                _InfoCard(icon: Icons.sync_outlined, label: 'LAST SYNC MARKER', value: sub.lastSyncedAt == null ? 'Not recorded' : DateFormat('dd MMM yyyy, HH:mm').format(sub.lastSyncedAt!.toLocal()), detail: 'Timestamp only; not proof that all records synced'),
              ];
              return Flex(direction: wide ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < cards.length; i++) ExpandedOrBox(wide: wide, child: cards[i], gapAfter: i == 0)]);
            }),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: WindowsDesktopShell.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sync status', style: TextStyle(color: WindowsDesktopShell.ink, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('The current subscription service records a timestamp only. It does not run a full case/client/document synchronization job. This screen therefore does not claim that a backup has completed.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 12, height: 1.6)),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _recording ? null : _recordMarker, icon: const Icon(Icons.history_toggle_off_rounded), label: Text(_recording ? 'Recording…' : 'Record a status check'), style: OutlinedButton.styleFrom(foregroundColor: WindowsDesktopShell.forest, side: const BorderSide(color: WindowsDesktopShell.border), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13))),
            ])),
          ]));
        },
      ),
    )),
  );
  Future<void> _recordMarker() async {
    setState(() => _recording = true);
    try {
      await SubscriptionService.instance.recordSync();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status timestamp recorded. No data synchronization was run.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not record the status timestamp.')));
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }
}
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value, required this.detail});
  final IconData icon; final String label; final String value; final String detail;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: WindowsDesktopShell.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: WindowsDesktopShell.gold, size: 23), const SizedBox(height: 13),
    Text(label, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .9)),
    const SizedBox(height: 8), Text(value, style: const TextStyle(color: WindowsDesktopShell.forest, fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 5), Text(detail, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10)),
  ]));
}
class ExpandedOrBox extends StatelessWidget {
  const ExpandedOrBox({super.key, required this.wide, required this.child, required this.gapAfter});
  final bool wide; final Widget child; final bool gapAfter;
  @override
  Widget build(BuildContext context) => wide ? Expanded(child: Padding(padding: EdgeInsets.only(right: gapAfter ? 12 : 0), child: child)) : Padding(padding: EdgeInsets.only(bottom: gapAfter ? 12 : 0), child: child);
}
