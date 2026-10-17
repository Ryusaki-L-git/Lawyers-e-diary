import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/case_model.dart';
import '../data/local/app_database.dart';
import '../repositories/case_repository.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsCauseListScreen extends StatefulWidget{
  const WindowsCauseListScreen({super.key});
  @override
  State<WindowsCauseListScreen> createState()=>_WindowsCauseListScreenState();
}
class _WindowsCauseListScreenState extends State<WindowsCauseListScreen>{
  DateTime _date=DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
  final _service=CaseRepository(database:AppDatabase.instance);
  final _dateFormat=DateFormat('EEEE, dd MMMM yyyy');
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('DAILY COURT DOCKET',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
        SizedBox(height:7),Text('Cause list',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
        SizedBox(height:5),Text('Review the matters scheduled for a selected hearing date.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
      ])),
      OutlinedButton.icon(onPressed:_pickDate,icon:const Icon(Icons.calendar_month_outlined),label:Text(DateFormat('dd MMM yyyy').format(_date)),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border),padding:const EdgeInsets.symmetric(horizontal:16,vertical:15))),
      const SizedBox(width:10),FilledButton.icon(onPressed:()=>Navigator.of(context).pushNamed('/add_case'),icon:const Icon(Icons.add_rounded),label:const Text('Add case'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:16,vertical:15))),
    ]),
    const SizedBox(height:20),
    Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:WindowsDesktopShell.forest,borderRadius:BorderRadius.circular(15)),child:Row(children:[
      Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0x22FFFFFF),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.gavel_rounded,color:WindowsDesktopShell.gold,size:23)),
      const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(_dateFormat.format(_date),style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),const Text('Your case register · hearing dates currently recorded in LED',style:TextStyle(color:Color(0xFFD8E1D9),fontSize:11)),
      ])),
      TextButton.icon(onPressed:()=>setState(()=>_date=DateTime.now()),icon:const Icon(Icons.today_rounded,color:WindowsDesktopShell.gold,size:17),label:const Text('Today',style:TextStyle(color:Colors.white))),
    ])),
    const SizedBox(height:16),
    Expanded(child:StreamBuilder<List<CaseModel>>(stream:_service.watchCasesForCurrentUser(hearingDateFrom:_date,hearingDateTo:_date.add(const Duration(days:1)).subtract(const Duration(microseconds:1)),sortBy:'nextHearing'),builder:(context,snapshot){
      if(snapshot.hasError)return _empty(Icons.error_outline_rounded,'Could not load cause list',snapshot.error.toString());
      if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
      final cases=snapshot.data??const <CaseModel>[];
      if(cases.isEmpty)return _empty(Icons.event_available_outlined,'No matters scheduled', 'No cases in your accessible docket have a hearing date recorded for this day.');
      return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:15),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:WindowsDesktopShell.border))),child:Row(children:[
          Expanded(flex:4,child:Text('MATTER  ·  \${cases.length}',style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('CLIENT',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('COURT / FORUM',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const Expanded(flex:2,child:Text('STATUS',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
          const SizedBox(width:20),
        ])),
        Expanded(child:ListView.separated(itemCount:cases.length,separatorBuilder:(_,__)=>const Divider(height:1,color:WindowsDesktopShell.border),itemBuilder:(context,index){
          final c=cases[index];
          final urgent=c.isUrgent;
          final color=urgent?const Color(0xFF9A4A3F):c.isCompleted?const Color(0xFF536D5A):WindowsDesktopShell.forest;
          return InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WindowsDesktopShell(activeRoute:'/cases',child:WindowsCaseDetailScreen(caseItem:c)))),child:Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),child:Row(children:[
            Expanded(flex:4,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(c.caseTitle,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800),maxLines:2,overflow:TextOverflow.ellipsis),
              const SizedBox(height:4),Text(c.caseNumber,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10)),
            ])),
            Expanded(flex:2,child:Text(c.clientName,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11),maxLines:2,overflow:TextOverflow.ellipsis)),
            Expanded(flex:2,child:Text(c.courtName,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11),maxLines:2,overflow:TextOverflow.ellipsis)),
            Expanded(flex:2,child:Align(alignment:Alignment.centerLeft,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:color.withValues(alpha:.09),borderRadius:BorderRadius.circular(7)),child:Text(c.status,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w800))))),
            const Icon(Icons.chevron_right_rounded,color:WindowsDesktopShell.muted,size:19),
          ])));
        })),
      ]));
    })),
  ]))));
  Future<void> _pickDate()async{
    final picked=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(DateTime.now().year-5),lastDate:DateTime(DateTime.now().year+10));
    if(picked!=null&&mounted)setState(()=>_date=DateTime(picked.year,picked.month,picked.day));
  }
  Widget _empty(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));
}
