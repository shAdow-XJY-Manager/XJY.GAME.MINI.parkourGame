import 'dart:math';

enum RunnerStatus { ready, playing, paused, failed, cleared }
class RunnerObstacle {
  final double x, width, height;
  final bool overhead;
  const RunnerObstacle(this.x,{this.width=54,this.height=44,this.overhead=false});
}
class RunnerCoin {
  final double x, aboveGround;
  bool collected=false;
  RunnerCoin(this.x,this.aboveGround);
}
class RunnerEngine {
  static const physicsStep=1/120;
  static const ground=384.0;
  final int level;
  late final double speed, finish;
  late final List<RunnerObstacle> obstacles;
  late final List<RunnerCoin> coins;
  RunnerStatus status=RunnerStatus.ready;
  double distance=0, elapsed=0, offset=0, velocity=0, accumulator=0;
  double jumpBuffer=0, coyote=.09, jumpAge=0;
  bool releaseRequested=false;
  bool grounded=true, slideHeld=false, sliding=false;
  int collected=0, chain=0, jumps=0, chainBonus=0;
  String reason='';
  RunnerEngine({this.level=0}) {
    speed=[240.0,280.0,320.0][level];
    finish=speed*[45.0,60.0,75.0][level];
    final spacing=[2.7,2.2,1.8][level];
    obstacles=[];coins=[];
    for(double time=5;time<finish/speed-3;time+=spacing) {
      final i=obstacles.length;
      final overhead=level==0 ? i>=4&&i%3==1 : i%3==1;
      final o=RunnerObstacle(time*speed,overhead:overhead,height:overhead?58:44,width:overhead?78:54);
      obstacles.add(o);
      for(final dx in [-60.0,0.0,60.0])coins.add(RunnerCoin(o.x+dx,overhead?18:90));
    }
  }
  int get score => (distance/10).floor()+collected*50+chainBonus+(status==RunnerStatus.cleared?500:0);
  double get progress=>min(1.0,distance/finish);
  double get bodyHeight=>sliding?30:64;
  void start(){if(status==RunnerStatus.ready)status=RunnerStatus.playing;}
  void pause(){if(status==RunnerStatus.playing){status=RunnerStatus.paused;_clearInput();accumulator=0;}}
  void resume(){if(status==RunnerStatus.paused){status=RunnerStatus.playing;_clearInput();accumulator=0;}}
  void _clearInput(){jumpBuffer=0;slideHeld=false;}
  void jump(){if(status==RunnerStatus.playing){jumpBuffer=.12;releaseRequested=false;}}
  void releaseJump(){if(status==RunnerStatus.playing){releaseRequested=true;if(jumpAge>=.16&&velocity < -300)velocity=-300;}}
  void slide(bool held){if(status==RunnerStatus.playing)slideHeld=held;}
  void advance(double dt){
    if(status!=RunnerStatus.playing||dt<=0)return;
    if(dt>.25){pause();return;}
    accumulator+=dt;
    int count=0;
    while(accumulator+1e-10>=physicsStep&&status==RunnerStatus.playing&&count<30){
      accumulator-=physicsStep;_step(physicsStep);count++;
    }
  }
  void _step(double dt){
    final previousDistance=distance;
    if(grounded)coyote=.09;else coyote=max(0.0,coyote-dt);
    // A low ceiling delays standing until the standing collision box fits.
    final ceiling=obstacles.any((o)=>o.overhead&&distance+30>o.x&&distance<o.x+o.width);
    sliding=grounded&&(slideHeld||(sliding&&ceiling));
    if(jumpBuffer>0&&coyote>0&&!sliding){velocity=-660;grounded=false;coyote=0;jumpBuffer=0;jumpAge=0;jumps++;}
    jumpBuffer=max(0.0,jumpBuffer-dt);
    if(!grounded){jumpAge+=dt;if(releaseRequested&&jumpAge>=.16&&velocity < -300)velocity=-300;offset+=velocity*dt+.5*1800*dt*dt;velocity+=1800*dt;if(offset>=0){offset=0;velocity=0;grounded=true;}}
    distance+=speed*dt;elapsed+=dt;
    final top=ground+offset-bodyHeight,bottom=ground+offset;
    for(final o in obstacles){
      final obstacleBottom=o.overhead?ground-42:ground;
      final obstacleTop=obstacleBottom-o.height;
      if(distance+30>o.x&&previousDistance<o.x+o.width&&bottom>obstacleTop&&top<obstacleBottom){
        status=RunnerStatus.failed;reason=o.overhead?'上方横梁需要按住滑行。':'跳得太晚或落地太早，碰到了路障。';_clearInput();return;
      }
    }
    for(final c in coins){
      if(c.collected)continue;
      final y=ground-c.aboveGround;
      if(distance+30>c.x-10&&previousDistance<c.x+10&&bottom>y-10&&top<y+10){c.collected=true;collected++;chain++;if(chain%5==0)chainBonus+=100;}
      else if(distance>c.x+20){c.collected=true;chain=0;}
    }
    if(distance>=finish){distance=finish;status=RunnerStatus.cleared;_clearInput();}
  }
}
