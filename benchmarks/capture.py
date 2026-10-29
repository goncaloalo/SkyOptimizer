"""Explicit laboratory PresentMon 2.3.1 console adapter. Default: plan only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid


def plan(tool, expected_sha256, process_id, seconds, directory):
    tool = Path(tool).resolve()
    if not re.fullmatch(r'[a-fA-F0-9]{64}', expected_sha256):
        raise ValueError('Operator-approved SHA256 required')
    actual = hashlib.sha256(tool.read_bytes()).hexdigest()
    if actual.lower() != expected_sha256.lower() or tool.suffix.lower() != '.exe':
        raise ValueError('Tool hash or extension mismatch')
    if type(process_id) is not int or process_id < 1 or type(seconds) is not int or not 1 <= seconds <= 1800:
        raise ValueError('Positive PID and 1..1800 seconds required')
    directory = Path(directory).resolve()
    if directory.exists():
        raise ValueError('Output directory must not exist')
    session = 'SkyBenchmark-' + uuid.uuid4().hex
    command = [str(tool), '--process_id', str(process_id), '--output_file', str(directory/'frames.csv'),
               '--timed', str(seconds), '--terminate_after_timed', '--terminate_on_proc_exit',
               '--session_name', session, '--v1_metrics', '--no_console_stats', '--no_track_input']
    return {'tool': 'PresentMon console 2.3.1; operator must verify version and provenance',
            'sha256': actual, 'session': session, 'seconds': seconds, 'command': command,
            'column': 'MsBetweenPresents', 'semantics': 'between_present_events', 'unit': 'ms',
            'source_reference': 'https://github.com/GameTechDev/PresentMon/blob/v2.3.1/README-ConsoleApplication.md',
            'status': 'Planned', 'physical_input_latency': 'NotMeasured'}


def execute(capture, directory, runner=None):
    if os.name != 'nt':
        raise ValueError('Live capture requires Windows; no fallback data')
    tool = Path(capture['command'][0])
    if hashlib.sha256(tool.read_bytes()).hexdigest() != capture['sha256']:
        raise ValueError('Tool changed since planning')
    directory = Path(directory)
    directory.mkdir(exist_ok=False)
    runner = runner or subprocess.run
    start = time.monotonic()
    try:
        with (directory/'tool.log').open('xb') as log:
            completed = runner(capture['command'], shell=False, stdout=log, stderr=subprocess.STDOUT,
                               timeout=capture['seconds'] + 30, check=False)
        capture['exit_code'] = completed.returncode
        csv = directory/'frames.csv'
        capture['status'] = 'CapturedUnvalidated' if completed.returncode == 0 and csv.is_file() and csv.stat().st_size else 'Failed'
        if csv.is_file():
            capture['csv_sha256'] = hashlib.sha256(csv.read_bytes()).hexdigest()
    except (OSError, subprocess.TimeoutExpired) as error:
        capture['status'] = 'Failed'
        capture['failure_type'] = type(error).__name__
        capture['session_cleanup'] = 'Unverified; inspect only the recorded session, never stop other sessions'
    finally:
        capture['elapsed_seconds'] = time.monotonic() - start
        with (directory/'capture.json').open('x', encoding='utf-8') as handle:
            json.dump(capture, handle, indent=2, allow_nan=False)
    return capture


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tool', type=Path, required=True)
    p.add_argument('--approved-sha256', required=True)
    p.add_argument('--pid', type=int, required=True)
    p.add_argument('--seconds', type=int, default=150)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--execute-authorized-lab-capture', action='store_true')
    a = p.parse_args()
    try:
        capture = plan(a.tool, a.approved_sha256, a.pid, a.seconds, a.output)
        if a.execute_authorized_lab_capture:
            capture = execute(capture, a.output)
        print(json.dumps(capture, indent=2))
        if capture['status'] == 'Failed':
            p.exit(1)
    except (OSError, ValueError) as error:
        p.exit(1, f'Capture unavailable: {error}\n')


if __name__ == '__main__':
    main()
