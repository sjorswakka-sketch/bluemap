using System;
using System.Collections.Generic;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>
 /// The original low-profile field art. The source paints these tiles with rectangles and lines instead of
 /// image files, so the same shapes and colours are painted here once and kept as small sprites.
 /// </summary>
 public static class GardenArt
 {
  static readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>(StringComparer.Ordinal);
  public static int Painted=>sprites.Count;
  sealed class Canvas
  {
   public readonly Color32[] Pixels=new Color32[32*32];
   public void Set(int x,int y,Color c){if(x<0||y<0||x>=32||y>=32)return;int i=(31-y)*32+x;Color under=Pixels[i];float a=c.a+under.a*(1-c.a);Pixels[i]=a<=0?new Color(0,0,0,0):new Color((c.r*c.a+under.r*under.a*(1-c.a))/a,(c.g*c.a+under.g*under.a*(1-c.a))/a,(c.b*c.a+under.b*under.a*(1-c.a))/a,a);}
   public void Rect(float x,float y,float w,float h,Color c){for(int py=Mathf.RoundToInt(y);py<Mathf.RoundToInt(y+h);py++)for(int px=Mathf.RoundToInt(x);px<Mathf.RoundToInt(x+w);px++)Set(px,py,c);}
   public void Outline(float x,float y,float w,float h,Color c){Rect(x,y,w,1,c);Rect(x,y+h-1,w,1,c);Rect(x,y+1,1,h-2,c);Rect(x+w-1,y+1,1,h-2,c);}
   /// <summary>A straight stroke of the given width; every garden stroke is horizontal, vertical or a short lean.</summary>
   public void Line(Vector2 a,Vector2 b,Color c,float width)
   {
    var touched=new HashSet<int>();float length=Vector2.Distance(a,b);int steps=Mathf.Max(1,Mathf.CeilToInt(length*2));float half=width/2f;
    for(int i=0;i<=steps;i++)
    {
     Vector2 p=Vector2.Lerp(a,b,i/(float)steps);
     for(int py=Mathf.RoundToInt(p.y-half);py<Mathf.RoundToInt(p.y+half);py++)for(int px=Mathf.RoundToInt(p.x-half);px<Mathf.RoundToInt(p.x+half);px++)if(touched.Add(py*64+px+2048))Set(px,py,c);
     if(width<=1&&touched.Add(Mathf.FloorToInt(p.y)*64+Mathf.FloorToInt(p.x)+2048))Set(Mathf.FloorToInt(p.x),Mathf.FloorToInt(p.y),c);
    }
   }
   public void Disc(Vector2 center,float radius,Color c){for(int py=Mathf.FloorToInt(center.y-radius);py<=Mathf.CeilToInt(center.y+radius);py++)for(int px=Mathf.FloorToInt(center.x-radius);px<=Mathf.CeilToInt(center.x+radius);px++)if(Vector2.Distance(new Vector2(px+.5f,py+.5f),center)<=radius)Set(px,py,c);}
  }
  static Color Hex(string hex,float alpha=1){ColorUtility.TryParseHtmlString("#"+hex,out var color);color.a=alpha;return color;}
  static Sprite Keep(string key,Action<Canvas> paint)
  {
   if(sprites.TryGetValue(key,out var known)&&known!=null)return known;
   var canvas=new Canvas();paint(canvas);var texture=new Texture2D(32,32,TextureFormat.RGBA32,false){filterMode=FilterMode.Point,wrapMode=TextureWrapMode.Clamp,name="garden "+key,hideFlags=HideFlags.HideAndDontSave};
   texture.SetPixels32(canvas.Pixels);texture.Apply(false,true);var sprite=Sprite.Create(texture,new Rect(0,0,32,32),new Vector2(.5f,.5f),32);sprite.name=key;sprite.hideFlags=HideFlags.HideAndDontSave;sprites[key]=sprite;return sprite;
  }
  /// <summary>Tilled soil; darker when water reaches it.</summary>
  public static Sprite Soil(bool watered)=>Keep("soil:"+watered,c=>
  {
   c.Rect(2,2,28,28,Hex(watered?"574636":"8d6d48"));foreach(int y in new[]{8,16,24})c.Line(new Vector2(5,y),new Vector2(27,y),Hex("3c392e"),2);
  });
  /// <summary>An irrigation channel; mask bits: left 1, right 2, up 4, down 8.</summary>
  public static Sprite Channel(bool wet,int mask)=>Keep("channel:"+wet+":"+mask,c=>
  {
   Color water=Hex(wet?"3d91b2":"59483b"),edge=Hex("302f2b");var steps=new[]{new Vector2(-1,0),new Vector2(1,0),new Vector2(0,-1),new Vector2(0,1)};
   c.Rect(7,7,18,18,edge);for(int i=0;i<4;i++)if((mask&(1<<i))!=0)c.Line(new Vector2(16,16),new Vector2(16,16)+steps[i]*17,edge,18);
   c.Rect(8,8,16,16,water);for(int i=0;i<4;i++)if((mask&(1<<i))!=0)c.Line(new Vector2(16,16),new Vector2(16,16)+steps[i]*17,water,16);
   if(wet)c.Line(new Vector2(14,16),new Vector2(18,16),Hex("a4dbe0"),2);
  });
  /// <summary>Grape vines and flowers, painted at the growth the source would show.</summary>
  public static Sprite Crop(string crop,double growth,double seconds,bool fertilized)
  {
   float ratio=Mathf.Clamp01((float)(growth/seconds));int step=Mathf.FloorToInt(ratio*18);bool grown=ratio>=.35f,fruit=ratio>=.65f,ripe=ratio>=1;
   return Keep("crop:"+crop+":"+step+":"+fruit+":"+ripe+":"+fertilized,c=>
   {
    if(crop=="grape")
    {
     if(grown){foreach(int x in new[]{6,25})c.Line(new Vector2(x,27),new Vector2(x,5),Hex("a38b60"),2);foreach(int y in new[]{9,18})c.Line(new Vector2(6,y),new Vector2(25,y),Hex("927d58"),1);}
     float height=5+step;c.Line(new Vector2(16,27),new Vector2(16,27-height),Hex("729858"),2);
     for(int i=0;i<(grown?3:1);i++){var leaf=new Vector2(i%2==0?11:21,23-i*6);c.Line(leaf-new Vector2(3,0),leaf+new Vector2(3,0),Hex("81a35e"),4);c.Line(leaf-new Vector2(1,2),leaf+new Vector2(1,2),Hex("9ebd74"),2);}
     if(fruit)foreach(var offset in new[]{new Vector2(10,13),new Vector2(21,19)})
     {
      foreach(var berry in new[]{new Vector2(-2,0),new Vector2(2,0),new Vector2(0,4)})c.Rect(offset.x+berry.x,offset.y+berry.y,3,3,Hex(ripe?"bc90d0":"86a06a"));
      if(ripe)c.Rect(offset.x,offset.y,2,2,Hex("e1b8e7"));
     }
    }
    else for(int i=0;i<(grown?3:1);i++)
    {
     var from=new Vector2(8+i*8,27);var head=from+new Vector2(0,-5-ratio*(12+i%2*4));c.Line(from,head,Hex("719c60"),2);c.Line(from+new Vector2(-3,-3),from+new Vector2(3,-3),Hex("91b174"),2);
     if(!fruit)continue;
     foreach(var offset in new[]{new Vector2(-3,0),new Vector2(3,0),new Vector2(0,-3),new Vector2(0,3)})c.Rect(head.x+offset.x-1,head.y+offset.y-1,3,3,Hex(ripe?"f0d2ad":"a3b477"));
     c.Rect(head.x-1,head.y-1,3,3,Hex("d4a365"));
    }
    if(fertilized)c.Rect(25,26,3,3,Hex("edcb76"));
   });
  }
  /// <summary>The small mark on a fertilized kitchen crop or tree.</summary>
  public static Sprite Fertilized=>Keep("fertilized",c=>c.Rect(26,27,2,2,Hex("e2c484")));
  /// <summary>The wild flowers beside the hive that feed the first bees.</summary>
  public static Sprite WildFlowers=>Keep("wild-flowers",c=>
  {
   foreach(var offset in new[]{new Vector2(9,12),new Vector2(20,23)}){c.Line(offset,offset+new Vector2(0,6),Hex("669455"),2);c.Disc(offset,4,Hex("e4b5c5"));c.Disc(offset,1.5f,Hex("f3dc85"));}
  });
  /// <summary>The corner marks on the tile the hoe is aimed at; green when the tool can work there.</summary>
  public static Sprite Preview(bool ok,bool channel,bool connected)=>Keep("preview:"+ok+":"+channel+":"+connected,c=>
  {
   Color color=Hex(ok?"b6d9ad":"e1b776");c.Rect(1,1,30,30,new Color(color.r,color.g,color.b,.10f));
   foreach(var corner in new[]{new Vector2(2,2),new Vector2(30,2),new Vector2(2,30),new Vector2(30,30)})
   {float dx=corner.x<16?5:-5,dy=corner.y<16?5:-5;c.Line(corner,corner+new Vector2(dx,0),color,2);c.Line(corner,corner+new Vector2(0,dy),color,2);}
   if(channel&&ok)c.Rect(8,8,16,16,Hex(connected?"7dbfd1":"c4a675",.45f));
  });
  /// <summary>The water overview: blue where water reaches, sand where it does not.</summary>
  public static Sprite WaterOutline(bool watered,bool channel)=>Keep("outline:"+watered+":"+channel,c=>
  {
   if(channel)c.Outline(4,4,24,24,Hex(watered?"8ac7d6":"d4b379"));else c.Outline(2,2,28,28,Hex(watered?"78b8cb":"d6ac73"));
  });
  /// <summary>The growth picture of the seed book for crops the source paints without an image.</summary>
  public static Texture2D Texture(Sprite sprite)=>sprite==null?null:sprite.texture;
 }
}
