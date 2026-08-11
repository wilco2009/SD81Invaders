; =============================================================
; explode.inc.asm - Explosiones de alien y de nave
;
; La del alien es un destello que se queda unos frames en el sitio
; donde estaba y se borra solo. Solo puede haber una a la vez, que
; es lo que hacia el arcade.
;
; La de la nave si congela la partida cerca de un segundo mientras
; alterna dos fotogramas, tambien como el original. Al ser un
; bucle propio sincronizado a VSYNC, el enjambre se para con ella.
;
; NOTA: los bitmaps estan dibujados a ojo, pendientes de
; contrastar con un volcado de la ROM de Taito.
; =============================================================

EXTIME  equ 12                  ; frames que dura el destello
PXFRM   equ 8                   ; frames por fotograma de la nave
PXREP   equ 6                   ; fotogramas alternados en total

; -------------------------------------------------------------
; exset - destello en (cax,cay); sustituye al que hubiera
; -------------------------------------------------------------
exset:  call exclr
        ld a,(cax)
        ld (exx),a
        ld a,(cay)
        ld (exy),a
        ld a,1
        ld (exon),a
        ld a,EXTIME
        ld (extim),a
        ld hl,alexp
        ld a,(exx)
        ld e,a
        ld a,(exy)
        ld d,a
        ld b,8
        jp sprdrw

; -------------------------------------------------------------
; exupd - un frame de destello; al agotarse se borra solo
; -------------------------------------------------------------
exupd:  ld a,(exon)
        or a
        ret z
        ld hl,extim
        dec (hl)
        ret nz
; -- cae aqui para borrarlo --

; exclr - borra el destello activo, si lo hay
exclr:  ld a,(exon)
        or a
        ret z
        xor a
        ld (exon),a
        ld hl,alexp
        ld a,(exx)
        ld e,a
        ld a,(exy)
        ld d,a
        ld b,8
        jp sprera

; -------------------------------------------------------------
; pxplod - explosion de la nave: alterna dos fotogramas y
;          detiene la partida mientras dura
; -------------------------------------------------------------
pxplod: ld a,PXREP
        ld (pxc),a
        xor a
        ld (pxf),a
pxp1:   call pxdrw
        ld b,PXFRM
        call pause
        call pxera
        ld a,(pxf)
        xor 1
        ld (pxf),a
        ld a,(pxc)
        dec a
        ld (pxc),a
        jr nz,pxp1
        ret

pxdrw:  call pxspr
        ld a,(plx)
        ld e,a
        ld d,PLY
        ld b,8
        jp sprdrw

pxera:  call pxspr
        ld a,(plx)
        ld e,a
        ld d,PLY
        ld b,8
        jp sprera

; pxspr - HL = fotograma actual de la explosion de la nave
pxspr:  ld hl,plexp
        ld a,(pxf)
        or a
        ret z
        ld de,16
        add hl,de
        ret

; =============================================================
; Explosiones de proyectil - dos ranuras, una por bando
;
; Se dibujan con OR y al agotarse el tiempo se retiran con
; AND NOT. De ese borrado sale gratis la erosion del fondo: los
; pixeles que quedaban tapados se van con la explosion. Es asi
; como el arcade muerde la linea verde del suelo cuando una bomba
; revienta abajo, sin codigo dedicado a ello.
;
; Ranura 0 - disparo del jugador al agotarse arriba
; Ranura 1 - bomba alien al llegar al suelo
; =============================================================

BLTIME  equ 14                  ; frames que dura la explosion
BLSZ    equ 6                   ; act, x, y, tiempo, sprite (2)
NBLAST  equ 2

; blsetp / blseta - lanzar explosion en su ranura
;                   HL = sprite, D = y, E = x
blsetp: ld ix,bltab
        jr blset
blseta: ld ix,bltab+BLSZ

blset:  push hl
        push de
        call blclr              ; retirar lo que hubiera antes
        pop de
        pop hl
        ld (ix+4),l
        ld (ix+5),h
        ld (ix+1),e
        ld (ix+2),d
        ld (ix+3),BLTIME
        ld (ix+0),1
        ld b,8
        jp sprdrw

; blclr - retira la explosion de la ranura IX, si la hay
blclr:  ld a,(ix+0)
        or a
        ret z
        ld (ix+0),0
        ld l,(ix+4)
        ld h,(ix+5)
        ld e,(ix+1)
        ld d,(ix+2)
        ld b,8
        jp sprera

; blclra - retira las dos, para las pausas y cambios de oleada
blclra: ld ix,bltab
        call blclr
        ld ix,bltab+BLSZ
        jp blclr

; blupd - un frame de explosiones
blupd:  ld ix,bltab
        ld b,NBLAST
blu1:   push bc
        push ix
        ld a,(ix+0)
        or a
        jr z,blu2
        dec (ix+3)
        jr nz,blu2
        call blclr
blu2:   pop ix
        pop bc
        ld de,BLSZ
        add ix,de
        djnz blu1
        ret

bltab:  defs NBLAST*BLSZ

; -------------------------------------------------------------
; pause - espera B frames sincronizados al VSYNC
; -------------------------------------------------------------
pause:  push bc
        call waitvs
        pop bc
        djnz pause
        ret

; --- Destello del alien: 12x8 en celda de 16 px ---
alexp:  defb 00100000b,01000000b
        defb 00010000b,10000000b
        defb 10001001b,00010000b
        defb 01000000b,00100000b
        defb 01000000b,00100000b
        defb 10001001b,00010000b
        defb 00010000b,10000000b
        defb 00100000b,01000000b

; --- Explosion de la nave: 13x8, dos fotogramas ---
plexp:  defb 00101000b,10100000b
        defb 10010101b,01001000b
        defb 01010010b,01010000b
        defb 10011111b,11001000b
        defb 01011111b,11010000b
        defb 10111111b,11101000b
        defb 01111111b,11110000b
        defb 10101010b,10101000b

        defb 01000101b,00010000b
        defb 10101000b,10101000b
        defb 00100111b,00100000b
        defb 10101111b,10101000b
        defb 01011111b,11010000b
        defb 10011111b,11001000b
        defb 01010101b,01010000b
        defb 10001000b,10001000b

; --- estado ---
exon:   defb 0                  ; 1 = hay destello en pantalla
exx:    defb 0
exy:    defb 0
extim:  defb 0                  ; frames que le quedan
pxf:    defb 0                  ; fotograma de la nave
pxc:    defb 0                  ; alternancias pendientes
