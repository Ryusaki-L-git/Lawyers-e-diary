import 'package:flutter/material.dart';

import '../../models/service_catalogue_item.dart';
import '../../services/services_catalogue_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';

class ServicesCatalogueScreen extends StatefulWidget {
  const ServicesCatalogueScreen({super.key});

  @override
  State<ServicesCatalogueScreen> createState() => _ServicesCatalogueScreenState();
}

class _ServicesCatalogueScreenState extends State<ServicesCatalogueScreen> {
  final _service = ServicesCatalogueService();
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
                                        onTap: item.available
                                            ? () => Navigator.of(context).pushNamed('/cases')
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
