import 'package:flutter/material.dart';

import '../../models/service_catalogue_item.dart';
import '../../services/services_catalogue_service.dart';
import '../../widgets/app_palette.dart';

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
}
