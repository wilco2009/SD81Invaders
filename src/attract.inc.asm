; =============================================================
; attract.inc.asm - Modo de atraccion
;
; Lo que el arcade mostraba con la maquina parada, para llamar la
; atencion de quien pasara por delante. Aqui, sin monedas de por
; medio, es el bucle previo a la partida: cicla entre el titulo y
; la tabla de puntuaciones hasta que se pulsa disparo.
;
; La SCORE ADVANCE TABLE del original ponia "=? MYSTERY" junto al
; OVNI en lugar de un numero: la propia maquina avisaba de que su
; puntuacion era variable. Aqui lo es de verdad - ver la tabla de
; disparos en ufo.inc.asm.
; =============================================================

ATTIME  equ 250                 ; frames por pantalla (~5 s)
ATTSX   equ 72                  ; x de los sprites de la tabla
ATTTX   equ 13                  ; columna de texto de la tabla

; -------------------------------------------------------------
; attmod - cicla las pantallas de atraccion
;          Devuelve Z si se pide salir, NZ para empezar partida
; -------------------------------------------------------------
attmod: call attttl
        ld b,ATTIME
        call attwt
        or a
        jr nz,attend
        call attscr
        ld b,ATTIME
        call attwt
        or a
        jr z,attmod
attend: cp 2
        ret

; -------------------------------------------------------------
; attwt - espera B frames vigilando el teclado
;         A = 0 se agoto el tiempo, 1 = disparo, 2 = salir
; -------------------------------------------------------------
attwt:  push bc
        call waitvs
        call plfire             ; Z si el disparo esta pulsado
        jr z,attw1
        ld a,KRQWE
        in a,(KBPORT)
        and 1                   ; Q
        jr z,attw2
        pop bc
        djnz attwt
        xor a
        ret
attw1:  pop bc
        ld a,1
        ret
attw2:  pop bc
        ld a,2
        ret

; -------------------------------------------------------------
; attttl - pantalla de titulo
; -------------------------------------------------------------
attttl: call clrbmp
        ld hl,txplay
        ld d,6
        ld e,14
        call prtstr
        ld hl,txtitl
        ld d,8
        ld e,9
        call prtstr
        ld hl,txpush
        ld d,18
        ld e,8
        jp prtstr

; -------------------------------------------------------------
; attscr - SCORE ADVANCE TABLE: un sprite y su valor por linea
; -------------------------------------------------------------
attscr: call clrbmp
        ld hl,txtabl
        ld d,3
        ld e,5
        call prtstr
        ld ix,attab
        ld b,4
ats1:   push bc
        ld l,(ix+0)             ; sprite
        ld h,(ix+1)
        ld d,(ix+2)             ; y en pixeles
        ld e,ATTSX
        ld b,(ix+3)             ; alto
        call sprdrw
        ld l,(ix+4)             ; texto del valor
        ld h,(ix+5)
        ld a,(ix+2)
        rrca
        rrca
        rrca
        and 1fh                 ; fila de texto = y / 8
        ld d,a
        ld e,ATTTX
        call prtstr
        pop bc
        ld de,6
        add ix,de
        djnz ats1
        ret

; --- Filas de la tabla: sprite, y, alto, texto ---
attab:  defw ufospr
        defb 64,7
        defw txufo
        defw sqda
        defb 88,8
        defw txsqd
        defw crba
        defb 112,8
        defw txcrb
        defw octa
        defb 136,8
        defw txoct

; --- Rotulos ---
txplay: defb CHA+'P'-'A',CHA+'L'-'A',CHA+'A'-'A',CHA+'Y'-'A',CHEOS

txtitl: defb CHA+'S'-'A',CHA+'P'-'A',CHA+'A'-'A',CHA+'C'-'A'
        defb CHA+'E'-'A',CHSP,CHA+'I'-'A',CHA+'N'-'A',CHA+'V'-'A'
        defb CHA+'A'-'A',CHA+'D'-'A',CHA+'E'-'A',CHA+'R'-'A'
        defb CHA+'S'-'A',CHEOS

txpush: defb CHA+'P'-'A',CHA+'R'-'A',CHA+'E'-'A',CHA+'S'-'A'
        defb CHA+'S'-'A',CHSP,CH0,CHSP,CHA+'T'-'A',CHA+'O'-'A'
        defb CHSP,CHA+'S'-'A',CHA+'T'-'A',CHA+'A'-'A'
        defb CHA+'R'-'A',CHA+'T'-'A',CHEOS

txtabl: defb CHAST,CHA+'S'-'A',CHA+'C'-'A',CHA+'O'-'A',CHA+'R'-'A'
        defb CHA+'E'-'A',CHSP,CHA+'A'-'A',CHA+'D'-'A',CHA+'V'-'A'
        defb CHA+'A'-'A',CHA+'N'-'A',CHA+'C'-'A',CHA+'E'-'A',CHSP
        defb CHA+'T'-'A',CHA+'A'-'A',CHA+'B'-'A',CHA+'L'-'A'
        defb CHA+'E'-'A',CHAST,CHEOS

txufo:  defb CHEQ,CHQUE,CHSP,CHA+'M'-'A',CHA+'Y'-'A',CHA+'S'-'A'
        defb CHA+'T'-'A',CHA+'E'-'A',CHA+'R'-'A',CHA+'Y'-'A',CHEOS

txsqd:  defb CHEQ,CH0+3,CH0,CHSP,CHA+'P'-'A',CHA+'O'-'A'
        defb CHA+'I'-'A',CHA+'N'-'A',CHA+'T'-'A',CHA+'S'-'A',CHEOS

txcrb:  defb CHEQ,CH0+2,CH0,CHSP,CHA+'P'-'A',CHA+'O'-'A'
        defb CHA+'I'-'A',CHA+'N'-'A',CHA+'T'-'A',CHA+'S'-'A',CHEOS

txoct:  defb CHEQ,CH0+1,CH0,CHSP,CHA+'P'-'A',CHA+'O'-'A'
        defb CHA+'I'-'A',CHA+'N'-'A',CHA+'T'-'A',CHA+'S'-'A',CHEOS
