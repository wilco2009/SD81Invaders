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
; El crater se centra en el punto de impacto, de modo que la mitad
; cae fuera del escudo. No importa: sprera solo quita pixeles que
; esten puestos, asi que lo que caiga en el vacio no hace nada.
; -------------------------------------------------------------
bserod: ld hl,dmglas            ; impacto del laser del jugador
        jr bsero1
bserob: ld hl,dmgbom            ; impacto de una bomba alien
bsero1: ld a,(bimx)
        sub 3
        ld e,a
        ld a,(bimy)
        sub 4
        ld d,a
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
