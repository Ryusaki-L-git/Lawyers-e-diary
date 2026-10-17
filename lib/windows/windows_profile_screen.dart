import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/profile/edit_profile_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsProfileScreen extends StatelessWidget{
  const WindowsProfileScreen({super.key});
  @override
  Widget build(BuildContext context){
    final user=FirebaseAuth.instance.currentUser;
    if(user==null)return const Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:Center(child:Text('Please sign in to view your profile.')));
    return Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),builder:(context,snapshot){
      if(snapshot.hasError)return Center(child:Text('Could not load profile: ${snapshot.error}'));
      if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
      final data=snapshot.data?.data()??<String,dynamic>{};
      String value(String key,String fallback)=>((data[key] as String?)?.trim().isNotEmpty==true)?(data[key] as String).trim():fallback;
      final name=value('name',user.displayName??'Advocate');
      return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(30,25,30,32),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('YOUR PROFESSIONAL IDENTITY',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
        const SizedBox(height:7),const Text('Legal profile',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
        const SizedBox(height:5),const Text('Keep your professional and office details up to date.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
        const SizedBox(height:24),
        Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:WindowsDesktopShell.forest,borderRadius:BorderRadius.circular(17)),child:Row(children:[
          Container(width:76,height:76,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0x22FFFFFF),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0x66CCA046))),child:Text(name.trim().isEmpty?'A':name.trim().substring(0,1).toUpperCase(),style:const TextStyle(color:WindowsDesktopShell.gold,fontFamily:'Georgia',fontSize:31,fontWeight:FontWeight.w700))),
          const SizedBox(width:18),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(name,style:const TextStyle(color:Colors.white,fontFamily:'Georgia',fontSize:23,fontWeight:FontWeight.w700)),
            const SizedBox(height:6),Text(value('advocateType','Legal professional'),style:const TextStyle(color:Color(0xFFD8E1D9),fontSize:12)),
            const SizedBox(height:7),Text(user.email??'No email available',style:const TextStyle(color:Color(0xFFB9C7BD),fontSize:11)),
          ])),
          FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/profile',child:EditProfileScreen()))),icon:const Icon(Icons.edit_outlined,size:17),label:const Text('Edit profile'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.gold,foregroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:16,vertical:15))),
        ])),
        const SizedBox(height:20),
        LayoutBuilder(builder:(context,constraints){
          final wide=constraints.maxWidth>850;
          final personal=_section('Personal details',Icons.person_outline_rounded,[
            _row('Full name',name),_row('Email address',value('email',user.email??'Not added')),_row('Phone number',value('phone','Not added')),_row('LED ID',value('ledId','Not assigned')),_row('Advocate category',value('advocateType','Not specified')),
          ]);
          final office=_section('Practice & office',Icons.account_balance_outlined,[
            _row('Qualifications',value('degrees','Not added')),_row('Office address',value('address',value('officeAddress','Not added'))),_row('Court address',value('courtAddress','Not added')),
          ]);
          if(!wide)return Column(children:[personal,const SizedBox(height:15),office]);
          return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:personal),const SizedBox(width:16),Expanded(child:office)]);
        }),
        const SizedBox(height:16),
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13),border:Border.all(color:WindowsDesktopShell.border)),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.verified_user_outlined,color:WindowsDesktopShell.gold,size:21),SizedBox(width:11),Expanded(child:Text('Your profile is shown from the signed-in LED account and its Firestore user document. Only edit details that are accurate and current.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11,height:1.5))),
        ])),
      ]));
    })));
  }
  Widget _section(String title,IconData icon,List<Widget> children)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:WindowsDesktopShell.gold,size:19),const SizedBox(width:9),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:15,fontWeight:FontWeight.w800))]),const SizedBox(height:13),...children]));
  Widget _row(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:140,child:Text(label,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11))),Expanded(child:Text(value,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:12,fontWeight:FontWeight.w700)))]));
}
