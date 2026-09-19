# VENDOR/sdl3 — enlaces Pascal de SDL3

Copia de los enlaces de
[PascalGameDevelopment/SDL3-for-Pascal](https://github.com/PascalGameDevelopment/SDL3-for-Pascal)
para el plugin Wayland (tarea T7.1 de `WAYLAND.md`).

| Dato | Valor |
|------|-------|
| Etiqueta de los enlaces | `v0.6` (commit `8e9795000d3d`, 2026-05-05) |
| Versión de SDL3 que declaran | **3.4.4** (`SDL_version.inc`) |
| Fecha de la copia | 2026-09-19 |
| Licencia | zlib (`LICENSE.md`, copiada tal cual) |

Solo se copia lo que necesita la unidad `SDL3`: `SDL3.pas`, sus `SDL_*.inc`,
`ctypes.inc`, `jedi.inc` y `sdl.inc`. Quedan fuera `SDL3_image`, `SDL3_ttf`,
`SDL3_mixer`, `SDL3_gfx` y `SDL3_textengine`: VPA no los usa.

Los ficheros son ajenos: no se les aplica la regla de «fuentes ASCII» del
proyecto (tres `.inc` traen caracteres UTF-8 en comentarios) ni se reformatean.
Toda modificación local se marca en el propio fichero, como exige la licencia
zlib, y se lista aquí debajo.

## Modificaciones locales

Ninguna.

## Versión de SDL3 objetivo (riesgo R10)

La versión objetivo del plugin es **SDL 3.4.x**, y la mínima es la **3.4.4**
que declaran los enlaces. Dentro de una misma serie menor SDL mantiene la ABI,
así que un `libSDL3.so.0` 3.4.x más nuevo es válido; uno más viejo no. El
plugin debe comprobarlo al inicializar comparando `SDL_GetVersion` con
`SDL_VERSION` y negarse a arrancar con una SDL más vieja que sus enlaces.
