"""Offline frametime analysis. Never launches games, captures, or Windows tweaks."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics


def summarize_frames(frames: list[float]) -> dict:
    if not frames or any(not math.isfinite(x) or x <= 0 for x in frames):
        raise ValueError("Every frame interval must be finite and greater than zero.")
    ordered = sorted(frames)
    count = len(frames)
    total = math.fsum(frames)
    slow_count = max(1, math.ceil(count * 0.01))
    percentiles = {
        str(p): ordered[max(0, math.ceil(count * p / 100) - 1)]
        for p in (50, 95, 99, 99.9)
    }
    edges = (4.167, 8.333, 16.667, 33.333, 50.0, 100.0)
    histogram = []
    lower = 0.0
    for upper in (*edges, math.inf):
        histogram.append({"lower_exclusive_ms": lower,
                          "upper_inclusive_ms": upper if math.isfinite(upper) else None,
                          "count": sum(lower < x <= upper for x in frames)})
        lower = upper
    return {
        "frames": count, "duration_seconds": total / 1000,
        "average_fps": 1000 * count / total,
        "one_percent_low_fps": 1000 / statistics.mean(ordered[-slow_count:]),
        "one_percent_sample_count": slow_count,
        "frametime_percentiles_ms": percentiles, "max_frametime_ms": ordered[-1],
        "spikes": {str(t): {"count": sum(x > t for x in frames),
                            "incidents": sum(x > t and (i == 0 or frames[i-1] <= t) for i, x in enumerate(frames)),
                            "excess_ms": math.fsum(max(0, x-t) for x in frames),
                            "incidents_per_minute": 60000 * sum(x > t and (i == 0 or frames[i-1] <= t) for i, x in enumerate(frames)) / total,
                            "total_interval_ms": math.fsum(x for x in frames if x > t)}
                   for t in (16.667, 33.333, 50.0)},
        "histogram": histogram,
    }


def read_run(path: Path, column: str, filters: dict) -> tuple[list[float], int, str]:
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    # Decode exactly the bytes hashed, not a second read of a potentially changing capture.
    import io
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig"), newline=""))
    fields = reader.fieldnames or []
    if len(fields) != len(set(fields)) or column not in fields:
        raise ValueError(f"{path}: missing interval column or duplicate CSV headers.")
    if any(key not in fields for key in filters):
        raise ValueError(f"{path}: filter references a missing column.")
    frames: list[float] = []
    skipped = 0
    streams: dict[str, set[str]] = {key: set() for key in ("ProcessID", "SwapChainAddress") if key in fields}
    for line, row in enumerate(reader, start=2):
        if None in row or any(value is None for value in row.values()):
            raise ValueError(f"{path}:{line}: malformed CSV row.")
        if any(row[key] != str(value) for key, value in filters.items()):
            skipped += 1
            continue
        for key in streams:
            streams[key].add(row[key])
        try:
            value = float(row[column])
        except (TypeError, ValueError) as error:
            raise ValueError(f"{path}:{line}: invalid interval; no silent exclusions.") from error
        if not math.isfinite(value) or value <= 0:
            raise ValueError(f"{path}:{line}: invalid interval; no silent exclusions.")
        frames.append(value)
    if any(len(values) > 1 for values in streams.values()):
        raise ValueError(f"{path}: multiple processes/swap chains; declare exact filters.")
    if not frames:
        raise ValueError(f"{path}: no frames after filtering.")
    return frames, skipped, digest


def analyze_manifest(path: Path) -> dict:
    path = path.resolve()
    manifest = json.loads(path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema_version") != 2:
        raise ValueError("Unsupported manifest schema.")
    environment = manifest.get("environment", {})
    required = ("cpu", "gpu", "windows_build", "gpu_driver", "game_version", "scene",
                "settings", "capture_tool", "capture_version", "optimizer_commit")
    if any(not isinstance(environment.get(key), str) or not environment[key].strip() for key in required):
        raise ValueError("Record all required environment fields before comparing runs.")
    if manifest.get("interval_kind") not in ("present", "display", "render"):
        raise ValueError("Declare interval_kind: present, display, or render. These are not interchangeable.")
    if not isinstance(manifest.get("frame_generation"), bool):
        raise ValueError("Declare frame_generation as a boolean.")
    if not isinstance(manifest.get("frametime_column"), str) or not manifest["frametime_column"]:
        raise ValueError("Declare the measured interval column in milliseconds.")
    measurement = manifest.get("measurement", {})
    semantics = {"present": "between_present_events", "display": "between_display_events",
                 "render": "between_render_completion_events"}
    if measurement.get("semantics") != semantics[manifest["interval_kind"]] or measurement.get("unit") != "ms":
        raise ValueError("Require intervals between events, not GPU/CPU busy or work duration.")
    if not isinstance(measurement.get("source_reference"), str) or not measurement["source_reference"].strip():
        raise ValueError("Document the column definition and capture-tool version source.")
    if any(word in manifest["frametime_column"].lower() for word in ("busy", "duration", "latency")):
        raise ValueError("Work/latency duration column cannot be used as frame cadence.")
    runs = manifest.get("runs", [])
    if not isinstance(runs, list) or not runs:
        raise ValueError("At least one run per condition is required.")
    results = []
    ids: set[str] = set()
    digests: set[str] = set()
    quality = []
    for run in runs:
        if run.get("condition") not in ("A", "B") or not run.get("id") or run["id"] in ids:
            raise ValueError("Runs need unique IDs and condition A or B.")
        ids.add(run["id"])
        filters = run.get("filters", {})
        if not isinstance(filters, dict):
            raise ValueError("filters must map column names to exact string values.")
        capture = (path.parent / run["csv"]).resolve()
        frames, skipped, digest = read_run(capture, manifest["frametime_column"], filters)
        if digest in digests:
            quality.append(f"{run['id']}: identical CSV content reused; verify independent capture.")
        digests.add(digest)
        metrics = summarize_frames(frames)
        if metrics["duration_seconds"] < 60:
            quality.append(f"{run['id']}: less than 60 seconds of intervals.")
        results.append({"id": run["id"], "condition": run["condition"], "csv": str(capture),
                        "sha256": digest, "filters": filters, "filtered_rows": skipped, **metrics})
    conditions = {}
    for condition in ("A", "B"):
        group = [run for run in results if run["condition"] == condition]
        if not group:
            raise ValueError("Both A and B conditions are required.")
        if len(group) < 5:
            quality.append(f"{condition}: fewer than five independent runs.")
        conditions[condition] = {"runs": len(group)}
        for metric in ("average_fps", "one_percent_low_fps", "max_frametime_ms"):
            values = [run[metric] for run in group]
            conditions[condition][metric] = {
                "median": statistics.median(values), "min": min(values), "max": max(values),
                "sample_stddev": statistics.stdev(values) if len(values) > 1 else None,
                "coefficient_of_variation": statistics.stdev(values) / statistics.mean(values) if len(values) > 1 else None,
            }
    comparison = {
        metric: 100 * (conditions["B"][metric]["median"] / conditions["A"][metric]["median"] - 1)
        for metric in ("average_fps", "one_percent_low_fps", "max_frametime_ms")
    }
    return {
        "schema_version": 2, "measurement": measurement, "environment": environment, "interval_kind": manifest["interval_kind"],
        "frame_generation": manifest["frame_generation"], "frametime_column": manifest["frametime_column"],
        "percentile_method": "nearest-rank", "runs": results, "conditions": conditions,
        "descriptive_median_change_B_vs_A_percent": comparison, "quality_issues": quality,
        "limits": ["Descriptive comparison; no automatic significance or causal performance claim.",
                   "Input latency, CPU/GPU telemetry and DPC/ISR are not inferred from frametimes.",
                   "Frame generation and presented frames do not establish rendered FPS or input latency.",
                   "Inspect temporal captures and control thermal, cache, scene and run-order effects."],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = analyze_manifest(args.manifest)
        # Exclusive creation: never overwrite a capture, manifest, or prior result.
        with args.output.open("x", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, ensure_ascii=False, allow_nan=False)
            handle.write("\n")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Analysis failed: {error}\n")


if __name__ == "__main__":
    main()
