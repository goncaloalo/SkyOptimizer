"""Paired, block-aware exploratory inference. Never applies optimizer actions."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import statistics

from analyze import analyze_manifest


METRICS = {'average_fps': 1, 'one_percent_low_fps': 1, 'p99_ms': -1}


def metric_value(row, metric):
    return row['frametime_percentiles_ms']['99'] if metric == 'p99_ms' else row[metric]


def evaluate(analysis, manifest):
    design = manifest['experimental_design']
    primary = design['primary_metric']
    if primary not in METRICS:
        raise ValueError('Unsupported primary metric')
    minimum = design['minimum_benefit_percent']
    margin = design['regression_margin_percent']
    if any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) or not 0 < x < 100 for x in (minimum, margin)):
        raise ValueError('Pre-register finite positive benefit and regression margins below 100%')
    seed = design['seed']
    draws = design.get('bootstrap_draws', 10000)
    if type(seed) is not int or type(draws) is not int or not 1000 <= draws <= 100000:
        raise ValueError('Integer seed and 1000..100000 bootstrap draws required')
    rows = {r['id']: r for r in analysis['runs']}
    pairs = {}
    for run in manifest['runs']:
        pair, block, order = run.get('pair'), run.get('block'), run.get('order')
        if not all(isinstance(x, str) and x.strip() for x in (pair, block)) or type(order) is not int or order < 1:
            raise ValueError('Declare pair, block and positive temporal order per run')
        group = pairs.setdefault(pair, {})
        if run['condition'] in group:
            raise ValueError('Exactly one A and one B per pair required')
        group[run['condition']] = (block, order, rows[run['id']])
    orders = [r['order'] for r in manifest['runs']]
    if len(set(orders)) != len(orders):
        raise ValueError('Temporal orders must be unique')
    blocks = {}
    sequences = []
    for group in pairs.values():
        if set(group) != {'A', 'B'} or group['A'][0] != group['B'][0]:
            raise ValueError('Pairs must be complete within one block')
        block = group['A'][0]
        sequences.append('AB' if group['A'][1] < group['B'][1] else 'BA')
        delta = {}
        for metric, direction in METRICS.items():
            a, b = metric_value(group['A'][2], metric), metric_value(group['B'][2], metric)
            delta[metric] = direction * math.log(b / a)
        blocks.setdefault(block, []).append(delta)
    if len(pairs) < 2 or len(blocks) < 2:
        raise ValueError('At least two pairs in two independent declared blocks required')
    # Cluster bootstrap: preserve every pair in a selected block; equal block weight.
    means = [{m: statistics.mean(d[m] for d in group) for m in METRICS} for group in blocks.values()]
    rng = random.Random(seed)
    boot = {m: [] for m in METRICS}
    for _ in range(draws):
        sample = rng.choices(means, k=len(means))
        for m in METRICS:
            boot[m].append(statistics.mean(b[m] for b in sample))
    issues = list(analysis['quality_issues'])
    if len(blocks) < 5 or len(pairs) < 8:
        issues.append('Pilot only: fewer than five blocks or eight pairs; cluster CI unreliable.')
    if abs(sequences.count('AB') - sequences.count('BA')) > 1:
        issues.append('AB/BA order is unbalanced; inspect carryover and drift.')
    if any(r['duration_seconds'] < 120 for r in analysis['runs']):
        issues.append('Capture shorter than the pre-planned starting duration of 120 seconds.')
    output = {}
    # Bonferroni over three predeclared metrics: approximate family coverage 95%.
    alpha = .05 / len(METRICS)
    for metric in METRICS:
        distribution = sorted(boot[metric])
        low = distribution[max(0, math.ceil(draws * alpha / 2) - 1)]
        high = distribution[min(draws - 1, math.ceil(draws * (1 - alpha / 2)) - 1)]
        point = statistics.mean(b[metric] for b in means)
        transform = lambda x: 100 * math.expm1(x)
        # For lower-is-better metrics report reciprocal ratio benefit; name explicitly.
        lo, hi = transform(low), transform(high)
        status = ('Regression' if hi < -margin else 'BenefitDetected' if lo > minimum else
                  'NoMeaningfulBenefit' if hi < minimum and lo > -margin else 'Inconclusive')
        if issues:
            status = 'Inconclusive'
        output[metric] = {'oriented_ratio_change_percent': transform(point), 'ci_percent': [lo, hi],
                          'status': status, 'block_log_stddev': statistics.stdev(b[metric] for b in means),
                          'pair_log_stddev': statistics.stdev(d[metric] for group in blocks.values() for d in group),
                          'A_run_median': statistics.median(metric_value(group['A'][2], metric) for group in pairs.values()),
                          'B_run_median': statistics.median(metric_value(group['B'][2], metric) for group in pairs.values())}
    status = ('Regression' if any(x['status'] == 'Regression' for x in output.values()) else
              'BenefitDetected' if output[primary]['status'] == 'BenefitDetected' and
              all(x['ci_percent'][0] > -margin for x in output.values()) else
              'NoMeaningfulBenefit' if output[primary]['status'] == 'NoMeaningfulBenefit' else 'Inconclusive')
    return {'schema_version': 1, 'synthetic': manifest.get('synthetic') is True,
            'status': status, 'primary_metric': primary, 'pairs': len(pairs), 'blocks': len(blocks),
            'metrics': output, 'quality_issues': issues, 'design': design,
            'method': 'Equal-block log ratios; cluster percentile bootstrap; Bonferroni three metrics',
            'limits': ['Exploratory intervals; declared blocks do not prove independence.',
                       'Lower-is-better benefit uses A/B-1, not percentage reduction B/A-1.',
                       'No causal attribution, automatic promotion or physical input latency measurement.']}


def report(result):
    lines = ['# SkyOptimizer — avaliação A/B', '',
             '**DADOS SINTÉTICOS — não são ganhos medidos.**' if result['synthetic'] else
             'Dados fornecidos pelo operador; autenticidade e condições requerem revisão.', '',
             f"Resultado: {result['status']}. Primária: {result['primary_metric']}. Pares: {result['pairs']}; blocos: {result['blocks']}.", '',
             'A/B são medianas descritivas dos runs (FPS; p99 em ms). A razão inferencial usa blocos com peso igual.', '',
             '| Métrica | A | B | Razão orientada (%) | Intervalo simultâneo aproximado (%) | Estado |',
             '|---|---:|---:|---:|---|---|']
    for name, row in result['metrics'].items():
        lines.append(f"| {name} | {row['A_run_median']:.3f} | {row['B_run_median']:.3f} | {row['oriented_ratio_change_percent']:.3f} | {row['ci_percent'][0]:.3f}, {row['ci_percent'][1]:.3f} | {row['status']} |")
    return '\n'.join(lines + ['', *result['quality_issues'], '', *result['limits']]) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--output', type=Path, required=True, help='New directory for JSON and Markdown')
    args = parser.parse_args()
    try:
        raw = args.manifest.read_bytes()
        manifest = json.loads(raw.decode('utf-8-sig'))
        analysis = analyze_manifest(args.manifest)
        if args.manifest.read_bytes() != raw:
            raise ValueError('Manifest changed during analysis')
        result = evaluate(analysis, manifest)
        result['manifest_sha256'] = hashlib.sha256(raw).hexdigest()
        args.output.mkdir(exist_ok=False)
        (args.output/'analysis.json').write_text(json.dumps(analysis, indent=2, allow_nan=False), encoding='utf-8')
        (args.output/'experiment.json').write_text(json.dumps(result, indent=2, allow_nan=False), encoding='utf-8')
        (args.output/'report.md').write_text(report(result), encoding='utf-8')
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'Experiment failed: {error}\n')


if __name__ == '__main__':
    main()
