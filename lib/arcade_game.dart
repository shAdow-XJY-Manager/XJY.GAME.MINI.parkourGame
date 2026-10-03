import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'arcade_style.dart';
import 'game_engine.dart';
import 'game_platform.dart' as platform;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,
    title:'终端跑酷 · 频率站',theme:arcadeTheme(),home:const RunnerArcade());
}
class RunnerArcade extends StatefulWidget {
  const RunnerArcade({super.key});
  @override State<RunnerArcade> createState()=>_RunnerArcadeState();
}
class _RunnerArcadeState extends State<RunnerArcade> with SingleTickerProviderStateMixin,WidgetsBindingObserver {
  RunnerEngine game=RunnerEngine();
  final FocusNode focus=FocusNode();
  final ValueNotifier<int> frames=ValueNotifier(0);
  late Ticker ticker;
  Duration? previous;
  final Map<String,ui.Image> images={};
  final List<(ImageStream,ImageStreamListener)> streams=[];
  final Set<IconData> pointerActions={};
  bool sound=true,reduced=false,saved=true;
  int unlocked=0,best=0;
  double? bestTime;
  @override void initState(){
    super.initState();sound=platform.readValue('manager.arcade.runner.sound.v1')!='off';
    reduced=platform.readValue('manager.arcade.runner.motion.v1')=='reduce'||platform.systemReducedMotion();
    unlocked=(int.tryParse(platform.readValue('manager.arcade.runner.unlocked.v1')??'0')??0).clamp(0,2).toInt();
    _readBest();ticker=createTicker(_tick)..start();WidgetsBinding.instance.addObserver(this);platform.watchSuspension(_pause);
  }
  @override void didChangeDependencies(){
    super.didChangeDependencies();if(streams.isNotEmpty)return;
    for(final name in ['runner-track.webp','runner.png','runner-jump.png','runner-slide.png']){
      final stream=NetworkImage(platform.gameAsset('game-assets/$name')).resolve(createLocalImageConfiguration(context));
      final listener=ImageStreamListener((info,_){if(mounted){images[name]=info.image;frames.value++;}},onError:(Object _,StackTrace? __){});
      streams.add((stream,listener));stream.addListener(listener);
    }
  }
  void _readBest(){best=int.tryParse(platform.readValue('manager.arcade.runner.best.${game.level}.v1')??'0')??0;
    bestTime=double.tryParse(platform.readValue('manager.arcade.runner.time.${game.level}.v1')??'');}
  void _record(){
    if(game.score>best){best=game.score;saved=platform.writeValue('manager.arcade.runner.best.${game.level}.v1','$best');}
    if(game.status==RunnerStatus.cleared){
      if(bestTime==null||game.elapsed<bestTime!){bestTime=game.elapsed;saved=platform.writeValue('manager.arcade.runner.time.${game.level}.v1','${game.elapsed}')&&saved;}
      unlocked=max(unlocked,min(2,game.level+1));saved=platform.writeValue('manager.arcade.runner.unlocked.v1','$unlocked')&&saved;
    }
  }
  void _tick(Duration now){
    final old=previous;previous=now;if(old==null||game.status!=RunnerStatus.playing)return;
    final before=game.status; final coins=game.collected,jumps=game.jumps;
    game.advance((now-old).inMicroseconds/1000000);
    if(sound){if(game.collected>coins)platform.playTone('collect');else if(game.jumps>jumps)platform.playTone('jump');}
    frames.value++;
    if(before!=game.status){if(game.status==RunnerStatus.failed||game.status==RunnerStatus.cleared){_record();if(sound)platform.playTone(game.status==RunnerStatus.cleared?'win':'fail');}setState((){});}
  }
  void _start(){setState((){game.start();previous=null;});focus.requestFocus();if(sound)platform.playTone('tap');}
  void _retry([int? level]){setState((){game=RunnerEngine(level:level??game.level);previous=null;_readBest();});frames.value++;focus.requestFocus();}
  void _pause(){if(!mounted||game.status!=RunnerStatus.playing)return;setState((){game.pause();previous=null;});frames.value++;}
  void _resume(){setState((){game.resume();previous=null;});focus.requestFocus();}
  void _jump(){game.jump();focus.requestFocus();}
  void _slide(bool pressed){final before=game.slideHeld;game.slide(pressed);if(before!=game.slideHeld&&mounted)setState((){});frames.value++;focus.requestFocus();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed)_pause();}
  KeyEventResult _key(FocusNode _,KeyEvent event){
    final key=event.logicalKey;
    final jump=key==LogicalKeyboardKey.space||key==LogicalKeyboardKey.arrowUp||key==LogicalKeyboardKey.keyW;
    final slide=key==LogicalKeyboardKey.arrowDown||key==LogicalKeyboardKey.keyS;
    if(event is KeyUpEvent){if(jump)game.releaseJump();if(slide)_slide(false);return jump||slide?KeyEventResult.handled:KeyEventResult.ignored;}
    if(event is! KeyDownEvent)return KeyEventResult.ignored;
    if(key==LogicalKeyboardKey.escape||key==LogicalKeyboardKey.keyP){if(game.status==RunnerStatus.paused){_resume();}else{_pause();}return KeyEventResult.handled;}
    if(key==LogicalKeyboardKey.enter&&game.status==RunnerStatus.ready){_start();return KeyEventResult.handled;}
    if(key==LogicalKeyboardKey.keyR&&(game.status==RunnerStatus.failed||game.status==RunnerStatus.cleared)){_retry();return KeyEventResult.handled;}
    if(game.status==RunnerStatus.playing){if(jump){_jump();return KeyEventResult.handled;}if(slide){_slide(true);return KeyEventResult.handled;}}
    return KeyEventResult.ignored;
  }
  Widget _heldButton(String label,IconData icon,VoidCallback down,VoidCallback up,{VoidCallback? activate}) {
    final textSize=MediaQuery.textScalerOf(context).scale(14);
    final screenWidth=MediaQuery.of(context).size.width;
    return Listener(
      onPointerDown:game.status==RunnerStatus.playing?(_){pointerActions.add(icon);down();}:null,
      onPointerUp:(_){up();scheduleMicrotask(()=>pointerActions.remove(icon));},
      onPointerCancel:(_){pointerActions.remove(icon);up();},
      child:SizedBox(width:textSize>21?min(240.0,screenWidth-32):min(144.0,(screenWidth-44)/2),child:OutlinedButton.icon(
        style:OutlinedButton.styleFrom(minimumSize:const Size(48,56)),
        onPressed:game.status==RunnerStatus.playing?(){if(!pointerActions.remove(icon)){(activate??down)();}}:null,
        icon:Icon(icon),label:Text(label))));
  }
  @override void dispose(){platform.unwatchSuspension();WidgetsBinding.instance.removeObserver(this);ticker.dispose();focus.dispose();frames.dispose();for(final pair in streams){pair.$1.removeListener(pair.$2);}super.dispose();}
  @override Widget build(BuildContext context)=>arcadeMotion(context,reduced,Focus(focusNode:focus,autofocus:true,onKeyEvent:_key,
    child:Scaffold(body:SafeArea(child:SingleChildScrollView(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1120),child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      ArcadeHeader(title:'终端跑酷',subtitle:'跳过路障 · 滑过横梁 · 抵达终点',sound:sound,reduced:reduced,playing:game.status==RunnerStatus.playing,
        toggleSound:(){setState(()=>sound=!sound);platform.writeValue('manager.arcade.runner.sound.v1',sound?'on':'off');},
        toggleMotion:(){setState(()=>reduced=!reduced);platform.writeValue('manager.arcade.runner.motion.v1',reduced?'reduce':'full');},pause:_pause),
      ValueListenableBuilder<int>(valueListenable:frames,builder:(context,_,child)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[Readout('路线','${game.level+1} / 3'),const SizedBox(width:8),Readout('分数','${game.score}',color:FrequencyPalette.accent),
          const SizedBox(width:8),Readout('金币','${game.collected}'),const SizedBox(width:8),Readout('时间','${game.elapsed.toStringAsFixed(1)} 秒'),const SizedBox(width:8),Readout('本关纪录','$best')])),
        const SizedBox(height:12),LinearProgressIndicator(value:game.progress,minHeight:6,backgroundColor:FrequencyPalette.border),
      ])),const SizedBox(height:16),
      LayoutBuilder(builder:(context,c){
        final ratio=c.maxWidth<600?1.25:16/9;
        final height=min(c.maxWidth/ratio,max(200.0,MediaQuery.of(context).size.height-(c.maxWidth<600?360:300)));
        return Center(child:SizedBox(width:height*ratio,height:height,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Stack(fit:StackFit.expand,children:[
        Semantics(label:'跑酷路线，使用下方跳跃和滑行控制',child:RepaintBoundary(child:CustomPaint(painter:_RunnerPainter(game,images,reduced,frames)))),
        if(game.status==RunnerStatus.ready)GamePanel(title:'路线 ${game.level+1} · ${['热身','节奏','冲刺'][game.level]}',
          text:'抵达终点，金币可以不拿。\nSpace / ↑ 跳跃，松开可短跳；↓ 按住滑行。\n触屏使用下方两个按钮。',action:'开始跑酷',onAction:_start),
        if(game.status==RunnerStatus.paused)GamePanel(title:'跑道已暂停',text:'角色、障碍和计时都已冻结。',action:'继续跑酷',onAction:_resume,
          extra:TextButton(onPressed:()=>_retry(),child:const Text('重新开始路线'))),
        if(game.status==RunnerStatus.failed)GamePanel(title:'这次停在了这里',text:'${game.reason}\n${game.score} 分 · ${game.collected} 枚金币${saved?'':' · 未能保存纪录'}',action:'立即重试',onAction:()=>_retry()),
        if(game.status==RunnerStatus.cleared)GamePanel(title:game.level==2?'三条路线都完成了':'终点抵达',text:'${game.score} 分 · ${game.collected} 枚金币\n${game.elapsed.toStringAsFixed(1)} 秒${saved?' · 已保存':' · 未能保存纪录'}',
          action:game.level<2?'下一条路线':'再跑一遍',onAction:()=>_retry(game.level<2?game.level+1:game.level)),
      ]))));}),const SizedBox(height:16),
      Center(child:Wrap(spacing:12,runSpacing:8,children:[_heldButton('跳跃',Icons.keyboard_arrow_up,_jump,()=>game.releaseJump()),
        _heldButton(game.slideHeld?'松开滑行':'按住滑行',Icons.keyboard_arrow_down,()=>_slide(true),()=>_slide(false),activate:()=>_slide(!game.slideHeld))])),
      const SizedBox(height:16),const Text('提前起跳，给落地留点空间。P / Esc 暂停，结束后 R 重试。',style:TextStyle(color:FrequencyPalette.muted)),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:List.generate(3,(i)=>OutlinedButton(onPressed:game.status==RunnerStatus.playing||i>unlocked?null:()=>_retry(i),
        child:Text(i>unlocked?'路线 ${i+1} · 未解锁':'路线 ${i+1}')))),const SizedBox(height:24),
    ])))))))));
}
class _RunnerPainter extends CustomPainter {
  final RunnerEngine game;final Map<String,ui.Image> images;final bool reduced;
  _RunnerPainter(this.game,this.images,this.reduced,Listenable repaint):super(repaint:repaint);
  @override void paint(Canvas canvas,Size size){
    final width=(size.width/size.height*540).clamp(640.0,960.0).toDouble();
    final scale=min(size.width/width,size.height/540);
    canvas.drawRect(Offset.zero&size,Paint()..color=FrequencyPalette.background);
    canvas.save();canvas.scale(scale);
    final background=images['runner-track.webp'];
    if(background!=null){canvas.drawImageRect(background,Rect.fromLTWH(0,0,width,540),Rect.fromLTWH(0,0,width,540),Paint());}
    canvas.drawLine(const Offset(0,RunnerEngine.ground),Offset(width,RunnerEngine.ground),Paint()..color=FrequencyPalette.amber..strokeWidth=3);
    for(final o in game.obstacles){final x=o.x-game.distance+180;if(x < -100||x>width+100)continue;
      final bottom=o.overhead?RunnerEngine.ground-42:RunnerEngine.ground;
      final r=Rect.fromLTWH(x,bottom-o.height,o.width,o.height);
      canvas.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(4)),Paint()..color=FrequencyPalette.border);
      canvas.drawRect(Rect.fromLTWH(x+3,bottom-o.height+3,o.width-6,6),Paint()..color=o.overhead?FrequencyPalette.accent:FrequencyPalette.amber);
    }
    for(final c in game.coins){if(c.collected)continue;final x=c.x-game.distance+180;if(x < -20||x>width+20)continue;
      final center=Offset(x,RunnerEngine.ground-c.aboveGround);
      canvas.drawCircle(center,9,Paint()..color=FrequencyPalette.amber);canvas.drawCircle(center,4,Paint()..color=FrequencyPalette.background);
    }
    final feet=RunnerEngine.ground+game.offset;
    final image=images[game.sliding?'runner-slide.png':(!game.grounded?'runner-jump.png':'runner.png')]??images['runner.png'];
    if(image!=null){
      final source=game.sliding&&images['runner-slide.png']!=null?const Rect.fromLTWH(20,16,119,52):
        (!game.grounded&&images['runner-jump.png']!=null?const Rect.fromLTWH(17,11,93,113):const Rect.fromLTWH(6,5,118,148));
      final h=game.sliding?32.0:72.0,w=h*source.width/source.height;
      canvas.drawImageRect(image,source,Rect.fromLTWH(164,feet-h,w,h),Paint());}

    final finishX=game.finish-game.distance+180;
    if(finishX<=width){canvas.drawLine(Offset(finishX,RunnerEngine.ground-150),Offset(finishX,RunnerEngine.ground),Paint()..color=FrequencyPalette.accent..strokeWidth=6);}
    if(game.status==RunnerStatus.failed){canvas.drawRect(Rect.fromLTWH(180,feet-game.bodyHeight,30,game.bodyHeight),Paint()..color=FrequencyPalette.error..style=PaintingStyle.stroke..strokeWidth=2);}
    canvas.restore();
  }
  @override bool shouldRepaint(covariant _RunnerPainter old)=>old.game!=game||old.reduced!=reduced;
}
