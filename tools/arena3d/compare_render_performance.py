"""Validate paired rendered 2D/3D reports; missing data and mismatched devices fail."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path


def validate(report: dict) -> None:
    if report.get('kind') != 'arena_render_performance' or report.get('mode') not in ('2d', '3d'):
        raise ValueError('Not an arena render report')
    if report.get('platform', {}).get('display') in (None, 'headless'):
        raise ValueError('Rendered display required')
    if report.get('fixture') in ('public-eight-bench-signature-v3', 'public-eight-bench-signature-v4') and report.get('mode') == '3d' and report.get('signature_attacks', 0) < 3:
        raise ValueError('Full character attacks did not run')
    if {r.get('case') for r in report.get('cases', [])} != {'idle', 'updates_and_attacks'} or len(report['cases']) != 2:
        raise ValueError('Both complete measurement windows are required')
    for row in report['cases']:
        gaps = row.get('frame_gaps_ms', [])
        if len(gaps) < 100 or any(isinstance(x, bool) or not isinstance(x, (int,float)) or not math.isfinite(x) or x <= 0 for x in gaps):
            raise ValueError('Invalid or incomplete frame samples')
        if sum(gaps) < report['seconds_per_case'] * 980:
            raise ValueError('Truncated measurement duration')
        if row['case'] != 'idle' and row.get('updates',0) < 3:
            raise ValueError('Animation workload did not run')


def stats(row: dict) -> dict:
    gaps = sorted(row['frame_gaps_ms'])
    return {**{key: gaps[max(0, math.ceil(len(gaps)*q)-1)] for key,q in [('p95',.95),('p99',.99)]},
            'max': max(gaps), 'mean': sum(gaps)/len(gaps), 'over50_fraction': sum(x>50 for x in gaps)/len(gaps)}


def compare(base: dict, candidate: dict) -> dict:
    validate(base)
    validate(candidate)
    if base['mode'] != '2d' or candidate['mode'] != '3d': raise ValueError('Expected 2D baseline and 3D candidate')
    for key in ('platform','fixture','attack_roster','simulated_touch','touch_profile','seconds_per_case'):
        if base.get(key) != candidate.get(key): raise ValueError('Mismatched '+key)
    results = []
    for left,right in zip(sorted(base['cases'],key=lambda r:r['case']), sorted(candidate['cases'],key=lambda r:r['case'])):
        a,b = stats(left),stats(right)
        limits = {'p95': max(a['p95']*1.10,a['p95']+1), 'p99':max(a['p99']*1.15,a['p99']+2),
                  'max':max(a['max']*1.20,50), 'mean':max(a['mean']*1.10,a['mean']+1),
                  'over50_fraction':a['over50_fraction']+.005}
        failures = [key for key in limits if b[key]>limits[key]]
        if b['max']>=1000: failures.append('one_second_stall')
        results.append({'case':left['case'],'2d':a,'3d':b,'limits':limits,'failures':failures,'passed':not failures})
    return {'schema_version':1,'passed':all(r['passed'] for r in results),'platform':base['platform'],'comparisons':results}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline',type=Path)
    parser.add_argument('candidate',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    try:
        result=compare(json.loads(args.baseline.read_text(encoding='utf-8-sig')),json.loads(args.candidate.read_text(encoding='utf-8-sig')))
    except (ValueError,KeyError,TypeError,OSError) as exc:
        result={'passed':False,'error':str(exc)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))
    return int(not result['passed'])


if __name__=='__main__': raise SystemExit(main())
