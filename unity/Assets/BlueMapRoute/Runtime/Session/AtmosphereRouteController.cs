using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Residents;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// The colour of the hour, the dark of caves, rain, snow, drifting sand, the glow of lamps and the quiet
 /// background sound of each climate. The clock itself already runs on active play time; this only shows it.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  sealed class Glow{public Transform Node;public Material Material;public Color Colour;public float Energy,Flicker;public bool Player;}
  sealed class Mote{public Transform Node;public SpriteRenderer Renderer;public Vector2 At;public float Speed,Phase;}
  static readonly (double time,Color colour,double night)[] DayKeys=
  {
   (0.00,new Color(1.00f,0.82f,0.72f),0.35),(0.07,new Color(1.00f,0.92f,0.82f),0.05),(0.17,Color.white,0),(0.52,Color.white,0),(0.60,new Color(1.00f,0.78f,0.56f),0.15),
   (0.68,new Color(0.62f,0.46f,0.62f),0.6),(0.76,new Color(0.30f,0.36f,0.66f),1.0),(0.90,new Color(0.30f,0.36f,0.66f),1.0),(0.96,new Color(0.58f,0.48f,0.70f),0.7),(1.00,new Color(1.00f,0.82f,0.72f),0.35),
  };
  static readonly Color DarkColour=new Color(0.1f,0.12f,0.24f);
  /// <summary>Automated picture comparisons of earlier phases keep the plain picture; ordinary play always shows the hour.</summary>
  public bool AtmosphereEnabled {get=>atmosphereEnabled??!Automated;set{atmosphereEnabled=value;atmosphereBuiltFor=null;}}
  bool? atmosphereEnabled;
  public Color SkyTint {get;private set;}=Color.white;public double LightNeed {get;private set;} public double RainLevel {get;private set;} public double SnowLevel {get;private set;} public double DustLevel {get;private set;} public double HazeLevel {get;private set;}
  public string AmbienceKey {get;private set;}="";public string ClockText {get;private set;}="";public int GlowCount=>glows.Count;public int WeatherMotes=>motes.Count(m=>m.Renderer.enabled);public bool AtmosphereReady=>skyMaterial!=null;
  GameObject atmosphereRoot;Material skyMaterial;Transform skyQuad;Shader additive;Texture2D lightTexture;readonly List<Glow> glows=new List<Glow>();readonly List<Mote> motes=new List<Mote>();
  FoundationWorldSnapshot atmosphereBuiltFor;bool outdoor;string weather="";double mapDark,atmosphereTime;Sprite rainSprite,snowSprite,dustSprite;
  static double WrapDay(double t){double r=t%1.0;return r<0?r+1:r;}
  static (int from,double share) DaySegment(double t)
  {
   t=WrapDay(t);
   for(int i=1;i<DayKeys.Length;i++)if(t<=DayKeys[i].time){double u=(t-DayKeys[i-1].time)/(DayKeys[i].time-DayKeys[i-1].time);return (i-1,u*u*(3-2*u));}
   return (DayKeys.Length-2,1);
  }
  public static Color TintAt(double t){var s=DaySegment(t);return Color.Lerp(DayKeys[s.from].colour,DayKeys[s.from+1].colour,(float)s.share);}
  public static double NightAt(double t){var s=DaySegment(t);return DayKeys[s.from].night+(DayKeys[s.from+1].night-DayKeys[s.from].night)*s.share;}
  public static string Climate(string weather)=>weather=="snow"?"sneeuw":weather=="heat"?"dorst":weather=="swamp"?"moeras":"bos";
  public static string AmbienceFor(string weather,double t)=>"amb_"+Climate(weather)+"_"+ResidentSocialModel.PhaseAt(t);
  public string PhaseLabel(double t){switch(ResidentSocialModel.PhaseAt(t)){case "ochtend":return Translate("Ochtend");case "dag":return Translate("Dag");case "avond":return Translate("Avond");}return Translate("Nacht");}
  static Color Blend(Color a,Color tint,double level)=>new Color(a.r*Mathf.Lerp(1,tint.r,(float)level),a.g*Mathf.Lerp(1,tint.g,(float)level),a.b*Mathf.Lerp(1,tint.b,(float)level),1);
  static Mesh Quad()
  {
   var mesh=new Mesh{name="atmosphere quad",hideFlags=HideFlags.HideAndDontSave};mesh.vertices=new[]{new Vector3(-.5f,-.5f),new Vector3(.5f,-.5f),new Vector3(-.5f,.5f),new Vector3(.5f,.5f)};
   mesh.uv=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(0,1),new Vector2(1,1)};mesh.triangles=new[]{0,2,1,2,3,1};mesh.RecalculateBounds();return mesh;
  }
  static Sprite Dot(int width,int height,Color colour)
  {
   var texture=new Texture2D(width,height,TextureFormat.RGBA32,false){filterMode=FilterMode.Point,hideFlags=HideFlags.HideAndDontSave};var pixels=new Color32[width*height];for(int i=0;i<pixels.Length;i++)pixels[i]=colour;
   texture.SetPixels32(pixels);texture.Apply(false,true);var sprite=Sprite.Create(texture,new Rect(0,0,width,height),new Vector2(.5f,.5f),32);sprite.hideFlags=HideFlags.HideAndDontSave;return sprite;
  }
  void ClearAtmosphere(){if(atmosphereRoot!=null)UnityEngine.Object.Destroy(atmosphereRoot);atmosphereRoot=null;skyQuad=null;glows.Clear();motes.Clear();}
  void BuildAtmosphere()
  {
   ClearAtmosphere();atmosphereBuiltFor=Session.Current;var data=Session.Current.MapData;
   outdoor=data.TryGet("outdoor",out var open)&&open.Kind=="bool"&&open.AsBool();weather=data.TryGet("weather",out var sky)&&sky.Kind=="string"?sky.AsString():"";
   mapDark=data.TryGet("dark",out var dark)&&(dark.Kind=="float"||dark.Kind=="int")?dark.AsDouble():0;
   RainLevel=RainTarget();SnowLevel=weather=="snow"?1:0;DustLevel=DustTarget();HazeLevel=HazeTarget();AmbienceKey="";
   if(!AtmosphereEnabled||Camera==null)return;
   if(skyMaterial==null)
   {
    var multiply=Resources.Load<Shader>("BlueMapMultiply");additive=Resources.Load<Shader>("BlueMapAdditive");if(multiply==null||additive==null)return;
    skyMaterial=new Material(multiply){hideFlags=HideFlags.HideAndDontSave};
    lightTexture=new Texture2D(128,128,TextureFormat.RGBA32,false){wrapMode=TextureWrapMode.Clamp,hideFlags=HideFlags.HideAndDontSave};var pixels=new Color32[128*128];
    for(int y=0;y<128;y++)for(int x=0;x<128;x++){float d=Mathf.Clamp01(Vector2.Distance(new Vector2(x+.5f,y+.5f),new Vector2(64,64))/64f);pixels[y*128+x]=new Color(1,1,1,1-d);}
    lightTexture.SetPixels32(pixels);lightTexture.Apply(false,true);
    rainSprite=Dot(2,10,new Color(.72f,.82f,.95f,.55f));snowSprite=Dot(3,3,new Color(1,1,1,.85f));dustSprite=Dot(2,2,new Color(.93f,.82f,.6f,.6f));
   }
   atmosphereRoot=new GameObject("Atmosphere");atmosphereRoot.transform.SetParent(World.transform,false);
   var quad=new GameObject("Colour of the hour");quad.transform.SetParent(atmosphereRoot.transform,false);quad.AddComponent<MeshFilter>().sharedMesh=Quad();var skyRenderer=quad.AddComponent<MeshRenderer>();skyRenderer.sharedMaterial=skyMaterial;skyRenderer.sortingOrder=28000;skyQuad=quad.transform;
   // Lamps: the player's own light and every lantern, torch and deep lamp of this map.
   AddGlow(null,Vector2.zero,new Color(1,.92f,.78f),1,3.2f,true);
   foreach(var node in Session.Current.Root.Require("scene").Items)
   {
    if(!node.TryGet("script",out var script)||script.Kind!="string"||!node.TryGet("globalTransform",out var transform))continue;string kind=System.IO.Path.GetFileNameWithoutExtension(script.AsString());
    var at=FoundationCoordinates.Vector(transform.Require("origin"));var obj=node.TryGet("fields",out var fields)?StoryModel.G(fields,"obj",fields):null;
    if(kind=="lantern")AddGlow(node,at+new Vector2(0,-24),new Color(1,.76f,.42f),.55f,2.0f,false);
    else if(kind=="torch"){bool cold=obj!=null&&StoryModel.G(obj,"cold",FoundationValue.Boolean(false)).Kind=="bool"&&StoryModel.G(obj,"cold",FoundationValue.Boolean(false)).AsBool();AddGlow(node,at+new Vector2(0,-10),cold?new Color(.4f,.7f,1):new Color(1,.7f,.35f),cold?.5f:.9f,cold?2.0f:2.6f,false);}
    else if(kind=="diepte_lamp")AddGlow(node,at+new Vector2(0,-10),new Color(.7f,.5f,1),.7f,2.2f,false);
   }
   for(int i=0;i<110;i++)
   {
    var node=new GameObject("weather "+i);node.transform.SetParent(atmosphereRoot.transform,false);var renderer=node.AddComponent<SpriteRenderer>();renderer.sortingOrder=27990;renderer.enabled=false;
    motes.Add(new Mote{Node=node.transform,Renderer=renderer,At=new Vector2(UnityEngine.Random.value,UnityEngine.Random.value),Speed=.8f+UnityEngine.Random.value*.5f,Phase=UnityEngine.Random.value*6.28f});
   }
  }
  void AddGlow(FoundationValue node,Vector2 source,Color colour,float energy,float scale,bool player)
  {
   var glow=new GameObject(player?"Player light":"Lamp light");glow.transform.SetParent(atmosphereRoot.transform,false);glow.AddComponent<MeshFilter>().sharedMesh=Quad();var renderer=glow.AddComponent<MeshRenderer>();
   var material=new Material(additive){hideFlags=HideFlags.HideAndDontSave,mainTexture=lightTexture};renderer.sharedMaterial=material;renderer.sortingOrder=28001;
   glow.transform.localScale=new Vector3(128*scale/32f,128*scale/32f,1);if(!player)glow.transform.position=FoundationCoordinates.ToUnity(source);
   glows.Add(new Glow{Node=glow.transform,Material=material,Colour=colour,Energy=energy,Flicker=UnityEngine.Random.value*6.28f,Player=player});
  }
  double RainTarget()=>ResidentSocialModel.Raining(weather,Gameplay.State.DayCount,Gameplay.State.DayTime)?1:0;
  double DustTarget()=>Gameplay.State.MapId=="sunwell"&&Gameplay.State.Flag("ra_spring")?0:weather=="heat"?1:0;
  double HazeTarget()=>weather!="swamp"?0:Gameplay.State.Flag("lw_drained")&&Gameplay.State.MapId=="kruipmoeras"?.3:1;
  static double Toward(double value,double target,double step)=>value<target?Math.Min(target,value+step):Math.Max(target,value-step);
  void TickAtmosphere(double delta)
  {
   if(Session?.Current==null)return;var state=Gameplay.State;
   if(!ReferenceEquals(atmosphereBuiltFor,Session.Current))BuildAtmosphere();
   atmosphereTime+=delta;RainLevel=Toward(RainLevel,RainTarget(),delta/4);SnowLevel=Toward(SnowLevel,weather=="snow"?1:0,delta/4);DustLevel=Toward(DustLevel,DustTarget(),delta/4);HazeLevel=HazeTarget();
   double t=state.DayTime;
   if(outdoor)
   {
    var tint=TintAt(t);tint=Blend(tint,new Color(.80f,.86f,.95f),RainLevel);tint=Blend(tint,new Color(.94f,.97f,1.04f),SnowLevel);tint=Blend(tint,new Color(1.06f,.99f,.86f),DustLevel);tint=Blend(tint,new Color(.92f,.97f,.9f),HazeLevel);
    SkyTint=tint;LightNeed=NightAt(t);
   }
   else{SkyTint=Color.Lerp(Color.white,DarkColour,(float)mapDark);LightNeed=mapDark>0?1:0;}
   ClockText=outdoor?PhaseLabel(t):"";
   // The background sound follows the climate and the part of the day; indoors and dungeons stay quiet.
   string want=!outdoor?"":state.MapId=="kruipmoeras"&&state.Flag("lw_drained")?AmbienceFor("",t):AmbienceFor(weather,t);
   if(want!=AmbienceKey){AmbienceKey=want;if(AtmosphereEnabled){if(want=="")World.StopRouteAmbience();else World.PlayRouteAmbience(want);}}
   if(atmosphereRoot==null||skyQuad==null||Camera==null)return;
   float height=Camera.orthographicSize*2,width=height*Camera.aspect;var centre=Camera.transform.position;
   skyQuad.position=new Vector3(centre.x,centre.y,0);skyQuad.localScale=new Vector3(width+2,height+2,1);skyMaterial.color=new Color(Mathf.Min(1,SkyTint.r),Mathf.Min(1,SkyTint.g),Mathf.Min(1,SkyTint.b),1);
   bool lantern=state.Count("lw_lantern")>0;
   foreach(var glow in glows)
   {
    float flicker=1+Mathf.Sin((float)atmosphereTime*7+glow.Flicker)*.05f+Mathf.Sin((float)atmosphereTime*19+glow.Flicker)*.03f,energy;
    if(glow.Player)
    {
     var at=FoundationCoordinates.ToUnity(World.Position);glow.Node.position=new Vector3(at.x,at.y,0);
     if(!outdoor){energy=mapDark>0?1:0;glow.Node.localScale=new Vector3(12.8f,12.8f,1);}
     else{energy=(float)Math.Max(.3*LightNeed,lantern?.45:0);if(LightNeed<=.02&&!lantern)energy=0;glow.Node.localScale=new Vector3(8.8f,8.8f,1);}
    }
    else energy=glow.Energy*(float)LightNeed*flicker;
    glow.Material.color=new Color(glow.Colour.r,glow.Colour.g,glow.Colour.b,Mathf.Clamp01(energy)*.55f);
   }
   // Weather drifts across the view: rain falls fast and slanted, snow slowly, sand sideways.
   int rain=(int)(RainLevel*90),snow=(int)(SnowLevel*70),dust=(int)(DustLevel*45);float step=(float)delta;
   for(int i=0;i<motes.Count;i++)
   {
    var mote=motes[i];string kind=i<rain?"rain":i<rain+snow?"snow":i<rain+snow+dust?"dust":"";mote.Renderer.enabled=kind!="";if(kind=="")continue;
    if(kind=="rain"){mote.Renderer.sprite=rainSprite;mote.At+=new Vector2(-.12f,-1.6f)*mote.Speed*step;}
    else if(kind=="snow"){mote.Renderer.sprite=snowSprite;mote.At+=new Vector2(Mathf.Sin((float)atmosphereTime+mote.Phase)*.05f,-.14f)*mote.Speed*step;}
    else{mote.Renderer.sprite=dustSprite;mote.At+=new Vector2(.22f,Mathf.Sin((float)atmosphereTime*.7f+mote.Phase)*.03f)*mote.Speed*step;}
    mote.At=new Vector2(Mathf.Repeat(mote.At.x,1),Mathf.Repeat(mote.At.y,1));mote.Node.position=new Vector3(centre.x+(mote.At.x-.5f)*width,centre.y+(mote.At.y-.5f)*height,0);
   }
  }
 }
}
