"""Normalize a selected PresentMon legacy-metrics stream; preserve exclusion evidence."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path


def normalize(raw, pid, swapchain):
    data = Path(raw).read_bytes()
    reader = csv.DictReader(io.StringIO(data.decode('utf-8-sig'), newline=''))
    columns = reader.fieldnames or []
    if len(columns) != len(set(columns)) or not {'ProcessID','SwapChainAddress','MsBetweenPresents'} <= set(columns):
        raise ValueError('Require PresentMon legacy metrics with PID, swapchain and MsBetweenPresents')
    frames=[]; filtered=0; boundary=0; selected=0
    for row in reader:
        if None in row or any(x is None for x in row.values()):
            raise ValueError('Malformed CSV')
        if row['ProcessID'] != str(pid) or row['SwapChainAddress'] != swapchain:
            filtered += 1
            continue
        value=float(row['MsBetweenPresents'])
        if value == 0 and selected == 0:
            boundary += 1
        elif not math.isfinite(value) or value <= 0:
            raise ValueError('Invalid selected interval; only the initial zero boundary may be excluded')
        else:
            frames.append(value)
        selected += 1
    if not frames:raise ValueError('No valid selected frames')
    return frames, {'raw_sha256': hashlib.sha256(data).hexdigest(), 'selected_pid': str(pid),
                    'selected_swapchain':swapchain, 'filtered_other_stream_rows': filtered,
                    'excluded_initial_zero_boundary':boundary, 'frames':len(frames),
                    'semantics':'between_present_events','unit':'ms'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('raw',type=Path);p.add_argument('--pid',type=int,required=True)
    p.add_argument('--swapchain',required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    try:
        frames,evidence=normalize(a.raw,a.pid,a.swapchain)
        a.output.mkdir(exist_ok=False)
        target=a.output/'frames.csv'
        with target.open('x',newline='',encoding='utf-8') as f:
            writer=csv.writer(f);writer.writerow(['FrameTimeMs']);writer.writerows((x,) for x in frames)
        evidence['normalized_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
        (a.output/'normalization.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
    except (OSError,ValueError,TypeError) as error:p.exit(1,f'Normalization failed: {error}\n')


if __name__=='__main__':main()
