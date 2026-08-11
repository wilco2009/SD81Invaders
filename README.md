# Space Invaders — ZX81 + SD81 Booster

Réplica del arcade de Taito de 1978, escrita desde cero en Z80 para el
[SD81 Booster](../SD81-Booster/README.md).

Estado: **esqueleto funcional**. Vídeo, sincronismo, blitter y marcha del
enjambre están montados y el juego arranca; disparos, escudos, colisiones,
OVNI y sonido son los siguientes pasos.

## Por qué el SD81 Booster

El juego usa el modo **Superfast HiRes Spectrum** del interface, que da un
framebuffer de 256×192 con atributos de color y libera al Z80 del refresco de
pantalla. Sobre esa base:

| Recurso del interface | Uso en el juego |
|---|---|
| Superfast HiRes Spectrum (`POKE 2045,172`) | Bitmap 256×192 en `$8000`, atributos en `$9800` |
| Doble buffer AUTO (`POKE 2057,173`) | Imagen sólida sin parpadeo; front buffer en el bloque 5 |
| Color Chroma81 (`OUT $7FEF`) | Bandas de color que reproducen la lámina del arcade |
| Joystick DB9 programable | Controles sin código específico (ver más abajo) |
| PEG (3 hilos, sin coste de CPU) | Marcha de fondo y efectos — *pendiente* |

Los escudos destructibles, que en modo carácter del ZX81 serían el problema
difícil, aquí son un `AND` de máscara sobre el bitmap.

## Compilar

Requiere [zmac](http://48k.ca/zmac.html). El script lo busca en `C:\zmac\zmac.exe`;
si está en otro sitio, define la variable `ZMAC`.

```bash
build.bat
```

Deja `INVADERS.BIN` en la raíz del proyecto.

## Ejecutar

Copia `INVADERS.BIN` a la microSD (o a la carpeta de SD virtual del emulador
EightyOne-CrossPlatform con emulación SD81) y desde BASIC:

```basic
10 FAST
20 LOAD FAST 'INVADERS.BIN' CODE 30000
30 RAND USR 30000
40 SLOW
```

La línea `10 FAST` **no es opcional**: en `SLOW` el generador de NMI del ZX81
sigue activo, el `DI` del juego no lo puede parar (la NMI es no enmascarable) y
el temporizado del bucle se va al traste. La dirección de carga y la de salto
son la misma, 30000 — el binario es un blob crudo sin cabecera.

Requiere un core FPGA con soporte de `POKE 2057` (doble buffer).

### Controles

| Tecla | Acción |
|-------|--------|
| `5` | Izquierda |
| `8` | Derecha |
| `0` | Disparo |
| `Q` | Salir a BASIC |

Son las teclas de cursor de Sinclair, así que el joystick DB9 funciona sin
tocar el código:

```basic
LOAD *JOY "  580"
```

(arriba y abajo sin asignar; izquierda `5`, derecha `8`, fuego `0`)

## Estructura

```
src/
├── invaders.asm      ← org, arranque, bucle de frame, cabecera de pantalla
├── hw.inc.asm        ← registros y puertos del SD81 Booster, teclado, códigos de carácter
├── layout.inc.asm    ← geometría del campo de juego
├── video.inc.asm     ← modo de vídeo, VSYNC, direccionamiento y blitter
├── text.inc.asm      ← texto con los glifos de la ROM ($1E00)
├── sprites.inc.asm   ← bitmaps del arcade y tablas por fila
├── swarm.inc.asm     ← los 55 aliens: barrido, oleada, rebote y descenso
└── player.inc.asm    ← nave y lectura de controles
```

El binario ocupa unos 1,2 KB y se carga en 30000 (`$7530`), muy por debajo de
`$8000`, donde empieza la pantalla.

## Decisiones de fidelidad

**Un alien por frame.** El arcade movía exactamente un alien por iteración,
recorriendo la formación de abajo-izquierda a arriba-derecha. De ahí salen dos
rasgos del original sin programarlos aparte: el enjambre avanza *en oleada* y no
en bloque, y a medida que mueren aliens el barrido salta las casillas vacías, la
pasada dura menos y la formación **acelera sola**.

**Dos posiciones, no 55.** La formación es una rejilla rígida, así que en vez de
guardar 55 coordenadas se guardan la posición de la pasada actual y la de la
anterior. Los aliens ya barridos usan una y los que faltan la otra; lo mismo con
el fotograma de animación. La oleada sale gratis.

**El giro se aplaza.** Tocar el borde no invierte la marcha en el acto: marca
una bandera que se aplica al cerrar la pasada, como en el original. Solo se
comprueba el borde hacia el que se marcha — comprobando los dos, la pasada de
bajada (que no avanza en horizontal) reencuentra el enjambre pegado al borde
que acaba de tocar y baja indefinidamente sin llegar a cambiar de sentido.

**Borrado por máscara.** `sprera` borra exactamente los píxeles del sprite
(`AND NOT`), no un rectángulo. Con los aliens a 16 px de distancia y el vecino
todavía sin mover, borrar por rectángulo le arrancaría media cabeza.

**Geometría.** El campo mantiene la escala horizontal 1:1 del arcade (224 px,
x 16..239) y comprime el eje vertical a las 192 líneas disponibles conservando
el orden y las proporciones de las bandas.

**Color.** El arcade no tenía color: llevaba una lámina de acetato con franjas.
Eso mapea exactamente a filas de atributos 8×8 — rojo en la banda del OVNI,
verde en la zona de escudos y nave, blanco en el resto — sin *attribute clash*
real, porque no hay solapamiento cromático entre sprites.

## Pendiente

En orden de implementación sugerido:

1. Proyectiles alien: los tres tipos (*rolling*, *plunger*, *squiggly*).
2. Muerte del jugador, vidas y fin de partida.
3. Invasión: los aliens llegan abajo y se acaba la partida.
4. OVNI, con la puntuación según el número de disparos del jugador.
5. Explosión del alien alcanzado (el sprite de estallido, unos frames).
6. Oleadas: al despejar la formación, la siguiente empieza más abajo.
7. Sonido: marcha de fondo de cuatro tonos en un hilo PEG, más disparo y
   explosiones en los otros dos.
8. *Attract mode* y la secuencia de demostración.

## Notas y supuestos

- Los bitmaps de `sprites.inc.asm` están **transcritos a mano** a partir de los
  gráficos del arcade. Se han verificado decodificando el binario ensamblado,
  pero conviene contrastarlos píxel a píxel con un volcado de la ROM de Taito
  antes de dar el juego por terminado.
- El texto usa los glifos de la ROM del ZX81 en `$1E00` como andamiaje. La
  tipografía propia del arcade se puede sustituir en `text.inc.asm` sin tocar
  nada más.
- `zmac` no distingue mayúsculas en los símbolos: cuidado al nombrar equates y
  etiquetas parecidas (`SWSTEP` / `swstep` colisionan).
- El código ensambla limpio y los datos de sprites están verificados, pero
  **todavía no se ha ejecutado en emulador ni en hardware real**.

## Créditos

Space Invaders es obra original de Tomohiro Nishikado para Taito (1978). Esta es
una reimplementación desde cero para ZX81 con SD81 Booster.
"# SD81Invaders" 
