"""Offline session observations. No capture, process control or Windows changes."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re


def number(value, name, positive=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{name}: finite numeric value required")
    if value < 0 or (positive and value == 0):
        raise ValueError(f"{name}: invalid range")
    return value


def diagnose(session):
    if session.get("schema_version") != 1 or session.get("clock") != "relative_monotonic_seconds":
        raise ValueError("Declare schema 1 and relative_monotonic_seconds clock.")
    cpus = number(session.get("logical_processors"), "logical_processors", True)
    if int(cpus) != cpus:
        raise ValueError("logical_processors must be an integer")
    target = session.get("game_process_id")
    if not isinstance(target, str) or not re.fullmatch(r"P[0-9]{3}", target):
        raise ValueError("Use anonymous game_process_id P001..P999.")
    samples = session.get("samples")
    if not isinstance(samples, list) or len(samples) < 2:
        raise ValueError("At least two temporal samples required.")
    previous = None
    windows = []
    observed_game = False
    for sample in samples:
        time = number(sample.get("seconds"), "seconds")
        if previous is not None and time <= previous[0]:
            raise ValueError("Sample times must increase strictly.")
        processes = {}
        for process in sample.get("processes", []):
            ident = process.get("id")
            # Identity includes lifetime; PID alone is insufficient after reuse.
            if not isinstance(ident, str) or not re.fullmatch(r"P[0-9]{3}", ident) or ident in processes:
                raise ValueError("Unique anonymous process IDs required per sample.")
            lifetime = process.get("lifetime")
            if not isinstance(lifetime, str) or not re.fullmatch(r"L[0-9]{3}", lifetime):
                raise ValueError("Anonymous lifetime token L001..L999 required.")
            for field in ("cpu_seconds", "read_bytes", "write_bytes", "private_bytes"):
                if process.get(field) is not None:
                    number(process[field], field)
            processes[ident] = process
            observed_game |= ident == target
        memory = sample.get("memory", {})
        for field in ("available_bytes", "commit_bytes", "commit_limit_bytes"):
            if memory.get(field) is not None:
                number(memory[field], field, field == "commit_limit_bytes")
        commit = memory.get("commit_bytes")
        limit = memory.get("commit_limit_bytes")
        if commit is not None and limit is not None and commit > limit:
            raise ValueError("Commit exceeds declared limit; check units/collection consistency.")
        storage = sample.get("game_volume", {})
        for field in ("read_bytes_per_second", "write_bytes_per_second", "latency_ms", "queue_length"):
            if storage.get(field) is not None:
                number(storage[field], field)
        if previous is not None:
            elapsed = time - previous[0]
            activity = []
            for ident, process in processes.items():
                old = previous[1].get(ident)
                matched = old is not None and old["lifetime"] == process["lifetime"]
                rates = {}
                for field, output in (("cpu_seconds", "cpu_core_equivalents"),
                                      ("read_bytes", "read_bytes_per_second"),
                                      ("write_bytes", "write_bytes_per_second")):
                    start = old.get(field) if matched else None
                    end = process.get(field)
                    if start is None or end is None:
                        rates[output] = None
                    else:
                        if end < start:
                            raise ValueError("Cumulative counter decreased within one process lifetime.")
                        rates[output] = number((end - start) / elapsed, output)
                cores = rates["cpu_core_equivalents"]
                if cores is not None and cores > cpus * 1.01:
                    raise ValueError("CPU delta exceeds machine capacity; check clock and units.")
                activity.append({"id": ident, "role": "game" if ident == target else "concurrent",
                                 "identity_matched": matched, **rates,
                                 "cpu_machine_percent": None if cores is None else 100 * cores / cpus,
                                 "private_bytes": process.get("private_bytes")})
            activity.sort(key=lambda row: (row["cpu_core_equivalents"] is not None,
                                           row["cpu_core_equivalents"] or 0), reverse=True)
            game_matched = (target in processes and target in previous[1] and
                            processes[target]['lifetime'] == previous[1][target]['lifetime'])
            windows.append({"start_seconds": previous[0], "end_seconds": time,
                            "game_observed_at_both_boundaries": game_matched,
                            "activity": activity,
                            "available_bytes": memory.get("available_bytes"),
                            "commit_fraction": None if commit is None or limit is None else commit / limit,
                            "game_volume": {key: storage.get(key) for key in
                                            ("read_bytes_per_second", "write_bytes_per_second", "latency_ms", "queue_length")}})
        previous = (time, processes)
    if not observed_game:
        raise ValueError("Selected game process was never observed.")
    candidates = sorted({row["id"] for window in windows if window['game_observed_at_both_boundaries']
                         for row in window["activity"]
                         if row["role"] == "concurrent" and
                         ((row["cpu_core_equivalents"] or 0) >= 0.25 or
                          (row["read_bytes_per_second"] or 0) + (row["write_bytes_per_second"] or 0) >= 1048576)})
    return {"schema_version": 1, "windows": windows, "concurrent_activity_candidates": candidates,
            "decision": "Investigate observed activity" if candidates else "No change justified by these samples",
            "thresholds": {"cpu_core_equivalents": 0.25, "process_io_bytes_per_second": 1048576},
            "limits": ["Thresholds prioritize inspection, not causal bottleneck or removal decisions.",
                       "CPU total cannot identify critical-thread ready/wait time. Short spikes may be missed.",
                       "Process I/O includes cached and other I/O; it is not physical disk throughput.",
                       "No working-set sum, RAM-saved claim or FPS/input-latency inference.",
                       "Missing GPU, temperature, DPC/ISR, frame alignment and functional use remain unknown.",
                       "Review private source data locally. Export contains only declared anonymous identities and metrics."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = diagnose(json.loads(args.session.read_text(encoding="utf-8-sig")))
        with args.output.open("x", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, allow_nan=False)
            handle.write("\n")
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        parser.exit(1, f"Session analysis failed: {error}\n")


if __name__ == "__main__":
    main()
