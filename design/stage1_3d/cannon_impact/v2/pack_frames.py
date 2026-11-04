from pathlib import Path
import zipfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
for kind in ['body','ground']:
 image=ET.Element('image',{'w':'1536','h':'1024','name':'Cannon V2 '+kind});stack=ET.SubElement(image,'stack')
 with zipfile.ZipFile(root/(kind+'.ora'),'w') as z:
  z.writestr('mimetype','image/openraster',compress_type=zipfile.ZIP_STORED)
  for f in range(24):
   src='data/%02d.png'%f;z.write(root/'frames'/kind/('%02d.png'%f),src)
   ET.SubElement(stack,'layer',{'name':'frame_%02d'%f,'src':src,'x':str(f%6*256),'y':str(f//6*256),'opacity':'1.0','visibility':'visible','composite-op':'svg:src-over'})
  z.writestr('stack.xml',ET.tostring(image))
