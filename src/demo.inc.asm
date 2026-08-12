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
DEMTOL  equ 2                   ; margen de punteria, en pixeles
;
; Ese margen es lo que impide que la IA malgaste el cañon. Sin el,
; disparaba en cuanto tenia via libre, aunque estuviera viajando
; hacia el objetivo siguiente: mataba al de abajo de una columna,
; el objetivo saltaba a la columna de al lado, y el disparo que ya
; salia se llevaba al que estaba encima. De ahi que vaciara
; columnas enteras y luego pareciera disparar a la nada.

; -------------------------------------------------------------
; demrun - una partida jugada por la maquina
;          Devuelve como attwt: 0 termino, 1 jugar, 2 salir
; -------------------------------------------------------------
demrun: ld a,1
        ld (demoon),a
        ld (nplay),a            ; la maquina juega sola, sin turnos
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

; -------------------------------------------------------------
; demclr - Z si la vertical sobre la nave esta libre de escudo
;
; Sin esto la IA se pasa la partida disparandole a su propio
; escudo: abre un tunel a fuerza de impactos, mata unos cuantos
; aliens a traves de el, y en cuanto el objetivo se desplaza y
; ella con el, vuelve a tener pared delante y no acierta ni una.
; Visto de fuera parece que ande buscando el hueco - y es que
; literalmente lo esta buscando.
; -------------------------------------------------------------
demclr: ld a,(plx)
        add a,PLW/2             ; por donde saldra el disparo
        ld e,a
        ld d,BASEY
        ld b,BASH
dcl1:   push bc
        push de
        call pixtst
        pop de
        pop bc
        ret nz                  ; hay pared: no disparar
        inc d
        djnz dcl1
        xor a
        ret                     ; via libre

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
demlin: defb 0                  ; 1 = encarada al objetivo
demtim: defw 0                  ; frames que le quedan a la demo
