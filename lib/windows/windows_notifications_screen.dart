import 'package:flutter/material.dart';
import 'windows_desktop_shell.dart';

class WindowsNotificationsScreen extends StatelessWidget{
  const WindowsNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('WORKSPACE ACTIVITY',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
    const SizedBox(height:7),const Text('Notifications',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
    const SizedBox(height:5),const Text('A central place for important case and practice updates.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
    const SizedBox(height:24),
    Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:560),child:Container(width:double.infinity,padding:const EdgeInsets.all(30),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:WindowsDesktopShell.border)),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:70,height:70,decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(20)),child:const Icon(Icons.notifications_none_rounded,color:WindowsDesktopShell.forest,size:34)),
      const SizedBox(height:18),const Text('No notification feed is connected yet',textAlign:TextAlign.center,style:TextStyle(color:WindowsDesktopShell.ink,fontFamily:'Georgia',fontSize:21,fontWeight:FontWeight.w700)),
      const SizedBox(height:9),const Text('This screen intentionally shows no sample alerts. LED still needs a persistent notification source before real case, team and JURIS events can appear here.',textAlign:TextAlign.center,style:TextStyle(color:WindowsDesktopShell.muted,fontSize:12,height:1.6)),
      const SizedBox(height:22),FilledButton.icon(onPressed:()=>Navigator.of(context).pushReplacementNamed('/reminders'),icon:const Icon(Icons.event_note_outlined),label:const Text('Open reminders'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:18,vertical:15))),
    ])))),
  ]))));
}
