# Créditos / Credits

O Fiat Lux foi escrito do zero; nenhum arquivo foi copiado ou adaptado de outro shaderpack.
Algumas técnicas públicas foram reimplementadas a partir da descrição original:

Fiat Lux was written from scratch; no file was copied or adapted from another shaderpack.
Some public techniques were reimplemented from their original descriptions:

- **ACES filmic tonemap (aproximação)** — Krzysztof Narkowicz, "ACES Filmic Tone Mapping Curve" (2016).
- **FXAA 3.11** — Timothy Lottes, NVIDIA (2011). Versão compacta própria do algoritmo.
- **Fresnel** (equações exatas para dielétricos e aproximação de Schlick), **lei de Beer-Lambert**,
  **janela de Snell / reflexão interna total** — física óptica clássica.
- **Sequência de Halton** (deslocamento sub-pixel do TAA) — J. H. Halton (1960).
- **Hash `fract(sin(dot(...)))`** e ruído de valor com fBm — técnicas de domínio comum em computação gráfica.

Feito para o mod **Elementar** (Fabric, Minecraft 1.21.1). Requer **Iris** e **Sodium**.
