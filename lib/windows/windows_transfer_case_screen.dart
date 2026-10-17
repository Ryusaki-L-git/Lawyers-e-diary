import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import 'windows_desktop_shell.dart';

class WindowsTransferCaseScreen extends StatefulWidget {
  const WindowsTransferCaseScreen({super.key});
  @override State<WindowsTransferCaseScreen> createState()=>_WindowsTransferCaseScreenState();
}
class _WindowsTransferCaseScreenState extends State<WindowsTransferCaseScreen>{
  final _service=TeamService.instance;
  String? _teamId,_caseId,_memberId;
  String _caseTitle='',_memberName='';
  bool _busy=false;
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('TEAM CASE ALLOCATION',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),const SizedBox(height:7),const Text('Assign a team case',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),const SizedBox(height:5),const Text('Assign a case already shared with one of your teams to an active member of that same team.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),const SizedBox(height:22),
    Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:850),child:ListView(children:[
      _panel('1. Choose a team you can manage',Icons.groups_2_outlined,[
        StreamBuilder<List<TeamModel>>(stream:_service.watchUserTeams(),builder:(context,snapshot){
          if(snapshot.hasError)return _note('Could not load your teams. Check your access and connectivity.');
          if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
          final teams=snapshot.data??const <TeamModel>[];
          if(teams.isEmpty)return _note('No active teams are available to this account. Create or join a team first.');
          final selected=teams.where((t)=>t.id==_teamId).toList();
          return DropdownButtonFormField<String>(value:selected.isEmpty?null:_teamId,decoration:const InputDecoration(labelText:'Team / chambers',border:OutlineInputBorder()),items:teams.map((t)=>DropdownMenuItem(value:t.id,child:Text(t.name+' · '+(t.lawFirm.isEmpty?'Practice team':t.lawFirm),overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(id)=>setState(() {_teamId=id;_caseId=null;_memberId=null;_caseTitle='';_memberName='';}));
        }),
      ]),const SizedBox(height:15),
      if(_teamId!=null)...[
        _panel('2. Choose a case in this team',Icons.folder_open_outlined,[
          StreamBuilder<List<CaseModel>>(stream:_service.watchTeamCases(_teamId!),builder:(context,snapshot){
            if(snapshot.hasError)return _note('Could not load cases for this team. Check team membership and Firestore access.');
            if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
            final cases=(snapshot.data??const <CaseModel>[]).where((c)=>!c.isDeleted&&!c.isCompleted).toList();
            if(cases.isEmpty)return _note('This team has no active shared cases available for assignment. Private/local-only cases are not shown.');
            final selected=cases.where((c)=>c.id==_caseId).toList();
            return DropdownButtonFormField<String>(value:selected.isEmpty?null:_caseId,decoration:const InputDecoration(labelText:'Team case',border:OutlineInputBorder()),items:cases.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.caseTitle+' · '+c.caseNumber,overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(id){final found=cases.where((c)=>c.id==id);setState(() {_caseId=id;_caseTitle=found.isEmpty?'':found.first.caseTitle;_memberId=null;_memberName='';});});
          }),
        ]),const SizedBox(height:15),
        _panel('3. Choose an active team member',Icons.person_add_alt_1_outlined,[
          StreamBuilder<TeamMembership?>(stream:_service.watchMyMembership(_teamId!),builder:(context,ownSnapshot){
            if(ownSnapshot.hasError)return _note('Could not verify your team role. Assignment is disabled until access can be checked.');
            if(ownSnapshot.connectionState==ConnectionState.waiting&&ownSnapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
            final own=ownSnapshot.data;
            final canManage=own?.isActive==true&&(own!.role==TeamRole.owner||own.role==TeamRole.leader);
            if(!canManage)return _note('Only an active team owner or leader can assign cases.');
            return StreamBuilder<List<TeamMembership>>(stream:_service.watchMembers(_teamId!),builder:(context,membersSnapshot){
              if(membersSnapshot.hasError)return _note('Could not load team membership.');
              if(membersSnapshot.connectionState==ConnectionState.waiting&&membersSnapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
              final members=(membersSnapshot.data??const <TeamMembership>[]).where((m)=>m.isActive&&m.hasFirebaseIdentity&&m.userId!=_service.currentUserId).toList();
              if(members.isEmpty)return _note('No other active, verified LED members are available in this team.');
              final selected=members.where((m)=>m.userId==_memberId).toList();
              return DropdownButtonFormField<String>(value:selected.isEmpty?null:_memberId,decoration:const InputDecoration(labelText:'Receiving member',border:OutlineInputBorder()),items:members.map((m)=>DropdownMenuItem(value:m.userId,child:Text(m.displayName+' · '+m.role.label,overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(id){final found=members.where((m)=>m.userId==id);if(found.isNotEmpty)setState(() {_memberId=id;_memberName=found.first.displayName;});});
            });
          }),
        ]),
      ],
      const SizedBox(height:15),
      Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:const Color(0xFFFFF7E7),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFEAD7A6))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline_rounded,color:Color(0xFF9B782B)),SizedBox(width:10),Expanded(child:Text('This workflow only assigns an existing team-shared cloud case. It does not transfer private local cases, change case ownership, or move attachments. The team service validates active membership before recording the assignment.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11,height:1.5)))])),
      const SizedBox(height:18),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_busy||_teamId==null||_caseId==null||_memberId==null?null:_confirm,icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.assignment_ind_outlined),label:Text(_busy?'Assigning…':'Confirm assignment'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:20,vertical:16)))),
    ])))),
  ]))));
  Widget _panel(String title,IconData icon,List<Widget> children)=>Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:WindowsDesktopShell.gold,size:20),const SizedBox(width:9),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:14,fontWeight:FontWeight.w800))]),const SizedBox(height:15),...children]));
  Widget _note(String text)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(text,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12,height:1.5)));
  Future<void> _confirm() async {
    final team=_teamId,caseId=_caseId,member=_memberId;
    if(team==null||caseId==null||member==null||_caseTitle.isEmpty)return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Confirm team assignment'),content:Text('Assign "'+_caseTitle+'" to '+_memberName+' within this team?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest),child:const Text('Assign case'))]));
    if(ok!=true||!mounted)return;setState(()=>_busy=true);
    try{await _service.assignCase(teamId:team,caseId:caseId,caseTitle:_caseTitle,memberId:member,memberName:_memberName);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Team case assignment saved.')));Navigator.of(context).pushReplacementNamed('/team');}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Assignment failed: $e')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
}