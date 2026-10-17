import 'package:flutter/material.dart';

import '../models/client_model.dart';
import '../services/client_service.dart';
import '../screens/clients/add_edit_client_screen.dart';
import '../screens/clients/client_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsClientsScreen extends StatefulWidget {
  const WindowsClientsScreen({super.key});
  @override
  State<WindowsClientsScreen> createState() => _WindowsClientsScreenState();
}

class _WindowsClientsScreenState extends State<WindowsClientsScreen> {
  final _search = TextEditingController();
  String _type = 'All';
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WindowsDesktopShell.canvas,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PRACTICE DIRECTORY', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            SizedBox(height: 7),
            Text('Clients', style: TextStyle(fontFamily: 'Georgia', color: WindowsDesktopShell.forest, fontSize: 29, fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('Client records and contact details in one place.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 13)),
          ])),
          FilledButton.icon(onPressed: _addClient, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Add client'), style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search name, phone or email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WindowsDesktopShell.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WindowsDesktopShell.border)), contentPadding: const EdgeInsets.symmetric(vertical: 16)))),
          const SizedBox(width: 12),
          SizedBox(width: 190, child: DropdownButtonFormField<String>(value: _type, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WindowsDesktopShell.border))), items: const ['All','Individual','Corporate','Government','Other'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged: (v) { if(v!=null) setState(()=>_type=v); })),
        ]),
        const SizedBox(height: 17),
        Expanded(child: StreamBuilder<List<ClientModel>>(
          stream: ClientService.instance.watchClients(searchQuery: _search.text, typeFilter: _type),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _message(Icons.error_outline_rounded, 'Could not load clients', snapshot.error.toString());
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) return const Center(child: CircularProgressIndicator(color: WindowsDesktopShell.forest));
            final clients = snapshot.data ?? const <ClientModel>[];
            if (clients.isEmpty) return _message(Icons.people_outline_rounded, 'No clients found', _search.text.isEmpty && _type=='All' ? 'Add a client to begin building your directory.' : 'Try changing your search or filter.');
            return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: WindowsDesktopShell.border)), child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WindowsDesktopShell.border))), child: Row(children: [
                Expanded(flex: 4, child: Text('CLIENT / ENTITY  ·  ${clients.length}', style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
                const Expanded(flex: 2, child: Text('TYPE', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
                const Expanded(flex: 3, child: Text('CONTACT', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
                const SizedBox(width: 30),
              ])),
              Expanded(child: ListView.separated(itemCount: clients.length, separatorBuilder: (_,__)=>const Divider(height:1, color: WindowsDesktopShell.border), itemBuilder: (context,index) {
                final c=clients[index];
                return InkWell(onTap: ()=>_openClient(c), child: Padding(padding: const EdgeInsets.symmetric(horizontal:20,vertical:14), child: Row(children: [
                  Expanded(flex:4, child: Row(children: [
                    Container(width:40,height:40,alignment:Alignment.center,decoration:BoxDecoration(color: const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(12)),child: Text(c.name.trim().isEmpty?'?':c.name.trim().substring(0,1).toUpperCase(),style:const TextStyle(color:WindowsDesktopShell.forest,fontWeight:FontWeight.w800))),
                    const SizedBox(width:12),
                    Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c.name,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(c.email.isEmpty?'No email recorded':c.email,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11),overflow:TextOverflow.ellipsis)])),
                  ])),
                  Expanded(flex:2,child: Align(alignment:Alignment.centerLeft,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:WindowsDesktopShell.canvas,borderRadius:BorderRadius.circular(7)),child:Text(c.type,style:const TextStyle(color:WindowsDesktopShell.forest,fontSize:10,fontWeight:FontWeight.w700))))),
                  Expanded(flex:3,child:Text(c.phone.isEmpty?'No phone recorded':c.phone,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:12))),
                  const Icon(Icons.chevron_right_rounded,color:WindowsDesktopShell.muted,size:19),
                ])));
              })),
            ]));
          },
        )),
      ]),
    )),
  );

  Widget _message(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));

  Future<void> _addClient() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WindowsDesktopShell(activeRoute:'/clients',child:AddEditClientScreen())));
  }
  Future<void> _openClient(ClientModel client) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WindowsDesktopShell(activeRoute:'/clients',child:ClientDetailScreen(client:client))));
  }
}
