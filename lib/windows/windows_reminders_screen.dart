import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder_model.dart';
import '../services/firestore_service.dart';
import '../screens/reminders/add_reminder_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsRemindersScreen extends StatefulWidget {
  const WindowsRemindersScreen({super.key});
  @override
  State<WindowsRemindersScreen> createState() => _WindowsRemindersScreenState();
}

class _WindowsRemindersScreenState extends State<WindowsRemindersScreen> {
  final _service = FirestoreService();
  String _filter = 'All';
  final _dateFormat = DateFormat('dd MMM yyyy · HH:mm');

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WindowsDesktopShell.canvas,
    body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(30,25,30,28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRACTICE ORGANIZATION',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
          SizedBox(height:7),Text('Reminders',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
          SizedBox(height:5),Text('Keep deadlines and follow-ups visible.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
        ])),
        FilledButton.icon(onPressed:_add,icon:const Icon(Icons.add_rounded),label:const Text('New reminder'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:18,vertical:16))),
      ]),
      const SizedBox(height:22),
      Row(children:[for(final f in const ['All','Pending','Completed']) Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(f),selected:_filter==f,onSelected:(_)=>setState(()=>_filter=f),selectedColor:WindowsDesktopShell.forest,backgroundColor:Colors.white,labelStyle:TextStyle(color:_filter==f?Colors.white:WindowsDesktopShell.ink,fontWeight:FontWeight.w700),side:const BorderSide(color:WindowsDesktopShell.border))))]),
      const SizedBox(height:15),
      Expanded(child:StreamBuilder<List<ReminderModel>>(stream:_service.watchReminders(showCompleted:true),builder:(context,snapshot){
        if(snapshot.hasError)return _empty('Could not load reminders',snapshot.error.toString());
        if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
        var items=snapshot.data??const <ReminderModel>[];
        if(_filter=='Pending')items=items.where((r)=>!r.isCompleted).toList();
        if(_filter=='Completed')items=items.where((r)=>r.isCompleted).toList();
        if(items.isEmpty)return _empty('Nothing to follow up on',_filter=='All'?'Create a reminder for a deadline or client follow-up.':'There are no reminders in this view.');
        return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:15),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:WindowsDesktopShell.border))),child:Row(children:[
            Expanded(flex:4,child:Text('REMINDER  ·  ${items.length}',style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
            const Expanded(flex:3,child:Text('RELATED MATTER',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
            const Expanded(flex:2,child:Text('DUE',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
            const SizedBox(width:86),
          ])),
          Expanded(child:ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1,color:WindowsDesktopShell.border),itemBuilder:(context,index){
            final r=items[index];final overdue=r.isOverdue&&!r.isCompleted;
            final status=r.isCompleted?'Completed':overdue?'Overdue':'Upcoming';
            final statusColor=r.isCompleted?const Color(0xFF536D5A):overdue?const Color(0xFF9A4A3F):WindowsDesktopShell.forest;
            return Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:13),child:Row(children:[
              Container(width:38,height:38,decoration:BoxDecoration(color:statusColor.withValues(alpha:.09),borderRadius:BorderRadius.circular(10)),child:Icon(r.isCompleted?Icons.check_circle_outline_rounded:overdue?Icons.warning_amber_rounded:Icons.notifications_none_rounded,color:statusColor,size:19)),
              const SizedBox(width:12),
              Expanded(flex:4,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(r.title,style:TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800,decoration:r.isCompleted?TextDecoration.lineThrough:null)),
                if((r.description??'').trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text(r.description!,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11))),
                const SizedBox(height:5),Text(status,style:TextStyle(color:statusColor,fontSize:10,fontWeight:FontWeight.w800)),
              ])),
              Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((r.caseTitle??'').isEmpty?'General reminder':r.caseTitle!,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700)),
                if((r.clientName??'').isNotEmpty)Text(r.clientName!,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10)),
              ])),
              Expanded(flex:2,child:Text(_dateFormat.format(r.dueDateTime),style:TextStyle(color:overdue?const Color(0xFF9A4A3F):WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700))),
              SizedBox(width:86,child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                IconButton(tooltip:r.isCompleted?'Mark pending':'Mark completed',onPressed:()=>_service.toggleReminderDone(r.id,r.isCompleted),icon:Icon(r.isCompleted?Icons.undo_rounded:Icons.check_rounded,color:WindowsDesktopShell.forest,size:19)),
                IconButton(tooltip:'Delete reminder',onPressed:()=>_delete(r),icon:const Icon(Icons.delete_outline_rounded,color:Color(0xFF9A4A3F),size:19)),
              ])),
            ]));
          })),
        ]));
      })),
    ]))),
  );

  Widget _empty(String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.notifications_none_rounded,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));

  Future<void> _add() async { await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/reminders',child:AddReminderScreen()))); }
  Future<void> _delete(ReminderModel r) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete reminder?'),content:Text('“${r.title}” will be permanently deleted.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(ok==true)await _service.deleteReminder(r.id);
  }
}
