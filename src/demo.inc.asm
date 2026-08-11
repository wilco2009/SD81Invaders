; =============================================================
; demo.inc.asm - La maquina jugando sola
;
; En el modo de atraccion, tras el titulo y la tabla, la maquina
; juega una partida ella misma.
;
; No hay un bucle de demo aparte: corre el mismo gmloop de
; siempre con demoon a 1, y son plmove y shfire los que, en vez
; de leer el teclado, preguntan a la IA. Asi la demo no puede
; desincronizarse del juego, porque es el juego.
;
; La IA es deliberadamente simple: se pone debajo del alien vivo
; mas bajo y dispara en cuanto tiene el cañon libre. No esquiva
; bombas, o sea que acaba muriendo - que es exactamente lo que
; hacia la demo del arcade.
; =============================================================

DEMTIME equ 1500                ; tope de la demo (~30 s)

; -------------------------------------------------------------
; demrun - una partida jugada por la maquina
;          Devuelve como attwt: 0 termino, 1 jugar, 2 salir
; -------------------------------------------------------------
demrun: ld a,1
        ld (demoon),a
        ld hl,DEMTIME
        ld (demtim),hl
        call newgam
        call gmloop
        push af
        xor a
        ld (demoon),a
        pop af
        ret

; -------------------------------------------------------------
; demtgt - objetivo de la IA: el alien vivo mas bajo
;          NZ si lo hay, con su posicion en cax/cay
;
; swaliv va indexado rango*11+columna con el rango 0 abajo, asi
; que el primero que aparece recorriendo el array de frente es ya
; el mas bajo de todos. No hay que buscar ningun minimo.
; -------------------------------------------------------------
demtgt: xor a
        ld (cidx),a
        ld (ccol),a
        ld (crank),a
        ld hl,swaliv
        ld b,SWNUM
dtg1:   ld a,(hl)
        or a
        jr nz,dtg2
        inc hl
        call dnexti
        djnz dtg1
        xor a
        ret                     ; no queda ninguno
dtg2:   call salpos
        ld a,1
        or a
        ret

; dnexti - avanza cidx/ccol/crank una casilla
dnexti: ld hl,cidx
        inc (hl)
        ld a,(ccol)
        inc a
        cp SWCOLS
        jr c,dnx1
        xor a
        ld (ccol),a
        ld hl,crank
        inc (hl)
        ret
dnx1:   ld (ccol),a
        ret

; --- estado ---
demoon: defb 0                  ; 1 = esta jugando la maquina
demtim: defw 0                  ; frames que le quedan a la demo
