import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/juris_service.dart';
import 'windows_desktop_shell.dart';

class WindowsJurisScreen extends StatefulWidget {
  const WindowsJurisScreen({super.key});
  @override
  State<WindowsJurisScreen> createState()=>_WindowsJurisScreenState();
}
class _WindowsJurisScreenState extends State<WindowsJurisScreen>{
  final _controller=TextEditingController();
  final _scroll=ScrollController();
  final _service=JurisService();
  final _sessionId='\${DateTime.now().microsecondsSinceEpoch}-\${math.Random().nextInt(1<<32)}';
  final List<_JurisMessage> _messages=[const _JurisMessage(false,'Welcome to JURIS. Ask a legal research or case-analysis question. Verify important conclusions against the original statute, judgment, and official source.')];
  bool _busy=false;
  @override
  void dispose(){_controller.dispose();_scroll.dispose();_service.dispose();super.dispose();}

  Future<void> _send([String? suggested])async{
    if(_busy)return;
    final text=(suggested??_controller.text).trim();if(text.isEmpty)return;
    setState((){_messages.add(_JurisMessage(true,text));_busy=true;_controller.clear();});
    _scrollEnd();
    try{
      final response=await _service.sendMessage(message:text,sessionId:_sessionId);
      if(mounted)setState(()=>_messages.add(_JurisMessage(false,response.reply)));
    }catch(e){
      if(mounted)setState(()=>_messages.add(_JurisMessage(false,'I could not complete that request. $e')));
    }finally{if(mounted){setState(()=>_busy=false);_scrollEnd();}}
  }
  void _scrollEnd()=>WidgetsBinding.instance.addPostFrameCallback((_){if(_scroll.hasClients)_scroll.animateTo(_scroll.position.maxScrollExtent,duration:const Duration(milliseconds:220),curve:Curves.easeOut);});

  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,24,30,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      Container(width:48,height:48,decoration:BoxDecoration(color:WindowsDesktopShell.forest,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.balance_rounded,color:WindowsDesktopShell.gold,size:26)),
      const SizedBox(width:14),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('LEGAL INTELLIGENCE',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
        SizedBox(height:5),Text('JURIS',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
        SizedBox(height:3),Text('Research and reasoning for your legal workflow.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:12)),
      ])),
      OutlinedButton.icon(onPressed:()=>setState(()=>_messages..clear()..add(const _JurisMessage(false,'New conversation. Ask a legal research or case-analysis question. Verify important conclusions against original sources.'))),icon:const Icon(Icons.add_rounded),label:const Text('New conversation'),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border),padding:const EdgeInsets.symmetric(horizontal:15,vertical:15))),
    ]),
    const SizedBox(height:18),
    Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFD5E0D7))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.verified_user_outlined,color:WindowsDesktopShell.forest,size:19),SizedBox(width:10),
      Expanded(child:Text('Legal accuracy matters. Confirm citations and legal propositions against official sources. JURIS responses are assistance, not a replacement for professional judgment.',style:TextStyle(color:WindowsDesktopShell.forest,fontSize:11,height:1.5))),
    ])),
    const SizedBox(height:14),
    Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Expanded(flex:7,child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:WindowsDesktopShell.border)),child:Column(children:[
        Expanded(child:ListView.builder(controller:_scroll,padding:const EdgeInsets.all(22),itemCount:_messages.length+(_busy?1:0),itemBuilder:(context,index){
          if(_busy&&index==_messages.length)return const Align(alignment:Alignment.centerLeft,child:Padding(padding:EdgeInsets.all(12),child:SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:WindowsDesktopShell.gold))));
          final m=_messages[index];
          return Align(alignment:m.user?Alignment.centerRight:Alignment.centerLeft,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:Container(margin:const EdgeInsets.only(bottom:13),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:m.user?WindowsDesktopShell.forest:WindowsDesktopShell.canvas,borderRadius:BorderRadius.circular(13),border:m.user?null:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(m.user?'YOU':'JURIS',style:TextStyle(color:m.user?WindowsDesktopShell.gold:WindowsDesktopShell.forest,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:1.1)),
            const SizedBox(height:8),SelectableText(m.text,style:TextStyle(color:m.user?Colors.white:WindowsDesktopShell.ink,fontSize:13,height:1.55)),
          ]))));
        })),
        Container(padding:const EdgeInsets.all(14),decoration:const BoxDecoration(border:Border(top:BorderSide(color:WindowsDesktopShell.border))),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Expanded(child:TextField(controller:_controller,minLines:1,maxLines:5,onSubmitted:(_)=>_send(),decoration:InputDecoration(hintText:'Ask JURIS about a legal issue…',filled:true,fillColor:WindowsDesktopShell.canvas,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:WindowsDesktopShell.border)),contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:14)))),
          const SizedBox(width:10),FilledButton(onPressed:_busy?null:()=>_send(),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.all(17)),child:const Icon(Icons.arrow_upward_rounded)),
        ])),
      ]))),
      const SizedBox(width:16),
      SizedBox(width:270,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('START WITH A TASK',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.2)),
        const SizedBox(height:10),
        _suggestion(Icons.policy_outlined,'Research a legal issue','Summarize the legal framework and identify official sources to verify.',()=>_send('Help me research a legal issue. Ask me for the jurisdiction and specific legal question if needed.')),
        _suggestion(Icons.account_balance_outlined,'Analyze a judgment','Extract the holding, reasoning, and issues that need verification.',()=>_send('Help me analyze a judgment. Ask me to provide the judgment text or official source first.')),
        _suggestion(Icons.edit_document,'Structure a draft','Create an outline from facts and relief sought, flagging missing information.',()=>_send('Help me structure a legal draft. Ask for the jurisdiction, document type, facts, and relief sought.')),
        const Spacer(),
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13),border:Border.all(color:WindowsDesktopShell.border)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.fact_check_outlined,color:WindowsDesktopShell.gold,size:22),SizedBox(height:10),
          Text('Accuracy over fluency',style:TextStyle(color:WindowsDesktopShell.ink,fontSize:12,fontWeight:FontWeight.w800)),
          SizedBox(height:5),Text('Check case names, citations, dates and current legal status against primary sources.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11,height:1.5)),
        ])),
      ])),
    ])),
  ]))));

  Widget _suggestion(IconData icon,String title,String subtitle,VoidCallback onTap)=>Padding(padding:const EdgeInsets.only(bottom:9),child(Material(color:Colors.white,borderRadius:BorderRadius.circular(13),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(13),child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(icon,color:WindowsDesktopShell.gold,size:18),const SizedBox(width:8),Expanded(child:Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:12,fontWeight:FontWeight.w800)))]),
    const SizedBox(height:7),Text(subtitle,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,height:1.4)),
  ])))));
}
class _JurisMessage{const _JurisMessage(this.user,this.text);final bool user;final String text;}
