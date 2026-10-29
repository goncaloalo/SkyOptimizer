"""No external executable runs: inert bytes and mocked subprocess only."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[1]))
import capture as c


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.tool=self.root/'inert.exe';self.tool.write_bytes(b'NOT AN EXECUTABLE')
        self.sha=hashlib.sha256(self.tool.read_bytes()).hexdigest();self.out=self.root/'capture'

    def plan(self):return c.plan(self.tool,self.sha,123,150,self.out)

    def test_plan_is_read_only_and_scoped(self):
        p=self.plan()
        self.assertFalse(self.out.exists())
        self.assertIn('--process_id',p['command'])
        self.assertNotIn('--stop_existing_session',p['command'])
        self.assertNotIn('--restart_as_admin',p['command'])

    def test_bad_hash_invalid_duration_existing_output(self):
        with self.assertRaises(ValueError):c.plan(self.tool,'0'*64,123,150,self.out)
        with self.assertRaises(ValueError):c.plan(self.tool,self.sha,123,0,self.out)
        self.out.mkdir()
        with self.assertRaises(ValueError):self.plan()

    def test_exit_zero_without_data_is_failure(self):
        with patch.object(c.os,'name','nt'):
            r=c.execute(self.plan(),self.out,lambda *a,**k:subprocess.CompletedProcess(a,0))
        self.assertEqual(r['status'],'Failed')
        self.assertTrue((self.out/'capture.json').exists())

    def test_nonzero_partial_and_timeout_never_success(self):
        for i,timeout in enumerate((False,True)):
            out=self.root/f'out{i}';p=c.plan(self.tool,self.sha,123,150,out)
            def runner(*args,**kwargs):
                (out/'frames.csv').write_text('partial')
                if timeout:raise subprocess.TimeoutExpired(args,180)
                return subprocess.CompletedProcess(args,5)
            with patch.object(c.os,'name','nt'):r=c.execute(p,out,runner)
            self.assertEqual(r['status'],'Failed')
            self.assertTrue((out/'frames.csv').exists())

    def test_success_still_requires_validation(self):
        def runner(*args,**kwargs):
            self.assertFalse(kwargs['shell'])
            (self.out/'frames.csv').write_text('SYNTHETIC ONLY')
            return subprocess.CompletedProcess(args,0)
        with patch.object(c.os,'name','nt'):r=c.execute(self.plan(),self.out,runner)
        self.assertEqual(r['status'],'CapturedUnvalidated')
        self.assertIn('csv_sha256',r)

    def test_changed_tool_refused_before_launch(self):
        p=self.plan();self.tool.write_bytes(b'changed')
        with patch.object(c.os,'name','nt'),self.assertRaises(ValueError):c.execute(p,self.out)
        self.assertFalse(self.out.exists())


if __name__=='__main__':unittest.main()
