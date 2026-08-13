; =============================================================
; bomb.inc.asm - Los proyectiles de los aliens
;
; Tres ranuras simultaneas y tres tipos animados, como el arcade.
; El tipo no se sortea: va pegado a la ranura, de forma que las
; tres bombas que puede haber en vuelo son siempre una de cada
; clase, igual que en el original. Cada una elige columna a su
; manera - ver bmfire, que es donde esta la gracia.
;
; La bomba sale siempre del alien mas bajo de su columna, nunca de
; uno que tenga companeros debajo.
;
; Cada ranura lleva su propia cuenta atras de recarga, escalonada
; al arrancar para que las tres no disparen a la vez. Lo que dura
; esa cuenta no es fijo: sale de la puntuacion del jugador, que es
; de donde el arcade sacaba toda su curva de dificultad. Ver
; bmrate.
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
; bmrate - A = frames de recarga segun la puntuacion en curso
;
; La curva de dificultad del arcade entera esta aqui. El original
; consultaba una tabla de cinco valores con el byte alto del
; marcador, que al ser BCD son directamente los millares y las
; centenas, asi que los cortes caen en cifras redondas: 200, 1000,
; 2000 y 3000 puntos. De 48 frames a 7 hay casi siete veces mas
; fuego alien, y no cambia ninguna otra cosa - los aliens no se
; mueven mas rapido por estar mas avanzada la partida, es que
; disparan mucho mas.
;
; Los valores son los del arcade tal cual (30h 10h 0Bh 08h 07h) y
; no estan escalados a los 50 Hz del ZX81. Alli eran 60, o sea que
; aqui cada escalon dura una quinta parte mas de tiempo real: es
; un pelo mas benevolo que el original, no mas duro.
;
; Cuenta la puntuacion del jugador de turno, no la mayor de los
; dos: a dos jugadores cada uno tiene su propia dificultad, como
; en el original.
; -------------------------------------------------------------
bmrate: call scradr
        inc hl
        ld a,(hl)               ; centenas y millares, en BCD
        ld hl,bmrtab
        cp 002h
        jr c,bmrt1              ; menos de 200
        inc hl
        cp 010h
        jr c,bmrt1              ; menos de 1000
        inc hl
        cp 020h
        jr c,bmrt1              ; menos de 2000
        inc hl
        cp 030h
        jr c,bmrt1              ; menos de 3000
        inc hl
bmrt1:  ld a,(hl)
        ret

bmrtab: defb 48                 ; hasta 199 puntos
        defb 16                 ; hasta 999
        defb 11                 ; hasta 1999
        defb 8                  ; hasta 2999
        defb 7                  ; de 3000 en adelante

; -------------------------------------------------------------
; bminit - ranuras vacias con las recargas escalonadas
; -------------------------------------------------------------
bminit: ld a,BMPINI             ; cada cursor, al principio de su tramo
        ld (bmpcur),a
        ld a,BMSINI
        ld (bmscur),a
        ld ix,bmtab
        ld b,NBOMB
        ld c,20
bmi1:   ld a,NBOMB
        sub b                   ; 0, 1, 2: el tipo va con la ranura
        ld (ix+3),a
        ld (ix+0),0
        ld (ix+4),0
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
        call bmrate
        ld (ix+5),a
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
        call bmrate
        ld (ix+5),a
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
; bmfire - lanza una bomba desde la ranura IX
;
; Aqui esta lo que de verdad distingue a los tres proyectiles del
; arcade, que no son tres dibujos distintos sino tres maneras de
; elegir columna:
;
;   0  rolling    persigue al jugador
;   1  plunger    indices 0-15 de la tabla de columnas
;   2  squiggly   indices 6-20 de la MISMA tabla
;
; De ahi sale el caracter del original: el rolling te obliga a no
; quedarte quieto y los otros dos son memorizables. Los dos tramos
; se solapan pero tienen largos primos entre si, 16 y 15, asi que
; el patron conjunto no se repite hasta 240 disparos.
;
; Ninguno de los tres busca una columna alternativa: si la que le
; toca esta ya barrida, ese tiro sencillamente no sale. Es lo que
; hace el arcade -FindInColumn devuelve C=0 y el disparo se
; descarta- y es tambien lo que permite comprarse un respiro
; despejando la columna que tienes encima.
;
; El plunger deja de dispararse cuando queda un solo alien.
; -------------------------------------------------------------
; El numero de tipo es el mismo indice que usa bmspt para el
; dibujo, asi que 0 es el squiggly y no el rolling. Equivocarlo no
; da error de nada: simplemente el que persigue sale pintado en
; zigzag y el zigzag rodando.
bmfire: ld a,(swleft)
        or a
        ret z
        ld a,(ix+3)
        cp 1
        jr z,bmfplg
        cp 2
        jr z,bmfrol
        ld hl,bmscur            ; --- squiggly ---
        ld d,BMSINI
        ld e,BMSEND
        jr bmftab

bmfplg: ld a,(swleft)           ; --- plunger ---
        dec a
        ret z                   ; con un solo alien, este no dispara
        ld hl,bmpcur
        ld d,BMPINI
        ld e,BMPEND

; -------------------------------------------------------------
; bmftab - toma la columna que marca el cursor (HL) y lo avanza,
;          dando la vuelta a D al llegar a E
; -------------------------------------------------------------
bmftab: ld c,(hl)               ; indice en curso
        inc (hl)
        ld a,(hl)
        cp e
        jr c,bmft1
        ld (hl),d               ; fin de SU tramo: vuelta al principio
bmft1:  ld b,0
        ld hl,bmctab
        add hl,bc
        ld a,(hl)
        dec a                   ; la tabla numera las columnas de 1 a 11
        ld c,a
        call alcol
        ret z                   ; columna barrida: este tiro no sale
        jr bmf3

; -------------------------------------------------------------
; bmfrol - el rolling sale de la columna que tiene encima al
;          jugador, que es la unica que mira
;
; El arcade calcula la columna contando decenasesis desde el alien
; de referencia y, si le sale una que no existe, se queda con la
; ultima. Aqui el equivalente es restar swx y dividir por SWDX,
; recortando por los dos extremos: por arriba porque el jugador
; puede estar mas a la derecha que la formacion entera, y por
; abajo porque puede estar mas a la izquierda.
; -------------------------------------------------------------
bmfrol: ld a,(plx)
        add a,PLW/2             ; centro de la nave
        ld c,a
        ld a,(swx)
        ld b,a
        ld a,c
        sub b                   ; ...respecto al origen del enjambre
        jr nc,bmfr1
        xor a                   ; la formacion queda a su derecha
bmfr1:  rrca                    ; / SWDX
        rrca
        rrca
        rrca
        and 0fh
        cp SWCOLS
        jr c,bmfr2
        ld a,SWCOLS-1           ; ...o a su izquierda
bmfr2:  ld c,a
        call alcol
        ret z                   ; nadie encima: este tiro no sale

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
        ld (ix+4),0             ; el tipo no se toca: es de la ranura
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
        call bmrate
        ld (ix+5),a
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
        jp c,bserob             ; escudo, con el crater de bomba
        cp PLY
        ret c                   ; hueco entre escudos y nave
        cp PLY+8
        jp c,pldead             ; ha dado a la nave
; cae aqui al tocar el suelo

; -------------------------------------------------------------
; bmgnd - la bomba revienta contra la linea del suelo
;
; La explosion se dibuja encima de la linea verde y, al retirarla,
; se lleva los pixeles que tapaba: de ahi salen las muescas del
; original. No hace falta erosionar aparte.
;
; Se apoya sobre la linea, no centrada en ella: restando BMH-1 la
; ultima fila del sprite queda justo encima del suelo, que es la
; unica que llega a morderlo. Centrandola, la explosion se hundia
; media altura por debajo y el mordisco salia demasiado profundo.
; -------------------------------------------------------------
bmgnd:  ld hl,dmgbom
        ld a,(bimx)
        sub 3
        ld e,a
        ld a,(bimy)
        sub 7                   ; ultima fila del sprite sobre la linea
        ld d,a
        jp blseta

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
; ColFireTable - la tabla de columnas del arcade, $1D00, tal cual
;
; Es UNA sola tabla de 21 entradas y los dos proyectiles con
; patron se reparten tramos que se solapan:
;
;   plunger    indices 00-0F   (da la vuelta al llegar a 10h)
;   squiggly   indices 06-14   (da la vuelta al llegar a 15h)
;
; Las cinco ultimas entradas parecen ser continuacion de la tabla
; pero no las usa nadie. En el desensamblado se sospecha que eran
; para el rolling, antes de que le cambiaran el comportamiento por
; el de perseguir al jugador.
;
; Numera de 1 a 11, asi que hay que restar uno. Y no es uniforme
; ni pretende serlo: la columna 1 sale siete veces de dieciseis en
; el tramo del plunger. Ese sesgo es del original.
; -------------------------------------------------------------
BMPINI  equ 000h                ; tramo del plunger
BMPEND  equ 010h
BMSINI  equ 006h                ; tramo del squiggly
BMSEND  equ 015h

bmctab: defb 001h,007h,001h,001h,001h,004h,00bh,001h
        defb 006h,003h,001h,001h,00bh,009h,002h,008h
        defb 002h,00bh,004h,007h,00ah

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
bmpcur: defb BMPINI             ; indice en curso de cada tramo
bmscur: defb BMSINI
