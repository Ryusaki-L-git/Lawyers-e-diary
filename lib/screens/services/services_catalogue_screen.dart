import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/case_model.dart';
import '../../models/service_catalogue_item.dart';
import '../../services/ecourts_service.dart';
import '../../services/firestore_service.dart';
import '../../services/services_catalogue_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';

class ServicesCatalogueScreen extends StatefulWidget {
  const ServicesCatalogueScreen({super.key, this.caseItem});

  final CaseModel? caseItem;

  @override
  State<ServicesCatalogueScreen> createState() => _ServicesCatalogueScreenState();
}

class _ServicesCatalogueScreenState extends State<ServicesCatalogueScreen> {
  final _service = ServicesCatalogueService();
  final _gateway = EcourtsService();
  final _cases = FirestoreService();
  bool _executing = false;
  final _searchController = TextEditingController();
  List<ServiceCatalogueItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _gateway.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchCatalogue();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<CaseModel>?> _pickCases({
    required bool multiple,
    required int minimum,
  }) async {
    if (!multiple && widget.caseItem != null) {
      return [widget.caseItem!];
    }

    final selectedIds = <String>{};
    return showDialog<List<CaseModel>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(multiple ? 'Select cases' : 'Select a case'),
          content: SizedBox(
            width: 440,
            height: 420,
            child: StreamBuilder<List<CaseModel>>(
              stream: _cases.watchCases(limit: 100),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your accessible cases.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cases = snapshot.data!;
                if (cases.isEmpty) {
                  return const Center(
                    child: Text('No cloud-accessible cases were found.'),
                  );
                }
                return ListView.builder(
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final item = cases[index];
                    final selected = selectedIds.contains(item.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (checked) {
                        if (!multiple) {
                          Navigator.of(dialogContext).pop([item]);
                          return;
                        }
                        setDialogState(() {
                          if (checked == true) {
                            selectedIds.add(item.id);
                          } else {
                            selectedIds.remove(item.id);
                          }
                        });
                      },
                      title: Text(
                        item.caseTitle.isEmpty ? item.caseNumber : item.caseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('CNR: ${item.caseNumber}'),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            if (multiple)
              FilledButton(
                onPressed: selectedIds.length < minimum
                    ? null
                    : () {
                        // The result list is re-read from the current stream
                        // by the next picker invocation; selection is by stable
                        // Firestore document ID, not by CNR.
                        Navigator.of(dialogContext).pop(
                          selectedIds
                              .map((id) => CaseModel(
                                    id: id,
                                    caseTitle: id,
                                    caseNumber: '',
                                    clientName: '',
                                  ))
                              .toList(),
                        );
                      },
                child: Text('Use ${selectedIds.length} selected'),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _runService(ServiceCatalogueItem item) async {
    if (_executing) return;
    setState(() => _executing = true);
    try {
      if (item.serviceId == 'smart_refresh') {
        final picked = await _pickCases(multiple: false, minimum: 1);
        if (picked == null || picked.isEmpty) return;
        final result = await _gateway.smartRefresh(caseId: picked.single.id);
        if (!mounted) return;
        await _showResult(item.displayName, {
          'status': 'ok',
          'message': result.message,
          'caseId': result.caseId,
          'cnr': result.cnr,
        });
        return;
      }

      final body = <String, dynamic>{};
      switch (item.serviceId) {
        case 'case_detail':
          final picked = await _pickCases(multiple: false, minimum: 1);
          if (picked == null || picked.isEmpty) return;
          body['case_id'] = picked.single.id;
          break;
        case 'order_download_pdf':
        case 'order_ai_summary':
        case 'order_markdown_pdf':
          final picked = await _pickCases(multiple: false, minimum: 1);
          if (picked == null || picked.isEmpty) return;
          final filename = await _promptText(
            title: 'Order PDF filename',
            hint: 'Enter the exact PDF filename',
          );
          if (filename == null || filename.isEmpty) return;
          body['case_id'] = picked.single.id;
          body['filename'] = filename;
          if (item.serviceId != 'order_ai_summary') body['signed'] = true;
          break;
        case 'cause_list_search':
          final query = await _promptText(
            title: 'Cause-list search',
            hint: 'Enter a case, party, advocate, or court search term',
          );
          if (query == null || query.isEmpty) return;
          body['params'] = {'q': query};
          break;
        case 'cnr_cause_list_check':
        case 'bulk_case_refresh':
          final picked = await _pickCases(
            multiple: true,
            minimum: item.serviceId == 'bulk_case_refresh' ? 2 : 1,
          );
          if (picked == null || picked.isEmpty) return;
          body['case_ids'] = picked.map((caseItem) => caseItem.id).toList();
          break;
        default:
          throw const EcourtsServiceException(
            'This service is listed as available but has no verified execution flow yet.',
          );
      }

      final result = await _gateway.executePaidService(
        serviceId: item.serviceId,
        body: body,
      );
      if (!mounted) return;
      await _showResult(item.displayName, result);
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${item.displayName} could not complete'),
          content: SelectableText(error.toString()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  Future<void> _showResult(String title, Map<String, dynamic> result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(result),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleItems = _items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.displayName.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      final matchesFilter = _filter == 'All' ||
          (_filter == 'Available' && item.available) ||
          (_filter == 'Planned' && !item.available);
      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: PlatformAppBar(
        title: 'Case Intelligence Services',
        eyebrow: 'JURIS • SERVICE DIRECTORY',
        subtitle: 'Verified availability and transparent token pricing.',
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh service directory',
            color: AppPalette.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppPalette.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppPalette.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppPalette.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const ['All', 'Available', 'Planned'])
                        ChoiceChip(
                          label: Text(option),
                          selected: _filter == option,
                          onSelected: (_) => setState(() => _filter = option),
                          selectedColor: AppPalette.primaryGreen.withValues(alpha: 0.12),
                          labelStyle: TextStyle(
                            color: _filter == option
                                ? AppPalette.primaryGreen
                                : AppPalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${visibleItems.length} services',
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 36, color: AppPalette.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Service directory unavailable',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppPalette.textMuted),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(child: Text('No services available.'))
                          : visibleItems.isEmpty
                              ? const Center(child: Text('No services match this search.'))
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                  itemCount: visibleItems.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = visibleItems[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: AppPalette.cardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppPalette.borderLight),
                                      ),
                                      child: ListTile(
                                        onTap: item.available && !_executing
                                            ? () => _runService(item)
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        leading: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: item.available
                                                ? AppPalette.primaryGreen.withValues(alpha: 0.10)
                                                : AppPalette.textMuted.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            item.available ? Icons.check_circle_outline_rounded : Icons.lock_clock_outlined,
                                            color: item.available ? AppPalette.primaryGreen : AppPalette.textMuted,
                                          ),
                                        ),
                                        title: Text(
                                          item.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 5),
                                          child: Text(
                                            item.description,
                                            style: const TextStyle(color: AppPalette.textMuted, height: 1.35),
                                          ),
                                        ),
                                        trailing: SizedBox(
                                          width: 112,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                item.tokenPrice == null
                                                    ? 'Pricing pending'
                                                    : '${item.tokenPrice} tokens',
                                                textAlign: TextAlign.end,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: item.tokenPrice == null
                                                      ? AppPalette.textMuted
                                                      : AppPalette.primaryGreen,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.billingUnit,
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(fontSize: 10, color: AppPalette.textMuted),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.available ? 'Available' : 'Planned',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: item.available ? AppPalette.primaryGreen : AppPalette.textMuted,
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
          ],
        ),
      ),
    );
  }
}
