; =============================================================
; player.inc.asm - Nave del jugador
;
; Controles por defecto: 5 = izquierda, 8 = derecha, 0 = disparo.
; Son las teclas de cursor de Sinclair, asi que el joystick DB9
; del interface funciona sin tocar nada configurandolo con:
;
;     LOAD *JOY "  580"
;
; (arriba / abajo sin asignar, izquierda 5, derecha 8, fuego 0)
; =============================================================

; -------------------------------------------------------------
; plinit - nave centrada y dibujada
; -------------------------------------------------------------
plinit: ld a,PLX0
        ld (plx),a
        jp pldrw

; -------------------------------------------------------------
; plmove - lee el teclado y desplaza la nave 1 px por frame,
;          que es la velocidad del original
; -------------------------------------------------------------
plmove: ld a,(plx)
        ld b,a
        ld a,KR123              ; media fila 1 2 3 4 5
        in a,(KBPORT)
        bit 4,a                 ; tecla 5 = izquierda
        jr nz,plm1
        ld a,b
        cp PLXMIN+1
        jr c,plm1
        dec b
plm1:   ld a,KR098              ; media fila 0 9 8 7 6
        in a,(KBPORT)
        bit 2,a                 ; tecla 8 = derecha
        jr nz,plm2
        ld a,b
        cp PLXMAX
        jr nc,plm2
        inc b
plm2:   ld a,(plx)
        cp b
        ret z                   ; no se ha movido: nada que repintar
        push bc
        call plera
        pop bc
        ld a,b
        ld (plx),a
        jp pldrw

; -------------------------------------------------------------
; plfire - devuelve Z si el disparo esta pulsado
;          TODO: un solo proyectil en vuelo, como en el arcade
; -------------------------------------------------------------
plfire: ld a,KR098
        in a,(KBPORT)
        and 1                   ; tecla 0
        ret

pldrw:  ld hl,plship
        ld a,(plx)
        ld e,a
        ld d,PLY
        ld b,8
        jp sprdrw

plera:  ld hl,plship
        ld a,(plx)
        ld e,a
        ld d,PLY
        ld b,8
        jp sprera

; --- estado del jugador ---
plx:    defb PLX0               ; x de la nave
plliv:  defb 3                  ; vidas (TODO)
