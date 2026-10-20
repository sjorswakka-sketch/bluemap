using System;
using System.Collections.Generic;
using System.Globalization;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    public sealed partial class LegacySaveImporter
    {
        public bool IsKnownWeapon(string id)=>id!=null&&rules.Require("weapons").TryGet(id,out _);
        private FoundationValue NormalizeFarm(FoundationValue raw,double clock)
        {
            var cells=new Dictionary<string,FoundationValue>();var jobs=new Dictionary<string,FoundationValue>();var animals=new Dictionary<string,FoundationValue>();var drops=new Dictionary<string,FoundationValue>();
            if(!Obj(raw))raw=Empty();var saved=Get(raw,"cells",Empty());
            if(Obj(saved))foreach(var p in saved.Entries)
            {
                var at=ParseCell(p.Key.AsString(),false);if(at.X<4||at.X>=35||at.Y<29||at.Y>=41||at.X==20||at.X==21||!Obj(p.Value))continue;
                string kind=MaybeString(Get(p.Value,"kind",S("")));if(kind!="soil"&&kind!="channel")continue;var entry=new Dictionary<string,FoundationValue>{{"kind",S(kind)}};
                string crop=MaybeString(Get(p.Value,"crop",S("")));if(kind=="soil"&&rules.Require("crops").TryGet(crop,out var data))
                {
                    entry["crop"]=S(crop);bool established=True(Get(p.Value,"established",B(false)))&&data.TryGet("regrow",out _);if(established)entry["established"]=B(true);
                    entry["growth"]=N(Bound(Get(p.Value,"growth",FoundationValue.Nil()),0,Get(data,established?"regrow":"seconds",N(0)).AsDouble()));entry["fertilized"]=B(True(Get(p.Value,"fertilized",B(false))));
                }cells[p.Key.AsString()]=O(entry);
            }
            saved=Get(raw,"jobs",Empty());if(Obj(saved))foreach(var p in rules.Require("farmJobs").Entries)
            {var job=Get(saved,p.Key.AsString(),FoundationValue.Nil());if(Obj(job))jobs[p.Key.AsString()]=O("batches",I((long)Bound(Get(job,"batches",FoundationValue.Nil()),1,20)),"time",N(Bound(Get(job,"time",FoundationValue.Nil()),0,p.Value.Require("seconds").AsDouble())));}
            foreach(string field in new[]{"animal_due","drops"})
            {
                saved=Get(raw,field,Empty());if(!Obj(saved))continue;var output=field=="animal_due"?animals:drops;
                foreach(var p in saved.Entries)
                {
                    if(output.Count>=128)break;string id=p.Key.AsString();if(id.Length>140)continue;
                    if(field=="animal_due")output[id]=N(Bound(p.Value,0,clock+90));
                    else if(Obj(p.Value)&&Get(p.Value,"map",FoundationValue.Nil()).Kind=="string")
                    {var pos=Get(p.Value,"pos",FoundationValue.Nil());if(pos.Kind=="array"&&pos.Items.Count==2&&Numeric(pos.Items[0])&&Numeric(pos.Items[1]))output[id]=O("map",p.Value.Require("map"),"pos",A(N(Bound(pos.Items[0],0,10000)),N(Bound(pos.Items[1],0,10000))));}
                }
            }
            return O("cells",O(cells),"jobs",O(jobs),"animal_due",O(animals),"drops",O(drops),"wild_due",N(Bound(Get(raw,"wild_due",FoundationValue.Nil()),0,clock+120)),"honey",I((long)Bound(Get(raw,"honey",FoundationValue.Nil()),0,8)),"honey_time",N(Bound(Get(raw,"honey_time",FoundationValue.Nil()),0,120)));
        }
        private FoundationValue NormalizeHome(FoundationValue raw)
        {
            var result=Copy(rules.Require("homeDefaults"));if(!Obj(raw))return O(result);
            foreach(string k in new[]{"floor","wall","light"})result[k]=I((long)Bound(Get(raw,k,I(0)),0,k=="light"?2:3));
            var owned=Copy(result["owned"]);var saved=Get(raw,"owned",Empty());if(Obj(saved))foreach(var p in rules.Require("homePieces").Entries)owned[p.Key.AsString()]=I(Math.Max(owned[p.Key.AsString()].AsInt64(),(long)Bound(Get(saved,p.Key.AsString(),I(0)),0,p.Value.Require("cap").AsInt64())));result["owned"]=O(owned);
            var layout=Get(raw,"layout",FoundationValue.Nil());if(Obj(layout)&&ValidHome(layout,result["owned"]))
            {var clean=new Dictionary<string,FoundationValue>();foreach(var p in layout.Entries){var e=p.Value;clean[p.Key.AsString()]=O("kind",e.Require("kind"),"cell",A(I(Int(e.Require("cell").Items[0])),I(Int(e.Require("cell").Items[1]))),"tint",I(Int(Get(e,"tint",I(0)))));}result["layout"]=O(clean);}return O(result);
        }
        private bool ValidHome(FoundationValue layout,FoundationValue owned)
        {
            if(layout.Entries.Count>12)return false;
            var used=new HashSet<Cell>();foreach(var rect in new[]{new Rect(7,3,1,2),new Rect(9,7,1,2),new Rect(10,5,1,1)})foreach(var c in rect.Cells())used.Add(c);
            var counts=new Dictionary<string,int>();int solid=0;
            foreach(var p in layout.Entries)
            {
                string id=p.Key.AsString();var e=p.Value;if(!Obj(e))return false;string kind=MaybeString(Get(e,"kind",S("")));if(!rules.Require("homePieces").TryGet(kind,out var piece))return false;
                bool basic=True(Get(piece,"base",B(false)));if(basic){if(id!=kind)return false;}else
                {string prefix=kind+":";if(!id.StartsWith(prefix,StringComparison.Ordinal)||!System.Text.RegularExpressions.Regex.IsMatch(id.Substring(prefix.Length),@"\A[+-]?[0-9]+\z")||!long.TryParse(id.Substring(prefix.Length),NumberStyles.Integer,CultureInfo.InvariantCulture,out long n)||n<1||n>piece.Require("cap").AsInt64())return false;}
                var cell=Get(e,"cell",FoundationValue.Nil());if(cell.Kind!="array"||cell.Items.Count!=2)return false;foreach(var n in cell.Items)if(!Numeric(n)||n.AsDouble()<2||n.AsDouble()>11||Math.Floor(n.AsDouble())!=n.AsDouble())return false;
                var tint=Get(e,"tint",I(0));if(!Numeric(tint)||tint.AsDouble()<0||tint.AsDouble()>2||Math.Floor(tint.AsDouble())!=tint.AsDouble())return false;
                counts.TryGetValue(kind,out int count);counts[kind]=count+1;if(count+1>Get(owned,kind,I(0)).AsInt64())return false;
                var area=new Rect((int)Int(cell.Items[0]),(int)Int(cell.Items[1]),(int)Int(piece.Require("size").Items[0]),(int)Int(piece.Require("size").Items[1]));if(area.X<2||area.Y<2||area.EndX>12||area.EndY>12)return false;if(True(Get(piece,"floor",B(false))))continue;
                foreach(var c in area.Cells()){if(ReservedHome(c)||!used.Add(c))return false;solid++;}
            }
            if(solid>26)return false;foreach(string k in new[]{"bed","table","shelf"})if(!layout.TryGet(k,out var e)||MaybeString(Get(e,"kind",S("")))!=k)return false;
            var seen=Flood(used,14,14,new Cell(6,10),c=>c.X>=2&&c.X<12&&c.Y>=2&&c.Y<12);if(seen.Count!=100-used.Count)return false;
            var bed=layout.Require("bed").Require("cell");var b=new Rect((int)Int(bed.Items[0]),(int)Int(bed.Items[1]),1,2);return seen.Contains(new Cell(b.X-1,b.EndY-1))||seen.Contains(new Cell(b.EndX,b.EndY-1))||seen.Contains(new Cell(b.X,b.EndY));
        }
        private static bool ReservedHome(Cell at)=>((at.X==6||at.X==7)&&at.Y>=6)||(at.Y==5&&at.X>=6)||at.Equals(new Cell(10,6))||at.Equals(new Cell(9,9));
        private FoundationValue NormalizeYard(FoundationValue raw,FoundationValue farm)
        {
            var result=Copy(rules.Require("yardDefaults"));if(!Obj(raw))return O(result);var extensions=new List<FoundationValue>();var ids=new HashSet<string>();var saved=Get(raw,"extensions",A());if(saved.Kind=="array")foreach(var id in saved.Items)if(id.Kind=="string"&&rules.Require("yardExtensions").TryGet(id.AsString(),out _)&&ids.Add(id.AsString()))extensions.Add(id);result["extensions"]=FoundationValue.Array(extensions);
            var owned=Copy(result["owned"]);saved=Get(raw,"owned",Empty());if(Obj(saved))foreach(var p in rules.Require("yardSupplies").Entries){var n=Get(saved,p.Key.AsString(),I(0));if(Numeric(n))owned[p.Key.AsString()]=I(Math.Max(owned[p.Key.AsString()].AsInt64(),(long)Bound(n,0,p.Value.Require("cap").AsInt64())));}result["owned"]=O(owned);
            var stations=Copy(result["stations"]);saved=Get(raw,"stations",Empty());if(Obj(saved))foreach(var p in rules.Require("yardUnits").Entries)
            {string id=p.Key.AsString();var a=Get(saved,id,p.Value.Require("start"));if(a.Kind=="array"&&a.Items.Count==0)stations[id]=a;else if(a.Kind=="array"&&a.Items.Count==2&&Numeric(a.Items[0])&&Numeric(a.Items[1])&&a.Items[0].AsDouble()>=0&&a.Items[0].AsDouble()<40&&a.Items[1].AsDouble()>=0&&a.Items[1].AsDouble()<44)stations[id]=A(I(Int(a.Items[0])),I(Int(a.Items[1])));}
            result["stations"]=O(stations);
            if(!ValidYard(O(result),farm,rules.Require("yardDefaults")))
            {foreach(var p in rules.Require("yardUnits").Entries)if(!Same(stations[p.Key.AsString()],p.Value.Require("start")))stations[p.Key.AsString()]=A();result["stations"]=O(stations);}
            foreach(string field in new[]{"paths","fences"})
            {
                saved=Get(raw,field,Empty());if(!Obj(saved))continue;var pieces=new Dictionary<string,FoundationValue>();
                foreach(var p in saved.Entries)
                {
                    if(pieces.Count>=(field=="paths"?80:40))break;string id=p.Key.AsString();if(p.Value.Kind!="string")continue;string kind=p.Value.AsString();Cell at=ParseCell(id,true);
                    if(!rules.Require("yardPieces").TryGet(kind,out var info)||True(Get(info,"path",B(false)))!=(field=="paths")||at.Key!=id)continue;
                    if(PlaceYard(at,O(result),farm,field=="fences"))pieces[id]=p.Value;
                }result[field]=O(pieces);
            }
            if(!ValidYard(O(result),farm,O(result))){result["paths"]=Empty();result["fences"]=Empty();}return O(result);
        }
        private bool PlaceYard(Cell at,FoundationValue data,FoundationValue farm,bool solid)
        {
            bool owned=false;foreach(var r in rules.Require("yardPlots").Items)if(Rect.From(r).Has(at))owned=true;
            foreach(var id in data.Require("extensions").Items)if(Rect.From(rules.Require("yardExtensions").Require(id.AsString()).Require("rect")).Has(at))owned=true;
            if(!owned||Terrain(at)!="."||fixedCells.Contains(at)||(solid&&ReservedYard(at))||farm.TryGet(at.Key,out _))return false;
            foreach(var p in farm.Entries)if(MaybeString(Get(p.Value,"crop",S("")))=="apple"&&new Rect(ParseCell(p.Key.AsString(),false).X-1,ParseCell(p.Key.AsString(),false).Y-1,3,3).Has(at))return false;return true;
        }
        private bool ValidYard(FoundationValue data,FoundationValue farm,FoundationValue baseline)
        {
            var paths=data.Require("paths");var fences=data.Require("fences");if(paths.Entries.Count>80||fences.Entries.Count>40)return false;
            var uses=new Dictionary<string,int>();foreach(var p in paths.Entries){string k=p.Value.AsString();uses.TryGetValue(k,out int n);uses[k]=n+1;}foreach(var p in fences.Entries){string g=rules.Require("yardPieces").Require(p.Value.AsString()).Require("group").AsString();uses.TryGetValue(g,out int n);uses[g]=n+1;}
            foreach(var p in rules.Require("yardSupplies").Entries)if(uses.TryGetValue(p.Key.AsString(),out int count)&&count>Get(data.Require("owned"),p.Key.AsString(),I(0)).AsInt64())return false;
            var areas=new Dictionary<string,Rect>();foreach(var p in rules.Require("yardUnits").Entries)
            {
                string id=p.Key.AsString();var a=data.Require("stations").Require(id);if(a.Items.Count==0)continue;var at=new Cell((int)Int(a.Items[0]),(int)Int(a.Items[1]));var r=new Rect(at.X-1,at.Y-1,3,3);areas[id]=r;
                bool original=false;foreach(var unit in rules.Require("yardUnits").Entries)if(Same(a,unit.Value.Require("start")))original=true;
                bool untouched=original&&Same(baseline.Require("stations").Require(id),a);
                foreach(var c in r.Cells()){if(!original){if(!PlaceYard(c,data,farm,true))return false;}else if(!untouched&&farm.TryGet(c.Key,out _))return false;}
            }
            foreach(var a in areas)foreach(var b in areas)if(a.Key!=b.Key&&a.Value.Grow(1).Intersects(b.Value))return false;
            foreach(string field in new[]{"paths","fences"})foreach(var p in data.Require(field).Entries)
            {var at=ParseCell(p.Key.AsString(),true);if(!PlaceYard(at,data,farm,field=="fences"))return false;foreach(var a in areas)if(a.Value.Has(at))return false;if(field=="paths"&&fences.TryGet(p.Key.AsString(),out var f)&&!True(Get(rules.Require("yardPieces").Require(f.AsString()),"gate",B(false))))return false;}
            var blocked=new HashSet<Cell>(fixedCells);foreach(var p in data.Require("stations").Entries){var a=p.Value;if(a.Items.Count==0)continue;var at=new Cell((int)Int(a.Items[0]),(int)Int(a.Items[1]));blocked.Add(at);if(p.Key.AsString()=="compost")blocked.Add(new Cell(at.X-1,at.Y));}
            foreach(var p in fences.Entries)if(!True(Get(rules.Require("yardPieces").Require(p.Value.AsString()),"gate",B(false))))blocked.Add(ParseCell(p.Key.AsString(),true));blocked.Remove(new Cell(7,22));
            var seen=Flood(blocked,40,44,new Cell(7,22),c=>!solidChars.Contains(Terrain(c)));
            foreach(var c in baseReach)if(OnPlot(c)&&!blocked.Contains(c)&&!seen.Contains(c))return false;
            foreach(var c in new[]{new Cell(9,27),new Cell(6,24),new Cell(19,40),new Cell(18,31),new Cell(23,31),new Cell(18,37),new Cell(23,37)})if(baseReach.Contains(c)&&!seen.Contains(c))return false;return true;
        }
        private bool OnPlot(Cell at){foreach(var r in rules.Require("yardPlots").Items)if(Rect.From(r).Has(at))return true;foreach(var r in rules.Require("yardExtensions").Entries)if(Rect.From(r.Value.Require("rect")).Has(at))return true;return false;}
        private string Terrain(Cell c){var rows=rules.Require("yardRows");return c.Y>=0&&c.Y<rows.Items.Count&&c.X>=0&&c.X<rows.Items[c.Y].AsString().Length?rows.Items[c.Y].AsString()[c.X].ToString():"#";}
        private static bool ReservedYard(Cell c)=>new Rect(6,21,4,4).Has(c)||new Rect(17,30,9,3).Has(c)||new Rect(17,36,9,3).Has(c)||new Rect(17,39,6,4).Has(c)||c.Equals(new Cell(9,27))||c.Equals(new Cell(6,24));
        private static HashSet<Cell> Flood(HashSet<Cell> blocked,int width,int height,Cell start,Func<Cell,bool> allowed)
        {var seen=new HashSet<Cell>{start};var q=new Queue<Cell>();q.Enqueue(start);while(q.Count>0){var at=q.Dequeue();foreach(var d in new[]{new Cell(1,0),new Cell(-1,0),new Cell(0,1),new Cell(0,-1)}){var c=new Cell(at.X+d.X,at.Y+d.Y);if(c.X>=0&&c.X<width&&c.Y>=0&&c.Y<height&&!blocked.Contains(c)&&allowed(c)&&seen.Add(c))q.Enqueue(c);}}return seen;}
        private readonly struct Cell:IEquatable<Cell>
        {public readonly int X,Y;public Cell(int x,int y){X=x;Y=y;}public string Key=>X.ToString(CultureInfo.InvariantCulture)+","+Y.ToString(CultureInfo.InvariantCulture);public bool Equals(Cell o)=>X==o.X&&Y==o.Y;public override bool Equals(object o)=>o is Cell c&&Equals(c);public override int GetHashCode()=>unchecked(X*397^Y);}
        private readonly struct Rect
        {public readonly int X,Y,W,H;public int EndX=>X+W;public int EndY=>Y+H;public Rect(int x,int y,int w,int h){X=x;Y=y;W=w;H=h;}public bool Has(Cell c)=>c.X>=X&&c.X<EndX&&c.Y>=Y&&c.Y<EndY;public bool Intersects(Rect r)=>X<r.EndX&&EndX>r.X&&Y<r.EndY&&EndY>r.Y;public Rect Grow(int n)=>new Rect(X-n,Y-n,W+n*2,H+n*2);public IEnumerable<Cell> Cells(){for(int y=Y;y<EndY;y++)for(int x=X;x<EndX;x++)yield return new Cell(x,y);}public static Rect From(FoundationValue a)=>new Rect((int)Int(a.Items[0]),(int)Int(a.Items[1]),(int)Int(a.Items[2]),(int)Int(a.Items[3]));}
        private static Cell ParseCell(string text,bool strict)
        {var p=text.Split(',');if(p.Length!=2)return new Cell(-99,-99);if(strict&&(!long.TryParse(p[0],NumberStyles.Integer,CultureInfo.InvariantCulture,out _)||!long.TryParse(p[1],NumberStyles.Integer,CultureInfo.InvariantCulture,out _)))return new Cell(-99,-99);try{return new Cell((int)Int(S(p[0])),(int)Int(S(p[1])));}catch{return new Cell(-99,-99);}}
        private static HashSet<Cell> CellSet(FoundationValue a){var s=new HashSet<Cell>();foreach(var c in a.Items)s.Add(new Cell((int)Int(c.Items[0]),(int)Int(c.Items[1])));return s;}
    }
}
