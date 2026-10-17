import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_desktop_shell.dart';

class WindowsCaseManagementScreen extends StatelessWidget{
  const WindowsCaseManagementScreen({super.key});
  @override
  Widget build(BuildContext context){
    final repository=CaseRepository(database:AppDatabase.instance);
    return Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:StreamBuilder<List<CaseModel>>(stream:repository.watchCasesForCurrentUser(sortBy:'created'),builder:(context,snapshot){
      final cases=snapshot.data??const <CaseModel>[];
      final urgent=cases.where((c)=>c.isUrgent).length;
      final upcoming=cases.where((c)=>c.nextHearingDate!=null&&!c.isCompleted).length;
      final noDate=cases.where((c)=>c.nextHearingDate==null).length;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('DOCKET OPERATIONS',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
        const SizedBox(height:7),const Text('Case management',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
        const SizedBox(height:5),const Text('A live operational overview of your local case register.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
        const SizedBox(height:22),
        if(snapshot.hasError)Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:WindowsDesktopShell.border)),child:Text('Could not load case statistics: \${snapshot.error}',style:const TextStyle(color:Color(0xFF9A4A3F),fontSize:12))),
        if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)const LinearProgressIndicator(color:WindowsDesktopShell.gold),
        LayoutBuilder(builder:(context,constraints){
          final cols=constraints.maxWidth>1100?4:constraints.maxWidth>700?2:1;
          final stats=[('ACTIVE CASES',cases.length,Icons.folder_open_outlined,WindowsDesktopShell.forest),('URGENT MATTERS',urgent,Icons.priority_high_rounded,const Color(0xFF9A4A3F)),('WITH HEARING DATE',upcoming,Icons.calendar_month_outlined,const Color(0xFF536D5A)),('DATE NOT SET',noDate,Icons.event_busy_outlined,const Color(0xFF9B782B))];
          return Wrap(spacing:12,runSpacing:12,children:[for(final s in stats)SizedBox(width:(constraints.maxWidth-(cols-1)*12)/cols,child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:WindowsDesktopShell.border)),child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:s.$4.withValues(alpha:.09),borderRadius:BorderRadius.circular(12)),child:Icon(s.$3,color:s.$4,size:21)),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s.$1,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:.7)),const SizedBox(height:7),Text(s.$2.toString(),style:TextStyle(color:s.$4,fontSize:25,fontWeight:FontWeight.w800))])),
          ])))]);
        }),
        const SizedBox(height:22),
        const Text('QUICK OPERATIONS',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.2)),
        const SizedBox(height:12),
        Expanded(child:LayoutBuilder(builder:(context,constraints){
          final cols=constraints.maxWidth>900?3:constraints.maxWidth>600?2:1;
          final actions=[
            ('Open master docket','Search and review your cases',Icons.folder_copy_outlined,'/cases'),
            ('Search case records','Find by title, client or case number',Icons.manage_search_rounded,'/search_cases'),
            ('Register a case','Add a matter to the local docket',Icons.add_circle_outline_rounded,'/add_case'),
            ('Calendar & hearings','Review upcoming scheduled dates',Icons.calendar_month_outlined,'/calendar'),
            ('Daily cause list','Review matters on a selected date',Icons.gavel_outlined,'/cause_list'),
            ('Client directory','Open client records and contacts',Icons.people_outline_rounded,'/clients'),
          ];
          return GridView.count(crossAxisCount:cols,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:2.6,children:[for(final a in actions)Material(color:Colors.white,borderRadius:BorderRadius.circular(14),child:InkWell(onTap:()=>Navigator.of(context).pushReplacementNamed(a.$4),borderRadius:BorderRadius.circular(14),child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:WindowsDesktopShell.border)),child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(12)),child:Icon(a.$3,color:WindowsDesktopShell.forest,size:21)),
            const SizedBox(width:12),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.$1,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(a.$2,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10),maxLines:2,overflow:TextOverflow.ellipsis)])),
            const Icon(Icons.chevron_right_rounded,color:WindowsDesktopShell.muted,size:18),
          ]))))]);
        })),
      ]);
    }))));
  }
}
