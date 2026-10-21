using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;

namespace BlueMapMigration.Combat
{
    /// <summary>Retained enemy atlases plus the original source's geometric attack warnings, independently sorted in the world.</summary>
    public sealed class EncounterPresentation : IDisposable
    {
        readonly Phase6Catalog catalog;
        readonly Transform parent;
        readonly Dictionary<string,SpriteRenderer> renderers=new Dictionary<string,SpriteRenderer>(StringComparer.Ordinal);
        readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>(StringComparer.Ordinal);
        readonly List<GameObject> objects=new List<GameObject>();
        readonly List<LineRenderer> lines=new List<LineRenderer>();
        readonly HashSet<string> live=new HashSet<string>(StringComparer.Ordinal);
        Sprite circle;
        Texture2D circleTexture,thornTexture;
        Sprite thorn;
        int lineIndex;
        public int VisibleActors {get;private set;}
        public int WarningCount {get;private set;}
        public Func<Vector2,Vector2,bool> ClearLine {get;set;}
        public EncounterPresentation(Phase6Catalog sourceCatalog,Transform sourceParent){catalog=sourceCatalog??throw new ArgumentNullException(nameof(sourceCatalog));parent=sourceParent;}
        Sprite Sheet(string sheet,int frame,int row,int width=16,int height=16)
        {
            string key=sheet+"/"+frame+"/"+row+"/"+width+"/"+height;if(sprites.TryGetValue(key,out var known))return known;
            Sprite full=catalog.GetSprite("image:assets/pixel_"+sheet+".png");int density=2;if(full==null){full=catalog.GetSprite("image:assets/"+sheet+".png");density=1;}if(full==null)throw new FormatException("Retained combat atlas absent: "+sheet);
            int w=width*density,h=height*density;int columns=Math.Max(1,(int)full.rect.width/w),rows=Math.Max(1,(int)full.rect.height/h);frame=Mathf.Clamp(frame,0,columns-1);row=Mathf.Clamp(row,0,rows-1);
            var sprite=Sprite.Create(full.texture,new Rect(full.rect.x+frame*w,full.rect.y+full.rect.height-(row+1)*h,w,h),Vector2.one*.5f,32*density);sprites.Add(key,sprite);return sprite;
        }
        Sprite Circle()
        {
            if(circle!=null)return circle;circleTexture=new Texture2D(32,32,TextureFormat.RGBA32,false,true){filterMode=FilterMode.Point};var pixels=new Color32[1024];for(int y=0;y<32;y++)for(int x=0;x<32;x++)pixels[y*32+x]=new Color32(255,255,255,(byte)((new Vector2(x-15.5f,y-15.5f)).sqrMagnitude<=256?255:0));circleTexture.SetPixels32(pixels);circleTexture.Apply();circle=Sprite.Create(circleTexture,new Rect(0,0,32,32),Vector2.one*.5f,32);return circle;
        }
        Sprite Thorn()
        {
            if(thorn!=null)return thorn;thornTexture=new Texture2D(32,16,TextureFormat.RGBA32,false,true){filterMode=FilterMode.Point};var pixels=new Color32[512];Vector2[] polygon={new Vector2(9,0),new Vector2(-5,-4),new Vector2(-2,0),new Vector2(-5,4)};
            for(int y=0;y<16;y++)for(int x=0;x<32;x++){float px=x-15.5f,py=7.5f-y;bool inside=false;for(int i=0,j=polygon.Length-1;i<polygon.Length;j=i++){Vector2 a=polygon[i],b=polygon[j];if((a.y>py)!=(b.y>py)&&px<(b.x-a.x)*(py-a.y)/(b.y-a.y)+a.x)inside=!inside;}if(inside)pixels[y*32+x]=new Color32(217,166,77,255);}thornTexture.SetPixels32(pixels);thornTexture.Apply();thorn=Sprite.Create(thornTexture,new Rect(0,0,32,16),Vector2.one*.5f,32);return thorn;
        }
        SpriteRenderer Renderer(string key)
        {
            live.Add(key);if(renderers.TryGetValue(key,out var renderer)){renderer.gameObject.SetActive(true);return renderer;}var go=new GameObject("Original combat "+key);go.transform.SetParent(parent,false);objects.Add(go);renderer=go.AddComponent<SpriteRenderer>();renderers.Add(key,renderer);return renderer;
        }
        void Image(string key,Sprite sprite,Vector2 at,Vector2 scale,int order,Color color,double angle=0)
        {var renderer=Renderer(key);catalog.Apply(renderer,sprite);renderer.color=color;renderer.sortingOrder=order;renderer.transform.localPosition=FoundationCoordinates.ToUnity(at);renderer.transform.localScale=new Vector3(scale.x,scale.y,1);renderer.transform.localRotation=Quaternion.Euler(0,0,(float)(-angle*Mathf.Rad2Deg));}
        void Line(Vector2[] points,Color color,float width,int order,bool warning=true)
        {
            if(points.Length<2)return;LineRenderer line;if(lineIndex>=lines.Count){var go=new GameObject("Original attack telegraph");go.transform.SetParent(parent,false);objects.Add(go);line=go.AddComponent<LineRenderer>();line.useWorldSpace=false;line.sharedMaterial=catalog.straightMaterial;line.numCapVertices=0;line.alignment=LineAlignment.View;lines.Add(line);}else line=lines[lineIndex];lineIndex++;line.gameObject.SetActive(true);line.positionCount=points.Length;line.startColor=line.endColor=color;line.startWidth=line.endWidth=width/32;line.sortingOrder=order;for(int i=0;i<points.Length;i++)line.SetPosition(i,FoundationCoordinates.ToUnity(points[i]));if(warning)WarningCount++;
        }
        static float Sin(double value)=>(float)Math.Sin(value);
        static float Clamp01(double value)=>(float)Math.Max(0,Math.Min(1,value));
        static Vector2 Side(Vector2 d)=>new Vector2(-d.y,d.x);
        static Vector2 Dir(double angle)=>new Vector2(Mathf.Cos((float)angle),Mathf.Sin((float)angle));
        void Ring(Vector2 at,double radius,Color color,int order,double first=0,double span=Math.PI*2,float width=2)
        {var points=new Vector2[33];for(int i=0;i<points.Length;i++)points[i]=at+Dir(first+span*i/(points.Length-1))*(float)radius;Line(points,color,width,order);}
        void Lane(Vector2 at,Vector2 direction,double length,double half,Color color,int order)
        {Vector2 side=Side(direction)*(float)half,end=at+direction*(float)length;Line(new[]{at-side,end-side,end+side,at+side,at-side},color,1.5f,order);Line(new[]{at,end},new Color(color.r,color.g,color.b,.45f),(float)Math.Max(2,half*1.5),order-1);}
        public void Draw(IReadOnlyList<EncounterActor> actors,IReadOnlyList<EncounterProjectile> projectiles,IReadOnlyList<EncounterPillar> pillars,bool enabled,Func<EncounterActor,bool> visible,EncounterPlayer player)
        {
            live.Clear();lineIndex=0;VisibleActors=WarningCount=0;
            if(enabled)
            {
                foreach(var actor in actors)if(visible(actor)){Actor(actor,player);VisibleActors++;}
                foreach(var projectile in projectiles)if(!projectile.Dead)Projectile(projectile);
                foreach(var pillar in pillars)Pillar(pillar);
            }
            foreach(var row in renderers)if(!live.Contains(row.Key))row.Value.gameObject.SetActive(false);
            for(int i=lineIndex;i<lines.Count;i++)lines[i].gameObject.SetActive(false);
        }
        void Actor(EncounterActor e,EncounterPlayer player)
        {
            int frame=0,row=0;float lift=-(float)e.AirHeight,scale=e.Number("scale",2);float size=e.Size;Color tint=e.Flash>0?new Color(3,3,3):Color.white;string behavior=e.Behavior;
            if(behavior=="animal")frame=(int)(e.Anim*.9f)%2+(e.Fleeing?2:0);
            else if(behavior=="chase")frame=(int)(e.Anim*.6f)%2+(e.Active&&Vector2.Distance(e.Position,player.Position)<e.Number("sight")?2:0);
            else if(behavior=="bat"){frame=e.State=="dash"?2:(int)(e.Time*12)%2;lift=-6+Sin(e.Time*6)*3;if(e.State=="telegraph"&&(int)(e.Time*20)%2==0)tint=new Color(2.5f,1.2f,1.2f);}
            else if(behavior=="archer"){Vector2 face=player.Position-e.Position;row=Math.Abs(face.y)>Math.Abs(face.x)?(face.y>0?0:1):(face.x>0?2:3);frame=e.State=="aim"?3:e.Desired!=Vector2.zero?1+(int)(e.Anim*.8f)%2:0;}
            else if(behavior=="mage"){frame=(int)(e.Time*2.2f)%2;lift=-5+Sin(e.Time*3)*2;if(e.State=="vanish"||e.State=="appear"){frame=3;lift=-2;float p=Clamp01(e.StateTime/e.Number(e.State=="vanish"?"vanish_time":"appear_time",1));scale*=e.State=="vanish"?1+.4f*p:1.4f-.4f*p;tint.a=e.State=="vanish"?1-.5f*p:.5f+.5f*p;}else if(e.State=="cast"||e.ActionFlash>0)frame=2;}
            else if(behavior=="spitter"){frame=(int)(e.Anim*.6f)%2;if(e.State=="windup"){frame=2;scale*=1+.12f*Clamp01(e.StateTime/e.Number("windup",1));}else if(e.State=="hop")frame=4;else if(e.ActionFlash>0)frame=3;}
            else if(behavior=="golem"){frame=e.State=="windup"?2:e.State=="recover"&&e.StateTime<.4f?3:(int)(e.Anim*.4f)%2;}
            else if(behavior=="king"){frame=e.State=="crouch"||e.State=="land"?2:e.State=="hop"?3:(int)(e.Anim*.5f)%2;if(e.Dead)tint.a=1-Clamp01(e.DeathTimer/1.6);}
            else if(behavior.StartsWith("cv_",StringComparison.Ordinal))frame=e.State=="cv_warn"?2:e.State=="cv_charge"||e.State=="cv_rest"?3:(int)(e.Time*5)%2;
            else if(behavior.StartsWith("rf_",StringComparison.Ordinal)){frame=e.State=="idle"?0:e.State=="rf_jump"?2:1;if(e.State=="rf_jump")lift=-Sin(Math.Min(1,e.StateTime/.32f)*Mathf.PI)*8;}
            else if(behavior.StartsWith("lw_",StringComparison.Ordinal))frame=e.State=="lw_warn"||e.State=="lw_song"?2:(int)(e.Time*5)%2;
            else if(behavior.StartsWith("echo_",StringComparison.Ordinal)){frame=e.State=="echo_warn"?2:e.State=="echo_dash"?3:(int)(e.Time*6)%2;if(behavior=="echo_volley")lift=-5+Sin(e.Time*5)*2;}
            else if(behavior.StartsWith("hb_",StringComparison.Ordinal)){frame=(int)(e.Time*3)%2;if(behavior=="hb_root")frame=e.State=="hb_root_warn"?2:e.State=="hb_root_hit"?3:e.State=="hb_rest"?4:frame;else{lift=-6+Sin(e.Time*6)*2;frame=e.State=="hb_moth_warn"?2:e.State=="hb_moth_dash"?3:e.Distracted?4+(int)(e.Time*3)%2:frame;}}
            else if(behavior.StartsWith("ad_",StringComparison.Ordinal)){frame=e.State=="ad_warn"||e.State=="ad_warn2"?2:e.State=="ad_swing"||e.State=="ad_pulse"?3:e.Desired.magnitude>1?(int)(e.Anim*2)%2:0;if(e.Kind=="ad_wisp")lift=Sin(e.Time*2)*3;}
            if(e.Kind=="guardian"){frame=e.State=="dormant"?6:e.State=="waking"?((e.StateTime<1.8*.35)?6:7):e.State=="charge_windup"?2:e.State=="charge_dash"?3:e.State=="stunned"?6:e.State=="slam_windup"?4:e.State=="slam_recover"?e.StateTime<.4f?5:0:e.State=="phase_shift"?7:e.State=="dying"?(int)(e.StateTime*8)%2==0?6:7:(int)(e.Anim*.4f)%2;if(e.State=="dormant")tint=new Color(.55f,.55f,.7f);}
            int order=Mathf.RoundToInt(e.Position.y);Image(e.Address+"/shadow",Circle(),e.Position+new Vector2(0,size*.44f),new Vector2(e.Number("shadow",10)*2/32,e.Number("shadow",10)*.7f/32),order-1,new Color(0,0,0,.3f));
            Image(e.Address,Sheet(e.Text("sheet",e.Kind),frame,row,(int)e.Number("cell",16),(int)e.Number("cell",16)),e.Position+new Vector2(0,lift),Vector2.one*scale,order,tint);
            Warnings(e,order);
        }
        void Warnings(EncounterActor e,int order)
        {
            Color amber=new Color(1,.67f,.35f,.85f),red=new Color(1,.25f,.3f,.85f),blue=new Color(.55f,.8f,1,.85f);Vector2 at=e.Position;
            if(e.State=="cv_warn"){float length=e.Behavior=="cv_ram"?110:220;for(int i=16;i<length;i+=8)if(!(ClearLine?.Invoke(at,at+e.Aim*i)??true)){length=i;break;}Lane(at,e.Aim,length,9,amber,order-2);Ring(at+new Vector2(0,-27),7,amber,order+1,-Mathf.PI/2,Mathf.PI*2*Clamp01(e.StateTime/.85f));}
            if(e.State=="rf_warn"||e.State=="lw_warn"||e.State=="telegraph"||e.State=="aim")Line(new[]{at+e.Aim*15,at+e.Aim*65},amber,3,order-1);
            if(e.State=="echo_warn")foreach(float angle in e.Behavior=="echo_charge"?new[]{0f}:new[]{-.45f,0,.45f}){Vector2 d=Dir(Mathf.Atan2(e.Aim.y,e.Aim.x)+angle);Line(new[]{at+d*14,at+d*(e.Behavior=="echo_charge"?112:90)},e.Behavior=="echo_charge"?blue:new Color(.95f,.6f,1,.8f),3,order-1);}
            if(e.State=="windup"&&e.Behavior=="spitter"){int count=(int)e.Number("fan");float progress=Clamp01(e.StateTime/e.Number("windup",1));for(int i=0;i<count;i++){Vector2 d=Dir(Mathf.Atan2(e.Aim.y,e.Aim.x)+(i-(count-1)/2f)*e.Number("fan_spread"));Line(new[]{at+new Vector2(0,6)+d*16,at+new Vector2(0,6)+d*(26+16*progress)},new Color(1,1,.7f,.5f+.5f*progress),2,order+1);}}
            if(e.State=="cast"&&e.Behavior=="mage"){float p=Clamp01(e.StateTime/e.Number("cast_time",1));Ring(at+new Vector2(0,-27),2+6*p,new Color(.85f,.6f,1,.9f),order+1);}
            if(e.State=="windup"&&e.Behavior=="golem")Ring(at+new Vector2(0,e.Size*.3f),56*Clamp01(e.StateTime/.9f),red,order-2);
            if(e.State=="crouch"&&e.Kind=="king")Ring(e.HopTo,e.HopPhase==1?64:e.HopPhase==2?74:86,amber,-9000);
            if(new[]{"hb_root_warn","hb_root_hit","hb_moth_warn","hb_moth_dash"}.Contains(e.State))Lane(e.Origin+e.Aim*(e.Behavior=="hb_root"?18:0),e.Aim,Math.Max(0,e.Length-(e.Behavior=="hb_root"?18:0)),12,new Color(.85f,.72f,.45f,.9f),-9000);
            if(e.Kind!="ad_wisp"&&(e.State=="ad_warn"||e.State=="ad_warn2"||e.State=="ad_swing"))
            {float angle=Mathf.Atan2(e.Aim.y,e.Aim.x);Ring(e.Origin,118,amber,-9000,angle-.58f,1.16f);Line(new[]{e.Origin,e.Origin+Dir(angle-.58f)*118},amber,2,-9000);Line(new[]{e.Origin,e.Origin+Dir(angle+.58f)*118},amber,2,-9000);}
            if(e.Kind=="ad_wisp"&&(e.State=="ad_warn"||e.State=="ad_pulse")){float angle=Mathf.Atan2(e.Aim.y,e.Aim.x);Ring(e.Origin,e.State=="ad_warn"?148:e.Pulse,blue,-9000,angle+.52f,Mathf.PI*2-1.04f);}
            if(e.Behavior=="lw_guard"&&e.GuardBroken<=0)Ring(at,18,blue,order+1,Mathf.Atan2(e.Aim.y,e.Aim.x)-.9f,1.8f,4);
            if(e.State=="lw_song")Ring(at,24+e.StateTime*28,new Color(.3f,1,.55f,.7f),order-1);
            if(e.State=="charge_windup"&&e.Kind=="guardian")Lane(at+new Vector2(0,14),e.Aim,e.Length,e.Radius+9,red,-9000);
            if(e.State=="slam_windup"&&e.Kind=="guardian"){Ring(at+new Vector2(0,14),78,red,-9000);foreach(float angle in e.SlamAngles)Line(new[]{at+new Vector2(0,14)+Dir(angle)*78,at+new Vector2(0,14)+Dir(angle)*168},red,2,-9000);}
            if(e.State=="phase_shift")Ring(at+new Vector2(0,14),60,new Color(.7f,.45f,1,.8f),-9000);
            if(e.State=="stunned"||e.GuardBroken>0)Ring(at+new Vector2(0,-e.Size*.4f),8,new Color(1,.9f,.5f),order+1,e.Time*4,Mathf.PI);
        }
        void Projectile(EncounterProjectile p)
        {
            if(p.Kind=="cv_thorn"){float heading=Mathf.Atan2(p.Velocity.y,p.Velocity.x);Image(p.Id,Thorn(),p.Position,Vector2.one,Mathf.RoundToInt(p.Position.y)+1,Color.white,heading);Line(new[]{p.Position-p.Velocity.normalized*12,p.Position},new Color(.7f,.9f,.4f,.5f),2,Mathf.RoundToInt(p.Position.y),false);return;}
            double angle=p.PlayerOwned?Mathf.Atan2(p.Direction.y,p.Direction.x)+p.Spin:p.Kind=="arrow"||p.Kind=="guardian_shard"?Mathf.Atan2(p.Velocity.y,p.Velocity.x):p.Age*8;
            string sheet=p.PlayerOwned?"items_boog":p.Kind=="arcane_orb"||p.Kind=="prism_spark"?"arcane_orb":p.Kind=="guardian_shard"?"depths_objects":"projectiles";
            int frame=p.PlayerOwned?2:sheet=="arcane_orb"?(int)(p.Age*12)%4:p.Kind=="guardian_shard"?3+(int)(p.Age*10)%2:p.Kind=="rock"?1:p.Kind=="slimeball"?2:0;float alpha=p.State=="fading"?Clamp01(p.Timer/.25f):p.State=="bounce"?Clamp01(p.Timer/.4f*1.5f):1;
            Image(p.Id,Sheet(sheet,frame,0),p.Position,Vector2.one*2,Mathf.RoundToInt(p.Position.y)+1,new Color(1,1,1,alpha),angle);
            if(p.PlayerOwned&&p.State=="flying")Line(new[]{p.Position-p.Direction*(p.Precise?24:16),p.Position},p.Precise?new Color(.4f,.85f,1,.8f):new Color(1,1,1,.3f),p.Precise?3:2,Mathf.RoundToInt(p.Position.y),false);
            if(p.Trail.Count>1)Line(p.Trail.ToArray(),new Color(.75f,.5f,1,.3f),3,Mathf.RoundToInt(p.Position.y),false);
        }
        void Pillar(EncounterPillar p)
        {
            var renderer=Renderer(p.Address);if(renderer.GetComponent<Collider2D>()==null)FoundationCollision.Box(renderer.gameObject,new Rect(-11,1,22,14),1,1);
            Image(p.Address,Sheet("depths_pillar",p.Charging&&p.Windup>0||p.Flash>0?1:0,0,16,32),p.Position+new Vector2(0,-16),Vector2.one*2,Mathf.RoundToInt(p.Position.y),Color.white);
            // Collider coordinates follow the unscaled original pillar foot, independent of the sprite's 2x scale.
            var collider=renderer.GetComponent<BoxCollider2D>();if(collider!=null){collider.offset=new Vector2(0,-24f/64);collider.size=new Vector2(22f/64,14f/64);}
            if(p.Charging&&p.Windup>0)foreach(double angle in p.Angles)Line(new[]{p.Position+new Vector2(0,2)+Dir(angle)*22,p.Position+new Vector2(0,2)+Dir(angle)*(p.Rings>1?90:150)},new Color(1,.25f,.3f,.65f),p.Rings>1?2:3,-9000);
        }
        public void Clear(){foreach(var obj in objects)if(obj!=null)UnityEngine.Object.Destroy(obj);objects.Clear();renderers.Clear();lines.Clear();}
        public void Dispose(){Clear();foreach(var sprite in sprites.Values)UnityEngine.Object.Destroy(sprite);sprites.Clear();if(circle!=null)UnityEngine.Object.Destroy(circle);if(circleTexture!=null)UnityEngine.Object.Destroy(circleTexture);if(thorn!=null)UnityEngine.Object.Destroy(thorn);if(thornTexture!=null)UnityEngine.Object.Destroy(thornTexture);}
    }
}
