import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/firestore_service.dart';
import 'windows_desktop_shell.dart';

class WindowsTransferCaseScreen extends StatefulWidget {
  const WindowsTransferCaseScreen({super.key, this.caseItem});
  final CaseModel? caseItem;
  @override State<WindowsTransferCaseScreen> createState() => _WindowsTransferCaseScreenState();
}
class _WindowsTransferCaseScreenState extends State<WindowsTransferCaseScreen> {
  final _service = FirestoreService();
  final _search = TextEditingController();
  CaseModel? _selectedCase;
  String _memberId = '';
  String _memberName = '';
  bool _busy = false;
  @override void initState() { super.initState(); _selectedCase = widget.caseItem; }
  @override void dispose() { _search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: WindowsDesktopShell.canvas, body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(30,25,30,30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('TEAM CASE ALLOCATION', style: TextStyle(color: WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
    const SizedBox(height:7), const Text('Transfer a case',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
    const SizedBox(height:5), const Text('Transfer an existing cloud case to a lawyer in the LED identity directory.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
    const SizedBox(height:22),
    Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:820), child: ListView(children: [
      _panel('1. Select a case', Icons.folder_open_outlined, [
        if (_selectedCase != null) Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_selectedCase!.caseTitle,style:const TextStyle(color:WindowsDesktopShell.forest,fontWeight:FontWeight.w800,fontSize:13)),
          const SizedBox(height:4), Text(_selectedCase!.caseNumber + ' · ' + _selectedCase!.clientName,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11)),
          Align(alignment:Alignment.centerRight,child:TextButton(onPressed:widget.caseItem==null?()=>setState(()=>_selectedCase=null):null,child:const Text('Change case'))),
        ])) else ...[
          TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Search accessible cloud cases')),
          const SizedBox(height:10),
          StreamBuilder<List<CaseModel>>(stream:_service.watchCases(searchQuery:_search.text,sortBy:'title',limit:200),builder:(context,snapshot){
            if(snapshot.hasError)return _note('Could not load cloud cases. Check access and connectivity.');
            if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
            final cases=snapshot.data??const <CaseModel>[];
            if(cases.isEmpty)return _note('No accessible cloud cases found. Local-only cases are not transferable through this cloud workflow.');
            return Column(children:[for(final item in cases) ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.folder_outlined,color:WindowsDesktopShell.gold),title:Text(item.caseTitle,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),subtitle:Text(item.caseNumber+' · '+item.clientName,style:const TextStyle(fontSize:10)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>setState(()=>_selectedCase=item))]);
          }),
        ],
      ]),
      const SizedBox(height:15),
      _panel('2. Select the receiving lawyer',Icons.people_outline_rounded,[
        StreamBuilder<List<TeamMemberModel>>(stream:_service.getTeamMembers(),builder:(context,snapshot){
          if(snapshot.hasError)return _note('Could not load the LED identity directory.');
          if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
          final members=(snapshot.data??const <TeamMemberModel>[]).where((m)=>m.id!=_service.currentUserId).toList();
          if(members.isEmpty)return _note('No other lawyers are available in the identity directory.');
          final selectedExists=members.any((m)=>m.id==_memberId);
          return DropdownButtonFormField<String>(value:selectedExists?_memberId:null,decoration:const InputDecoration(labelText:'Receiving lawyer',border:OutlineInputBorder()),hint:const Text('Choose a lawyer'),items:members.map((m)=>DropdownMenuItem(value:m.id,child:Text(m.name+' · '+m.role,overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(id){final found=members.where((m)=>m.id==id);if(found.isNotEmpty){final m=found.first;setState(()=>{_memberId=m.id;_memberName=m.name;});}});
        }),
      ]),
      const SizedBox(height:15),
      Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:const Color(0xFFFFF7E7),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFEAD7A6))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline_rounded,color:Color(0xFF9B782B)),SizedBox(width:10),Expanded(child:Text('This updates the cloud case handler and user assignment. It does not transfer unsynced local-only records or attachments. Confirm the receiving lawyer is authorized before proceeding.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11,height:1.5)))])),
      const SizedBox(height:18),
      Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_busy||_selectedCase==null||_memberId.isEmpty?null:_confirm,icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.send_rounded),label:Text(_busy?'Transferring…':'Confirm transfer'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:20,vertical:16)))),
    ])))),
  ]))));
  Widget _panel(String title,IconData icon,List<Widget> children)=>Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:WindowsDesktopShell.gold,size:20),const SizedBox(width:9),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:14,fontWeight:FontWeight.w800))]),const SizedBox(height:15),...children]));
  Widget _note(String text)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(text,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12,height:1.5)));
  Future<void> _confirm() async {
    final item=_selectedCase; if(item==null||_memberId.isEmpty)return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Confirm case transfer'),content:Text('Transfer "'+item.caseTitle+'" to '+_memberName+'? The cloud assignment will be updated.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest),child:const Text('Transfer case'))]));
    if(ok!=true||!mounted)return; setState(()=>_busy=true);
    try { await _service.transferCase(caseId:item.id,targetLawyerId:_memberId,targetLawyerName:_memberName); if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Transfer request processed. Verify the case assignment in the receiving account.'))); Navigator.of(context).pushReplacementNamed('/cases'); }
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Transfer failed. Check access and try again.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
}