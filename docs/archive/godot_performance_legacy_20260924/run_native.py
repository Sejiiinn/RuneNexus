#!/usr/bin/env python3
"""Run Android native samples serially; no screen recording during measurements."""
import json, os, select, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/analysis/godot_validation_20260915'
ADB=str(Path.home()/'Library/Android/sdk/platform-tools/adb')
PACKAGE='com.example.rune_nexus.godotpreview'
def adb(*args, **kw):
    return subprocess.run([ADB,*args],check=True,**kw)
def run(scenario,duration,tag):
    adb('shell','am','force-stop',PACKAGE,stdout=subprocess.DEVNULL)
    adb('logcat','-c')
    log=open(OUT/f'{tag}.log','w')
    reader=subprocess.Popen([ADB,'logcat','-v','threadtime'],stdout=subprocess.PIPE,text=True,bufsize=1)
    adb('shell','am','start','-n',PACKAGE+'/com.example.rune_nexus.GodotBenchmarkActivity','--es','scenario',scenario,'--es','mode',os.environ.get('RN_MODE','standalone'),'--es','duration',str(duration),stdout=subprocess.DEVNULL)
    deadline=time.monotonic()+duration+120
    result=None
    runtime_errors=[]
    try:
        while time.monotonic()<deadline:
            ready,_,_=select.select([reader.stdout],[],[],1)
            if not ready: continue
            line=reader.stdout.readline(); log.write(line)
            if 'SCRIPT ERROR' in line or 'FATAL EXCEPTION' in line:
                print(line.strip(),flush=True)
                runtime_errors.append(line.strip())
            if 'RN_NATIVE ' not in line: continue
            record=json.loads(line.split('RN_NATIVE ',1)[1])
            if record.get('event')=='begin':
                adb('shell','dumpsys','SurfaceFlinger','--timestats','-clear','-enable',stdout=subprocess.DEVNULL)
                print(f'{tag}: measuring',flush=True)
            if record.get('event')=='complete':
                if runtime_errors:
                    raise RuntimeError(f'{tag}: runtime errors: {runtime_errors}')
                result=record
                with open(OUT/f'{tag}-surfaceflinger.txt','w') as f:
                    adb('shell','dumpsys','SurfaceFlinger','--timestats','-dump','-disable',stdout=f)
                with open(OUT/f'{tag}-memory.txt','w') as f:
                    adb('shell','dumpsys','meminfo',PACKAGE+':godot_benchmark',stdout=f)
                (OUT/f'{tag}.json').write_text(json.dumps(record,indent=2))
                print(f'{tag}: fps={record["fps"]:.2f} p95={record["frame_ms"]["p95"]:.2f}ms',flush=True)
                break
        if result is None: raise RuntimeError(f'{tag}: no completion; inspect log')
    finally:
        reader.terminate(); reader.wait(); log.close()
        with open(OUT/f'{tag}.log','w') as f:
            adb('logcat','-d','-v','threadtime',stdout=f)
    return result
if __name__=='__main__':
    for scenario in sys.argv[1:] or ['normal','fire','fire_4x','stress_4x','combat_normal','combat_fire']:
        run(scenario,float(os.environ.get('RN_DURATION','20')),os.environ.get('RN_TAG','native')+'-'+scenario)
