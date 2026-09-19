#!/usr/bin/env python3
"""Capture all baseline phases and native handoff without screenshots or builds."""
import json,os,select,subprocess,time
from run_native import ADB,OUT,PACKAGE,adb
adb('shell','am','force-stop',PACKAGE)
adb('logcat','-c')
reader=subprocess.Popen([ADB,'logcat','-v','threadtime'],stdout=subprocess.PIPE,text=True,bufsize=1)
launch=['shell','am','start','-n',PACKAGE+'/com.example.rune_nexus.GodotPreviewActivity']
if os.environ.get('RN_IMPELLER') in ['true', 'false']:
    launch += ['--ez', 'enable-impeller', os.environ['RN_IMPELLER']]
adb(*launch)
buffer=''; deadline=time.monotonic()+480
prefix=os.environ.get('RN_BASELINE_TAG','baseline')
stop_after=os.environ.get('RN_BASELINE_STOP_AFTER','')
try:
    with open(OUT/f'{prefix}-final.log','w') as log:
        while time.monotonic()<deadline:
            ready,_,_=select.select([reader.stdout],[],[],1)
            if not ready:continue
            line=reader.stdout.readline();log.write(line)
            record=None
            if 'RN_VALIDATION_CHUNK ' in line:
                kind,data=line.split('RN_VALIDATION_CHUNK ',1)[1].rstrip('\n').split(' ',1)
                buffer=data if kind=='START' else buffer+data
            elif 'RN_VALIDATION_END' in line and buffer:
                record=json.loads(buffer);buffer=''
            elif 'RN_NATIVE ' in line:
                record=json.loads(line.split('RN_NATIVE ',1)[1])
            if record is None:continue
            event=record.get('event'); scenario=record.get('scenario','handoff')
            if event=='begin':
                print('begin '+scenario,flush=True)
                adb('shell','dumpsys','SurfaceFlinger','--timestats','-clear','-enable',stdout=subprocess.DEVNULL)
            if event=='end' or (event=='complete' and record.get('mode')=='flutter_handoff'):
                tag=prefix+'-'+scenario if event=='end' else 'handoff-'+scenario
                with open(OUT/f'{tag}-surfaceflinger.txt','w') as f:
                    adb('shell','dumpsys','SurfaceFlinger','--timestats','-dump','-disable',stdout=f)
                print('end '+tag,flush=True)
                if event=='end' and scenario==stop_after:
                    adb('shell','am','force-stop',PACKAGE)
                    break
            if event=='error':raise RuntimeError(record)
            if event=='complete' and record.get('mode')=='flutter_handoff':
                (OUT/'handoff.json').write_text(json.dumps(record,indent=2))
                with open(OUT/'handoff-memory.txt','w') as f:
                    adb('shell','dumpsys','meminfo',PACKAGE,stdout=f)
                    adb('shell','dumpsys','meminfo',PACKAGE+':godot_benchmark',stdout=f)
                break
        else:raise RuntimeError('Baseline/handoff completion timeout')
finally:
    reader.terminate();reader.wait()
