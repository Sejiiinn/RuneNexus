from pathlib import Path
import struct,zlib
lines=[]
for p in sorted(Path('assets/images/ui/combat_components/native').glob('*.png')):
 b=p.read_bytes();pos=8;compressed=b''
 while pos<len(b):
  n=struct.unpack('>I',b[pos:pos+4])[0];tag=b[pos+4:pos+8];data=b[pos+8:pos+8+n];pos+=12+n
  if tag==b'IHDR':w,h,depth,color,*_=struct.unpack('>IIBBBBB',data)
  if tag==b'IDAT':compressed+=data
 assert (depth,color)==(8,6),(p,depth,color)
 raw=zlib.decompress(compressed);stride=w*4;prev=bytearray(stride);alpha=[]
 for y in range(h):
  f=raw[y*(stride+1)];row=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
  for x in range(stride):
   a=row[x-4] if x>=4 else 0;b=prev[x];c=prev[x-4] if x>=4 else 0
   if f==1:v=a
   elif f==2:v=b
   elif f==3:v=(a+b)//2
   elif f==4:
    q=a+b-c;pa,pb,pc=abs(q-a),abs(q-b),abs(q-c);v=a if pa<=pb and pa<=pc else (b if pb<=pc else c)
   else:v=0
   row[x]=(row[x]+v)%256
  alpha.extend(row[3::4]);prev=row
 assert min(alpha)==0 and max(alpha)>=254
 lines.append(f'{p.name}: {w}x{h}, RGBA8; alpha range {min(alpha)}..{max(alpha)}; transparent pixels {alpha.count(0)}/{w*h}; PASS')
text='\n'.join(lines)+'\nVisual: native-preview.png inspected; all 6 intact silhouettes/corner hardware/colors remain. V3 faint outer colored edge speckles remain from source; no redraw or alpha reconstruction performed.\n'
Path('design/combat_ui_concepts/2026-09-22/modal-components/native/verification.txt').write_text(text)
print(text)
