import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../repositories/case_repository.dart';
import 'windows_desktop_shell.dart';

class WindowsAddCaseScreen extends StatefulWidget{
  const WindowsAddCaseScreen({super.key});
  @override
  State<WindowsAddCaseScreen> createState()=>_WindowsAddCaseScreenState();
}
class _WindowsAddCaseScreenState extends State<WindowsAddCaseScreen>{
  final _form=GlobalKey<FormState>();
  final _repo=CaseRepository(database:AppDatabase.instance);
  final _title=TextEditingController(),_number=TextEditingController(),_client=TextEditingController(),_opponent=TextEditingController(),_court=TextEditingController(),_phone=TextEditingController(),_handler=TextEditingController(),_notes=TextEditingController();
  String _type='Civil Case',_status='active';DateTime? _hearing;bool _saving=false;
  @override void dispose(){for(final c in [_title,_number,_client,_opponent,_court,_phone,_handler,_notes]){c.dispose();}super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:WindowsDesktopShell.canvas,body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(30,25,30,32),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1050),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[IconButton(onPressed:()=>Navigator.of(context).pop(),icon:const Icon(Icons.arrow_back_rounded),tooltip:'Back'),const SizedBox(width:8),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('MASTER DOCKET',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.5)),SizedBox(height:6),Text('Register a case',style:TextStyle(fontFamily:'Georgia',color:WindowsDesktopShell.forest,fontSize:28,fontWeight:FontWeight.w700))])),if(_saving)const CircularProgressIndicator(color:WindowsDesktopShell.forest)else FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save case'),style:FilledButton.styleFrom(backgroundColor:WindowsDesktopShell.forest,padding:const EdgeInsets.symmetric(horizontal:18,vertical:16)))]),
    const SizedBox(height:20),
    LayoutBuilder(builder:(context,constraints){
      final wide=constraints.maxWidth>800;
      final left=Column(children:[
        _panel('Matter details',Icons.folder_outlined,[
          _field('Case title *',_title,'Enter the matter title'),
          _field('Case / CNR number',_number,'Enter official case number'),
          _dropdown('Case type',_type,const ['Civil Case','Criminal','Corporate','Family','Constitutional','Tax','Labor','Appellate'],(v)=>setState(()=>_type=v)),
          _dropdown('Status',_status,const ['active','upcoming','urgent'],(v)=>setState(()=>_status=v)),
        ]),
        const SizedBox(height:15),
        _panel('Court & hearing',Icons.account_balance_outlined,[
          _field('Court / forum',_court,'Court or tribunal name'),
          _dateField(),
          _field('Handled by',_handler,'Advocate or assigned handler'),
        ]),
      ]);
      final right=Column(children:[
        _panel('Parties & contact',Icons.people_outline_rounded,[
          _field('Client name *',_client,'Client or entity name'),
          _field('Opposing party',_opponent,'Opposing party name',required:false),
          _field('Client phone',_phone,'Contact number',required:false,type:TextInputType.phone),
        ]),
        const SizedBox(height:15),
        _panel('Initial notes',Icons.notes_rounded,[_field('Notes',_notes,'Key facts, next steps or preparation notes',required:false,maxLines:6)]),
      ]);
      if(!wide)return Column(children:[left,const SizedBox(height:15),right]);
      return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:left),const SizedBox(width:16),Expanded(child:right)]);
    }),
    const SizedBox(height:14),
    const Text('New cases are saved through the existing authenticated local case repository.',style:TextStyle(color:WindowsDesktopShell.muted,fontSize:11)),
  ])))))),
  );
  Widget _panel(String title,IconData icon,List<Widget> fields)=>Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:WindowsDesktopShell.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:WindowsDesktopShell.gold,size:19),const SizedBox(width:9),Text(title,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:14,fontWeight:FontWeight.w800))]),const SizedBox(height:16),...fields]));
  Widget _field(String label,TextEditingController c,String hint,{bool required=true,TextInputType type=TextInputType.text,int maxLines=1})=>Padding(padding:const EdgeInsets.only(bottom:13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:7),TextFormField(controller:c,maxLines:maxLines,keyboardType:type,decoration:InputDecoration(hintText:hint,filled:true,fillColor:WindowsDesktopShell.canvas,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:WindowsDesktopShell.border)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:WindowsDesktopShell.border)),contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:13)),validator:required?(v)=>(v==null||v.trim().isEmpty)?'This field is required':null:null)]));
  Widget _dropdown(String label,String value,List<String> options,ValueChanged<String> changed)=>Padding(padding:const EdgeInsets.only(bottom:13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:7),DropdownButtonFormField<String>(value:value,decoration:InputDecoration(filled:true,fillColor:WindowsDesktopShell.canvas,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:WindowsDesktopShell.border)),contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:10)),items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)changed(v);})]));
  Widget _dateField()=>Padding(padding:const EdgeInsets.only(bottom:13),child(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Next hearing date',style:TextStyle(color:WindowsDesktopShell.ink,fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:7),InkWell(onTap:_pickDate,child:Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:13,vertical:14),decoration:BoxDecoration(color:WindowsDesktopShell.canvas,borderRadius:BorderRadius.circular(10),border:Border.all(color:WindowsDesktopShell.border)),child:Row(children:[const Icon(Icons.calendar_month_outlined,color:WindowsDesktopShell.forest,size:18),const SizedBox(width:10),Expanded(child:Text(_hearing==null?'Select a date':'\${_hearing!.day.toString().padLeft(2,'0')}/\${_hearing!.month.toString().padLeft(2,'0')}/\${_hearing!.year}',style:const TextStyle(color:WindowsDesktopShell.ink,fontSize:12))),if(_hearing!=null)IconButton(onPressed:()=>setState(()=>_hearing=null),icon:const Icon(Icons.close_rounded,size:17))])))]));
  Future<void> _pickDate()async{final now=DateTime.now();final d=await showDatePicker(context:context,initialDate:_hearing??now,firstDate:DateTime(now.year-5),lastDate:DateTime(now.year+10));if(d!=null&&mounted)setState(()=>_hearing=d);}
  Future<void> _save()async{
    if(!_form.currentState!.validate())return;
    setState(()=>_saving=true);
    try{
      await _repo.createCase(caseTitle:_title.text.trim(),caseNumber:_number.text.trim(),clientName:_client.text.trim(),opponentName:_opponent.text.trim(),courtName:_court.text.trim(),caseType:_type,status:_status,handledBy:_handler.text.trim().isEmpty?'Counsel':_handler.text.trim(),clientPhone:_phone.text.trim().isEmpty?null:_phone.text.trim(),nextHearingDate:_hearing,notes:_notes.text.trim().isEmpty?const []:_notes.text.trim().split('\n'));
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Case saved to your docket.')));Navigator.of(context).pop();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save case: $e')));}
    finally{if(mounted)setState(()=>_saving=false);}
  }
}
