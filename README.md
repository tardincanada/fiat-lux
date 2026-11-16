# Fiat Lux

Shaderpack para **Iris** (Minecraft 1.21.1, Fabric), feito para o mod **Elementar**, mas funciona em qualquer mundo.
Licença MIT (ver `LICENSE`). Créditos de técnicas em `CREDITS.md`.

## Requisitos
- Minecraft 1.21.1, Fabric, **Iris 1.8 ou mais novo** e **Sodium 0.6**.
- OpenGL 3.3. A **luz colorida** precisa de OpenGL 4.3 (imagens + compute shaders); em Mac e placas
  sem suporte o pack abre normalmente e só a luz colorida fica desligada.
- Testado em NVIDIA (RTX 4080). AMD e Intel ainda não foram testadas.

## Recursos
- **Iluminação:** sombras do sol e da lua (inclusive coloridas por vidro), luz ambiente que segue a cor do céu,
  luz de blocos com tremulação, bloom.
- **Luz colorida por lâmpada** (Elementar): sódio de baixa pressão que apaga as cores, LED, carbureto, trítio,
  arco elétrico tremeluzente etc.
- **Água** por líquido e por bioma (doce, salgada, salmoura; turquesa glacial, barrenta, de pântano, oceanos
  quentes/temperados/frios), absorção realista pela profundidade, ondas, reflexo, **refração** e
  **janela de Snell** vista de baixo. Fica dessaturada e mais escura na chuva e na neve.
- **Céu por bioma** (vivo, nebuloso, nublado), **três camadas de nuvens** que se afastam na chuva, cirros,
  céu de grande altitude, perspectiva atmosférica, crepúsculo e estrelas no horário certo.
- **Chuva e neve realistas** (traços finos, flocos lentos, sem bordas), neblina mais densa na neve.
- **Folhas e plantas ao vento**, mais fortes na tempestade.
- **Radiação de Cherenkov** em blocos e itens radioativos do Elementar.
- **A Lua do Elementar** (`periodic_elements:moon`): sem atmosfera, céu preto com as estrelas, o Sol e a
  Terra que o mod desenha, sem névoa, nuvens nem chuva, sol branco e forte, sombras quase pretas e um
  luar azulado fraco vindo da Terra.
- **Marte do Elementar** (`periodic_elements:mars`): céu cor de caramelo de dia e azul em volta do Sol no pôr do sol
  (o céu do mod passa direto), névoa de poeira caramelo mais longe que na Terra, sol mais fraco e quente, sombras
  macias, sem nuvens nem chuva, e tempestades de poeira com névoa marrom e grossa.
- **Mercúrio do Elementar** (`periodic_elements:mercury`): sem ar como a Lua, sol branco muito forte que segue a
  linha da aurora do mod (rasante perto dela, a pino no lado do dia, noite do outro lado).
- **Vênus do Elementar** (`periodic_elements:venus`): céu amarelo-esbranquiçado, névoa amarelada leve, sol forte e
  difuso, sombras macias, luz amarelada das nuvens vinda de baixo, e as nuvens de ácido (blocos) como vidro fosco,
  com névoa grossa quando a câmera está dentro delas.
- **Brilho próprio do Elementar:** plasma rosa-violeta do Tokamak, verde de aurora do Escudo Magnético e branco-azulado
  do Reator de Aniquilação (os três também iluminam o lugar), meteoro em brasa e as partes de cor de chama do foguete.
- **Anti-aliasing:** FXAA ou TAA. Perfis BAIXO / MÉDIO / ALTO e opções para desligar o que pesa.

## Instalar
Coloque `FiatLux.zip` em `.minecraft/shaderpacks` e escolha no menu de shaders do Iris.

## Integração com o Elementar (id interno periodic_elements)
Já configurado em `shaders/block.properties` e `shaders/item.properties`, seguindo o `radiation.json` do mod:
- **Cherenkov no ar (10100):** reator nuclear, acelerador de íons pesados e cíclotron quando `lit=true`;
  itens acima de 0,1 Sv/h (rádio, radônio, califórnio, combustível gasto, rejeito de alta atividade...).
- **Cherenkov só na água (10101):** os 4 minérios de pechblenda e o gerador de radioisótopo; itens entre
  0,0001 e 0,1 Sv/h (amerício, polônio, pechblenda bruta...). Brilham quando vistos através da água ou submerso.
- **Luz própria (10000):** as 80 máquinas com `lit=true`, tritium_light, tallow_candle e gamma_garden.
  Só as partes quentes/claras da textura brilham.
- O halo de Cherenkov que o mod desenha (`CherenkovRenderer`) passa pelo `gbuffers_basic` e vira luz
  própria com bloom, em vez de ser reiluminado pelo shader.
Ao adicionar blocos ao mod, inclua os IDs novos nesses arquivos.

## Estrutura
- `gbuffers_*` → desenham a cena; opacos gravam o G-buffer, transparentes se iluminam sozinhos.
- `shadow` → mapa de sombras.  `deferred` → ilumina os opacos.
- `composite` → água, neblina, nuvens, chuva/neve.  `composite1/2` → bloom.  `composite3` → TAA.
  `composite4` → tonemap.  `final` → FXAA ou nitidez.  `shadowcomp` → espalha a luz colorida.
- `lib/settings.glsl` → todas as opções.
- `program/` → corpo dos programas grandes (a raiz e `moon/` só incluem).
- `moon/`, `mars/`, `mercury/` e `venus/` → os mesmos programas com `#define DIM_MOON` / `DIM_MARS` /
  `DIM_MERCURY` (+ `DIM_MOON`) / `DIM_VENUS`, usados em cada dimensão (`dimension.properties`).
  Gerada por `python3 tools/gen_dims.py shaders`; rode de novo ao criar um programa novo.

## Luz colorida
Cada lâmpada ilumina com sua cor: sódio de baixa pressão (âmbar, apaga as cores), LED (branco frio),
carbureto, trítio, fogo das almas, redstone etc. IDs 10200–10299 em `block.properties`/`item.properties`,
cores em `lightSourceColor()` (lib/common.glsl). Em PCs fracos: perfil BAIXO, ou desligue
"Luz colorida no ambiente", ou use alcance 64.

Os blocos e itens de luz do mod vêm do `lights.json` do Elementar. Para atualizar:
`python3 tools/gen_lights.py <lights.json> FiatLux/shaders` (reescreve a seção gerada de
block.properties/item.properties e lib/light_overrides.glsl). Tipo novo: acrescente em KIND_ID
(tools/gen_lights.py) e em lightSourceColor() (lib/common.glsl).
