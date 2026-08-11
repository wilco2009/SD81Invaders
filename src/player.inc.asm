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
        ld a,PLLIV0
        ld (plliv),a
        call drwliv
        jp pldrw

; -------------------------------------------------------------
; pldead - una bomba ha alcanzado la nave
;
; Se limpian disparo y bombas para que el jugador no reaparezca
; debajo de un proyectil que ya venia en camino.
; -------------------------------------------------------------
pldead: call plera
        call shclr
        call bmclr
        call blclra
        call mchoff             ; la marcha calla mientras dura la pausa
        call sndexp
        call pxplod             ; la partida se para mientras estalla
        ld hl,plliv
        dec (hl)
        call drwliv
        ld a,(plliv)
        or a
        jr z,pdover
        ld a,PLX0               ; renacer en el centro
        ld (plx),a
        jp pldrw
pdover: ld a,1
        ld (gover),a
        ret

; -------------------------------------------------------------
; drwliv - indicador de vidas: el numero y una nave por cada vida
;          de reserva (la que se esta jugando no cuenta)
; -------------------------------------------------------------
drwliv: call clrliv
        ld a,(plliv)
        add a,CH0
        ld d,ROWLIV
        ld e,1
        call prtchr
        ld a,(plliv)
        or a
        ret z
        dec a
        ret z
        ld b,a
        ld e,3*8                ; x en pixeles
bliv1:  push bc
        push de
        ld hl,plship
        ld d,ROWLIV*8
        ld b,8
        call sprdrw
        pop de
        pop bc
        ld a,e
        add a,16
        ld e,a
        djnz bliv1
        ret

; clrliv - borra la banda de 8 lineas del indicador
clrliv: ld d,ROWLIV*8
        ld b,8
clv1:   push bc
        push de
        ld e,0
        call pixad
        ld b,32
clv2:   ld (hl),0
        inc l
        djnz clv2
        pop de
        pop bc
        inc d
        djnz clv1
        ret

; -------------------------------------------------------------
; plmove - lee el teclado y desplaza la nave 1 px por frame,
;          que es la velocidad del original
; -------------------------------------------------------------
plmove: ld a,(plx)
        ld b,a
        ld a,(demoon)
        or a
        jr nz,pldemo            ; en la demo manda la IA
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
; pldemo - la IA coloca la nave bajo el alien vivo mas bajo.
;          Deja en B la x deseada y sigue por el tronco comun,
;          igual que haria el teclado.
; -------------------------------------------------------------
pldemo: push bc
        call demtgt
        pop bc
        or a
        jp z,plm2               ; sin objetivo: quieta
        ld a,(cax)
        add a,4                 ; centro aproximado del alien
        ld c,a
        ld a,b
        add a,PLW/2             ; centro de la nave
        cp c
        jp z,plm2               ; ya esta alineada
        jr c,pldmr
        ld a,b                  ; el objetivo queda a la izquierda
        cp PLXMIN+1
        jp c,plm2
        dec b
        jp plm2
pldmr:  ld a,b                  ; queda a la derecha
        cp PLXMAX
        jp nc,plm2
        inc b
        jp plm2

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
plliv:  defb PLLIV0             ; vidas restantes
gover:  defb 0                  ; 1 = partida terminada
