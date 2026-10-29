"""End-to-end offline pipeline using visibly synthetic CSV only."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).parents[1]))
import normalize as n
import diagnose as d


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)

    def test_normalization_is_exact_and_boundary_is_explicit(self):
        p=self.root/'raw.csv';p.write_text('ProcessID,SwapChainAddress,MsBetweenPresents\n12,0x1,0\n12,0x2,99\n12,0x1,10\n')
        frames,e=n.normalize(p,12,'0x1')
        self.assertEqual(frames,[10]);self.assertEqual(e['excluded_initial_zero_boundary'],1)
        self.assertEqual(e['filtered_other_stream_rows'],1)
        p.write_text(p.read_text()+'12,0x1,0\n')
        with self.assertRaises(ValueError):n.normalize(p,12,'0x1')

    def test_cli_creates_labelled_report_without_replacing_outputs(self):
        manifest=json.loads((Path(__file__).parents[1]/'manifest.example.json').read_text())
        manifest['environment']={k:'SYNTHETIC FIXTURE' for k in manifest['environment']}
        manifest.update(synthetic=True,experimental_design={'primary_metric':'average_fps',
            'minimum_benefit_percent':2,'regression_margin_percent':2,'seed':19,'bootstrap_draws':1000})
        manifest['measurement']['source_reference']='SYNTHETIC FrameTimeMs fixture'
        manifest['runs']=[]
        for i in range(8):
            for c in ('A','B'):
                ident=f'{c}{i}';p=self.root/f'{ident}.csv'
                # Unique capture bytes and >120 seconds; no real measurement.
                interval=10+i*.01 if c=='A' else 9+i*.01
                p.write_text('FrameTimeMs\n'+(str(interval)+'\n')*14000)
                manifest['runs'].append({'id':ident,'condition':c,'csv':p.name,'pair':str(i),'block':str(i),
                    'order':i*2+(1 if c==('A' if i%2==0 else 'B') else 2)})
        path=self.root/'manifest.json';path.write_text(json.dumps(manifest))
        command=[sys.executable,'-B',str(Path(__file__).parents[1]/'experiment.py'),str(path),'--output',str(self.root/'report')]
        result=subprocess.run(command,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        report=(self.root/'report/report.md').read_text(encoding='utf-8')
        self.assertIn('SINTÉTICOS',report)
        self.assertIn('BenefitDetected',report)
        self.assertNotEqual(subprocess.run(command,capture_output=True).returncode,0)
        self.assertEqual((self.root/'report/report.md').read_text(encoding='utf-8'),report)

    def test_diagnosis_recommends_measurements_not_mutations(self):
        session=json.loads((Path(__file__).parents[1]/'session.example.json').read_text())
        for sample in session['samples']:
            sample['memory']={'commit_bytes':95,'commit_limit_bytes':100}
        recommendations=d.diagnose(session)['recommendations']
        self.assertEqual(len(recommendations),2)
        self.assertTrue(all('next_measurement' in r for r in recommendations))
        self.assertIn('does not prove paging',recommendations[1]['next_measurement'])


if __name__=='__main__':unittest.main()
