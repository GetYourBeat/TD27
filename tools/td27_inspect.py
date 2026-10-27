#!/usr/bin/env python3
"""Independent reference parser for observed TD-27 1.02 containers; no writer."""
import argparse, hashlib, json, struct
from pathlib import Path

def inspect(data):
    def require(ok, reason):
        if not ok: raise ValueError(reason)
    def u32(o): return struct.unpack_from('<I', data, o)[0]
    def name(o,n): return data[o:o+n].split(b'\0')[0].decode('ascii', errors='replace').rstrip()
    require(4256 <= len(data) <= 256*1024*1024, 'size')
    require(data[:8] == b'TD-27\0KT', 'signature')
    require(data[20:24] in (b'1.01',b'1.02'), 'version')
    require(hashlib.md5(data[:4240]).digest() == data[4240:4256], 'core MD5')
    result = dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), name=name(48,12),
                  header_name=name(8,12), version=name(20,4), core_md5=True, blocks=[])
    if len(data) == 4256: return result
    require(len(data)>=20352, 'sample metadata truncated')
    require(data[4256:4274] == b'TD-27\0USUsrSmplPrm', 'sample signature')
    require(data[4276:4280] == data[20:24], 'sample version')
    require(hashlib.md5(data[4256:20304]).digest() == data[20304:20320], 'sample MD5')
    result['sample_metadata_md5'] = True
    result['named_slots'] = [dict(slot=i, name=name(4304+i*32,16)) for i in range(500)
                             if name(4304+i*32,16) not in ('','----------------')]
    require(data[20320:20324] == b'SMPh' and u32(20324)==32 and u32(20328)==2, 'SMPh layout')
    count = u32(20332); require(count<=500, 'block count'); cursor=20352
    for i in range(count):
        require(cursor+48<=len(data) and data[cursor:cursor+4]==b'SMPd', 'SMPd header')
        size=u32(cursor+8); require(size<=len(data)-cursor-48, 'sample payload truncated')
        result['blocks'].append(dict(offset=cursor, payload_bytes=size, opaque_word=u32(cursor+4),
                                     frame_count_candidate=u32(cursor+12), name=name(cursor+16,16),
                                     reference_candidate=struct.unpack_from('<H',data,cursor+32)[0]))
        cursor += 48+size
    require(cursor==len(data), 'trailing data')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('files',nargs='+',type=Path); args=parser.parse_args()
    print(json.dumps({p.name:inspect(p.read_bytes()) for p in args.files},indent=2))
