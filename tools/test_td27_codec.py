import hashlib,os,struct,tempfile,unittest,wave
from pathlib import Path
from td27_codec import *
import test_td27

class CodecTests(unittest.TestCase):
    def test_pcm_mono_stereo_roundtrip(self):
        for channels in (1,2):
            for frames in (1,31,32,33,191,192,193,255,256,257,65535,65536):
                pcm=b''.join(struct.pack('<h',((i*731)%65536)-32768) for i in range(frames*channels))
                block=encode_audio(pcm,channels,499,'Test.wav');a=read_audio(block)
                self.assertEqual(a['pcm'],pcm);self.assertEqual(a['channels'],channels);self.assertEqual(a['slot'],499)
    def test_bad_channel_padding(self):
        b=bytearray(encode_audio(bytes(400),1,2,'a'));b[48]=1
        with self.assertRaisesRegex(ValueError,'padding'):read_audio(b)
    def test_truncated_audio(self):
        b=encode_audio(bytes(400),1,2,'a')
        with self.assertRaises(ValueError):read_audio(b[:-1])
    def test_unknown_slot(self):
        with self.assertRaises(ValueError):encode_audio(bytes(4),1,500,'a')
    def test_length_limit(self):
        with self.assertRaises(ValueError):encode_audio(bytes(44100*181*2),1,2,'a')
    def write_wav(self,p,channels=1,bits=2):
        raw=b''.join(struct.pack('<h',((i*321)%65536)-32768) for i in range(100*channels))
        if bits==3:raw=b''.join(b'\0'+raw[i:i+2] for i in range(0,len(raw),2))
        with wave.open(str(p),'wb') as w:w.setnchannels(channels);w.setsampwidth(bits);w.setframerate(44100);w.writeframes(raw)
        return raw
    def test_export_assignments_parameters_and_preservation(self):
        template=bytes(test_td27.FormatTests().core())
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'kick.wav';pcm=self.write_wav(p)
            data,audit=export(template,[dict(zone=0,wav=str(p),level_db=-3.5,pan=-0.5,semitones=2),dict(zone=23,wav=str(p))],'MY KIT')
            info=assignments(data);slot=audit[0]['sample_slot']
            self.assertEqual(slot,audit[1]['sample_slot']);self.assertEqual(len(source_blocks(data)),1)
            self.assertEqual(read_audio(source_blocks(data)[slot])['pcm'],pcm)
            self.assertEqual(info['main'][0],dict(instrument=slot,bank=1,level_db=-3.5,pitch_cents=200))
            self.assertEqual(data[COMMON],241);self.assertEqual(data[COMMON+5],0)
            self.assertEqual(data[MAIN+28:MAIN+23*28],template[MAIN+28:MAIN+23*28])
            self.assertEqual(data[SUB:4240],template[SUB:4240])
            self.assertEqual(inspect(data)['name'],'MY KIT')
            self.assertEqual(hashlib.md5(data[:4240]).digest(),data[4240:4256])
    def test_24bit_reduction(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'stereo.wav';raw=self.write_wav(p,2,3);pcm,ch=read_wav(p)
            self.assertEqual(ch,2);self.assertEqual(pcm,b''.join(raw[i+1:i+3] for i in range(0,len(raw),3)))
    def test_invalid_parameter(self):
        with self.assertRaises(ValueError):export(bytes(test_td27.FormatTests().core()),[dict(zone=24,wav='unused')])
    def test_unknown_bank_rejected(self):
        data=test_td27.FormatTests().core();data[MAIN+4]=2;data[4240:4256]=hashlib.md5(data[:4240]).digest()
        with self.assertRaisesRegex(ValueError,'bank'):export(bytes(data),[])
    def test_cli_never_overwrites_existing_file(self):
        import subprocess,sys
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);template=root/'source.TD0';template.write_bytes(test_td27.FormatTests().core())
            mapping=root/'mapping.json';mapping.write_text('[]');output=root/'existing.TD0';output.write_bytes(b'ORIGINAL')
            completed=subprocess.run([sys.executable,str(Path(__file__).with_name('td27_codec.py')),str(template),str(mapping),str(output)],capture_output=True)
            self.assertNotEqual(completed.returncode,0);self.assertEqual(output.read_bytes(),b'ORIGINAL')
    def test_reference_blocks_exact_roundtrip(self):
        folder=os.environ.get('TD27_FIXTURES')
        if not folder:self.skipTest('TD27_FIXTURES not set')
        paths=[Path(folder)/'KIT-130(1).TD0']
        extra=os.environ.get('TD27_EXTRA_FIXTURES')
        if extra:paths+=list(Path(extra).rglob('*.TD0'))
        count=0
        for p in paths:
            source=p.read_bytes();blocks=source_blocks(source)
            for slot,b in blocks.items():
                a=read_audio(b);self.assertEqual(encode_audio(a['pcm'],a['channels'],slot,a['name'],a['tails'],a['header']),b);count+=1
            self.assertEqual(export(source,[])[0],source)
        self.assertGreaterEqual(count,8)
    def test_preserve_original_blocks_when_adding_wav(self):
        folder=os.environ.get('TD27_FIXTURES')
        if not folder:self.skipTest('TD27_FIXTURES not set')
        source=(Path(folder)/'KIT-130(1).TD0').read_bytes();original=source_blocks(source)
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'new.wav';self.write_wav(p)
            data,audit=export(source,[dict(zone=0,wav=str(p))]);new=source_blocks(data)
            self.assertEqual(len(new),len(original)+1)
            for slot,b in original.items():self.assertEqual(new[slot],b)
            self.assertNotIn(audit[0]['sample_slot'],original)
if __name__=='__main__':unittest.main(verbosity=2)
