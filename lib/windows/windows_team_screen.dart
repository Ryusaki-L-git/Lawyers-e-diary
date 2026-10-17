import 'package:flutter/material.dart';

import '../models/team_model.dart';
import '../services/team_service.dart';
import '../screens/team/create_team_screen.dart';
import '../screens/team/team_entry_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsTeamScreen extends StatelessWidget {
  const WindowsTeamScreen({super.key});

  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('COLLABORATIVE PRACTICE',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
        SizedBox(height:7),Text('Team & chambers',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
        SizedBox(height:5),Text('Your firm teams, members and shared practice.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
      ])),
      OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/team',child:TeamEntryScreen()))),icon:const Icon(Icons.dashboard_customize_outlined),label:const Text('Open team workspace'),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border),padding:const EdgeInsets.symmetric(horizontal:15,vertical:15))),
      const SizedBox(width:10),
      FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/team',child:CreateTeamScreen()))),icon:const Icon(Icons.add_rounded),label:const Text('Create team'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:16,vertical:16))),
    ]),
    const SizedBox(height:22),
    Expanded(child:StreamBuilder<List<TeamModel>>(stream:TeamService.instance.watchUserTeams(),builder:(context,snapshot){
      if(snapshot.hasError)return _empty(Icons.error_outline_rounded,'Could not load teams',snapshot.error.toString());
      if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
      final teams=snapshot.data??const <TeamModel>[];
      if(teams.isEmpty)return Center(child:Container(width:520,padding:const EdgeInsets.all(34),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:WindowsDesktopShell.border)),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:66,height:66,decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.groups_2_outlined,color:WindowsDesktopShell.forest,size:32)),
        const SizedBox(height:18),const Text('Build your chamber workspace',style:TextStyle(color:WindowsDesktopShell.ink,fontFamily:'Georgia',fontSize:22,fontWeight:FontWeight.w700)),
        const SizedBox(height:9),const Text('Create a team to organize colleagues, shared matters and team communication. Existing personal cases stay in your personal workspace.',textAlign:TextAlign.center,style:TextStyle(color:WindowsDesktopShell.muted,fontSize:12,height:1.6)),
        const SizedBox(height:22),FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/team',child:CreateTeamScreen()))),icon:const Icon(Icons.add_rounded),label:const Text('Establish firm team'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:18,vertical:15))),
      ])));
      return ListView.separated(itemCount:teams.length,separatorBuilder:(_,__)=>const SizedBox(height:14),itemBuilder:(context,index){
        final team=teams[index];
        return Container(padding:const EdgeInsets.all(21),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:52,height:52,decoration:BoxDecoration(color:WindowsDesktopShell.forest,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.account_balance_rounded,color:WindowsDesktopShell.gold,size:25)),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(team.name,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),
              const SizedBox(height:4),Text(team.lawFirm.isEmpty?'Firm name not specified':team.lawFirm,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12)),
            ])),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(8)),child:Text('\${team.memberCount} members',style:const TextStyle(color:WindowsDesktopShell.forest,fontSize:11,fontWeight:FontWeight.w800))),
            const SizedBox(width:12),OutlinedButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/team',child:TeamEntryScreen()))),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border)),child:const Text('Manage team')),
          ]),
          if(team.description.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:14),child:Text(team.description,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12,height:1.5))),
          const SizedBox(height:17),
          StreamBuilder<List<TeamMembership>>(stream:TeamService.instance.watchMembers(team.id),builder:(context,memberSnapshot){
            if(memberSnapshot.hasError)return Text('Could not load members: \${memberSnapshot.error}',style:const TextStyle(color:Color(0xFF9A4A3F),fontSize:11));
            if(memberSnapshot.connectionState==ConnectionState.waiting&&memberSnapshot.data==null)return const LinearProgressIndicator(color:WindowsDesktopShell.gold);
            final members=memberSnapshot.data??const <TeamMembership>[];
            return Wrap(spacing:9,runSpacing:9,children:[for(final member in members)Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),decoration:BoxDecoration(color:WindowsDesktopShell.canvas,borderRadius:BorderRadius.circular(10)),child:Row(mainAxisSize:MainAxisSize.min,children:[
              Container(width:27,height:27,alignment:Alignment.center,decoration:const BoxDecoration(color:Color(0xFFDDE6DE),shape:BoxShape.circle),child:Text(member.displayName.trim().isEmpty?'?':member.displayName.trim().substring(0,1).toUpperCase(),style:const TextStyle(color:WindowsDesktopShell.forest,fontSize:10,fontWeight:FontWeight.w800))),
              const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(member.displayName.isEmpty?'Team member':member.displayName,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w800)),
                const SizedBox(height:2),Text(member.role.label,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:9)),
              ]),
            ]))]);
          }),
        ]));
      });
    })),
  ]))));

  Widget _empty(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));
}
