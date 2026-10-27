import hashlib, os, struct, unittest
from pathlib import Path
from td27_inspect import inspect

class FormatTests(unittest.TestCase):
    def core(self):
        d=bytearray(4256);d[:8]=b'TD-27\0KT';d[20:24]=b'1.02';d[48:60]=b'Test        '
        d[4240:]=hashlib.md5(d[:4240]).digest();return d
    def sample(self):
        d=self.core()+bytearray(20352-4256)
        d[4256:4274]=b'TD-27\0USUsrSmplPrm';d[4276:4280]=b'1.02'
        d[20304:20320]=hashlib.md5(d[4256:20304]).digest()
        d[20320:20324]=b'SMPh';struct.pack_into('<III',d,20324,32,2,1)
        h=bytearray(48);h[:4]=b'SMPd';struct.pack_into('<I',h,8,4)
        return d+h+b'\0'*4
    def test_core(self): self.assertEqual(inspect(self.core())['name'],'Test')
    def test_core_corruption(self):
        d=self.core();d[100]^=1
        with self.assertRaisesRegex(ValueError,'core MD5'):inspect(d)
    def test_wrong_module(self):
        d=self.core();d[3:5]=b'17'
        with self.assertRaisesRegex(ValueError,'signature'):inspect(d)
    def test_unknown_version(self):
        d=self.core();d[20:24]=b'2.00'
        with self.assertRaisesRegex(ValueError,'version'):inspect(d)
    def test_core_truncation(self):
        for size in [0,8,36,4240,4255]:
            with self.assertRaises(ValueError):inspect(self.core()[:size])
    def test_sample_walk(self): self.assertEqual(len(inspect(self.sample())['blocks']),1)
    def test_sample_metadata_corruption(self):
        d=self.sample();d[4304]^=1
        with self.assertRaisesRegex(ValueError,'sample MD5'):inspect(d)
    def test_payload_truncation(self):
        with self.assertRaisesRegex(ValueError,'payload'):inspect(self.sample()[:-1])
    def test_trailing(self):
        with self.assertRaisesRegex(ValueError,'trailing'):inspect(self.sample()+b'x')
    def test_oversized_length(self):
        d=self.sample();struct.pack_into('<I',d,20360,0xffffffff)
        with self.assertRaisesRegex(ValueError,'payload'):inspect(d)
    def test_wrong_count(self):
        d=self.sample();struct.pack_into('<I',d,20332,501)
        with self.assertRaisesRegex(ValueError,'count'):inspect(d)
    def test_originals(self):
        folder=os.environ.get('TD27_FIXTURES')
        if not folder:self.skipTest('Set TD27_FIXTURES for supplied original files')
        fixtures=[('KIT-008(1).TD0',4256,'FATTITUDE',0),('KIT-130(1).TD0',2913536,'MOONWALK2',8)]
        for name,size,kit,blocks in fixtures:
            d=(Path(folder)/name).read_bytes();r=inspect(d)
            self.assertEqual((r['bytes'],r['name'],len(r['blocks'])),(size,kit,blocks))
            for end in [4257,20303,20319,20351,len(d)-1]:
                if end>4256 and end<len(d):
                    with self.assertRaises(ValueError):inspect(d[:end])

if __name__=='__main__':unittest.main(verbosity=2)
