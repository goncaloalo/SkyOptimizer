"""Synthetic arithmetic fixtures only. These are not gaming benchmark results."""
import csv
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("sky_benchmark", Path(__file__).parents[1] / "analyze.py")
analyze = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analyze)


class MetricsTests(unittest.TestCase):
    def test_adjacent_slow_frames_are_one_incident_and_excess_is_not_interval_time(self):
        r = analyze.summarize_frames([10, 60, 70, 10, 80])['spikes']['50.0']
        self.assertEqual(r['count'], 3)
        self.assertEqual(r['incidents'], 2)
        self.assertEqual(r['total_interval_ms'], 210)
        self.assertEqual(r['excess_ms'], 60)
    def test_constant_frametimes(self):
        result = analyze.summarize_frames([10.0] * 100)
        self.assertEqual(result["average_fps"], 100.0)
        self.assertEqual(result["one_percent_low_fps"], 100.0)
        self.assertEqual(sum(bin_["count"] for bin_ in result["histogram"]), 100)

    def test_slow_frame_and_nearest_rank(self):
        result = analyze.summarize_frames([10.0] * 100 + [100.0])
        self.assertAlmostEqual(result["average_fps"], 101000 / 1100)
        self.assertEqual(result["one_percent_sample_count"], 2)
        self.assertAlmostEqual(result["one_percent_low_fps"], 1000 / 55)
        self.assertEqual(result["frametime_percentiles_ms"]["99"], 10)
        self.assertEqual(result["frametime_percentiles_ms"]["99.9"], 100)
        self.assertEqual(result["spikes"]["50.0"]["count"], 1)

    def test_invalid_intervals_are_never_silently_dropped(self):
        for frames in ([], [0], [-1], [math.nan], [math.inf]):
            with self.subTest(frames=frames), self.assertRaises(ValueError):
                analyze.summarize_frames(frames)

    def test_single_frame_low_is_defined(self):
        self.assertEqual(analyze.summarize_frames([20])["one_percent_low_fps"], 50)


class ManifestTests(unittest.TestCase):
    def test_work_duration_and_legacy_untyped_manifest_are_rejected(self):
        self.manifest['measurement']['semantics'] = 'gpu_work_duration'
        with self.assertRaises(ValueError): self.run_analysis()
        self.manifest['measurement']['semantics'] = 'between_present_events'
        self.manifest['frametime_column'] = 'GPUBusy'
        with self.assertRaises(ValueError): self.run_analysis()
        self.manifest['frametime_column'] = 'FrameTimeMs'
        self.manifest['schema_version'] = 1
        with self.assertRaises(ValueError): self.run_analysis()
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = {
            "schema_version": 2, "frametime_column": "FrameTimeMs", "interval_kind": "present",
            "frame_generation": False,
            "measurement": {"semantics": "between_present_events", "unit": "ms", "source_reference": "synthetic event intervals"},
            "environment": {key: "synthetic test fixture" for key in (
                "cpu", "gpu", "windows_build", "gpu_driver", "game_version", "scene", "settings",
                "capture_tool", "capture_version", "optimizer_commit")},
            "runs": [{"id": "A1", "condition": "A", "csv": "A.csv"},
                     {"id": "B1", "condition": "B", "csv": "B.csv"}],
        }
        self.capture("A.csv", [[1, "a", 10], [1, "a", 10]])
        self.capture("B.csv", [[1, "a", 20], [1, "a", 20]])

    def capture(self, name, rows):
        with (self.root / name).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["ProcessID", "SwapChainAddress", "FrameTimeMs"])
            writer.writerows(rows)

    def run_analysis(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.manifest), encoding="utf-8")
        return analyze.analyze_manifest(path)

    def test_descriptive_deltas_do_not_mask_regressions_or_small_samples(self):
        result = self.run_analysis()
        self.assertEqual(result["descriptive_median_change_B_vs_A_percent"]["average_fps"], -50)
        self.assertEqual(len(result["runs"][0]["sha256"]), 64)
        self.assertEqual(len(result["quality_issues"]), 4)
        self.assertIn("no automatic significance", result["limits"][0])

    def test_multiple_processes_or_swapchains_require_explicit_selection(self):
        self.capture("A.csv", [[1, "a", 10], [2, "b", 50]])
        with self.assertRaises(ValueError):
            self.run_analysis()
        self.manifest["runs"][0]["filters"] = {"ProcessID": "1", "SwapChainAddress": "a"}
        result = self.run_analysis()
        self.assertEqual(result["runs"][0]["filtered_rows"], 1)
        self.assertEqual(result["runs"][0]["average_fps"], 100)

    def test_missing_filter_column_and_zero_matching_frames_fail(self):
        self.manifest["runs"][0]["filters"] = {"MissingColumn": "1"}
        with self.assertRaises(ValueError):
            self.run_analysis()
        self.manifest["runs"][0]["filters"] = {"ProcessID": "999"}
        with self.assertRaises(ValueError):
            self.run_analysis()

    def test_missing_metadata_and_duplicate_ids_fail(self):
        self.manifest["environment"]["scene"] = ""
        with self.assertRaises(ValueError):
            self.run_analysis()
        self.manifest["environment"]["scene"] = "synthetic"
        self.manifest["runs"][1]["id"] = "A1"
        with self.assertRaises(ValueError):
            self.run_analysis()

    def test_invalid_csv_intervals_fail(self):
        for value in ("", "NaN", "Infinity", "0", "bad"):
            self.capture("A.csv", [[1, "a", value]])
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.run_analysis()

    def test_both_conditions_required(self):
        self.manifest["runs"] = self.manifest["runs"][:1]
        with self.assertRaises(ValueError):
            self.run_analysis()

    def test_duplicate_capture_is_flagged_and_frames_are_not_pooled_across_runs(self):
        self.manifest["runs"].append({"id": "A2", "condition": "A", "csv": "A.csv"})
        result = self.run_analysis()
        self.assertTrue(any("identical CSV" in issue for issue in result["quality_issues"]))
        self.assertEqual(result["conditions"]["A"]["runs"], 2)
        self.assertEqual(result["conditions"]["A"]["average_fps"]["median"], 100)


if __name__ == "__main__":
    unittest.main()
