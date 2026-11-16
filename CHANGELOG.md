# Fiat Lux 1.0.0-beta.4

- The Moon (Elementar 3.64, dimension `periodic_elements:moon`) has its own programs: no air, so the sky is black even by day, with the stars, Sun and Earth drawn by the mod; no sky scattering, distance fog, clouds, rain or snow. The Sun is white and strong, shadows are sharp and almost black, and a faint bluish earthshine comes from the Earth in the northern sky. New "Elementar" screen with Moon sunlight, shadow fill and earthshine sliders.
- Fusion plasma: a lit Tokamak (`vacuum_vessel` and `tokamak` with `lit=true`) glows pink-violet (Balmer lines) and lights its surroundings with that colour. New "Fusion plasma glow" slider.
- Elementar meteors glow yellowish white, and the flame-coloured parts of a flying rocket glow orange. New sliders.
- Elementar's life support panel lights up like other machine indicator lamps.

# Fiat Lux 1.0.0-beta.3

- Ice: water under ice no longer shows waves, and the ice surface has subtle frost and cracks, seen in its faint reflection and sun glint. New "Ice surface texture" slider.
- In rain the sky and distance fog are darker, so far hills no longer look whiter than the clouds; ambient light is unchanged. New "Rain sky and fog brightness" slider.
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
