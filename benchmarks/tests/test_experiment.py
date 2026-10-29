"""SYNTHETIC fixtures only; these outcomes are not measured SkyOptimizer gains."""
import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).parents[1]))
import experiment as e


def fixture(ratio=1.1, blocks=8):
    manifest = {'synthetic': True, 'experimental_design': {'primary_metric': 'average_fps',
        'minimum_benefit_percent': 2, 'regression_margin_percent': 2, 'seed': 42, 'bootstrap_draws': 1000}, 'runs': []}
    analysis = {'quality_issues': [], 'runs': []}
    for i in range(blocks):
        for c in ('A', 'B'):
            ident=f'{c}{i}'
            factor=1 if c=='A' else ratio
            manifest['runs'].append({'id':ident,'condition':c,'pair':str(i),'block':str(i),
                                     'order':2*i+(1 if c==('A' if i%2==0 else 'B') else 2)})
            analysis['runs'].append({'id':ident,'average_fps':100*factor,'one_percent_low_fps':80*factor,
                                    'frametime_percentiles_ms':{'99':15/factor},'duration_seconds':150})
    return analysis, manifest


class ExperimentTests(unittest.TestCase):
    def test_known_effect_null_and_regression(self):
        for ratio, status in ((1.1,'BenefitDetected'),(1,'NoMeaningfulBenefit'),(.9,'Regression')):
            a,m=fixture(ratio)
            r=e.evaluate(a,m)
            self.assertEqual(r['status'],status)
            self.assertAlmostEqual(r['metrics']['average_fps']['oriented_ratio_change_percent'],(ratio-1)*100)
            self.assertEqual(r['metrics']['average_fps']['A_run_median'],100)
            self.assertAlmostEqual(r['metrics']['average_fps']['B_run_median'],100*ratio)
            self.assertAlmostEqual(r['metrics']['p99_ms']['B_run_median'],15/ratio)
            self.assertIn('SINTÉTICOS',e.report(r))

    def test_guardrail_prevents_primary_promotion(self):
        a,m=fixture()
        for row in a['runs']:
            if row['id'].startswith('B'): row['one_percent_low_fps']=60
        self.assertEqual(e.evaluate(a,m)['status'],'Regression')

    def test_seed_reproducibility_and_variability(self):
        a,m=fixture()
        for i,row in enumerate(a['runs']):
            if row['id'].startswith('B'): row['average_fps']*=.8 if i%4==1 else 1.2
        r=e.evaluate(a,m)
        self.assertEqual(r,e.evaluate(a,m))
        self.assertGreater(r['metrics']['average_fps']['block_log_stddev'],0)
        self.assertEqual(r['status'],'Inconclusive')

    def test_pilot_and_quality_flags_never_promote(self):
        for blocks in (2,8):
            a,m=fixture(blocks=blocks)
            if blocks==8:a['quality_issues']=['duplicate source']
            self.assertEqual(e.evaluate(a,m)['status'],'Inconclusive')

    def test_incomplete_cross_block_duplicate_order_refused(self):
        for case in ('missing','block','order','duplicate'):
            a,m=fixture()
            if case=='missing':m['runs'].pop()
            if case=='block':m['runs'][0]['block']='different'
            if case=='order':m['runs'][0]['order']=m['runs'][1]['order']
            if case=='duplicate':m['runs'].append(copy.deepcopy(m['runs'][0]))
            with self.subTest(case=case), self.assertRaises(ValueError):e.evaluate(a,m)

    def test_invalid_preregistration_refused(self):
        for value in (0,-1,True,float('nan'),101):
            a,m=fixture();m['experimental_design']['minimum_benefit_percent']=value
            with self.assertRaises(ValueError):e.evaluate(a,m)


if __name__=='__main__':unittest.main()
