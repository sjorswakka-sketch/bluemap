#!/usr/bin/env python3
"""Render isolated native game evidence; requires a display.
Uses only the standard library. Keeps logs and JSON for comparison.
"""
import argparse, json, os, re, shutil, subprocess, tempfile, time, uuid
from pathlib import Path
from run_tests import ERROR
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('godot');p.add_argument('--label',default='world-atlas');p.add_argument('--source')
a=p.parse_args();engine=str(Path(shutil.which(a.godot) or a.godot).resolve())
source=Path(a.source).resolve() if a.source else Path(__file__).resolve().parent.parent
folder=Path(tempfile.mkdtemp(prefix='bluemap-whole-'+a.label+'-'));project=folder/'project'
shutil.copytree(source,project,ignore=shutil.ignore_patterns('.git','.godot','__pycache__','build','dist'))
shutil.copyfile(Path(__file__).with_name('world_map_preview.gd'),project/'tools/world_map_preview.gd')
token='Bluemap-Codex-Tests-'+uuid.uuid4().hex
settings=(project/'project.godot').read_text(encoding='utf8')
settings=re.sub(r'^config/name=.*$', 'config/name='+json.dumps(token),settings,flags=re.M)
settings=re.sub(r'^config/use_custom_user_dir=.*\n?','',settings,flags=re.M)
(project/'project.godot').write_text(settings,encoding='utf8')
(project/'isolation_probe.gd').write_text('extends SceneTree\nfunc _initialize():\n var p:=OS.get_user_data_dir()\n print("ISOLATED_USER_DIR="+p)\n quit(0 if p.get_file()=='+json.dumps(token)+' else 1)\n',encoding='utf8')
env=dict(os.environ,BLUEMAP_LANG='nl');user_dir=None
try:
 for label,args in [('import',['--headless','--editor','--import']),('isolation',['--headless','-s','res://isolation_probe.gd']),('space',['--headless','-s','res://tools/world_space_audit.gd']),*[(f'{state}_{lang}_{width}{suffix}', ['--audio-driver','Dummy','-s','res://tools/world_map_preview.gd','--',f'--state={state}',f'--lang={lang}',f'--view={width}x{height}',f'--output={project / (state+"_"+lang+"_"+str(width)+suffix+".png")}', *(['--controller'] if suffix else [])]) for state,lang,width,height,suffix in [('fresh','nl',960,540,''),('sparse','nl',1152,648,''),('legacy','nl',960,540,''),('all','nl',1152,648,''),('all','nl',960,540,'_controller'),('fresh','en',960,540,''),('sparse','en',1152,648,''),('legacy','en',1152,648,''),('all','en',960,540,''),('all','en',960,540,'_controller')]]]:
  start=time.perf_counter()
  try:
   r=subprocess.run([engine,'--path',str(project),*args],capture_output=True,text=True,encoding='utf8',errors='replace',env=env,timeout=240)
  except subprocess.TimeoutExpired as exc:
   output=lambda value: value.decode('utf8','replace') if isinstance(value,bytes) else (value or '')
   (folder/(label+'.log')).write_text('TIMEOUT\n'+output(exc.stdout)+output(exc.stderr),encoding='utf8')
   raise SystemExit('Timed out; evidence retained: '+str(folder))
  log=r.stdout+r.stderr;(folder/(label+'.log')).write_text(log,encoding='utf8')
  print(label,r.returncode,round(time.perf_counter()-start,3),'s',log[-700:],flush=True)
  if r.returncode or ERROR.search(log):raise SystemExit(1)
  if label=='isolation':
   match=re.search(r'^ISOLATED_USER_DIR=(.+)$',log,re.M)
   if not match or Path(match[1].strip()).name!=token:raise SystemExit('Save isolation not verified')
   user_dir=Path(match[1].strip())
  if label not in ['import','isolation','space'] and 'ATLAS_PREVIEW=' not in log:raise SystemExit('Missing completion marker')
 print('EVIDENCE='+str(folder),flush=True)
finally:
 if user_dir is not None and user_dir.name==token and user_dir.exists():shutil.rmtree(user_dir)
