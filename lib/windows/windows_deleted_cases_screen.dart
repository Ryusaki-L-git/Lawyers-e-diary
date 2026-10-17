import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsDeletedCasesScreen extends StatelessWidget{
  const WindowsDeletedCasesScreen({super.key});
  @override
  Widget build(BuildContext context){
    final database=AppDatabase.instance;
    final repository=CaseRepository(database:database);
    final uid=repository.currentUserId;
    final stream=(database.select(database.localCases)..where((row)=>row.ownerUid.equals(uid))..where((row)=>row.isDeleted.equals(true))..orderBy([(row)=>OrderingTerm.desc(row.updatedAt)])).watch().map((rows)=>rows.map((row)=>LocalCaseRecord.fromRow(row).toCaseModel()).toList());
    return Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('CASE LIFECYCLE',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
      const SizedBox(height:7),const Text('Deleted cases',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
      const SizedBox(height:5),const Text('Review archived matters and restore them when appropriate.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
      const SizedBox(height:20),
      Expanded(child:StreamBuilder<List<CaseModel>>(stream:stream,builder:(context,snapshot){
        if(snapshot.hasError)return _empty(Icons.error_outline_rounded,'Could not load deleted cases',snapshot.error.toString());
        if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
        final cases=snapshot.data??const <CaseModel>[];
        if(cases.isEmpty)return _empty(Icons.delete_outline_rounded,'No deleted cases','Cases moved to deleted status will appear here.');
        return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:ListView.separated(itemCount:cases.length,separatorBuilder:(_,__)=>const Divider(height:1,color:WindowsDesktopShell.border),itemBuilder:(context,index){
          final c=cases[index];
          return Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFF8E8E5),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.archive_outlined,color:Color(0xFF9A4A3F),size:20)),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(c.caseTitle,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800)),
              const SizedBox(height:4),Text('\${c.caseNumber} · \${c.clientName}',style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11)),
            ])),
            OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WindowsDesktopShell(activeRoute:'/deleted_cases',child:WindowsCaseDetailScreen(caseItem:c)))),icon:const Icon(Icons.visibility_outlined,size:16),label:const Text('Review'),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border))),
            const SizedBox(width:8),FilledButton.icon(onPressed:()async{try{await repository.restoreCase(c.id);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Case restored to active status.')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not restore case: $e')));}},icon:const Icon(Icons.restore_rounded,size:16),label:const Text('Restore'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest)),
          ]));
        }));
      })),
    ]))));
  }
  Widget _empty(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));
}
