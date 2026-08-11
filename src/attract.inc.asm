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

; --- La broma de la Y ---
;
; El titulo aparece con la Y de PLAY del reves. Un calamar entra
; por la derecha por la misma linea del rotulo, se planta justo al
; lado de la Y ofensiva, da media vuelta y se la lleva a rastras
; por donde vino. Vuelve a salir por la derecha con la Y ya del
; derecho, la deja en su sitio y se esfuma. Es el primer modo de
; atraccion de la historia con sentido del humor, y estaba ya en
; el original del 78.
;
; El glifo de la Y no se guarda como dato: se copia de la tabla de
; caracteres de la ROM del ZX81 y se invierte leyendo sus ocho
; filas al reves.
YCODE   equ CHA+'Y'-'A'         ; codigo ZX81 de la Y
YHOMEX  equ 17*8                ; sitio de la Y dentro del rotulo
YHOMEY  equ 6*8
ANIY    equ YHOMEY              ; camina por la linea del rotulo
ANSPD   equ 1                   ; px por frame
ANXY    equ YHOMEX+8            ; justo a la derecha de la Y
ANYOFS  equ 8                   ; la Y va pegada a su izquierda
ANANIM  equ 10                  ; frames por fotograma del calamar

; La x del calamar es de 16 bits para que el par pueda salirse de
; la pantalla del todo. Con la Y a su izquierda, hace falta llegar
; a 264 para que tambien ella quede fuera; con 272 sobra margen.
; Lo que no cabe en pantalla no se dibuja, y el blitter recorta
; por la derecha, asi que la salida es un deslizamiento y no un
; corte seco.
ANX0    equ 272                 ; fuera de pantalla por la derecha
ANPASO  equ (ANX0-ANXY)/ANSPD   ; pasos de cada tramo

; -------------------------------------------------------------
; attmod - cicla las pantallas de atraccion
;          Devuelve Z si se pide salir, NZ para empezar partida
; -------------------------------------------------------------
attmod: call attttl
        ld b,60
        call attwt
        or a
        jr nz,attend
        call attani             ; el calamar arregla la Y
        or a
        jr nz,attend
        ld b,80
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
        ld hl,txplay            ; solo "PLA": la Y va aparte
        ld d,6
        ld e,14
        call prtstr
        call anyinv             ; ...y sale del reves
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

; -------------------------------------------------------------
; ybuild - copia el glifo de la Y de la ROM a dos sprites de 8x8,
;          derecho e invertido. El invertido sale leyendo las
;          ocho filas del glifo al reves.
; -------------------------------------------------------------
ybuild: ld hl,GLYPHS+YCODE*8
        ld de,yspr
        ld b,8
yb1:    ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        inc hl
        djnz yb1
        ld hl,GLYPHS+YCODE*8+7
        ld de,yinv
        ld b,8
yb2:    ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        dec hl
        djnz yb2
        ret

; anyinv - la Y del rotulo, del reves
anyinv: ld hl,yinv
        ld e,YHOMEX
        ld d,YHOMEY
        ld b,8
        jp sprdrw

; -------------------------------------------------------------
; attani - la secuencia completa
;          Devuelve como attwt: 0 termino, 1 disparo, 2 salir
;
; No hace falta borrar ni volver a pintar la Y del rotulo en los
; relevos: el calamar la recoge y la deja en x = anx-8, que en los
; extremos de cada tramo cae clavado en YHOMEX. La Y que arrastra
; es literalmente la que estaba escrita.
; -------------------------------------------------------------
attani: ld hl,ANX0              ; entra por la derecha
        ld (anx),hl
        ld a,-ANSPD
        ld (anstp),a
        xor a
        ld (ancar),a
        ld (anfrm),a
        ld a,ANANIM
        ld (ancnt),a
        ld b,ANPASO             ; hasta plantarse al lado de la Y
        call anwalk
        or a
        ret nz

        ld hl,yinv              ; carga con ella y da media vuelta
        ld (anysp),hl
        ld a,1
        ld (ancar),a
        ld a,ANSPD
        ld (anstp),a
        ld b,ANPASO             ; se la lleva por donde vino
        call anwalk
        or a
        ret nz
        call anera

        ld hl,ANX0              ; reaparece con la Y del derecho
        ld (anx),hl
        ld hl,yspr
        ld (anysp),hl
        ld a,-ANSPD
        ld (anstp),a
        ld b,ANPASO             ; hasta dejarla en su sitio
        call anwalk
        or a
        ret nz

        xor a                   ; la suelta y se esfuma: anera ya
        ld (ancar),a            ; solo se lleva al calamar
        call anera
        xor a
        ret

; -------------------------------------------------------------
; anwalk - B pasos del invasor. Devuelve como attwt.
; -------------------------------------------------------------
anwalk: push bc
        call anera              ; borra con el fotograma con el que pinto
        ld a,(anstp)            ; paso con signo, extendido a 16 bits
        ld e,a
        rlca
        sbc a,a
        ld d,a
        ld hl,(anx)
        add hl,de
        ld (anx),hl
        ld hl,ancnt             ; el calamar anima al caminar
        dec (hl)
        jr nz,anw1
        ld (hl),ANANIM
        ld a,(anfrm)
        xor 1
        ld (anfrm),a
anw1:   call andrw
        call anpoll
        pop bc
        or a
        ret nz
        djnz anwalk
        xor a
        ret

; anpoll - un frame, vigilando el teclado
anpoll: call waitvs
        call plfire
        jr z,anp1
        ld a,KRQWE
        in a,(KBPORT)
        and 1
        jr z,anp2
        xor a
        ret
anp1:   ld a,1
        ret
anp2:   ld a,2
        ret

; anspr - HL = fotograma actual del calamar
anspr:  ld hl,sqda
        ld a,(anfrm)
        or a
        ret z
        ld de,16
        add hl,de
        ret

; andrw / anera - el calamar y, si carga con ella, la Y
;
; Cada uno se dibuja solo si su x cabe en un byte; si el byte alto
; no es cero, esta fuera de pantalla por la derecha y se salta.
andrw:  ld a,1
        jr anpin
anera:  xor a
anpin:  ld (anmod),a
        ld hl,(anx)
        ld a,h
        or a
        jr nz,anpy              ; el calamar ya no cabe
        call anspr
        ld a,(anx)
        ld e,a
        ld d,ANIY
        ld b,8
        call anblt
anpy:   ld a,(ancar)
        or a
        ret z
        ld hl,(anx)
        ld de,ANYOFS
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz                  ; la Y tampoco cabe
        ld a,l
        ld e,a
        ld hl,(anysp)
        ld d,YHOMEY
        ld b,8
; anblt - dibuja o borra segun anmod
anblt:  ld a,(anmod)
        or a
        jp nz,sprdrw
        jp sprera

; --- estado de la animacion ---
anmod:  defb 0                  ; 1 = dibujar, 0 = borrar
anx:    defw 0                  ; x del calamar, 16 bits
anstp:  defb 0                  ; paso, con signo
ancar:  defb 0                  ; 1 = lleva la Y a rastras
anysp:  defw 0                  ; sprite de la Y que lleva
anfrm:  defb 0                  ; fotograma del calamar
ancnt:  defb ANANIM             ; frames para el siguiente
yspr:   defs 16                 ; glifo de la Y, derecho
yinv:   defs 16                 ; y del reves

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
txplay: defb CHA+'P'-'A',CHA+'L'-'A',CHA+'A'-'A',CHEOS

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
