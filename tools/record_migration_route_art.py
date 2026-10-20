#!/usr/bin/env python3
"""Capture original route decoration drawing twice in UUID-isolated Godot projects."""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,struct,subprocess,tempfile,uuid
from pathlib import Path
from migration_data_codec import canonical_bytes
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, no_symlink
ROOT=Path(__file__).resolve().parents[1]
REL="unity/Assets/BlueMapRoute/Runtime/Presentation/Resources/BlueMapRouteArt"
EXPORTER="tools/migration_route_art.gd"
def source_fingerprint():
 result=fingerprint(ROOT)
 for p in [*(ROOT/"assets").rglob("*"),ROOT/EXPORTER]:
  if p.is_file():result[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes().replace(b"\r\n",b"\n") if p.suffix==".gd" else p.read_bytes()).hexdigest()
 return result

def normalize(directory):
 index=json.loads((directory/"index.json").read_text(encoding="utf8"))
 if index.get("schemaVersion")!=1 or index.get("tilePixels")!=32 or index.get("alphaMode")!="premultiplied" or index.get("gameSaveAccessed") is not False:raise ValueError("Route art contract invalid")
 if not index["nodes"]:raise ValueError("No original route drawing captured")
 names={"index.json"};addresses=set()
 for row in index["nodes"]:
  key=(row["mapId"],row["address"])
  if row["mapId"] not in ["village","player_home","forest_edge","forest"] or key in addresses:raise ValueError("Duplicate or foreign source node")
  addresses.add(key)
  name=row["file"]
  if not re.fullmatch(r"node-[0-9a-f]{20}\.png",name):raise ValueError("Unsafe captured texture path")
  names.add(name);raw=(directory/name).read_bytes()
  if raw[:8]!=b"\x89PNG\r\n\x1a\n" or struct.unpack_from(">II",raw,16)!=(row["width"],row["height"]):raise ValueError("Route texture dimensions differ")
  row["sha256"]=hashlib.sha256(raw).hexdigest();row["bytes"]=len(raw)
  from PIL import Image
  with Image.open(directory/name) as image:row["rgbaSha256"]=hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()
  if row["script"] not in index["sourceFiles"]:raise ValueError("Captured drawing has no source identity")
 if {p.name for p in directory.iterdir() if p.is_file()}!=names:raise ValueError("Unexpected captured files")
 index["exporterSha256"]=hashlib.sha256((ROOT/EXPORTER).read_bytes().replace(b"\r\n",b"\n")).hexdigest()
 (directory/"index.json").write_bytes(canonical_bytes(index))
 return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.iterdir() if p.is_file()}

def verify_reference(directory):
 no_symlink(directory)
 index=json.loads((directory/"index.json").read_text(encoding="utf8"))
 if index.get("schemaVersion")!=1 or index.get("tilePixels")!=32 or index.get("alphaMode")!="premultiplied" or index.get("gameSaveAccessed") is not False:raise ValueError("Invalid source art manifest")
 if index.get("exporterSha256")!=hashlib.sha256((ROOT/EXPORTER).read_bytes().replace(b"\r\n",b"\n")).hexdigest():raise ValueError("Original art exporter identity changed")
 for name,digest in index["sourceFiles"].items():
  if not re.fullmatch(r"res://scripts/[a-zA-Z0-9_/]+\.gd",name):raise ValueError("Unsafe original script path")
  source=ROOT/name.removeprefix("res://");no_symlink(source)
  if hashlib.sha256(source.read_bytes().replace(b"\r\n",b"\n")).hexdigest()!=digest:raise ValueError("Original draw source changed: "+name)
 names={"index.json"};seen=set();snapshots={}
 for row in index["nodes"]:
  key=(row["mapId"],row["address"])
  if key in seen or row["mapId"] not in ["village","player_home","forest_edge","forest"]:raise ValueError("Duplicate/foreign original node")
  seen.add(key);name=row["file"]
  if not re.fullmatch(r"node-[0-9a-f]{20}\.png",name):raise ValueError("Unsafe original texture path")
  names.add(name);path=directory/name;no_symlink(path);raw=path.read_bytes()
  if hashlib.sha256(raw).hexdigest()!=row["sha256"] or len(raw)!=row["bytes"] or raw[:8]!=b"\x89PNG\r\n\x1a\n" or struct.unpack_from(">II",raw,16)!=(row["width"],row["height"]):raise ValueError("Original texture bytes/dimensions differ")
  from PIL import Image
  with Image.open(path) as image:
   if hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()!=row.get("rgbaSha256"):raise ValueError("Original source RGBA pixels differ")
  if row["mapId"] not in snapshots:
   data=json.loads((ROOT/"migration/world/snapshots/fresh_baseline"/(row["mapId"]+".json")).read_text(encoding="utf8"))
   snapshots[row["mapId"]]={"/".join(str(x) for x in n["address"]):n for n in data["scene"]}
  node=snapshots[row["mapId"]].get(row["address"])
  if node is None or node["script"]!=row["script"]:raise ValueError("Original scene address/script differs")
  position=[float(x["value"]) for x in node["globalTransform"]["origin"]["values"]]
  if position!=row["position"]:raise ValueError("Original source object moved in captured art")
 if {p.name for p in directory.iterdir() if p.is_file() and p.suffix!=".meta"}!=names:raise ValueError("Unexpected original route art files")
 if set(snapshots)!={"village","player_home","forest_edge","forest"}:raise ValueError("Original route maps incomplete")
 print("ROUTE ART SOURCE VERIFIED",len(seen),"source nodes,",len(names)-1,"original textures",flush=True)
 return {"nodes":len(seen),"textures":len(names)-1,"maps":len(snapshots),"gameSaveAccessed":False}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("godot",nargs="?");parser.add_argument("--verify-reference",action="store_true");parser.add_argument("--check",action="store_true");parser.add_argument("--evidence-dir",type=Path);parser.add_argument("--output-dir",type=Path,default=ROOT/REL);args=parser.parse_args()
 if args.verify_reference:verify_reference(args.output_dir);return
 if not args.godot or args.evidence_dir is None:parser.error("Native GPU replay requires godot and --evidence-dir")
 for p in [args.evidence_dir,args.output_dir]:no_symlink(p)
 if args.evidence_dir.exists() or (args.output_dir.exists() and not args.check):raise ValueError("Use a fresh evidence/output directory")
 if args.evidence_dir.resolve().is_relative_to(ROOT.resolve()):raise ValueError("Evidence must stay outside the source tree")
 engine=str(Path(args.godot).resolve());version=subprocess.run([engine,"--version"],capture_output=True,text=True,timeout=30)
 if version.returncode or version.stdout.strip()!=ENGINE_VERSION:raise ValueError("Wrong pinned Godot engine")
 before=source_fingerprint();args.evidence_dir.mkdir(parents=True)
 task=Path(tempfile.mkdtemp(prefix="bluemap-route-art-"));project=task/"project";project.mkdir()
 token="Bluemap-Codex-Tests-"+uuid.uuid4().hex
 for name in ["scripts","scenes","assets","translations","tools"]:shutil.copytree(ROOT/name,project/name,ignore=shutil.ignore_patterns("__pycache__"))
 for name in ["project.godot","icon.svg"]:shutil.copy2(ROOT/name,project/name)
 for script in [*(project/"scripts").rglob("*.gd"),*(project/"tools").rglob("*.gd")]:script.write_bytes(script.read_bytes().replace(b"\r\n",b"\n"))
 p=project/"project.godot";text=p.read_text(encoding="utf8");text=re.sub(r"^config/name=.*$","config/name="+json.dumps(token),text,flags=re.M);text=re.sub(r"^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?","",text,flags=re.M);text=text.replace("[application]","[application]\nconfig/use_custom_user_dir=false",1);p.write_text(text,encoding="utf8")
 startup=None
 if os.name=="nt":startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 def run(label,arguments,gpu=False):
  mode=["--rendering-method","gl_compatibility","--audio-driver","Dummy"] if gpu else ["--headless"]
  result=subprocess.run([engine,*mode,"--path",str(project),*arguments],cwd=project,capture_output=True,text=True,encoding="utf8",errors="replace",timeout=1200,startupinfo=startup,env=dict(os.environ,BLUEMAP_LANG="nl"))
  log=result.stdout+result.stderr;(args.evidence_dir/(label+".log")).write_text(log,encoding="utf8")
  if result.returncode or ERROR.search(log):raise RuntimeError(label+" failed: "+log[-10000:])
  return log
 run("import",["--editor","--import"])
 results=[]
 for number in (1,2):
  destination=args.evidence_dir/("export-"+str(number))
  log=run("export-"+str(number),["-s","res://"+EXPORTER,"--","--output-dir",str(destination)],True)
  if "MIGRATION ROUTE ART OK" not in log:raise ValueError("Route art export did not complete")
  results.append(normalize(destination));print("Original route art GPU export",number,"complete",flush=True)
 if results[0]!=results[1]:raise ValueError("Two native source route captures differ")
 if source_fingerprint()!=before:raise ValueError("Original source art changed during capture")
 if args.check:
  expected={p.name:hashlib.sha256(p.read_bytes().replace(b"\r\n",b"\n") if p.suffix==".json" else p.read_bytes()).hexdigest() for p in args.output_dir.iterdir() if p.is_file() and p.suffix!=".meta"}
  if results[0]!=expected:raise ValueError("Native source route capture differs from checked-in art")
 else:shutil.copytree(args.evidence_dir/"export-1",args.output_dir)
 receipt={"success":True,"schemaVersion":1,"engineVersion":ENGINE_VERSION,"repeatedEngineRuns":2,"sourceUnchanged":True,"gameSaveAccessed":False,"isolatedUserDirectoryToken":token,"capturedFiles":results[0],"project":str(project)}
 (args.evidence_dir/"receipt.json").write_bytes(canonical_bytes(receipt));print("ROUTE ART VERIFIED",len(results[0]),"files",flush=True)
if __name__=="__main__":main()
