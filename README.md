# Space Invaders — ZX81 + SD81 Booster

Réplica del arcade de Taito de 1978, escrita desde cero en Z80 para el
[SD81 Booster](../SD81-Booster/README.md).

Estado: **juego completo**. Enjambre, disparo, escudos destructibles,
proyectiles alien, vidas, explosiones, oleadas sucesivas, OVNI y sonido por el
PEG. Falta el *attract mode* y afinar los bitmaps contra la ROM original.

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
20 LOAD THEN CLEAR 29999
30 LOAD FAST 'INVADERS.BIN' CODE 30000
40 RAND USR 30000
50 SLOW
```

(el cargador está también en [invaders.b81](invaders.b81))

Dos detalles que no son opcionales:

- **`FAST` antes del `USR`**: en `SLOW` el generador de NMI del ZX81 sigue
  activo, el `DI` del juego no lo puede parar —la NMI es no enmascarable— y el
  temporizado del bucle se va al traste.
- **`CLEAR 29999`** baja RAMTOP por debajo del código para que el BASIC no lo
  pise. Si se cambia el `org`, hay que cambiar el `CLEAR` con él.

La dirección de carga y la de salto son la misma, 30000 — el binario es un blob
crudo sin cabecera, y `start:` es lo primero tras el `org`.

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
├── player.inc.asm    ← nave, controles, vidas y muerte
├── shot.inc.asm      ← disparo del jugador y reparto de impactos
├── shield.inc.asm    ← los cuatro escudos y su erosión
├── bomb.inc.asm      ← proyectiles alien: tres ranuras, tres tipos
├── explode.inc.asm   ← explosiones de alien y de nave
├── ufo.inc.asm       ← nave nodriza y su puntuación
└── sound.inc.asm     ← protocolo con el MCU y efectos PEG
```

El binario ocupa 3651 bytes en `$61A8`–`$6FEB`, con 4117 bytes de margen hasta
`$8000`, donde empieza el bitmap de pantalla. Al agotarlo habrá que bajar el
`org` **y el `CLEAR` del cargador a la vez**: cargar en una dirección código
ensamblado para otra da pantalla negra, porque el primer `call` ya salta a donde
no hay nada.

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
el orden de las bandas.

Esa compresión de 256 a 192 tiene una consecuencia que no es obvia. Los 64 px
que faltan no se pueden quitar de los sprites, ni de los escudos, ni del número
de filas: todos tienen altura mínima fija. Así que se los come entero **el hueco
entre el enjambre y la nave**, justo el espacio que da tiempo de reacción, y el
juego sale bastante más difícil que el original sin que nada lo delate.

La solución es apretar las filas del enjambre: con `SWDY` a 12 px en vez de 16,
la formación ocupa 56 px en lugar de 72 y esos 16 px vuelven al hueco.

| | Con `SWDY`=16 | Con `SWDY`=12 | Arcade |
|---|---|---|---|
| Hueco hasta escudos | 32 px (17%) | 48 px (25%) | ~25% |
| Hueco hasta la nave | 56 px (29%) | 72 px (38%) | ~34% |
| Bajadas hasta invasión | 7 | 9 | |

**Velocidad de los proyectiles.** A 4 px por frame una bomba cubría el hueco en
0,28 s. El arcade daba cerca de un segundo. Con `BMSPD` a 2 y el hueco ya
recuperado son 0,72 s, en el orden del original.

**Color.** El arcade no tenía color: llevaba una lámina de acetato con franjas.
Eso mapea exactamente a filas de atributos 8×8 — rojo en la banda del OVNI,
verde en la zona de escudos y nave, blanco en el resto — sin *attribute clash*
real, porque no hay solapamiento cromático entre sprites.

**La marcha acelera sola.** El tempo de los cuatro tonos graves sale del número
de aliens vivos, no de un temporizador: la música corre más porque queda menos
formación. Es el mismo mecanismo que hace acelerar al enjambre.

**El OVNI no vale lo que parece.** El arcade llevaba la cuenta de los disparos
del jugador y consultaba con ella una tabla de 15 entradas, así que la
puntuación parecía aleatoria pero era perfectamente predecible — de ahí la
técnica conocida de contar disparos para cazar el OVNI de 300 puntos. La tabla
está reproducida en `ufo.inc.asm`.

## Sonido

El interface tiene **tres generadores independientes**: dos chips AY por
hardware (compatibles ZonX-81) y el PEG, que es un tercer AY sintetizado dentro
del MCU. No comparten registros, así que se pueden usar a la vez sin pisarse.

| Generador | Canal | Registros | Uso |
|---|---|---|---|
| AY chip A (`$DF`/`$1F`) | A, tono | `R0`/`R1`, `R8` | Marcha de fondo |
| PEG hilo 0 | A, tono | `R0`/`R1`, `R8` | Disparo del jugador |
| PEG hilo 1 | B, tono | `R2`/`R3`, `R9` | OVNI |
| PEG hilo 2 | C, ruido | `R6`, `R10` | Explosiones |

**Los tres hilos del PEG comparten un solo AY**, así que cada uno tiene su
canal. Es obligatorio y no una elección estética: `R7` (habilitación) es un
registro *único* para los tres canales, de modo que un efecto que lo apagara al
terminar callaría también a los otros dos. Cada efecto lo deja en `PEGMIX`
(`$1C` — tono A, tono B, ruido C) al empezar, operación idempotente que da igual
quién ejecute primero, y al acabar pone a cero **solo su propia amplitud**.

Y un detalle que muerde: **`STOP_PEG` detiene el programa pero no toca los
registros del AY**. Si se corta un efecto continuo a media ejecución, su nota se
queda sonando fija para siempre. Por eso al retirar el OVNI hay que lanzarle
encima un pequeño programa silenciador en vez de solo pararlo.

**La marcha va al AY hardware y no al PEG**, y el reparto no es arbitrario: son
cuatro tonos fijos, sin envolvente ni ruido, con el ritmo marcado desde el bucle
de frame — justo lo que no necesita una máquina virtual. Dejarla ahí libera los
tres hilos del PEG para los efectos, que sí son barridos y fundidos, y con ello
disparo y OVNI dejan de cortarse.

Un efecto PEG, una vez lanzado, **no consume ni un ciclo del Z80**: se envían
tres bytes al MCU y suena solo. Los programas se vuelcan una única vez al
arrancar.

Las variables del PEG (`V0`–`V15`) son comunes a los tres hilos, así que cada
efecto usa las suyas —láser `V0`–`V1`, explosiones `V4`–`V5`, OVNI `V2`—; si se
compartieran, dos efectos simultáneos se estropearían mutuamente.

En los puertos AY, `A7` hace de línea BC1 (1 = seleccionar registro, 0 = escribir
dato) y `A3` elige chip (1 = A, 0 = B). Los periodos de los cuatro tonos están
calculados para un reloj de AY de ~1,625 MHz y salen en 147 / 139 / 131 / 123 Hz;
si suenan altos o bajos, se ajustan en la tabla `mchton` de `sound.inc.asm`.

## Pendiente

- *Attract mode* y la secuencia de demostración.
- Mostrar la puntuación del OVNI en el sitio donde se le derriba.
- Contrastar todos los bitmaps con un volcado de la ROM de Taito.
- Ajustar los periodos AY de la marcha al reloj real del interface.

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

