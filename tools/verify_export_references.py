#!/usr/bin/env python3
"""Read-only external-fixture verification. Supply original TD0 paths."""
import hashlib,json,sys
from pathlib import Path
from td27_codec import source_blocks,read_audio,encode_audio,export,assignments
reports=[]
for arg in sys.argv[1:]:
    path=Path(arg);data=path.read_bytes();blocks=source_blocks(data);rows=[]
    for slot,b in blocks.items():
        a=read_audio(b)
        rebuilt=encode_audio(a['pcm'],a['channels'],slot,a['name'],a['tails'],a['header'])
        assert rebuilt==b
        rows.append(dict(slot=slot,channels=a['channels'],pcm_bytes=len(a['pcm']),frames=len(a['pcm'])//(2*a['channels']),
                         pcm_sha256=hashlib.sha256(a['pcm']).hexdigest(),block_roundtrip_exact=True))
    assert export(data,[])[0]==data
    refs=[x['instrument'] for layer in assignments(data).values() for x in layer if x['bank']==1]
    assert set(refs)==set(blocks)
    reports.append(dict(filename=path.name,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),blocks=rows,
                        all_references_resolve=True,whole_file_roundtrip_exact=True))
print(json.dumps(reports,indent=2))
