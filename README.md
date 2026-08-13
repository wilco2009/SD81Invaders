# Space Invaders — ZX81 + SD81 Booster

Réplica del arcade de Taito de 1978, escrita desde cero en Z80 para el interface
SD81 Booster.

Estado: **completo y probado en hardware real**. Modo de atracción con la broma
de la Y, la `SCORE ADVANCE TABLE` y la máquina jugando sola; enjambre, disparo,
escudos destructibles, proyectiles alien con las tres estrategias del original,
uno o dos jugadores por turnos, vidas, nave extra a los 1500, explosiones,
oleadas sucesivas que arrancan más abajo, dificultad creciente con la
puntuación, OVNI con su puntuación y su lado de entrada predecibles, y sonido.

Todos los gráficos y las tablas de comportamiento salen de la ROM original de
Taito, contrastados contra el desensamblado anotado de
[Computer Archeology](https://computerarcheology.com/Arcade/SpaceInvaders/).

Dos cosas se apartan del original a propósito, y las dos son añadidos: el récord
sobrevive en la SD, y se puede guardar y recuperar la partida.

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
| PEG (3 hilos, sin coste de CPU) | Efectos: disparo, OVNI, explosiones y nave extra |
| AY hardware ZonX-81 (`$DF`/`$1F`) | Marcha de fondo de cuatro tonos |
| Tarjeta SD (comandos `LOAD`/`SAVE` del MCU) | Récord y partida guardada |

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
20 LOAD THEN CLEAR 24999
30 LOAD FAST "INVADERS.BIN" CODE 25000
40 RAND USR 25000
50 SLOW
```

(el cargador está también en [invaders.b81](invaders.b81))

Dos detalles que no son opcionales:

- **`FAST` antes del `USR`**: en `SLOW` el generador de NMI del ZX81 sigue
  activo, el `DI` del juego no lo puede parar —la NMI es no enmascarable— y el
  temporizado del bucle se va al traste.
- **`CLEAR 24999`** baja RAMTOP por debajo del código para que el BASIC no lo
  pise. Si se cambia el `org`, hay que cambiar el `CLEAR` con él.

La dirección de carga y la de salto son la misma, 25000 — el binario es un blob
crudo sin cabecera, y `start:` es lo primero tras el `org`.

Requiere un core FPGA con soporte de `POKE 2057` (doble buffer).

### Controles

| Tecla | Acción |
|-------|--------|
| `1` / `2` | Empezar partida de uno o dos jugadores (desde la atracción) |
| `5` | Izquierda |
| `8` | Derecha |
| `0` | Disparo |
| `S` | Guardar la partida en la SD |
| `L` | Recuperarla (en juego o desde la atracción) |
| `Q` | Salir a BASIC |

## Dos jugadores

Como en el arcade, los dos jugadores **no comparten partida: alternan**. Cada uno
tiene su marcador, sus vidas, su formación y sus escudos, y el turno pasa al otro
cada vez que uno pierde una nave. Cuando a uno se le acaban, el otro sigue solo.

Eso obliga a guardar y restaurar el estado entero al cambiar de turno, **incluido
el mapa de bits de los escudos**: cada jugador los tiene erosionados a su manera
y no valdría repintarlos enteros. El arcade hacía exactamente esto — en su
desensamblado están las rutinas `RememberShields` y `RestoreShields`.

El bloque del enjambre está declarado contiguo a propósito (`swx`…`swaliv`, 68
bytes) para poder salvarlo de un solo `LDIR`. Son 486 bytes por jugador: 68 del
enjambre, 2 de nave y vidas, 384 de escudos y 32 de la línea del suelo.

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
├── players.inc.asm   ← uno o dos jugadores por turnos, marcadores y nave extra
├── shot.inc.asm      ← disparo del jugador y reparto de impactos
├── shield.inc.asm    ← los cuatro escudos y su erosión
├── bomb.inc.asm      ← proyectiles alien: tres ranuras, tres estrategias
├── explode.inc.asm   ← explosiones de alien y de nave
├── ufo.inc.asm       ← nave nodriza, su puntuación y su lado de entrada
├── sound.inc.asm     ← marcha en el AY, protocolo MCU y efectos PEG
├── attract.inc.asm   ← título, la broma de la Y y SCORE ADVANCE TABLE
├── demo.inc.asm      ← la IA que juega sola en la atracción
├── hiscore.inc.asm   ← el récord, en un fichero de la SD
└── savegame.inc.asm  ← guardar y recuperar la partida
```

El ciclo de la máquina es **atracción → demo → partida → atracción**, y las tres
fases hablan el mismo idioma en `A`: 0 si nadie pulsó nada, 1 o 2 para empezar
partida con ese número de jugadores, 3 para salir a BASIC y 4 para recuperar una
partida de la SD.

La demo **no tiene bucle propio**: corre el mismo `gmloop` de la partida real
con `demoon` a 1, y son `plmove` y `shfire` los que dejan de leer el teclado y
preguntan a la IA. Así no puede desincronizarse del juego, porque *es* el juego.
La IA se coloca bajo el alien vivo más bajo y dispara en cuanto tiene el cañón
libre; no esquiva bombas, o sea que acaba muriendo — que es exactamente lo que
hacía la demo del arcade.

En el modo de atracción, el título sale con la **Y de PLAY del revés**: un
calamar entra por la derecha por la línea del rótulo, se planta junto a la Y
ofensiva, da media vuelta y se la lleva a rastras por donde vino; vuelve a
salir con ella ya del derecho, la deja en su sitio y se esfuma. Estaba ya en el
original del 78 y es el primer *attract mode* de la historia con sentido del
humor.

No hace falta borrar ni repintar la Y del rótulo en los relevos: el calamar la
lleva en `x-8`, que en los extremos de cada tramo cae clavado en su sitio. La Y
que arrastra es literalmente la que estaba escrita.

Hasta que hubo modo de atracción no existía un "empezar partida nueva": el
binario se cargaba, se jugaba una vez y se salía, así que el estado inicial venía
en los propios datos. Ahora `newgam` devuelve a su sitio la oleada, la altura de
salida del enjambre, las vidas y los marcadores — sin eso, la segunda partida
empezaría donde acabó la primera.

El binario ocupa 6357 bytes en `$61A8`–`$7A7C`, con 1411 bytes de margen hasta
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

**El OVNI no vale lo que parece, y tampoco sale por donde parece.** El arcade
llevaba la cuenta de los disparos del jugador y consultaba con ella una tabla de
15 entradas, así que la puntuación parecía aleatoria pero era perfectamente
predecible — de ahí la técnica conocida de contar disparos para cazar el OVNI de
300 puntos. El lado de entrada sale del **bit 0** de un contador de disparos
distinto: impar entra por la izquierda, par por la derecha. Hacen falta los dos
contadores, porque 15 es impar y compartir uno solo se saltaría un cambio de
lado en cada vuelta.

Los disparos se cuentan **al desaparecer el proyectil, no al dispararlo**, y da
igual cómo desaparezca: reventando contra un alien, mordiendo un escudo,
derribado por una bomba o estrellándose contra el techo del campo.

**La dificultad sube con el marcador, y solo con eso.** El arcade consultaba una
tabla de cinco valores con el byte alto de la puntuación, que al ser BCD son
directamente los millares y las centenas:

| Puntuación | Frames de recarga |
|---|---|
| hasta 199 | 48 |
| hasta 999 | 16 |
| hasta 1999 | 11 |
| hasta 2999 | 8 |
| 3000 en adelante | 7 |

De un extremo al otro hay casi siete veces más fuego alien. No cambia nada más:
los aliens no se mueven más rápido por ir la partida avanzada, es que disparan
mucho más. Cuenta la puntuación del jugador de turno, así que a dos jugadores
cada uno arrastra su propia dificultad.

**Las tres bombas no son la misma con otro dibujo.** Lo que las distingue en el
original es cómo eligen columna, y el tipo va pegado a la ranura — las tres que
puede haber en vuelo son siempre una de cada clase:

| Proyectil | Cómo elige columna |
|---|---|
| Rolling | La que tiene encima al jugador |
| Plunger | Índices 00–0F de la tabla de columnas |
| Squiggly | Índices 06–14 de la **misma** tabla |

La tabla es la del arcade, copiada de `$1D00`: una sola de 21 entradas con los
dos tramos solapados y de largos 16 y 15, primos entre sí, así que el patrón
conjunto no se repite hasta 240 disparos. Numera las columnas de 1 a 11 y no es
uniforme — la columna 1 sale siete veces de dieciséis en el tramo del plunger.

Ninguno de los tres busca una columna alternativa: si la que le toca está ya
barrida, **ese tiro no sale**. Es lo que hace el original, y es también lo que
permite comprarse un respiro despejando la columna que tienes encima. El plunger
además calla cuando queda un solo alien.

**La nave extra a los 1500.** En el arcade era una opción de fábrica —1000 o
1500 puntos, y de serie venía a 1500— y se da una sola vez por jugador. No hace
falta anotar a quién ya le tocó: el marcador nunca baja, así que haber pasado de
1500 es exactamente lo mismo que valer 1500 o más. Por eso sobrevive solo al
cambio de turno y a recuperar una partida de la SD.

**La invasión se mide con quien queda vivo.** El fin de partida por invasión no
mira dónde estaría la fila de abajo, sino dónde está la fila viva más baja. Con
la formación entera son lo mismo; con un solo alien superviviente en la fila de
arriba, no.

## Sonido

El interface tiene **tres generadores independientes**: dos chips AY por
hardware (compatibles ZonX-81) y el PEG, que es un tercer AY sintetizado dentro
del MCU. No comparten registros, así que se pueden usar a la vez sin pisarse.

| Generador | Canal | Registros | Uso |
|---|---|---|---|
| AY chip A (`$DF`/`$1F`) | A, tono | `R0`/`R1`, `R8` | Marcha de fondo |
| PEG hilo 0 | A, tono | `R0`/`R1`, `R8` | Disparo del jugador y nave extra |
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

## Puntuación máxima

Lo único que se aparta del original a propósito: en el arcade el récord moría al
apagar la máquina, y aquí sobrevive en un fichero `HISCORE.HI` de dos bytes en
el mismo directorio del juego. Se lee al arrancar y solo se escribe cuando el
récord cambia de verdad, no una vez por partida.

La extensión no es decorativa y **no puede omitirse**: un nombre sin ella se
trata como `.P`, o sea como un programa BASIC, y los dos bytes no sobrevivirían
al viaje. Tampoco vale cualquiera — `.ROM` carga en la dirección 0 y resetea la
máquina, y `.WAV` se reproduce. `.HI` no significa nada para el MCU, que es
justo lo que se busca: que devuelva los bytes tal cual.

El nombre viaja en **códigos ZX81, no en ASCII**, aunque al otro lado haya una
FAT32. Lo pide así el firmware, que al recibirlo lo pasa por su tabla
`asc81_to_ascii` antes de tocar la tarjeta (ver `cmd_save` y `cmd_load` en
`COMMANDS.cpp` del interface). Mandarlo ya en ASCII lo hace atravesar esa tabla
una segunda vez y llegar convertido en cualquier cosa.

## Guardar la partida

`S` guarda y `L` recupera, en un fichero `INVADERS.SG` de 488 bytes. `L`
funciona también desde la atracción, que es lo natural al encender la máquina.

Se guarda **solo al jugador en curso**, así que una partida recuperada se reanuda
siempre como de un jugador: salvar los dos con sus dos formaciones y sus dos
juegos de escudos serían unos 1400 bytes y no compensa.

| Bloque | Bytes |
|---|---|
| Enjambre (posiciones, oleada y `swaliv`) | 68 |
| Nave y vidas | 2 |
| Marcador | 2 |
| Escudos, tal y como estén erosionados | 384 |
| Línea del suelo, con sus muescas | 32 |

La línea del suelo va aparte porque se erosiona con las bombas y no forma parte
de ninguna ranura de jugador. Los proyectiles, el OVNI y las explosiones no se
guardan: al recuperar se ponen a cero.

**Nada se escribe en pantalla hasta haber validado la longitud**, de modo que un
fichero que no existe o que no cuadra deja la partida como estaba. La respuesta
se consume entera igualmente, porque dejar bytes sin recoger descuadraría al MCU
para todo lo que viniera después.

## Pendiente

Del repaso contra el desensamblado quedan tres cosas, todas menores y decididas
a conciencia:

- **Los bitmaps de las tres bombas están dibujados a ojo.** La mecánica es la del
  arcade y las tablas también, pero los píxeles exactos siguen sin contrastar
  contra la ROM. Es lo único del juego que no sale de ella.
- **Las bombas no aceleran** al quedar 8 aliens o menos (el arcade pasa de 4 a 5
  px por paso). Aquí van a 2 px por frame constantes.
- **No hay pausa de dos segundos al empezar la partida.** Tras morir sí la hay.

Y dos diferencias estructurales que no son descuidos:

- La recarga es un contador **por ranura**; el arcade compara contra los pasos de
  los otros dos disparos, o sea que su cadencia es global.
- Las alturas de salida por oleada bajan 8 px linealmente cinco veces. El arcade
  usa una tabla (`$78`, `$50`, `$48`, `$48`, `$40`…) que no es portable tal cual
  con el eje vertical comprimido a 192 líneas.

Refinamientos posibles:

- La IA de la demo no esquiva bombas: se limita a perseguir y disparar.
- El destello del alien alcanzado es un solo fotograma fijo; podría animarse.
- La explosión del OVNI reutiliza el destello del alien en vez de tener el suyo.

## Notas y supuestos

- Los bitmaps de `sprites.inc.asm` y el escudo están **extraídos de la ROM
  original de Taito** (romset MAME `invaders`) y verificados píxel a píxel
  contra ella. El vídeo del arcade va girado 90°, así que en la ROM cada byte
  es una columna de 8 píxeles con el bit 7 arriba; aquí se guardan por filas.
  Direcciones: `$1C00` pulpo A, `$1C30` pulpo B, `$1C10` cangrejo A, `$1C40`
  cangrejo B, `$1C20` calamar A, `$1C50` calamar B, `$1C60` nave, `$1D68` OVNI
  y `$1D20` escudo.
- Los cráteres de las barreras también salen de la ROM: `ShotExploding` en
  `$1C91` (8×8) para el láser del jugador y `AShotExplo` en `$1CDC` (6×8) para
  las bombas alien. **Son dos formas fijas distintas según quién dispare**, y
  por eso los destrozos del original se reconocen a simple vista.
- El texto usa los glifos de la ROM del ZX81 en `$1E00` como andamiaje. La
  tipografía propia del arcade se puede sustituir en `text.inc.asm` sin tocar
  nada más.
- Las tablas de comportamiento —puntuación del OVNI, columnas de fuego, recarga
  por puntuación— están copiadas del desensamblado anotado de Computer
  Archeology, con la dirección original anotada en el fuente.
- `zmac` no distingue mayúsculas en los símbolos: cuidado al nombrar equates y
  etiquetas parecidas (`SWSTEP` / `swstep` colisionan, y también `BONUS` /
  `bonus`). Tampoco admite literales binarios con `%`; hay que usar el sufijo
  `b`.
- Probado en el emulador EightyOne con emulación SD81 y en hardware real.

## Créditos

Space Invaders es obra original de Tomohiro Nishikado para Taito (1978). Esta es
una reimplementación desde cero para ZX81 con SD81 Booster.

