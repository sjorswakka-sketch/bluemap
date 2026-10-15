#!/usr/bin/env python3
"""Check preview version consistency and, optionally, a real Windows download ZIP."""
import argparse, re, struct, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',type=Path);a=p.parse_args()
project=(ROOT/'project.godot').read_text(encoding='utf8')
version=re.search(r'^config/version="([^"]+)"$',project,re.M).group(1)
windows_version=version.split('-')[0]+'.0'
export=(ROOT/'export_presets.cfg').read_text(encoding='utf8')
for field in ['file_version','product_version']:
 actual=re.search(r'^application/'+field+r'="([^"]+)"$',export,re.M).group(1)
 if actual!=windows_version:raise SystemExit(field+': '+actual+' != '+windows_version)
for path in ['README.md','distribution/LEESMIJ.txt']:
 if version not in (ROOT/path).read_text(encoding='utf8'):raise SystemExit('Missing current version in '+path)
if a.package:
 with zipfile.ZipFile(a.package) as archive:
  files={x.filename for x in archive.infolist() if not x.is_dir()}
  expected={'BluemapQuest/BluemapQuest.exe','BluemapQuest/LEESMIJ.txt'}
  if files!=expected:raise SystemExit('Unexpected packaged files: '+str(files))
  if archive.testzip() is not None:raise SystemExit('ZIP CRC validation failed')
  if archive.read('BluemapQuest/LEESMIJ.txt')!=(ROOT/'distribution/LEESMIJ.txt').read_bytes():raise SystemExit('Packaged instructions differ from source')
  info=archive.getinfo('BluemapQuest/BluemapQuest.exe')
  if info.file_size<10_000_000:raise SystemExit('Windows executable unexpectedly small')
  with archive.open(info) as exe:
   header=exe.read(4096)
  if header[:2]!=b'MZ':raise SystemExit('Not a Windows executable')
  offset=struct.unpack_from('<I',header,0x3c)[0]
  if offset+26>len(header) or header[offset:offset+4]!=b'PE\0\0':raise SystemExit('Missing PE header')
  if struct.unpack_from('<H',header,offset+4)[0]!=0x8664:raise SystemExit('Expected Windows x64 executable')
 print('WINDOWS PACKAGE OK:',a.package.name,info.file_size,'exe bytes')
print('RELEASE CHECK OK:',version)
