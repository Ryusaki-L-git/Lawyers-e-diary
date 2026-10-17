import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_model.dart';
import '../services/firestore_service.dart';
import '../screens/fees/add_fee_screen.dart';
import '../screens/fees/fee_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsFeesScreen extends StatelessWidget {
  const WindowsFeesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service=FirestoreService();
    final money=NumberFormat('#,##0.00','en_US');
    return Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(30,25,30,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('PRACTICE FINANCES',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),
          SizedBox(height:7),Text('Fees & transactions',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:29,fontWeight:FontWeight.w700)),
          SizedBox(height:5),Text('Track agreed fees, received payments and outstanding balances.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:13)),
        ])),
        FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const WindowsDesktopShell(activeRoute:'/fee',child:AddFeeScreen()))),icon:const Icon(Icons.add_rounded),label:const Text('New fee record'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:18,vertical:16))),
      ]),
      const SizedBox(height:22),
      Expanded(child:StreamBuilder<List<FeeModel>>(stream:service.watchFees(),builder:(context,snapshot){
        if(snapshot.hasError)return _empty(Icons.error_outline_rounded,'Could not load fee records',snapshot.error.toString());
        if(snapshot.connectionState==ConnectionState.waiting&&snapshot.data==null)return const Center(child:CircularProgressIndicator(color:WindowsDesktopShell.forest));
        final fees=snapshot.data??const <FeeModel>[];
        final agreed=fees.fold<double>(0,(s,f)=>s+f.agreedTotal);
        final collected=fees.fold<double>(0,(s,f)=>s+f.collectedTotal);
        final pending=fees.fold<double>(0,(s,f)=>s+f.pendingTotal);
        if(fees.isEmpty)return Column(children:[_summary(agreed,collected,pending,money),const Expanded(child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.account_balance_wallet_outlined,size:42,color:WindowsDesktopShell.gold),SizedBox(height:12),Text('No fee records yet',style:TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),SizedBox(height:6),Text('Create a fee record to begin tracking payments.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:12))])))]);
        return Column(children:[
          _summary(agreed,collected,pending,money),
          const SizedBox(height:17),
          Expanded(child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(children:[
            Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:15),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:WindowsDesktopShell.border))),child:Row(children:[
              Expanded(flex:4,child:Text('CLIENT / MATTER  ·  ${fees.length}',style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
              const Expanded(flex:2,child:Text('AGREED',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
              const Expanded(flex:2,child:Text('COLLECTED',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
              const Expanded(flex:2,child:Text('OUTSTANDING',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1))),
              const SizedBox(width:105),
            ])),
            Expanded(child:ListView.separated(itemCount:fees.length,separatorBuilder:(_,__)=>const Divider(height:1,color:WindowsDesktopShell.border),itemBuilder:(context,index){
              final f=fees[index];
              final statusColor=f.status==FeeStatus.settled?const Color(0xFF536D5A):f.status==FeeStatus.partiallyPaid?const Color(0xFF9B782B):WindowsDesktopShell.muted;
              return InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WindowsDesktopShell(activeRoute:'/fee',child:FeeDetailScreen(fee:f)))),child:Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:15),child:Row(children:[
                Expanded(flex:4,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(f.clientName,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:13,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(f.caseTitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:11)),const SizedBox(height:6),Text(f.status.label,style:TextStyle(color:statusColor,fontSize:10,fontWeight:FontWeight.w800))])),
                Expanded(flex:2,child:Text('₹ ${money.format(f.agreedTotal)}',style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700))),
                Expanded(flex:2,child:Text('₹ ${money.format(f.collectedTotal)}',style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11))),
                Expanded(flex:2,child:Text('₹ ${money.format(f.pendingTotal)}',style:TextStyle(color:f.pendingTotal>0?const Color(0xFF9A4A3F):WindowsDesktopShell.forest,fontSize:11,fontWeight:FontWeight.w800))),
                SizedBox(width:105,child:Align(alignment:Alignment.centerRight,child:OutlinedButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>WindowsDesktopShell(activeRoute:'/fee',child:FeeDetailScreen(fee:f)))),style:OutlinedButton.styleFrom(foregroundColor:WindowsDesktopShell.forest,side:const BorderSide(color:WindowsDesktopShell.border)),child:const Text('Details')))),
              ])));
            })),
          ]))),
        ]);
      })),
    ]))));
  }

  Widget _summary(double agreed,double collected,double pending,NumberFormat money)=>Row(children:[
    _stat('TOTAL AGREED',agreed,money,WindowsDesktopShell.forest),
    const SizedBox(width:12),_stat('COLLECTED',collected,money,const Color(0xFF536D5A)),
    const SizedBox(width:12),_stat('OUTSTANDING',pending,money,const Color(0xFF9A4A3F)),
  ]);
  Widget _stat(String label,double amount,NumberFormat money,Color color)=>Expanded(child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1)),const SizedBox(height:9),Text('₹ ${money.format(amount)}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:color,fontSize:21,fontWeight:FontWeight.w800))])));
  Widget _empty(IconData icon,String title,String subtitle)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:42,color:WindowsDesktopShell.gold),const SizedBox(height:12),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:WindowsDesktopShell.muted,fontSize:12))]));
}
