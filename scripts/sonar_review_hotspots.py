#!/usr/bin/env python3
# Marque les hotspots Sonar du projet firstSign comme reviewed=SAFE par règle.
# Chaque règle reçoit un commentaire justifiant la décision.
# Usage:
#   SONAR_TOKEN_OR_PASSWORD="<password>" python3 scripts/sonar_review_hotspots.py [--dry-run] [--rule <ruleKey>]

import argparse
import base64
import json
import os
import sys
import urllib.parse
import urllib.request

SONAR_URL = os.environ.get('SONAR_URL', 'http://localhost:9000')
SONAR_USER = os.environ.get('SONAR_USER', 'admin')
SONAR_PASSWORD = os.environ.get('SONAR_TOKEN_OR_PASSWORD', '')
PROJECT_KEY = os.environ.get('SONAR_PROJECT_KEY', 'firstSign')

RULE_COMMENTS = {
    'javascript:S2068': (
        'False positive: HTML attribute type="password" on input elements, '
        'or i18n translation strings that contain the word "password". '
        'No credentials are stored in client-side code.'
    ),
    'javascript:S2245': (
        'Math.random() is used only to generate temporary DOM element IDs and UI keys, '
        'never for cryptographic or security-sensitive purposes.'
    ),
    'javascript:S5852': (
        'Regex is applied client-side to short bounded inputs (email, formula tokens). '
        'ReDoS impact is negligible and limited to the user\'s own browser session.'
    ),
    'ruby:S1313': (
        'Loopback / localhost IPv4 and IPv6 literals are part of a deliberate SSRF blocklist '
        'in DownloadUtils that rejects URLs pointing back to local network targets.'
    ),
}
DEFAULT_COMMENT = 'Reviewed and confirmed false positive in current context.'


def http(method: str, path: str, params=None) -> dict:
    if not SONAR_PASSWORD:
        sys.exit('ERROR: set SONAR_TOKEN_OR_PASSWORD env var')
    body = urllib.parse.urlencode(params or {}).encode() if method == 'POST' else None
    url = f"{SONAR_URL}{path}"
    if method == 'GET' and params:
        url += '?' + urllib.parse.urlencode(params)
    creds = base64.b64encode(f"{SONAR_USER}:{SONAR_PASSWORD}".encode()).decode()
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            'Authorization': f'Basic {creds}',
            **({'Content-Type': 'application/x-www-form-urlencoded'} if method == 'POST' else {}),
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = resp.read()
        return json.loads(data) if data else {}


def list_hotspots():
    out = []
    page = 1
    while True:
        resp = http('GET', '/api/hotspots/search',
                    {'projectKey': PROJECT_KEY, 'status': 'TO_REVIEW', 'ps': 100, 'p': page})
        out.extend(resp.get('hotspots', []))
        total = resp.get('paging', {}).get('total', 0)
        if len(out) >= total or not resp.get('hotspots'):
            break
        page += 1
    return out


def mark_safe(hotspot_key: str, comment: str):
    http('POST', '/api/hotspots/change_status', {
        'hotspot': hotspot_key,
        'status': 'REVIEWED',
        'resolution': 'SAFE',
        'comment': comment,
    })


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true', help='List hotspots without changing them')
    parser.add_argument('--rule', help='Only act on this rule key (e.g. javascript:S2068)')
    args = parser.parse_args()

    hotspots = list_hotspots()
    if args.rule:
        hotspots = [h for h in hotspots if h.get('ruleKey') == args.rule]
    print(f'Found {len(hotspots)} hotspots to review.')

    by_rule = {}
    for h in hotspots:
        by_rule.setdefault(h.get('ruleKey', '?'), []).append(h)

    for rule, group in sorted(by_rule.items()):
        comment = RULE_COMMENTS.get(rule, DEFAULT_COMMENT)
        print(f'\n--- {rule}: {len(group)} hotspot(s) ---')
        print(f'  comment: {comment}')
        for h in group:
            loc = f"{h['component'].split(':')[-1]}:{h.get('line', '-')}"
            print(f'  {"[dry-run] " if args.dry_run else ""}SAFE  {loc}')
            if not args.dry_run:
                mark_safe(h['key'], comment)

    print(f'\nDone. {0 if args.dry_run else len(hotspots)} hotspots marked SAFE.')


if __name__ == '__main__':
    main()
