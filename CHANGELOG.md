# Fiat Lux 1.0.0-beta.3

- Fixed distant tree tops flickering: shadow bias now follows the shadow texel size, leaves are offset toward the light, and wind fades out beyond ~60 blocks.
- Thunderstorms are darker than plain rain: the top of the sky darkens most and a lighter band stays near the horizon; ambient light drops with it. New "Storm darkness" slider.
- Slimes look like a cell: the outer layer is a translucent membrane (thin in front, denser at the edges) with the core, eyes and mouth visible inside, and it casts only a faint shadow. New "Creatures" screen with an on/off switch and a membrane opacity slider. Works with any anti-aliasing.

# Fiat Lux 1.0.0-beta.2

- Rain, snow and thunderstorms now block direct sunlight and moonlight: no sun shadows, no sun/moon discs or halo, and no sun or moon reflections on water while the sky is overcast.
- Less fog in jungles (new, lighter jungle fog; option "Jungle fog" under Sky).
- Menu fully translated: English and Portuguese, with a tooltip on every option.

# Fiat Lux 1.0.0-beta.1

First public release (beta). Iris shaderpack for Minecraft 1.21.1, made for the Elementar mod but works in any world.
Requires Iris 1.8+ and Sodium 0.6. Coloured light needs OpenGL 4.3. Tested on NVIDIA; AMD and Intel not yet tested.

- Sun and moon shadows (coloured through glass), sky-tinted ambient light, flickering block light, bloom.
- Per-lamp coloured light for Elementar lamps (low-pressure sodium, LED, carbide, tritium, electric arc).
- Water by liquid and biome, depth absorption, waves, reflection, refraction and Snell's window.
- Biome skies, three cloud layers, realistic rain and snow, foliage in the wind.
- Cherenkov glow on Elementar's radioactive blocks and items.
- FXAA or TAA; LOW / MEDIUM / HIGH profiles.
