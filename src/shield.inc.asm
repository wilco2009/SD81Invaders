; =============================================================
; shield.inc.asm - Los cuatro escudos
;
; Van colocados a multiplos de 8 px a proposito: asi se dibujan
; con escrituras de byte directas, sin desplazamiento, y el
; blitter general se queda para lo que si se mueve.
;
; La erosion es lo que en modo caracter del ZX81 seria el
; problema dificil y aqui es una linea: borrar un crater con la
; misma rutina AND NOT que usa el enjambre.
; =============================================================

BASX0   equ 32                  ; x del primer escudo
BASSEP  equ 56                  ; separacion entre escudos
BASW    equ 22                  ; ancho real en pixeles
BASH    equ 16                  ; alto
NBASES  equ 4

; -------------------------------------------------------------
; bsdraw - pinta los cuatro escudos
; -------------------------------------------------------------
bsdraw: ld a,BASX0/8
        ld (bscol),a
        ld c,NBASES
bsd0:   push bc
        ld hl,bsspr
        ld (bssrc),hl
        ld d,BASEY
        ld b,BASH
bsd1:   push bc
        push de
        ld a,(bscol)
        ld e,a
        call pixad
        ex de,hl                ; DE = destino
        ld hl,(bssrc)
        ld a,(hl)               ; tres bytes por linea = 24 px
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc hl
        ld (bssrc),hl
        pop de
        pop bc
        inc d
        djnz bsd1
        ld a,(bscol)
        add a,BASSEP/8
        ld (bscol),a
        pop bc
        dec c
        jr nz,bsd0
        ret

; -------------------------------------------------------------
; bserod / bserob - abren un crater en el punto de impacto
;
; El arcade no erosiona con una mancha cualquiera: usa una forma
; fija distinta segun quien dispare, y por eso los destrozos del
; original se reconocen a simple vista. bserod es el del laser del
; jugador y bserob el de una bomba alien.
;
; Los dos NO se colocan igual, porque no llegan igual.
;
; bimy es siempre el pixel mas alto que encontro el sondeo. Para
; el laser, que sube, eso es lo mas hondo que llego a penetrar: si
; ademas se centrara el crater ahi, se comeria cuatro filas por
; encima de donde el disparo llego de verdad. Por eso cuelga del
; punto de impacto hacia abajo, mordiendo el escudo por su borde
; inferior.
;
; La bomba baja y bimy es su primer roce con el borde de arriba,
; asi que ahi si se centra.
;
; La mitad del crater cae fuera del escudo en ambos casos. No
; importa: sprera solo quita pixeles que esten puestos, y lo que
; caiga en el vacio no hace nada.
; -------------------------------------------------------------
; El desplazamiento horizontal del laser tampoco es cosmetico. Su
; primera fila es dispersa ("#...#..#"), asi que si el pixel
; tocado cae en uno de sus huecos NO se borra: el siguiente
; disparo choca contra el mismo pixel, repite el mismo crater y la
; barrera deja de recibir dano. Restando 4 en vez de 3, el pixel
; tocado cae sobre el '#' de la columna 4 y el agujero progresa.
; -------------------------------------------------------------
bserod: ld hl,dmglas            ; impacto del laser del jugador
        ld a,(bimy)
        ld d,a
        ld a,(bimx)
        sub 4
        jr bsero1
bserob: ld hl,dmgbom            ; impacto de una bomba alien
        ld a,(bimy)
        sub 4
        ld d,a
        ld a,(bimx)
        sub 3
bsero1: ld e,a
        ld b,8
        jp sprera

; --- Escudo: 22x16 en celda de 24 px (2 bits de relleno) ---
;
; Extraido de la ROM original de Taito, en $1D20: 44 bytes, dos
; por columna. Fijarse en que el arco NO es simetrico - tiene un
; pixel mas de pared por la derecha - y en que son ocho filas
; macizas, no siete.
bsspr:  defb 00001111b,11111111b,11000000b   ; ....##############....
        defb 00011111b,11111111b,11100000b   ; ...################...
        defb 00111111b,11111111b,11110000b   ; ..##################..
        defb 01111111b,11111111b,11111000b   ; .####################.
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111111b,11111111b,11111100b   ; ######################
        defb 11111110b,00000011b,11111100b   ; #######.......########
        defb 11111100b,00000001b,11111100b   ; ######.........#######
        defb 11111000b,00000000b,11111100b   ; #####...........######
        defb 11111000b,00000000b,11111100b   ; #####...........######

; --- Crateres de erosion, extraidos de la ROM de Taito ---
;
; ShotExploding, $1C91: 99 3C 7E 3D BC 3E 7C 99   (8x8)
; AShotExplo,    $1CDC: 4A 15 BE 3F 5E 25         (6x8)
;
; En la ROM cada byte es una columna con el bit 7 arriba, que es
; el arte del desensamblado girado 90 grados antihorario.
dmglas: defb 10001001b,00000000b   ; #...#..#
        defb 00100010b,00000000b   ; ..#...#.
        defb 01111110b,00000000b   ; .######.
        defb 11111111b,00000000b   ; ########
        defb 11111111b,00000000b   ; ########
        defb 01111110b,00000000b   ; .######.
        defb 00100100b,00000000b   ; ..#..#..
        defb 10010001b,00000000b   ; #..#...#

dmgbom: defb 00100000b,00000000b   ; ..#...
        defb 10001000b,00000000b   ; #...#.
        defb 00110100b,00000000b   ; ..##.#
        defb 01111000b,00000000b   ; .####.
        defb 10111000b,00000000b   ; #.###.
        defb 01111100b,00000000b   ; .#####
        defb 10111000b,00000000b   ; #.###.
        defb 01010100b,00000000b   ; .#.#.#

; --- variables ---
bssrc:  defw 0                  ; puntero de lectura del escudo
bscol:  defb 0                  ; columna en bytes del escudo en curso
