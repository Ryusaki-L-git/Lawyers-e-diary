import 'package:flutter/material.dart';

import '../models/client_model.dart';
import '../screens/clients/add_edit_client_screen.dart';
import '../screens/clients/client_detail_screen.dart';
import '../services/client_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

/// Windows practice directory surface.
///
/// Lists the signed-in user's client records with a live search and a client
/// type filter.
class WindowsClientsScreen extends StatefulWidget {
  const WindowsClientsScreen({super.key});
  @override
  State<WindowsClientsScreen> createState() => _WindowsClientsScreenState();
}

class _WindowsClientsScreenState extends State<WindowsClientsScreen> {
  final _search = TextEditingController();
  String _type = 'All';

  int _retry = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WindowsPageHeader(
              eyebrow: 'PRACTICE DIRECTORY',
              title: 'Clients',
              subtitle: 'Client records and contact details in one place.',
              actions: FilledButton.icon(
                onPressed: _addClient,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add client'),
                style: WindowsButtonStyles.primary(),
              ),
            ),
            const SizedBox(height: 22),
            _filters(),
            const SizedBox(height: 17),
            Expanded(
              child: StreamBuilder<List<ClientModel>>(
                key: ValueKey(_retry),
                stream: ClientService.instance.watchClients(
                  searchQuery: _search.text,
                  typeFilter: _type,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return WindowsMessageState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load clients',
                      message: snapshot.error.toString(),
                      isError: true,
                      action: OutlinedButton.icon(
                        onPressed: () => setState(() => _retry++),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: WindowsButtonStyles.secondary(),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return const WindowsLoadingPanel();
                  }
                  final clients = snapshot.data ?? const <ClientModel>[];
                  if (clients.isEmpty) {
                    return WindowsMessageState(
                      icon: Icons.people_outline_rounded,
                      title: 'No clients found',
                      message: _search.text.isEmpty && _type == 'All'
                          ? 'Add a client to begin building your directory.'
                          : 'Try changing your search or filter.',
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: AppPalette.cardBackground,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppPalette.borderLight),
                            ),
                          ),
                          child: Row(
                            children: [
                              WindowsColumnLabel(
                                'Client / entity · ${clients.length}',
                                flex: 4,
                              ),
                              const WindowsColumnLabel('Type', flex: 2),
                              const WindowsColumnLabel('Contact', flex: 3),
                              const SizedBox(width: 19),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: clients.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppPalette.borderLight,
                            ),
                            itemBuilder: (context, index) {
                              final c = clients[index];
                              return InkWell(
                                onTap: () => _openClient(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: AppPalette.statusTile,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                c.name.trim().isEmpty
                                                    ? '?'
                                                    : c.name
                                                          .trim()
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                style: const TextStyle(
                                                  color:
                                                      AppPalette.primaryGreen,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.name,
                                                    style: const TextStyle(
                                                      color: AppPalette
                                                          .textPrimary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    c.email.isEmpty
                                                        ? 'No email recorded'
                                                        : c.email,
                                                    style: const TextStyle(
                                                      color:
                                                          AppPalette.textMuted,
                                                      fontSize: 11,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: WindowsStatusChip(
                                            label: c.type,
                                            color: AppPalette.primaryGreen,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          c.phone.isEmpty
                                              ? 'No phone recorded'
                                              : c.phone,
                                          style: const TextStyle(
                                            color: AppPalette.textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppPalette.textMuted,
                                        size: 19,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// The directory toolbar.
  ///
  /// A narrow window stacks the controls so the search field keeps a usable
  /// width and the toolbar never overflows.
  Widget _filters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchField(),
              const SizedBox(height: 12),
              _typeFilter(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 12),
            SizedBox(width: 190, child: _typeFilter()),
          ],
        );
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration:
          const WindowsFieldDecoration(hint: 'Search name, phone or email')
              .build()
              .copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText: 'Search',
              ),
    );
  }

  Widget _typeFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      isExpanded: true,
      decoration: const WindowsFieldDecoration(hint: 'All client types')
          .build()
          .copyWith(labelText: 'Client type'),
      items: const ['All', 'Individual', 'Corporate', 'Government', 'Other']
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(v, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _type = v);
      },
    );
  }

  Future<void> _addClient() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/clients',
          child: AddEditClientScreen(),
        ),
      ),
    );
  }

  Future<void> _openClient(ClientModel client) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WindowsDesktopShell(
          activeRoute: '/clients',
          child: ClientDetailScreen(client: client),
        ),
      ),
    );
  }
}
