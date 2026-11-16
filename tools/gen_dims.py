#!/usr/bin/env python3
"""Gera a pasta de programas da Lua (shaders/moon/) do Fiat Lux.

Uso: python3 gen_dims.py <pasta shaders>

O Iris escolhe a pasta de programas pela dimensão (dimension.properties). A Lua do Elementar
(periodic_elements:moon) usa shaders/moon/ e Marte (periodic_elements:mars) usa shaders/mars/, onde cada
programa é o mesmo da raiz com '#define DIM_MOON' ou '#define DIM_MARS' logo depois do #version.
As outras dimensões continuam usando a raiz.

- Programas grandes da raiz (mais de 8 linhas) têm o corpo movido para shaders/program/<nome>.glsl,
  e a raiz vira só '#version' + '#include'. Assim a Lua e a raiz compartilham o mesmo código.
- shaders/moon/ é reescrita do zero a cada execução. Rode de novo ao criar um programa novo.
"""
import os, sys, glob, shutil

DIMS = {'moon': '#define DIM_MOON', 'mars': '#define DIM_MARS'}
EXTS = ('.fsh', '.vsh', '.csh', '.gsh')

def main(shaders):
    progs = sorted(f for f in os.listdir(shaders) if f.endswith(EXTS))
    os.makedirs(os.path.join(shaders, 'program'), exist_ok=True)
    for f in progs:
        path = os.path.join(shaders, f)
        lines = open(path, encoding='utf-8').read().split('\n')
        assert lines[0].startswith('#version'), f
        if len([l for l in lines if l.strip()]) > 8:
            body = '\n'.join(lines[1:]).lstrip('\n')
            open(os.path.join(shaders, 'program', f + '.glsl'), 'w', encoding='utf-8').write(body)
            open(path, 'w', encoding='utf-8').write('%s\n#include "/program/%s.glsl"\n' % (lines[0], f))
    for d, define in DIMS.items():
        out = os.path.join(shaders, d)
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out)
        for f in progs:
            lines = open(os.path.join(shaders, f), encoding='utf-8').read().split('\n')
            text = '\n'.join([lines[0], define] + lines[1:])
            open(os.path.join(out, f), 'w', encoding='utf-8').write(text)
    print('programas: %d, dimensões: %s' % (len(progs), ', '.join(DIMS)))

if __name__ == '__main__':
    main(sys.argv[1])
