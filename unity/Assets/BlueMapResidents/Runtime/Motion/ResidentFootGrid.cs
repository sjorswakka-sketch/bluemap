using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace BlueMapMigration.Residents
{
 // Square 32px, offset(16,16), no diagonals, default Euclidean heuristic.
 // The neighbor order, Float32 scores and binary-heap tie behavior deliberately
 // match Godot 4.4.1 AStarGrid2D; see GodotAStar.LICENSE.txt in this directory.
 public sealed class ResidentFootGrid
 {
  public readonly int Width,Height;
  readonly HashSet<Vector2Int> solid=new HashSet<Vector2Int>();
  public ResidentFootGrid(int width,int height,IEnumerable<Vector2Int> blocked=null){Width=width;Height=height;if(blocked!=null)foreach(var c in blocked)if(InBounds(c))solid.Add(c);}
  public bool InBounds(Vector2Int c)=>c.x>=0&&c.y>=0&&c.x<Width&&c.y<Height;
  public bool IsSolid(Vector2Int c)=>!InBounds(c)||solid.Contains(c);
  public void SetSolid(Vector2Int c,bool value=true){if(!InBounds(c))return;if(value)solid.Add(c);else solid.Remove(c);}
  public ResidentFootGrid Clone()=>new ResidentFootGrid(Width,Height,solid);
  public IReadOnlyList<Vector2Int> SolidCells=>solid.OrderBy(c=>c.y).ThenBy(c=>c.x).ToArray();
  public List<Vector2> FindPath(Vector2Int start,Vector2Int goal)
  {
   var result=new List<Vector2>();if(!InBounds(start)||!InBounds(goal))return result;
   // Godot returns this singleton even if the same start/goal is solid.
   if(start==goal){result.Add(Center(start));return result;}if(IsSolid(goal))return result;
   var nodes=new Dictionary<Vector2Int,Point>();var first=new Point{Cell=start,G=0,F=Cost(start,goal)};nodes[start]=first;
   var heap=new List<Point>{first};bool found=false;
   while(heap.Count>0)
   {
    var p=heap[0];if(p.Cell==goal){found=true;break;}Pop(heap);p.Closed=true;
    foreach(var step in new[]{new Vector2Int(0,-1),new Vector2Int(1,0),new Vector2Int(0,1),new Vector2Int(-1,0)})
    {
     var cell=p.Cell+step;if(IsSolid(cell))continue;
     if(nodes.TryGetValue(cell,out var e)&&e.Closed)continue;
     float g=Round(p.G+1);bool fresh=e==null;
     if(fresh){e=new Point{Cell=cell};nodes[cell]=e;heap.Add(e);}else if(g>=e.G)continue;
     e.Previous=p;e.G=g;e.F=Round(g+Cost(cell,goal));Push(heap,fresh?heap.Count-1:heap.IndexOf(e),0,e);
    }
   }
   if(!found)return result;var at=nodes[goal];while(at!=null){result.Add(Center(at.Cell));at=at.Previous;}result.Reverse();return result;
  }
  public List<Vector2> MemoryPath(Vector2 actor,Vector2Int goal,IEnumerable<Vector2> otherResidents,Vector2 player)
  {
   var grid=Clone();var start=ResidentMotionModel.Cell(actor);
   if(!InBounds(start)||!InBounds(goal)||IsSolid(goal))return new List<Vector2>();
   foreach(var p in (otherResidents??Enumerable.Empty<Vector2>()).Concat(new[]{player}))
   {var c=ResidentMotionModel.Cell(p);if(c==goal)return new List<Vector2>();if(grid.InBounds(c)&&c!=start)grid.SetSolid(c);}
   grid.SetSolid(start,false);return grid.FindPath(start,goal);
  }
  public List<Vector2> SupperPath(Vector2 actor,Vector2Int goal,IEnumerable<Vector2> otherResidents,Vector2 player)
  {
   var grid=Clone();var start=ResidentMotionModel.Cell(actor);
   foreach(var p in (otherResidents??Enumerable.Empty<Vector2>()).Concat(new[]{player}))grid.SetSolid(ResidentMotionModel.Cell(p));
   grid.SetSolid(start,false);grid.SetSolid(goal,false);return grid.FindPath(start,goal);
  }
  public Vector2 SafeSpawn(Vector2Int at,Vector2 player,IEnumerable<Vector2> residents)
  {
   foreach(var offset in new[]{Vector2Int.zero,Vector2Int.left,Vector2Int.right,Vector2Int.up,Vector2Int.down})
   {
    // Unity Vector2Int.up is source DOWN, coordinates here retain +Y down.
    var cell=at+offset;var p=Center(cell);
    if(!IsSolid(cell)&&ResidentMotionModel.Distance(p,player)>30&&!(residents??Enumerable.Empty<Vector2>()).Any(a=>ResidentMotionModel.Distance(p,a)<30))return p;
   }
   return Center(at);
  }
  public static Vector2 Center(Vector2Int c)=>new Vector2(c.x*32+16,c.y*32+16);
  static float Round(float v)=>BitConverter.Int32BitsToSingle(BitConverter.SingleToInt32Bits(v));
  static float Cost(Vector2Int a,Vector2Int b){var d=a-b;return (float)Math.Sqrt((long)d.x*d.x+(long)d.y*d.y);}
  sealed class Point{public Vector2Int Cell;public float G,F;public Point Previous;public bool Closed;}
  static bool Worse(Point a,Point b)=>a.F>b.F||(a.F==b.F&&a.G<b.G);
  static void Push(List<Point> heap,int hole,int top,Point value)
  {int parent=(hole-1)/2;while(hole>top&&Worse(heap[parent],value)){heap[hole]=heap[parent];hole=parent;parent=(hole-1)/2;}heap[hole]=value;}
  static void Pop(List<Point> heap)
  {
   int len=heap.Count-1;if(len==0){heap.Clear();return;}var value=heap[len];int hole=0,child=2;
   while(child<len){if(Worse(heap[child],heap[child-1]))child--;heap[hole]=heap[child];hole=child;child=2*(child+1);}
   if(child==len){heap[hole]=heap[child-1];hole=child-1;}Push(heap,hole,0,value);heap.RemoveAt(len);
  }
 }
 public sealed class ResidentRoamObstacle
 {public string Type="";public bool Enabled=true;public Vector2 PositionTiles,SizeTiles=Vector2.one;}
 public static class ResidentPassability
 {
  public static bool RoamSafe(Vector2 at,Vector2 anchor,string map,Func<Vector2,bool> tileSolid,IEnumerable<ResidentRoamObstacle> objects,IEnumerable<Vector2> otherNpcs)
  {
   if(ResidentMotionModel.Distance(at,anchor)>46)return false;
   foreach(var offset in new[]{new Vector2(-8,0),new Vector2(8,0),new Vector2(0,14),new Vector2(0,-10)})if(tileSolid!=null&&tileSolid(at+offset))return false;
   if(objects!=null)foreach(var o in objects)
   {
    if(!o.Enabled||o.Type=="npc"||o.Type=="trigger"||o.Type=="pickup"||o.Type=="profession_resource")continue;
    var min=ResidentMotionModel.Scale(o.PositionTiles,32)-new Vector2(14,14);var max=min+(ResidentMotionModel.Scale(o.SizeTiles,32)+new Vector2(28,28));
    if(at.x>=min.x&&at.y>=min.y&&at.x<max.x&&at.y<max.y)return false;
   }
   if(map=="village"&&at.y>=928)return false;
   return otherNpcs==null||!otherNpcs.Any(p=>ResidentMotionModel.Distance(p,at)<26);
  }
 }
}
