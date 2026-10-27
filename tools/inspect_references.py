#!/usr/bin/env python3
"""Read-only fingerprinting of supplied files, firmware tar inventory and TDZ header."""
import hashlib,json,re,sys,tarfile
from pathlib import Path
out={}
for p in sorted(Path(sys.argv[1]).iterdir()):
    b=p.read_bytes()
    r={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'first_96_hex':b[:96].hex()}
    if p.suffix.lower()=='.tdz':
        r['strings']=[{'offset':m.start(),'text':m.group().decode()} for m in re.finditer(rb'[ -~]{8,}',b[:256])]
    if p.name=='TD27_UPA.BIN' and tarfile.is_tarfile(p):
        with tarfile.open(p) as t:
            r['tar_members']=[{'name':m.name,'bytes':m.size,'sha256':hashlib.sha256(t.extractfile(m).read()).hexdigest()} for m in t if m.isfile()]
    out[p.name]=r
print(json.dumps(out,indent=2))
