"""Compare local pre/post APK package cost; public release is outside this task."""
from pathlib import Path
import json, zipfile, hashlib
root=Path(__file__).resolve().parents[4]
here=Path(__file__).resolve().parent
apk=root/'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
before=json.loads((here/'apk-before.json').read_text())
with zipfile.ZipFile(apk) as z:
    pck=z.getinfo('assets/rune_nexus.pck')
    report={'apk':str(apk.relative_to(root)), 'bytes':apk.stat().st_size,
            'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
            'pck_bytes':pck.file_size,'pck_compressed':pck.compress_size,
            'abis':sorted({i.filename.split('/')[1] for i in z.infolist() if i.filename.startswith('lib/')}),
            'unwanted_originals':[n for n in z.namelist() if n.endswith(('.glb','.blend')) or n.startswith('assets/flutter_assets/design/')],
            'baseline':'Previous local arm64 preview APK, not a public release'}
for key in ('bytes','pck_bytes','pck_compressed'):
    report[key+'_delta']=report[key]-before[key]
(here/'apk-after.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
