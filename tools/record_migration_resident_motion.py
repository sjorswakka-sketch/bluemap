#!/usr/bin/env python3
"""Two fresh, silent, UUID-isolated Godot processes invoke original resident code."""
from __future__ import annotations
import argparse, hashlib, json, math, os, re, shutil, struct, subprocess, sys, tempfile, uuid
from pathlib import Path
from migration_data_codec import canonical_bytes
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, first_differences, no_symlink
ROOT=Path(__file__).resolve().parents[1]
SCHEMA='bluemap.resident-motion.source-oracle.v1'
COMPARISON_POLICY='exact-tagged-f32-vectors-f64-scalars-no-tolerance-v1'
FAMILIES={'route','path','safe','step','pose','occupancy','spawn'}

def validate_numeric_witnesses(value):
    count=0
    if isinstance(value,dict):
        tags=set(value)&{'$f64','$v2'}
        if tags:
            if len(value)!=1 or len(tags)!=1: raise ValueError('Malformed numeric witness')
            tag=next(iter(tags)); text=value[tag]
            if not isinstance(text,str) or not re.fullmatch('[0-9a-f]{16}',text): raise ValueError('Invalid exact numeric encoding')
            numbers=struct.unpack('<d' if tag=='$f64' else '<ff',bytes.fromhex(text))
            if not all(math.isfinite(x) for x in numbers): raise ValueError('Nonfinite numeric witness')
            return len(numbers)
        for child in value.values(): count+=validate_numeric_witnesses(child)
    elif isinstance(value,list):
        for child in value: count+=validate_numeric_witnesses(child)
    elif isinstance(value,float): raise ValueError('Untagged floating point number')
    return count

def validate_document(document):
    if document.get('schema')!=SCHEMA or document.get('personalSavesUsed') is not False or document.get('numericEncoding')!='tagged-little-endian-ieee754-v1': raise ValueError('Motion schema/privacy changed')
    validate_numeric_witnesses(document)
    rows=document.get('cases',[]); ids=set();families=set()
    for row in rows:
        if set(row)!={'id','kind','inputs','before','expected'} or not row['id'] or row['id'] in ids or row['kind'] not in FAMILIES: raise ValueError('Invalid/duplicate motion case')
        ids.add(row['id']);families.add(row['kind'])
    if families!=FAMILIES or len(rows)<500 or len(document.get('catalog',{}).get('places',{}))!=8: raise ValueError('Incomplete original motion coverage')
    for kind in ('npc','village','supper','memory'):
        for branch in ('wait','wait_cross','path_request','path_empty','arrive','last_arrive','move','blocked','stuck','mode_reset','locked','near','cat_excluded'):
            if 'step_'+kind+'_'+branch not in ids: raise ValueError('Missing motion branch')
    return document

def main():
    p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--evidence-dir',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args()
    before=fingerprint(ROOT);token='Bluemap-Codex-Tests-ResidentMotion-'+str(uuid.uuid4());user_dir=None
    try:
        no_symlink(args.evidence_dir);args.evidence_dir.mkdir(parents=True,exist_ok=True)
        if any(args.evidence_dir.iterdir()): raise ValueError('Use a fresh evidence directory')
        engine=shutil.which(args.godot)
        if not engine: raise ValueError('Godot executable not found')
        version=subprocess.run([engine,'--version'],capture_output=True,text=True,timeout=30)
        if version.returncode or version.stdout.strip()!=ENGINE_VERSION: raise ValueError('Requires exact Godot '+ENGINE_VERSION)
        with tempfile.TemporaryDirectory(prefix=token+'-',dir=args.evidence_dir.parent) as temp:
            project=Path(temp)/'project';shutil.copytree(ROOT,project,ignore=shutil.ignore_patterns('.git','.godot','.testdata','build','dist','__pycache__','unity','migration'))
            settings=project/'project.godot';text=settings.read_text(encoding='utf-8');text=re.sub(r'^config/name=.*$','config/name='+json.dumps(token),text,flags=re.M);text=re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?','',text,flags=re.M);text=text.replace('[application]','[application]\nconfig/use_custom_user_dir=false',1);settings.write_text(text,encoding='utf-8')
            (project/'route_isolation_probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tvar p:=OS.get_user_data_dir()\n\tprint("ISOLATED_USER_DIR="+p)\n\tquit(0 if p.replace(char(92),"/").get_file()=='+json.dumps(token)+' else 1)\n',encoding='utf-8')
            def run(label,arguments,marker=None):
                result=subprocess.run([engine,'--headless','--audio-driver','Dummy','--path',str(project),*arguments],cwd=project,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,env=dict(os.environ,BLUEMAP_LANG='nl'))
                log=result.stdout+result.stderr;(args.evidence_dir/(label+'.log')).write_text(log,encoding='utf-8')
                if result.returncode or ERROR.search(log) or (marker and marker not in log): raise ValueError(label+' failed: '+log[-12000:])
                return log
            run('import',['--editor','--import']);log=run('isolation',['-s','res://route_isolation_probe.gd']);match=re.search(r'^ISOLATED_USER_DIR=(.+)$',log,re.M)
            if not match or Path(match[1].strip()).name!=token: raise ValueError('Exact UUID isolation not verified')
            user_dir=Path(match[1].strip());outputs=[]
            for n in (1,2):
                out=args.evidence_dir/('run-'+str(n)+'.json');run('run-'+str(n),['--quit-after','600','-s','res://tools/migration_resident_motion_export.gd','--','--output',str(out)],'MIGRATION RESIDENT MOTION EXPORT OK');outputs.append(canonical_bytes(validate_document(json.loads(out.read_text(encoding='utf-8')))))
            if outputs[0]!=outputs[1]:
                (args.evidence_dir/'difference.json').write_bytes(canonical_bytes(first_differences(json.loads(outputs[0]),json.loads(outputs[1]),limit=20)));raise ValueError('Motion source recording changed across fresh processes')
            if fingerprint(ROOT)!=before: raise ValueError('Original source changed during recording')
            data=json.loads(outputs[0])
            if args.check:
                if canonical_bytes(validate_document(json.loads(args.output.read_text(encoding='utf-8'))))!=outputs[0]: raise ValueError('Fresh source motion disagrees with frozen reference')
            else:
                if args.output.exists(): raise ValueError('Never overwrite existing motion evidence')
                args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(outputs[0])
            (args.evidence_dir/'motion-oracle.json').write_bytes(outputs[0]);sources=sorted({m.split('::')[0] for m in data['sourceMethods']}|{'scripts/core/world_memory.gd','scripts/entities/npc.gd','scripts/entities/coast_resident.gd','scripts/core/opening.gd'})
            receipt={'schema':1,'success':True,'engineVersion':ENGINE_VERSION,'freshProcessRuns':2,'silent':True,'audioDriver':'Dummy','personalSavesUsed':False,'sourceUnchanged':True,'checkOnly':args.check,'cases':len(data['cases']),'caseFamilies':sorted({r['kind'] for r in data['cases']}),'exactNumericValues':validate_numeric_witnesses(data),'comparisonPolicy':COMPARISON_POLICY,'sha256':hashlib.sha256(outputs[0]).hexdigest(),'sourceHashes':{name:before[name] for name in sources}}
            (args.evidence_dir/'receipt.json').write_bytes(canonical_bytes(receipt));print('MIGRATION RESIDENT MOTION ORACLE OK: 2 fresh silent processes, '+str(len(data['cases']))+' cases');return 0
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print(str(error),file=sys.stderr);return 1
    finally:
        if user_dir is not None and user_dir.name==token and user_dir.is_dir(): shutil.rmtree(user_dir)
if __name__=='__main__':raise SystemExit(main())
