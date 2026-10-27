#!/usr/bin/env python3
"""Report byte differences; never infer parameter meaning from offsets alone."""
import json,sys
from pathlib import Path
from td27_inspect import inspect
before,after=[Path(p).read_bytes() for p in sys.argv[1:3]]
inspect(before);inspect(after)
ranges=[];start=None
for i in range(max(len(before),len(after))):
    different=i>=min(len(before),len(after)) or before[i]!=after[i]
    if different and start is None:start=i
    if start is not None and (not different or i==max(len(before),len(after))-1):
        end=i if not different else i+1
        ranges.append({'start':start,'end_exclusive':end,'before_hex':before[start:end].hex(),'after_hex':after[start:end].hex()});start=None
print(json.dumps({'before_bytes':len(before),'after_bytes':len(after),'changed_ranges':ranges},indent=2))
