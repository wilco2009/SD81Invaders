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
; bserod - abre un crater en el punto de impacto (bimx,bimy)
; -------------------------------------------------------------
bserod: ld a,(bimx)
        dec a
        ld e,a
        ld a,(bimy)
        dec a
        ld d,a
        ld hl,crater
        ld b,4
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

; --- Crater de erosion: 4x4 en celda de 16 px ---
crater: defb 01100000b,00000000b
        defb 11110000b,00000000b
        defb 11110000b,00000000b
        defb 01100000b,00000000b

; --- variables ---
bssrc:  defw 0                  ; puntero de lectura del escudo
bscol:  defb 0                  ; columna en bytes del escudo en curso
