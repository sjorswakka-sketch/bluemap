using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.Combat
{
    /// <summary>The original captured sword/bow draws, sampled at original timers and rotated to actual independent aim.</summary>
    public sealed class PlayerCombatPresentation:IDisposable
    {
        readonly List<LineRenderer> lines=new List<LineRenderer>();int lineIndex;
        readonly Phase6Catalog catalog;readonly GameObject root;readonly SpriteRenderer sword,bow;
        public bool SwordVisible=>sword.enabled;public bool BowVisible=>bow.enabled;
        public PlayerCombatPresentation(Phase6Catalog source,Transform parent)
        {catalog=source;root=new GameObject("Original player attack drawings");root.transform.SetParent(parent,false);sword=Make("Source sword");bow=Make("Source bow");}
        SpriteRenderer Make(string name){var obj=new GameObject(name);obj.transform.SetParent(root.transform,false);return obj.AddComponent<SpriteRenderer>();}
        static string Row(Vector2 d)=>Mathf.Abs(d.y)>Mathf.Abs(d.x)?(d.y>0?"down":"up"):(d.x>0?"right":"left");
        void Draw(SpriteRenderer renderer,string id,Vector2 direction,int order)
        {var sprite=catalog.GetSprite(id);renderer.enabled=sprite!=null;if(sprite==null)return;catalog.Apply(renderer,sprite);renderer.sortingOrder=order;string row=Row(direction);float cardinal=row=="down"?90:row=="up"?-90:row=="left"?180:0;renderer.transform.localRotation=Quaternion.Euler(0,0,-(Mathf.Atan2(direction.y,direction.x)*Mathf.Rad2Deg-cardinal));}
        public void Draw(CombatModel model,Vector2 at)
        {
            sword.enabled=bow.enabled=false;foreach(var line in lines)line.gameObject.SetActive(false);lineIndex=0;if(model==null)return;var p=model.Player;if(p.Invulnerable>0&&(int)(p.Invulnerable*12)%2==0)return;
            if(p.AttackTimer>0)Draw(sword,"generated:sword:"+model.State.Get("weapon").AsString()+":"+(p.ComboSweep?"true":"false")+":"+Row(p.AttackDirection)+":"+Mathf.Clamp((int)((1-p.AttackTimer/.18)*8),0,7),p.AttackDirection,Mathf.RoundToInt(at.y)+3);
            Technique(model,Mathf.RoundToInt(at.y)+4);
            if(p.BowAnim>0)Draw(bow,"generated:bow:"+Row(p.BowDirection)+":"+Mathf.Clamp((int)((1-p.BowAnim/.25)*8),0,7),p.BowDirection,Mathf.RoundToInt(at.y)+3);
        }
        void Line(Vector2[] points,Color color,float width,int order)
        {
            LineRenderer line;if(lineIndex<lines.Count)line=lines[lineIndex];else{var go=new GameObject("Original player technique draw");go.transform.SetParent(root.transform,false);line=go.AddComponent<LineRenderer>();line.useWorldSpace=false;line.sharedMaterial=catalog.straightMaterial;line.numCapVertices=0;lines.Add(line);}lineIndex++;line.gameObject.SetActive(true);line.positionCount=points.Length;for(int i=0;i<points.Length;i++)line.SetPosition(i,FoundationCoordinates.ToUnity(points[i]));line.startWidth=line.endWidth=width/32;line.startColor=line.endColor=color;line.sortingOrder=order;
        }
        void Arc(Vector2 at,float radius,float start,float span,int count,Color color,float width,int order)
        {var points=new Vector2[count+1];for(int i=0;i<=count;i++){float a=start+span*i/count;points[i]=at+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*radius;}Line(points,color,width,order);}
        void Technique(CombatModel model,int order)
        {
            var p=model.Player;if(p.Phase=="")return;Vector2 d=p.TechniqueDirection;float a=Mathf.Atan2(d.y,d.x);var color=new Color(.55f,.9f,1);
            if(p.Profile.TryGet("mode",out var mode)&&mode.AsString()=="cw_anchor"&&p.Phase!="strike")
            {color=p.Phase=="counter"?new Color(242/255f,209/255f,138/255f):new Color(163/255f,217/255f,220/255f);Arc(Vector2.zero,23,a-1.1f,2.2f,22,color,4,order);Line(new[]{d*8,d*(p.Phase=="counter"?40:18)},color,2,order);if(p.Phase=="guard")Arc(new Vector2(0,-28),6,0,Mathf.PI*2*Mathf.Clamp01((float)(1-p.Elapsed/.32)),14,color,2,order);return;}
            if(p.Phase=="prepare")
            {float progress=Mathf.Clamp01((float)(p.Elapsed/p.Profile.Require("windup").AsDouble()));Line(new[]{new Vector2(-15,-26),new Vector2(15,-26)},new Color(.03f,.07f,.1f),4,order);Line(new[]{new Vector2(-14,-26),new Vector2(-14+28*progress,-26)},color,2,order+1);Line(new[]{d*12,d*32},new Color(color.r,color.g,color.b,.5f),2,order);if(p.Ranged)Arc(d*12,11,a-Mathf.PI/2,Mathf.PI,12,color,2,order);else Line(new[]{-d*4,-d*17},color,3,order);}
            else if(!p.Ranged)
            {float reach=(float)(model.Reach+p.Profile.Require("reach").AsDouble()),length=reach*Mathf.Sin(Mathf.Clamp01((float)(p.Elapsed/.2))*Mathf.PI);if(p.Profile.Require("cone").AsDouble()<0)Arc(Vector2.zero,reach-4,a-1.8f,3.6f,24,new Color(color.r,color.g,color.b,.6f),5,order);else{Line(new[]{d*8,d*length},color,5,order);Line(new[]{d*8,d*length},Color.white,1,order+1);}}
        }
        public void Dispose(){if(root!=null){root.SetActive(false);UnityEngine.Object.Destroy(root);}}
    }
}
