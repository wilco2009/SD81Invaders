; =============================================================
; shot.inc.asm - El disparo del jugador
;
; Un solo proyectil en vuelo, como en el arcade: hasta que el
; anterior no desaparece no se puede volver a disparar. Mantener
; pulsado el boton dispara en cuanto se libera, que es como se
; comportaba el original.
;
; La deteccion de impactos lee la pantalla (pixtst) en las cuatro
; lineas de la nueva posicion. Como el disparo avanza justo su
; propia altura, la region barrida queda cubierta entera y no
; puede atravesar nada sin verlo.
; =============================================================

BULSPD  equ 4                   ; px por frame
BULH    equ 4                   ; alto del disparo
BULTOP  equ 16                  ; altura a la que se apaga

; -------------------------------------------------------------
; shupd - un frame de disparo
; -------------------------------------------------------------
shupd:  ld a,(shon)
        or a
        jr z,shfire             ; nada en vuelo: mirar el boton

        call shera              ; borrar donde estaba
        ld a,(shy)
        cp BULTOP+BULSPD
        jr c,shkill             ; se sale por arriba
        sub BULSPD
        ld (shy),a
        call shchk              ; comprobar lo que hay en el camino
        ret nz                  ; hubo impacto: el disparo ya se anulo
        jp shdrw

shkill: xor a
        ld (shon),a
        ret

; -------------------------------------------------------------
; shclr - anula el disparo en vuelo, si lo hay, borrandolo de la
;         pantalla. Lo usan la muerte del jugador y las bombas
;         alien, que en el arcade pueden derribar tu disparo.
; -------------------------------------------------------------
shclr:  ld a,(shon)
        or a
        ret z
        call shera
        xor a
        ld (shon),a
        ret

; -------------------------------------------------------------
; shfire - lanza un disparo si el boton esta pulsado
; -------------------------------------------------------------
shfire: call plfire
        ret nz                  ; plfire devuelve Z si esta pulsado
        ld a,(plx)
        add a,PLW/2             ; centro de la nave
        ld (shx),a
        ld a,PLY-BULH
        ld (shy),a
        ld a,1
        ld (shon),a
        call ufshot             ; cuenta de disparos para el OVNI
        call sndlas
        jp shdrw

; -------------------------------------------------------------
; shchk - NZ si el disparo ha chocado con algo en su nueva
;         posicion; en ese caso lo apaga y despacha el impacto
; -------------------------------------------------------------
shchk:  ld a,(shy)
        ld d,a
        ld b,BULH
sck1:   push bc
        push de
        ld a,(shx)
        ld e,a
        call pixtst
        pop de
        pop bc
        jr nz,sckhit
        inc d
        djnz sck1
        xor a                   ; camino libre
        ret

sckhit: ld a,d
        ld (bimy),a             ; punto exacto del impacto
        ld a,(shx)
        ld (bimx),a
        xor a
        ld (shon),a             ; el disparo desaparece al tocar
        call shimp
        ld a,1
        or a
        ret                     ; NZ

; -------------------------------------------------------------
; shimp - reparte el impacto segun la banda en la que ocurre.
;         Las bandas no se solapan, asi que la y basta para saber
;         contra que se ha chocado.
; -------------------------------------------------------------
shimp:  ld a,(bimy)
        cp UFOY+UFOH
        jp c,ufohit             ; banda del OVNI, por encima de todo
        cp BASEY
        jp c,alhit              ; zona del enjambre
        cp BASEY+BASH
        jp c,bserod             ; escudos
        jp alhit

; -------------------------------------------------------------
shdrw:  ld hl,bulspr
        ld a,(shx)
        ld e,a
        ld a,(shy)
        ld d,a
        ld b,BULH
        jp sprdrw

shera:  ld hl,bulspr
        ld a,(shx)
        ld e,a
        ld a,(shy)
        ld d,a
        ld b,BULH
        jp sprera

; --- Disparo del jugador: 1x4 en celda de 16 px ---
bulspr: defb 10000000b,00000000b
        defb 10000000b,00000000b
        defb 10000000b,00000000b
        defb 10000000b,00000000b

; --- estado del disparo ---
shon:   defb 0                  ; 1 = hay disparo en vuelo
shx:    defb 0
shy:    defb 0
bimx:   defb 0                  ; punto de impacto
bimy:   defb 0
