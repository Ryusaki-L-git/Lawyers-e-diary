import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'windows_desktop_shell.dart';

class WindowsSettingsScreen extends StatelessWidget {
  const WindowsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user=FirebaseAuth.instance.currentUser;
    return Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(30,25,30,32),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('WORKSPACE PREFERENCES',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
      const SizedBox(height:7),const Text('Settings',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
      const SizedBox(height:5),const Text('Manage your LED workspace and account tools.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
      const SizedBox(height:24),
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:WindowsDesktopShell.forest,borderRadius:BorderRadius.circular(16)),child:Row(children:[
        Container(width:56,height:56,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0x22FFFFFF),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0x66CCA046))),child:const Icon(Icons.manage_accounts_outlined,color:WindowsDesktopShell.gold,size:29)),
        const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(user?.displayName?.trim().isNotEmpty==true?user!.displayName!:'Your LED account',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
          const SizedBox(height:5),Text(user?.email??'No signed-in email available',style:const TextStyle(color:Color(0xFFD8E1D9),fontSize:12)),
          const SizedBox(height:7),const Text('Account details are read from the current authentication session.',style:TextStyle(color:Color(0xFFB9C7BD),fontSize:10)),
        ])),
        OutlinedButton(onPressed:()=>Navigator.of(context).pushReplacementNamed('/profile'),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Color(0x66FFFFFF))),child:const Text('Open profile')),
      ])),
      const SizedBox(height:22),
      const Text('PREFERENCES & SERVICES',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.2)),
      const SizedBox(height:12),
      _SettingTile(icon:Icons.tune_rounded,title:'Application settings',subtitle:'General preferences and app behavior',route:'/settings_native',onTap:()=>Navigator.of(context).pushNamed('/settings_native')),
      _SettingTile(icon:Icons.security_outlined,title:'Security & access',subtitle:'Password recovery and account access',route:'/security',onTap:()=>Navigator.of(context).pushNamed('/security')),
      _SettingTile(icon:Icons.cloud_outlined,title:'Cloud storage',subtitle:'Review available storage options',route:'/cloud_storage',onTap:()=>Navigator.of(context).pushNamed('/cloud_storage')),
      _SettingTile(icon:Icons.workspace_premium_outlined,title:'Plans & upgrades',subtitle:'Review available plan information',route:'/upgrade',onTap:()=>Navigator.of(context).pushNamed('/upgrade')),
      _SettingTile(icon:Icons.help_outline_rounded,title:'Help & support',subtitle:'Get help with your LED workspace',route:'/support',onTap:()=>Navigator.of(context).pushNamed('/support')),
      const SizedBox(height:14),
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13),border:Border.all(color:WindowsDesktopShell.border)),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(Icons.shield_outlined,color:WindowsDesktopShell.gold,size:22),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Keep your legal workspace secure',style:TextStyle(color:WindowsDesktopShell.ink,fontSize:12,fontWeight:FontWeight.w800)),
          SizedBox(height:5),Text('Use your own account, protect access to your device, and verify that case data is shared only with authorized people.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11,height:1.5)),
        ])),
      ])),
    ]))));
  }
}

class _SettingTile extends StatelessWidget{
  const _SettingTile({required this.icon,required this.title,required this.subtitle,required this.route,required this.onTap});
  final IconData icon;final String title;final String subtitle;final String route;final VoidCallback onTap;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Material(color:Colors.white,borderRadius:BorderRadius.circular(13),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(13),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),border:Border.all(color:WindowsDesktopShell.border)),child:Row(children:[
    Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE9EEE9),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:WindowsDesktopShell.forest,size:21)),
    const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11))])),
    const Icon(Icons.chevron_right_rounded,color:WindowsDesktopShell.muted),
  ])))));
}
