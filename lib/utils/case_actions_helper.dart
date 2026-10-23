import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/case_model.dart';
import '../services/subscription_service.dart';
import '../widgets/calendar_components.dart';
import 'hearing_update_message.dart';

abstract final class CaseActionsHelper {
  static String? normalizeWhatsAppNumber(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null;
    return digits;
  }

  static HearingDateOrigin originFromCaseSource(String source) {
    final s = source.toLowerCase().trim();
    if (s == 'manual') return HearingDateOrigin.manual;
    if (s.contains('ecourt') ||
        s == 'synced' ||
        s == 'court' ||
        s == 'authorized' ||
        s == 'case_record' ||
        s == 'smart_backend') {
      return HearingDateOrigin.caseRecord;
    }
    return HearingDateOrigin.unknown;
  }

  /// Opens WhatsApp using the universal web/deep link format:
  /// `https://wa.me/<number>?text=<encoded_message>`
  /// Never auto-sends; opens chat draft for confirmation.
  static Future<bool> openWhatsAppClient({
    required BuildContext context,
    required CaseModel caseItem,
  }) async {
    // Paid-only entitlement check at the operation boundary.
    SubscriptionInfo subscription;
    try {
      subscription = await SubscriptionService.instance.fetchSubscription();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not verify subscription: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    if (subscription.isFree) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp hearing updates are available with a paid subscription.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final phone = normalizeWhatsAppNumber(caseItem.clientPhone);
    if (phone == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid WhatsApp number recorded for this client.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final advocateName =
        (FirebaseAuth.instance.currentUser?.displayName ?? '').trim().isNotEmpty
        ? FirebaseAuth.instance.currentUser!.displayName!.trim()
        : (caseItem.handledBy.trim().isNotEmpty
              ? caseItem.handledBy.trim()
              : 'Advocate');

    final origin = originFromCaseSource(caseItem.caseSource);

    if (!context.mounted) return false;
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => _WhatsAppHearingUpdateDialog(
        caseItem: caseItem,
        phone: phone,
        advocateName: advocateName,
        origin: origin,
      ),
    );

    if (message == null || message.trim().isEmpty) {
      return false;
    }

    final uri = Uri.https('wa.me', '/$phone', {'text': message.trim()});

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return launched;
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp opened. Please review and send the message yourself.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open WhatsApp. Please verify the client number and installation.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch WhatsApp: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Shares case details using system share sheet.
  static Future<void> shareCase({
    required CaseModel caseItem,
    bool fullDetails = true,
  }) async {
    final hearingText = caseItem.nextHearingDate != null
        ? CalendarDateHelper.formatDateDigits(caseItem.nextHearingDate!)
        : 'To be announced';

    final text = fullDetails
        ? 'CASE DOSSIER: ${caseItem.caseTitle}\n'
              'Case Number: ${caseItem.caseNumber}\n'
              'Type: ${caseItem.caseType}\n'
              'Status: ${caseItem.status.toUpperCase()}\n'
              'Client: ${caseItem.clientName}\n'
              'Opponent: ${caseItem.opponentName.isEmpty ? "N/A" : caseItem.opponentName}\n'
              'Court: ${caseItem.courtName}\n'
              'Next Hearing: $hearingText\n'
              'Counsel: ${caseItem.handledBy}\n'
              'Notes: ${caseItem.notes.isEmpty ? "None" : caseItem.notes.join("; ")}'
        : 'Case Summary: ${caseItem.caseTitle} (${caseItem.caseNumber}) at ${caseItem.courtName}. '
              'Next Date: $hearingText.';

    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Case Summary: ${caseItem.caseTitle}'),
    );
  }

  /// Generates a professional legal PDF document and invokes the Printing system.
  static Future<void> printCaseDetails({
    required BuildContext context,
    required CaseModel caseItem,
  }) async {
    final pdf = pw.Document();

    final hearingText = caseItem.nextHearingDate != null
        ? CalendarDateHelper.formatDateDigits(caseItem.nextHearingDate!)
        : 'None Scheduled';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'LAWYER\'S E-DIARY',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#13382E'),
                    ),
                  ),
                  pw.Text(
                    'CONFIDENTIAL LEGAL DOSSIER',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#888888'),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#13382E')),
              pw.SizedBox(height: 12),

              // Title & Number
              pw.Text(
                caseItem.caseTitle,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1A1A1A'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'CNR / Case Number: ${caseItem.caseNumber}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#555555'),
                ),
              ),
              pw.SizedBox(height: 16),

              // Details Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7F5F2'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _pdfRow('Case Type', caseItem.caseType),
                    _pdfRow('Current Status', caseItem.status.toUpperCase()),
                    _pdfRow('Client', caseItem.clientName),
                    _pdfRow(
                      'Opponent',
                      caseItem.opponentName.isEmpty
                          ? 'N/A'
                          : caseItem.opponentName,
                    ),
                    _pdfRow('Court / Forum', caseItem.courtName),
                    _pdfRow('Next Hearing Date', hearingText),
                    _pdfRow('Assigned Counsel', caseItem.handledBy),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Notes Section
              pw.Text(
                'Case Notes & Observations',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (caseItem.notes.isEmpty)
                pw.Text(
                  'No docket notes entered.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                  ),
                )
              else
                ...caseItem.notes.map(
                  (note) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      '• $note',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ),

              pw.Spacer(),
              pw.Divider(color: PdfColor.fromHex('#CCCCCC')),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on ${CalendarDateHelper.formatDateDigits(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    'Lawyer\'s E-Diary System',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Case_${caseItem.caseNumber.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Prints multiple selected cases summary report.
  static Future<void> printMultipleCases({
    required BuildContext context,
    required List<CaseModel> cases,
    String title = 'Cause List Report',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#13382E'),
                  ),
                ),
                pw.Text(
                  'Total: ${cases.length}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#13382E')),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Case Title',
                'Number',
                'Type',
                'Court',
                'Hearing Date',
              ],
              data: cases.map((c) {
                final d = c.nextHearingDate != null
                    ? CalendarDateHelper.formatDateDigits(c.nextHearingDate!)
                    : '-';
                return [c.caseTitle, c.caseNumber, c.caseType, c.courtName, d];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F7F5F2'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cause_List_Report.pdf',
    );
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#555555'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppHearingUpdateDialog extends StatefulWidget {
  const _WhatsAppHearingUpdateDialog({
    required this.caseItem,
    required this.phone,
    required this.advocateName,
    required this.origin,
  });

  final CaseModel caseItem;
  final String phone;
  final String advocateName;
  final HearingDateOrigin origin;

  @override
  State<_WhatsAppHearingUpdateDialog> createState() =>
      _WhatsAppHearingUpdateDialogState();
}

class _WhatsAppHearingUpdateDialogState
    extends State<_WhatsAppHearingUpdateDialog> {
  late HearingUpdateKind _kind;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _kind = HearingUpdateKind.short;
    _controller = TextEditingController(text: _buildMessage(_kind));
  }

  String _buildMessage(HearingUpdateKind kind) {
    return HearingUpdateMessageBuilder.build(
      kind: kind,
      clientName: widget.caseItem.clientName,
      hearingDate: widget.caseItem.nextHearingDate,
      hearingPurpose: widget.caseItem.hearingPurpose,
      dateOrigin: widget.origin,
      advocateName: widget.advocateName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WhatsApp hearing update'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipient: ${widget.phone}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Short'),
                  selected: _kind == HearingUpdateKind.short,
                  onSelected: (_) {
                    setState(() {
                      _kind = HearingUpdateKind.short;
                      _controller.text = _buildMessage(_kind);
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Detailed'),
                  selected: _kind == HearingUpdateKind.detailed,
                  onSelected: (_) {
                    setState(() {
                      _kind = HearingUpdateKind.detailed;
                      _controller.text = _buildMessage(_kind);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Message (editable)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _controller.text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Open WhatsApp'),
        ),
      ],
    );
  }
}
