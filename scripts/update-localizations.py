#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

"""Check English catalogs against Objective-C and Interface Builder; --write refreshes them.

Extract each application's and framework's source tree into its owning catalog,
including implementation sources in organizational subfolders.
Requires the active Xcode developer tools. Existing translations are preserved.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
CODE = ['FolioKit/FolioKit', 'Write/Write', 'Write/WriteKit', 'Research/Research', 'Research/ResearchKit', 'Composer/Composer', 'Composer/ComposerKit']
STORYBOARDS = [
    ('Write/Write/Base.lproj/Main.storyboard', 'Write/Write/mul.lproj/Main.xcstrings'),
    ('Research/Research/Base.lproj/Main.storyboard', 'Research/Research/mul.lproj/Main.xcstrings'),
    ('Write/WriteKit/Resources/Base.lproj/Editor.storyboard', 'Write/WriteKit/Resources/mul.lproj/Editor.xcstrings'),
    ('Composer/Composer/Base.lproj/Main.storyboard', 'Composer/Composer/mul.lproj/Main.xcstrings'),
]


def read_strings(path):
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))


def refresh(path, values, comments, write):
    data = json.loads(path.read_text()) if path.exists() else {'sourceLanguage': 'en', 'strings': {}, 'version': '1.2'}
    assert data['sourceLanguage'] == 'en', path
    problems = []
    for key, value in values.items():
        entry = data['strings'].get(key, {})
        old = entry.get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value')
        if old != value or not entry.get('comment'):
            problems.append(key)
        if write:
            if old is not None and old != value:
                for language, localization in entry.get('localizations', {}).items():
                    if language != 'en' and 'stringUnit' in localization:
                        localization['stringUnit']['state'] = 'needs_review'
            entry['extractionState'] = 'manual'
            entry['comment'] = comments.get(key) or entry.get('comment') or f'{key}: user-facing text.'
            entry.setdefault('localizations', {})['en'] = {'stringUnit': {'state': 'translated', 'value': value}}
            # Keyboard shortcut glyphs must continue to describe the implemented shortcut.
            if 'shortcut' in key:
                entry['shouldTranslate'] = False
            data['strings'][key] = entry
    stale = set(data['strings']) - set(values)
    if stale:
        problems.extend(sorted(stale))
        if write:
            for key in stale:
                data['strings'][key]['extractionState'] = 'stale'
    if write:
        data['strings'] = dict(sorted(data['strings'].items()))
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    elif problems:
        raise SystemExit(f'{path.relative_to(ROOT)}: refresh/review {", ".join(problems)}')
    print(f'{path.relative_to(ROOT)}: {len(values)} extracted strings')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Refresh source entries while preserving translations.')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='folio-localization-') as temporary:
        temp = Path(temporary)
        for index, folder in enumerate(CODE):
            output = temp / str(index)
            output.mkdir()
            sources = [str(p) for p in (ROOT / folder).rglob('*.m')]
            subprocess.run(['xcrun', 'genstrings', '-q', '-o', str(output), *sources], check=True)
            strings = output / 'Localizable.strings'
            values = read_strings(strings) if strings.exists() else {}
            comments = {}
            if strings.exists():
                text = strings.read_text(encoding='utf-16')
                for comment, key in re.findall(r'/\*\s*(.*?)\s*\*/\s*"([^"\\]+)"\s*=', text, re.S):
                    comments[key] = comment.strip()
            refresh(ROOT / folder / 'Localizable.xcstrings', values, comments, args.write)
        for index, (storyboard, catalog) in enumerate(STORYBOARDS):
            strings = temp / f'storyboard-{index}.strings'
            subprocess.run(['xcrun', 'ibtool', '--export-strings-file', str(strings), str(ROOT / storyboard)], check=True)
            objects = {e.get('id'): e for e in ET.parse(ROOT / storyboard).iter() if e.get('id')}
            comments = {}
            values = read_strings(strings)
            for key in values:
                identifier, _, property_name = key.partition('.')
                element = objects[identifier]
                label = element.get('userLabel', identifier)
                comments[key] = f'{label} — {element.tag} {property_name} in {Path(storyboard).stem}. Keep Folio domain terms consistent with the glossary.'
            refresh(ROOT / catalog, values, comments, args.write)


if __name__ == '__main__':
    main()
