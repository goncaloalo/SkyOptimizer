import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('diagnose', Path(__file__).parents[1] / 'diagnose.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class DiagnosisTests(unittest.TestCase):
    def setUp(self):
        self.session = {'schema_version': 1, 'clock': 'relative_monotonic_seconds',
                        'logical_processors': 8, 'game_process_id': 'P001', 'samples': []}
        for second in (0, 2):
            self.session['samples'].append({'seconds': second, 'processes': [
                {'id': 'P001', 'lifetime': 'L001', 'cpu_seconds': second},
                {'id': 'P002', 'lifetime': 'L002', 'cpu_seconds': second / 2,
                 'read_bytes': second * 2000000, 'private_bytes': 100}],
                'memory': {'available_bytes': 10, 'commit_bytes': 80, 'commit_limit_bytes': 100}})

    def test_rates_normalization_and_unknown_are_distinct(self):
        r = d.diagnose(self.session)
        self.assertEqual(r['concurrent_activity_candidates'], ['P002'])
        game, other = r['windows'][0]['activity']
        self.assertEqual(game['cpu_core_equivalents'], 1)
        self.assertEqual(game['cpu_machine_percent'], 12.5)
        self.assertEqual(other['read_bytes_per_second'], 2000000)
        self.assertIsNone(other['write_bytes_per_second'])
        self.assertEqual(r['windows'][0]['commit_fraction'], .8)
        self.assertIsNone(r['windows'][0]['game_volume']['latency_ms'])

    def test_reused_process_identity_does_not_create_false_delta(self):
        self.session['samples'][1]['processes'][1]['lifetime'] = 'L003'
        r = d.diagnose(self.session)
        self.assertEqual(r['concurrent_activity_candidates'], [])
        self.assertIsNone(r['windows'][0]['activity'][1]['cpu_core_equivalents'])

    def test_invalid_time_counter_capacity_and_memory_fail(self):
        for change in ('time', 'counter', 'capacity', 'memory', 'nan'):
            s = copy.deepcopy(self.session)
            if change == 'time': s['samples'][1]['seconds'] = 0
            if change == 'counter': s['samples'][0]['processes'][1]['cpu_seconds'] = 10
            if change == 'capacity': s['samples'][1]['processes'][1]['cpu_seconds'] = 100
            if change == 'memory': s['samples'][1]['memory']['commit_bytes'] = 101
            if change == 'nan': s['samples'][1]['processes'][1]['read_bytes'] = float('nan')
            with self.subTest(change=change), self.assertRaises(ValueError): d.diagnose(s)

    def test_private_fields_are_not_copied_and_no_change_is_valid(self):
        for sample in self.session['samples']:
            sample['processes'][1]['cpu_seconds'] = 0
            sample['processes'][1]['read_bytes'] = 0
            sample['processes'][1]['command_line'] = 'private-secret'
        r = d.diagnose(self.session)
        self.assertNotIn('private-secret', str(r))
        self.assertIn('No change', r['decision'])

    def test_duplicate_and_absent_game_are_rejected(self):
        self.session['game_process_id'] = 'P003'
        with self.assertRaises(ValueError): d.diagnose(self.session)
        self.session['game_process_id'] = 'P001'
        self.session['samples'][0]['processes'].append(self.session['samples'][0]['processes'][0])
        with self.assertRaises(ValueError): d.diagnose(self.session)
