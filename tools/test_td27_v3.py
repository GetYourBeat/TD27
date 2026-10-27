import hashlib,struct,tempfile,unittest,wave
from pathlib import Path
from td27_codec import export
from td27_inspect import inspect

class V3Tests(unittest.TestCase):
    def core(self):
        d=bytearray(4256);d[:8]=b'TD-27\0KT';d[20:24]=b'1.02'
        d[0xADC:0xADE]=bytes([34,2]);d[0xADC+24:0xADE+24]=bytes([24,1])
        d[4240:]=hashlib.md5(d[:4240]).digest();return d
    def test_inherited_vedit_reset_and_other_zone_preserved(self):
        d=self.core()
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'x.wav'
            with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(bytes(200))
            out,_=export(bytes(d),[dict(zone=0,wav=str(p))])
            self.assertEqual(out[0xADC:0xADE],bytes([0,100]))
            self.assertEqual(out[0xADC+24:0xADE+24],bytes([24,1]))
            out,_=export(bytes(d),[dict(zone=0,wav=str(p),instrument_pitch=-25,instrument_decay=50,pad_decay=75)])
            self.assertEqual(out[0xADC:0xADE],bytes([231,50]));self.assertEqual(out[0x594+11],75)
    def test_modern_core_inspect_checksum_and_export_boundary(self):
        d=bytearray(4288);d[:8]=b'TD-27\0KT';d[20:24]=b'2.21';d[80:92]=b'Modern      '
        d[4272:]=hashlib.md5(d[:4272]).digest()
        self.assertEqual(inspect(d)['name'],'Modern')
        with self.assertRaisesRegex(ValueError,'not verified'):export(bytes(d),[])
        d[80]^=1
        with self.assertRaisesRegex(ValueError,'MD5'):inspect(d)
