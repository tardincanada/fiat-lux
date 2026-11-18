#!/usr/bin/env python3
"""Gera os IDs de luz colorida do Fiat Lux a partir do lights.json do mod Elementar.

Uso: python3 gen_lights.py <lights.json> <pasta shaders do Fiat Lux>

- Reescreve a seção entre '# >>> lights.json' e '# <<< lights.json' em block.properties e item.properties.
- Tira do block.10000 / item.10000 os blocos e itens do mod que o lights.json classifica.
- Blocos que já têm ID de Cherenkov (101xx) não mudam de ID; a cor da luz deles vai para
  lib/light_overrides.glsl (radioactiveLightId).
"""
import json, re, sys, os

KIND_ID = {
    'sodium_low_pressure': 10200, 'led_cool_white': 10201, 'carbide_flame': 10202, 'tritium': 10203,
    'incandescent': 10204, 'generic': 10209,
    'ember_glow': 10210, 'furnace_glow': 10211, 'white_hot': 10212, 'electric_arc': 10213,
    'bunsen_flame': 10214, 'ion_beam': 10215, 'cherenkov': 10216, 'cleanroom_yellow': 10217,
    'indicator_lamp': 10218, 'fusion_plasma': 10219,
    'shield_aurora': 10220, 'annihilation': 10221,
}
BEGIN, END = '# >>> lights.json (gerado por tools/gen_lights.py, não edite à mão)', '# <<< lights.json'

def token(e):
    return e['id'] + (':' + e['state'] if e.get('state') else '')

def read_ids(text, prefix):
    """{token: id} das linhas prefix.N=... (juntando continuações com \\)."""
    flat = re.sub(r'\\\n', ' ', text)
    out = {}
    for m in re.finditer(r'^%s\.(\d+)=(.*)$' % prefix, flat, re.M):
        for t in m.group(2).split():
            out[t] = int(m.group(1))
    return out

def strip_section(text):
    return re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END) + r'\n?', '', text, flags=re.S)

def remove_tokens(text, prefix, line_id, tokens):
    """tira tokens da linha prefix.line_id (com continuações)."""
    m = re.search(r'^%s\.%d=(?:.*\\\n)*.*$' % (prefix, line_id), text, re.M)
    if not m: return text
    body = m.group(0)[len('%s.%d=' % (prefix, line_id)):]
    toks = [t for t in re.sub(r'\\\n', ' ', body).split() if t not in tokens]
    lines, cur = [], ''
    for t in toks:
        if len(cur) + len(t) > 110:
            lines.append(cur.rstrip()); cur = ''
        cur += t + ' '
    lines.append(cur.rstrip())
    new = '%s.%d=' % (prefix, line_id) + ' \\\n '.join(lines)
    return text[:m.start()] + new + text[m.end():]

def section(entries, prefix, protected):
    by = {}
    for e in entries:
        t = e['id'] if prefix == 'item' else token(e)
        if t in protected: continue
        by.setdefault(KIND_ID[e['kind']], []).append((t, e['kind']))
    out = [BEGIN]
    for i in sorted(by):
        out.append('# %d = %s' % (i, by[i][0][1]))
        out.append('%s.%d=%s' % (prefix, i, ' '.join(sorted(set(t for t, _ in by[i])))))
    out.append(END)
    return '\n'.join(out) + '\n'

def main(lights_path, shaders):
    data = json.load(open(lights_path, encoding='utf-8'))
    unknown = sorted({e['kind'] for e in data['lights']} - set(KIND_ID))
    if unknown: sys.exit('Tipos de luz sem ID no shader: %s (acrescente em KIND_ID e lightSourceColor)' % unknown)
    blocks = [e for e in data['lights'] if not e.get('item')]
    items = [e for e in data['lights'] if e.get('item')]
    overrides = {}
    for prefix, entries, fname in (('block', blocks, 'block.properties'), ('item', items, 'item.properties')):
        path = os.path.join(shaders, fname)
        text = strip_section(open(path, encoding='utf-8').read())
        ids = read_ids(text, prefix)
        mine = {(e['id'] if prefix == 'item' else token(e)) for e in entries}
        # IDs de Cherenkov ficam; o resto do mod sai das linhas antigas
        # (compara pelo nome do bloco, sem o estado: o ID de Cherenkov vale para todos os estados)
        rad = {}
        for t, i in ids.items():
            if 10100 <= i < 10200: rad[':'.join(t.split(':')[:2])] = i
        protected = {t for t in mine if ':'.join(t.split(':')[:2]) in rad}
        for t in protected:
            if prefix == 'block':
                kind = next(e['kind'] for e in entries if token(e) == t)
                rid = rad[':'.join(t.split(':')[:2])]
                if rid in overrides and overrides[rid] != KIND_ID[kind]:
                    sys.exit('ID %d de Cherenkov mistura luzes de tipos diferentes' % rid)
                overrides[rid] = KIND_ID[kind]
        old = {}
        for t in mine - protected:
            if t in ids: old.setdefault(ids[t], set()).add(t)
        for line_id, toks in old.items():
            text = remove_tokens(text, prefix, line_id, toks)
        # linhas que ficaram vazias
        text = re.sub(r'^%s\.\d+=\s*$\n?' % prefix, '', text, flags=re.M)
        text = text.rstrip('\n') + '\n\n' + section(entries, prefix, protected)
        open(path, 'w', encoding='utf-8').write(text)
    lines = ['// Gerado por tools/gen_lights.py: blocos com ID de Cherenkov que também emitem luz colorida.',
             'int radioactiveLightId(int id) {']
    for rid, lid in sorted(overrides.items()):
        lines.append('    if (id == %d) return %d;' % (rid, lid))
    lines += ['    return ID_EMISSIVE;', '}', '']
    open(os.path.join(shaders, 'lib', 'light_overrides.glsl'), 'w').write('\n'.join(lines))
    print('blocos: %d, itens: %d, Cherenkov com luz: %s' % (len(blocks), len(items), overrides))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
