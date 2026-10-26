import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/service_catalogue_item.dart';
import '../../services/services_catalogue_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/windows_desktop_ui.dart';

class ServicesCatalogueScreen extends StatefulWidget {
  const ServicesCatalogueScreen({super.key});

  @override
  State<ServicesCatalogueScreen> createState() => _ServicesCatalogueScreenState();
}

class _ServicesCatalogueScreenState extends State<ServicesCatalogueScreen> {
  final _service = ServicesCatalogueService();
  List<ServiceCatalogueItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
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
    if (defaultTargetPlatform == TargetPlatform.windows) return _buildWindowsCatalogue();
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: AppBar(
        title: const Text('eCourts Services'),
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppPalette.textMuted),
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? const Center(child: Text('No services available.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(item.displayName),
                              subtitle: Text(item.description),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.tokenPrice} tokens',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    item.billingUnit,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppPalette.textMuted,
                                    ),
                                  ),
                                  Text(
                                    item.available ? 'Available' : 'Planned',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.available
                                          ? AppPalette.primaryGreen
                                          : AppPalette.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
  Widget _buildWindowsCatalogue() {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'INTELLIGENCE & SERVICES',
                title: 'Service catalogue',
                subtitle: 'Explore available LED service actions and their token costs.',
                actions: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: WindowsButtonStyles.secondary(),
                ),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const WindowsLoadingPanel(label: 'Loading service catalogue')
              else if (_error != null)
                WindowsMessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Catalogue unavailable',
                  message: _error!,
                  isError: true,
                  action: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                    style: WindowsButtonStyles.secondary(),
                  ),
                )
              else if (_items.isEmpty)
                const WindowsMessageState(
                  icon: Icons.grid_view_rounded,
                  title: 'No services available',
                  message: 'Available service actions will appear here when the catalogue can be loaded.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1120
                        ? 3
                        : constraints.maxWidth >= 720
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 188,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return WindowsPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppPalette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  WindowsStatusChip(
                                    label: item.available ? 'AVAILABLE' : 'PLANNED',
                                    color: item.available
                                        ? AppPalette.statusSuccess
                                        : AppPalette.textMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(
                                  item.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const Divider(height: 18, color: AppPalette.borderLight),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.billingUnit,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppPalette.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${item.tokenPrice} tokens',
                                    style: const TextStyle(
                                      color: AppPalette.primaryGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

}
