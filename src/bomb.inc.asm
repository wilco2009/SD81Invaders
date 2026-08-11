; =============================================================
; bomb.inc.asm - Los proyectiles de los aliens
;
; Tres ranuras simultaneas y tres tipos animados, como el arcade.
; Cada bomba sale del alien mas bajo de una columna elegida al
; azar, que es de donde salian en el original: nunca de un alien
; que tenga companeros debajo.
;
; Cada ranura lleva su propia cuenta atras de recarga, escalonada
; al arrancar para que las tres no disparen a la vez.
;
; NOTA: los bitmaps de los tres tipos estan dibujados a ojo. La
; mecanica (tres tipos, tres ranuras, cuatro fotogramas) es la del
; arcade; los pixeles exactos estan pendientes de contrastar.
; =============================================================

NBOMB   equ 3                   ; bombas simultaneas
BMSZ    equ 6                   ; bytes por ranura
BMSPD   equ 2                   ; px por frame
BMH     equ 7                   ; alto del proyectil
BMW     equ 3                   ; ancho
BMBOT   equ 184                 ; tope inferior de seguridad
BMRELO  equ 80                  ; frames de recarga
;
; A 4 px por frame el proyectil cubria el hueco hasta la nave en
; unos 18 frames: un tercio de segundo para reaccionar. El arcade
; daba cerca de un segundo. Con 2 px son ~36 frames, que con el
; hueco ya recuperado (SWDY) se queda en el orden del original.
;
; bmchk sondea justo BMSPD lineas de cabeza, asi que sigue siendo
; exacto al cambiar la velocidad: la franja que barre el proyectil
; entre frame y frame es exactamente la que se comprueba.

; Campos de la ranura (IX): 0=activa 1=x 2=y 3=tipo 4=frame 5=recarga

; -------------------------------------------------------------
; bminit - ranuras vacias con las recargas escalonadas
; -------------------------------------------------------------
bminit: ld ix,bmtab
        ld b,NBOMB
        ld c,20
bmi1:   ld (ix+0),0
        ld (ix+5),c
        ld a,c
        add a,20
        ld c,a
        ld de,BMSZ
        add ix,de
        djnz bmi1
        ret

; -------------------------------------------------------------
; bmclr - borra de la pantalla y desactiva todas las bombas
;         (al morir el jugador la pantalla se limpia)
; -------------------------------------------------------------
bmclr:  ld ix,bmtab
        ld b,NBOMB
bmc1:   push bc
        ld a,(ix+0)
        or a
        jr z,bmc2
        call bmera
        ld (ix+0),0
        ld (ix+5),BMRELO
bmc2:   pop bc
        ld de,BMSZ
        add ix,de
        djnz bmc1
        ret

; -------------------------------------------------------------
; bmupd - un frame de proyectiles alien
; -------------------------------------------------------------
; IX se salva en la pila: si la bomba mata al jugador, pldead
; llama a bmclr, que recorre la tabla entera y deja IX al final.
bmupd:  ld ix,bmtab
        ld b,NBOMB
bmu1:   push bc
        push ix
        call bmone
        pop ix
        pop bc
        ld de,BMSZ
        add ix,de
        djnz bmu1
        ret

; -------------------------------------------------------------
; bmone - actualiza la ranura apuntada por IX
; -------------------------------------------------------------
bmone:  ld a,(ix+0)
        or a
        jr z,bmfree

        call bmera              ; borrar con el fotograma con el que se pinto
        ld a,(ix+2)
        add a,BMSPD
        cp BMBOT
        jr nc,bmoff
        ld (ix+2),a
        ld a,(ix+4)             ; siguiente fotograma de la animacion
        inc a
        and 3
        ld (ix+4),a
        call bmchk
        ret nz                  ; hubo impacto: la bomba ya se anulo
        jp bmdrw

bmoff:  ld (ix+0),0
        ld (ix+5),BMRELO
        ret

; Con la cuenta ya a cero se reintenta cada frame: si bmfire falla
; por no haber columna util, la ranura no se queda muerta.
bmfree: ld a,(ix+5)             ; ranura libre: contar para recargar
        or a
        jr z,bmfire
        dec a
        ld (ix+5),a
        ret nz
        jp bmfire

; -------------------------------------------------------------
; bmfire - lanza una bomba desde una columna con aliens vivos
; -------------------------------------------------------------
bmfire: ld a,(swleft)
        or a
        ret z
        call rnd                ; columna de partida
        and 15
        cp SWCOLS
        jr c,bmf1
        sub SWCOLS
bmf1:   ld c,a
        ld b,SWCOLS
bmf2:   push bc
        call alcol
        pop bc
        jr nz,bmf3
        inc c                   ; columna vacia: probar la siguiente
        ld a,c
        cp SWCOLS
        jr c,bmf2b
        ld c,0
bmf2b:  djnz bmf2
        ret                     ; ninguna columna util

bmf3:   call salpos             ; posicion del alien que dispara
        ld hl,alwid
        ld a,(crow)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        srl a                   ; centrar el proyectil en el alien
        dec a
        ld hl,cax
        add a,(hl)
        ld (ix+1),a
        ld a,(cay)
        add a,8                 ; justo por debajo
        ld (ix+2),a
        call rnd                ; tipo: 0, 1 o 2
        and 3
        cp 3
        jr c,bmf4
        xor a
bmf4:   ld (ix+3),a
        ld (ix+4),0
        ld (ix+0),1
        jp bmdrw

; -------------------------------------------------------------
; bmchk - NZ si la bomba choca con algo en su nueva posicion.
;
; Solo se comprueban las BMSPD lineas de cabeza: el resto del
; proyectil pisa terreno que acaba de borrar el propio bmera, y
; leerlo daria un falso positivo consigo mismo.
; -------------------------------------------------------------
bmchk:  ld a,(ix+2)
        add a,BMH-BMSPD
        ld (bcky),a
        ld b,BMSPD
bck1:   push bc
        ld a,(ix+1)
        ld (bckx),a
        ld b,BMW
bck2:   push bc
        ld a,(bckx)
        ld e,a
        ld a,(bcky)
        ld d,a
        call pixtst
        pop bc
        jr nz,bckhit
        ld a,(bckx)
        inc a
        ld (bckx),a
        djnz bck2
        pop bc
        ld a,(bcky)
        inc a
        ld (bcky),a
        djnz bck1
        xor a
        ret                     ; camino libre

bckhit: pop bc                  ; descartar el contador de lineas
        ld a,(bckx)
        ld (bimx),a
        ld a,(bcky)
        ld (bimy),a
        ld (ix+0),0             ; la bomba desaparece al tocar
        ld (ix+5),BMRELO
        call bmimp
        ld a,1
        or a
        ret

; -------------------------------------------------------------
; bmimp - reparte el impacto por bandas. Por encima de los
;         escudos lo unico que puede haber es el disparo del
;         jugador: en el arcade una bomba puede anularlo.
; -------------------------------------------------------------
bmimp:  ld a,(bimy)
        cp BASEY
        jp c,shclr              ; ha chocado con el disparo del jugador
        cp BASEY+BASH
        jp c,bserod             ; escudo
        cp PLY
        ret c                   ; hueco entre escudos y nave
        cp PLY+8
        jp c,pldead             ; ha dado a la nave
        ret                     ; suelo

; -------------------------------------------------------------
; bmspr - HL = sprite del tipo y fotograma de la bomba en IX
; -------------------------------------------------------------
bmspr:  ld a,(ix+3)
        add a,a
        ld l,a
        ld h,0
        ld de,bmspt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = base del tipo
        ld a,(ix+4)
        ld c,a
        add a,a
        add a,a
        add a,a
        sub c                   ; frame * 7
        add a,a                 ; frame * 14 bytes
        ld e,a
        ld d,0
        add hl,de
        ret

bmdrw:  call bmspr
        ld a,(ix+1)
        ld e,a
        ld a,(ix+2)
        ld d,a
        ld b,BMH
        jp sprdrw

bmera:  call bmspr
        ld a,(ix+1)
        ld e,a
        ld a,(ix+2)
        ld d,a
        ld b,BMH
        jp sprera

; -------------------------------------------------------------
; rnd - pseudoaleatorio de 8 bits
; -------------------------------------------------------------
rnd:    ld a,(rndsd)
        ld b,a
        rrca
        rrca
        rrca
        xor 1fh
        add a,b
        sbc a,255
        ld (rndsd),a
        ret

rndsd:  defb 7

; --- Tabla de tipos ---
bmspt:  defw bmsqg              ; 0 - squiggly (zigzag)
        defw bmplg              ; 1 - plunger (barra que sube)
        defw bmrol              ; 2 - rolling

; --- Squiggly: zigzag de 4 fases, 3x7 en celda de 16 px ---
bmsqg:  defb 01000000b,0
        defb 10000000b,0
        defb 01000000b,0
        defb 00100000b,0
        defb 01000000b,0
        defb 10000000b,0
        defb 01000000b,0

        defb 10000000b,0
        defb 01000000b,0
        defb 00100000b,0
        defb 01000000b,0
        defb 10000000b,0
        defb 01000000b,0
        defb 00100000b,0

        defb 01000000b,0
        defb 00100000b,0
        defb 01000000b,0
        defb 10000000b,0
        defb 01000000b,0
        defb 00100000b,0
        defb 01000000b,0

        defb 00100000b,0
        defb 01000000b,0
        defb 10000000b,0
        defb 01000000b,0
        defb 00100000b,0
        defb 01000000b,0
        defb 10000000b,0

; --- Plunger: barra transversal subiendo ---
bmplg:  defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 11100000b,0

        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 11100000b,0
        defb 01000000b,0

        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 11100000b,0
        defb 01000000b,0
        defb 01000000b,0

        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 11100000b,0
        defb 01000000b,0
        defb 01000000b,0
        defb 01000000b,0

; --- Rolling: aspas girando ---
bmrol:  defb 01000000b,0
        defb 11000000b,0
        defb 01000000b,0
        defb 01100000b,0
        defb 01000000b,0
        defb 11000000b,0
        defb 01000000b,0

        defb 01000000b,0
        defb 01100000b,0
        defb 01000000b,0
        defb 11000000b,0
        defb 01000000b,0
        defb 01100000b,0
        defb 01000000b,0

        defb 11000000b,0
        defb 01000000b,0
        defb 01100000b,0
        defb 01000000b,0
        defb 11000000b,0
        defb 01000000b,0
        defb 01100000b,0

        defb 01100000b,0
        defb 01000000b,0
        defb 11000000b,0
        defb 01000000b,0
        defb 01100000b,0
        defb 01000000b,0
        defb 11000000b,0

; --- ranuras y scratch ---
bmtab:  defs NBOMB*BMSZ
bckx:   defb 0                  ; punto que se esta sondeando
bcky:   defb 0
