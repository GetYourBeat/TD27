#!/usr/bin/env python3
"""Observed TD-27 1.01/1.02 offline codec. Hardware compatibility is untested.
No MIDI writes. Requires an original TD0 template; never invents the kit core.
"""
import argparse, hashlib, io, json, struct, wave
from pathlib import Path
from td27_inspect import inspect

MAIN=0x594
SUB=0x834
COMMON=0x1d4

def aligned(n,unit): return (n+unit-1)//unit*unit

def read_audio(block):
    if len(block)<48 or block[:4]!=b'SMPd':raise ValueError('SMPd header')
    header,pages,size,n=struct.unpack_from('<HHII',block,4)
    flags=struct.unpack_from('<H',block,32)[0];slot=flags&0x7fff;channels=1+(flags>>15)
    stride=aligned(n+128,512)
    if header!=48 or n<2 or n%2 or slot>=500 or size!=stride*channels or len(block)!=48+size or pages!=(stride+131071)//131072:
        raise ValueError('Unsupported sample framing')
    payload=block[48:];planes=[];tails=[]
    for c in range(channels):
        p=payload[c*stride:(c+1)*stride];end=64+aligned(n,64)
        if p[:64]!=bytes(64) or p[end:end+64]!=bytes(64) or p[end+64:]!=b'\xff'*(stride-end-64):
            raise ValueError('Unsupported channel padding')
        planes.append(p[64:64+n]);tails.append(p[64+n:end])
    pcm=bytearray(n*channels)
    for c,p in enumerate(planes):
        for j in range(0,n,2):pcm[(j//2*channels+c)*2:(j//2*channels+c)*2+2]=p[j:j+2]
    return dict(slot=slot,channels=channels,pcm=bytes(pcm),tails=tails,header=block[:48],name=block[16:32].split(b'\0')[0].decode('ascii',errors='replace'))

def encode_audio(pcm,channels,slot,name,tails=None,original_header=None):
    if channels not in (1,2) or not 0<=slot<500 or not pcm or len(pcm)%(2*channels):raise ValueError('Invalid PCM')
    n=len(pcm)//channels
    if n>44100*180*2:raise ValueError('Sample exceeds 180 seconds')
    stride=aligned(n+128,512);rounded=aligned(n,64)
    header=bytearray(original_header or bytes(48));header[:4]=b'SMPd'
    struct.pack_into('<HHII',header,4,48,(stride+131071)//131072,stride*channels,n)
    if original_header is None:header[16:32]=fixed_name(name,16,0)
    struct.pack_into('<H',header,32,slot|(0x8000 if channels==2 else 0))
    payload=bytearray()
    for c in range(channels):
        plane=bytearray(n)
        for j in range(n//2):plane[j*2:j*2+2]=pcm[(j*channels+c)*2:(j*channels+c)*2+2]
        tail=tails[c] if tails is not None else bytes(rounded-n)
        if len(tail)!=rounded-n:raise ValueError('Alignment tail size')
        payload+=bytes(64)+plane+tail+bytes(64)+b'\xff'*(stride-rounded-128)
    return bytes(header+payload)

def fixed_name(text,count,pad=32):
    name=text.encode('ascii',errors='replace')[:count]
    return name+bytes([pad])*(count-len(name))

def read_wav(path):
    with wave.open(str(path),'rb') as w:
        ch=w.getnchannels();bits=w.getsampwidth();rate=w.getframerate();pcm=w.readframes(w.getnframes())
        if rate!=44100 or ch not in (1,2) or bits not in (2,3) or w.getcomptype()!='NONE':raise ValueError('Use PCM WAV, 44.1 kHz, mono/stereo, 16/24 bit')
    if bits==3:pcm=b''.join(pcm[i+1:i+3] for i in range(0,len(pcm),3)) # explicit 24 -> 16 bit truncation
    return pcm,ch

def source_blocks(source):
    report=inspect(source);result={}
    for r in report['blocks']:
        block=source[r['offset']:r['offset']+48+r['payload_bytes']];a=read_audio(block)
        if a['slot'] in result:raise ValueError('Duplicate sample slot')
        result[a['slot']]=block
    return result

def assignments(source):
    return {label:[{'instrument':struct.unpack_from('<H',source,base+i*28)[0],
             'bank':source[base+i*28+4], 'level_db':struct.unpack_from('<h',source,base+i*28+2)[0]/10,
             'pitch_cents':struct.unpack_from('<h',source,base+i*28+12)[0]}
             for i in range(24)] for label,base in [('main',MAIN),('sub',SUB)]}

def export(template,edits,title=None):
    info=inspect(template)
    if info["version"] == "2.21": raise ValueError("2.21 sample container not verified; use a 1.01/1.02 base")
    blocks=source_blocks(template);core=bytearray(template[:4256]);meta=None
    if len(template)>4256:meta=bytearray(template[4256:20304])
    if title is not None:
        name=fixed_name(title,12);core[8:20]=name;core[48:60]=name
    used=set(blocks)
    for bank in assignments(template).values():
        for a in bank:
            if a['bank'] not in (0,1):raise ValueError('Unknown instrument bank in template')
            if a['bank']==1:
                if a['instrument'] not in blocks:raise ValueError('Template references a sample without embedded audio')
                used.add(a['instrument'])
    if meta is not None:
        used.update(i for i in range(500) if meta[48+32*i:64+32*i] not in (b'----------------',bytes(16),b' '*16))
    slots={};audit=[]
    for e in edits:
        zone=int(e['zone']);level=float(e.get('level_db',0));pan=float(e.get('pan',0));tuning=float(e.get('semitones',0))
        if not 0<=zone<24 or not -60<=level<=6 or not -1<=pan<=1 or not -24<=tuning<=24:raise ValueError('Invalid zone/parameter')
        key=str(Path(e['wav']).resolve())
        if key not in slots:
            slot=next((s for s in range(2,500) if s not in used),None)
            if slot is None:raise ValueError('No unused sample slot')
            pcm,ch=read_wav(e['wav']);blocks[slot]=encode_audio(pcm,ch,slot,Path(key).name)
            used.add(slot);slots[key]=slot
            if meta is None:
                meta=bytearray(48+500*32);meta[:18]=b'TD-27\0USUsrSmplPrm';meta[20:36]=core[20:36];meta[41]=1
                for i in range(500):meta[48+32*i:64+32*i]=b'----------------'
            o=48+slot*32;meta[o:o+32]=fixed_name(Path(key).stem,16)+bytes(8)+b'\x01'+bytes(7)
        slot=slots[key];o=MAIN+zone*28
        struct.pack_into('<Hh',core,o,slot,round(level*10));core[o+4]=1
        core[o+5]=0;core[o+10]=0;core[o+11]=100;struct.pack_into('<h',core,o+12,round(tuning*100));core[o+14]=0
        ip=float(e.get('instrument_pitch',0));decay=float(e.get('instrument_decay',100));pd=float(e.get('pad_decay',100))
        if not -100<=ip<=100 or not 1<=decay<=100 or not 1<=pd<=100:raise ValueError('Invalid instrument parameter')
        core[0xADC+zone*24]=round(ip)&255;core[0xADD+zone*24]=round(decay);core[o+11]=round(pd)
        core[COMMON+zone*40]=round(pan*30)&255;core[COMMON+zone*40+5]=0 # disable old sub-layer on replaced zone
        audit.append({'zone':zone,'sample_slot':slot,'wav':Path(key).name})
    if blocks:
        total=sum(len(read_audio(b)['pcm'])/88200 for b in blocks.values())
        if total>1440:raise ValueError('Exceeds 24 mono-equivalent minutes')
        core[40]=1;core[41]=1
    core[4240:4256]=hashlib.md5(core[:4240]).digest()
    result=bytes(core)
    if blocks:
        result+=bytes(meta)+hashlib.md5(meta).digest()+struct.pack('<4sIII16x',b'SMPh',32,2,len(blocks))
        result+=b''.join(blocks[i] for i in sorted(blocks))
    inspect(result);source_blocks(result)
    return result,audit

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('template',type=Path);p.add_argument('mapping',type=Path);p.add_argument('output',type=Path);p.add_argument('--title');a=p.parse_args()
    data,audit=export(a.template.read_bytes(),json.loads(a.mapping.read_text()),a.title)
    with a.output.open('xb') as f:f.write(data)
    print(json.dumps({'output':str(a.output),'bytes':len(data),'assignments':audit,'hardware_tested':False},indent=2))
