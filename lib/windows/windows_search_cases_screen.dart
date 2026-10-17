import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsSearchCasesScreen extends StatefulWidget{
  const WindowsSearchCasesScreen({super.key});
  @override
  State<WindowsSearchCasesScreen> createState()=>_WindowsSearchCasesScreenState();
}
class _WindowsSearchCasesScreenState extends State<WindowsSearchCasesScreen>{
  final _query=TextEditingController();final _repo=CaseRepository(database:AppDatabase.instance);
  String _status='All',_sort='nextHearing';
  @override void dispose(){_query.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('DOCKET DISCOVERY',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
    const SizedBox(height:7),const Text('Search cases',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
    const SizedBox(height:5),const Text('Search your local case register by title, client, or case number.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
    const SizedBox(height:20),
    Row(children:[
      Expanded(child:TextField(controller:_query,onChanged:(_)=>setState((){}),decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:'Search title, client or case number',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border)),contentPadding:const EdgeInsets.symmetric(vertical:15)))),
      const SizedBox(width:12),SizedBox(width:165,child:DropdownButtonFormField<String>(value:_status,decoration:InputDecoration(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border))),items:const ['All','active','upcoming','urgent','completed'].map((v)=>DropdownMenuItem(value:v,child:Text(v=='All'?'All statuses':v[0].toUpperCase()+v.substring(1)))).toList(),onChanged:(v){if(v!=null)setState(()=>_status=v);})),
      const SizedBox(width:12),SizedBox(width:190,child:DropdownButtonFormField<String>(value:_sort,decoration:InputDecoration(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border))),items:const [DropdownMenuItem(value:'nextHearing',child:Text('Next hearing')),DropdownMenuItem(value:'title',child:Text('Case title')),DropdownMenuItem(value:'created',child:Text('Recently updated'))],onChanged:(v){if(v!=null)setState(()=>_sort=v);})),
    ]),
    const SizedBox(height:16),
    Expanded(child:StreamBuilder<List<CaseModel>>(stream:_repo.watchCasesForCurrentUser(searchQuery:_query.text,status:_status,sortBy:_sort),builder:(context,snapshot){
      if(snapshot.hasError)return _empty(Icons.error_outline_rounded,'Search unavailable',snapshot.error.toString());
      if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
      final items=snapshot.data??const <CaseModel>[];
      if(items.isEmpty)return _empty(Icons.search_off_rounded,'No matching cases',_query.text.isEmpty?'No cases are available in this view yet.':'Try a different title, client name, or case number.');
      return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:15),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:WindowsDesktopShell.border))),child:Row(children:[
          Expanded(flex:4,child:Text('CASE REGISTER  ·  ${items.length}',style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('CLIENT',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('NEXT HEARING',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('STATUS',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const SizedBox(width:20),
        ])),
        Expanded(child:ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1,color:WindowsDesktopShell.border),itemBuilder:(context,index){
          final c=items[index];final color=c.isUrgent?const Color(0xFF9A4A3F):c.isCompleted?const Color(0xFF536D5A):WindowsDesktopShell.forest;
          return InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WindowsDesktopShell(activeRoute:'/cases',child:WindowsCaseDetailScreen(caseItem:c)))),child:Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),child:Row(children:[
            Expanded(flex:4,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c.caseTitle,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800),maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:4),Text(c.caseNumber,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10))])),
            Expanded(flex:2,child:Text(c.clientName,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11),maxLines:2,overflow:TextOverflow.ellipsis)),
            Expanded(flex:2,child:Text(c.nextHearingDate==null?'Not scheduled':'${c.nextHearingDate!.day.toString().padLeft(2,'0')}/${c.nextHearingDate!.month.toString().padLeft(2,'0')}/${c.nextHearingDate!.year}',style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11))),
            Expanded(flex:2,child:Align(alignment:Alignment.centerLeft,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:color.withValues(alpha:.09),borderRadius:BorderRadius.circular(7)),child:Text(c.status,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w800))))),
            const Icon(Icons.chevron_right_rounded,color:WindowsDesktopShell.muted,size:19),
          ])));
        })),
      ]));
    })),
  ]))));
  Widget _empty(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));
}
