; =============================================================
; ufo.inc.asm - La nave nodriza
;
; Cruza la banda superior a intervalos, alternando el lado de
; entrada, y solo mientras queden mas de UFOMIN aliens: en el
; arcade deja de salir cuando la formacion esta casi barrida.
;
; La puntuacion no es fija. El arcade llevaba la cuenta de los
; disparos del jugador y consultaba una tabla de 15 entradas con
; ese contador, de forma que el valor parecia aleatorio pero era
; perfectamente predecible - de ahi la tecnica conocida de contar
; disparos para cazar el OVNI de 300 puntos.
; =============================================================

UFOW    equ 16                  ; ancho del sprite
UFOH    equ 7                   ; alto
UFOSPD  equ 1                   ; px por movimiento
UFODIV  equ 1                   ; se mueve uno de cada N frames
;
; A 2 px por frame cruzaba el campo en 2,2 s, demasiado rapido: el
; OVNI del arcade es una deriva que da tiempo a apuntar. A 1 px
; por frame son 224 frames, unos 4,5 s.
;
; El divisor esta para poder bajar de 1 px por frame, que es el
; minimo entero. Si se toca, hay que ajustar con el las vueltas
; del efecto de sonido en datufo: el zumbido tiene que durar
; aproximadamente lo mismo que el cruce.
UFOMIN  equ 8                   ; deja de salir con 7 o menos aliens
UFOWAIT equ 1200                ; frames entre apariciones (~24 s)
UFOROW  equ 2                   ; fila de texto de la banda del OVNI
UFSTIME equ 60                  ; frames que se queda la puntuacion

; -------------------------------------------------------------
; ufoini - sin OVNI y con la primera aparicion programada
; -------------------------------------------------------------
ufoini: xor a
        ld (ufon),a
        ld (ufsid),a
        ld (ufcnt),a
        ld (ufstim),a
        ld hl,UFOWAIT
        ld (ufotim),hl
        ret

; -------------------------------------------------------------
; ufoupd - un frame de OVNI
; -------------------------------------------------------------
ufoupd: ld a,(ufon)
        or a
        jr z,ufowt

        ld hl,ufoct             ; solo avanza uno de cada UFODIV
        dec (hl)
        ret nz
        ld (hl),UFODIV

        call ufoera             ; borrar donde estaba
        ld a,(ufox)
        ld hl,ufodir
        add a,(hl)
        ld (ufox),a
        ld a,(ufodir)
        or a
        jp m,ufoizq
        ld a,(ufox)             ; se marcha por la derecha
        cp FLDR-UFOW+1
        jr nc,ufokil
        jp ufodrw
ufoizq: ld a,(ufox)             ; se marcha por la izquierda
        cp FLDL+1
        jr c,ufokil
        jp ufodrw

ufowt:  ld hl,(ufotim)          ; contar hasta la siguiente salida
        dec hl
        ld (ufotim),hl
        ld a,h
        or l
        ret nz

; -------------------------------------------------------------
; ufospw - sacar el OVNI, alternando el lado de entrada
; -------------------------------------------------------------
ufospw: ld a,(swleft)
        cp UFOMIN
        jr c,ufors              ; queda poca formacion: no sale
        ld a,(ufsid)
        xor 1
        ld (ufsid),a
        or a
        jr z,ufsder
        ld a,FLDL               ; entra por la izquierda
        ld (ufox),a
        ld a,UFOSPD
        jr ufson
ufsder: ld a,FLDR-UFOW          ; entra por la derecha
        ld (ufox),a
        ld a,-UFOSPD
ufson:  ld (ufodir),a
        ld a,UFODIV
        ld (ufoct),a
        ld a,1
        ld (ufon),a
        call sndufo
        jp ufodrw

ufors:  ld hl,UFOWAIT           ; reintentar mas adelante
        ld (ufotim),hl
        ret

; -------------------------------------------------------------
; ufokil - retirar el OVNI y reprogramar la siguiente salida.
;          No borra: quien llama ya lo ha hecho.
; -------------------------------------------------------------
ufokil: xor a
        ld (ufon),a
        ld hl,UFOWAIT
        ld (ufotim),hl
        jp sndufx

; -------------------------------------------------------------
; ufohit - el disparo del jugador ha alcanzado la banda superior
; -------------------------------------------------------------
ufohit: ld a,(ufon)
        or a
        ret z                   ; no habia OVNI: disparo perdido
        call ufoera
        call sndexa

        ld hl,uftab             ; puntuacion segun el contador
        ld a,(ufcnt)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (ufsval),de          ; se queda un momento en pantalla,
        push de                 ; que es la gracia del OVNI
        ld a,(ufox)
        rrca
        rrca
        rrca
        and 1fh                 ; columna de texto = x / 8
        ld (ufscol),a
        ld a,UFSTIME
        ld (ufstim),a
        call ufsdrw
        pop de
        call addsc2
        jp ufokil

; -------------------------------------------------------------
; ufsupd - cuenta atras de la puntuacion en pantalla
; -------------------------------------------------------------
ufsupd: ld a,(ufstim)
        or a
        ret z
        dec a
        ld (ufstim),a
        ret nz
; cae en ufsclr al agotarse

; ufsclr - borra la puntuacion escribiendo espacios encima
ufsclr: xor a
        ld (ufstim),a
        ld a,(ufscol)
        ld e,a
        ld d,UFOROW
        ld b,3
ufsc1:  push bc
        xor a                   ; el glifo del espacio esta en blanco
        call prtchr
        pop bc
        inc e
        djnz ufsc1
        ret

; -------------------------------------------------------------
; ufsdrw - escribe el valor de (ufsval) donde estaba el OVNI
;
; Son tres digitos con el cero de la izquierda en blanco, de forma
; que 50 sale como " 50" y 300 como "300".
; -------------------------------------------------------------
ufsdrw: ld a,(ufscol)
        ld e,a
        ld d,UFOROW
        ld a,(ufsval+1)
        and 0fh
        jr z,ufsd1
        add a,CH0
        jr ufsd2
ufsd1:  ld a,CHSP
ufsd2:  call prtchr
        inc e
        ld a,(ufsval)
        rrca
        rrca
        rrca
        rrca
        and 0fh
        add a,CH0
        call prtchr
        inc e
        ld a,(ufsval)
        and 0fh
        add a,CH0
        jp prtchr

; -------------------------------------------------------------
; ufshot - un disparo mas en la cuenta, modulo 15
;
; Se llama cuando el disparo DESAPARECE, no cuando sale del cañon.
; Da igual como se vaya: tocando algo, agotandose arriba o
; derribado por una bomba. Contarlo al disparar hacia que la
; cuenta corriera por delante de lo que se ve en pantalla, y con
; ella la puntuacion del OVNI.
;
; En el impacto va antes de repartirlo, de modo que si lo que ha
; tocado es el propio OVNI, el disparo se cuenta a si mismo antes
; de consultar la tabla.
; -------------------------------------------------------------
ufshot: ld a,(ufcnt)
        inc a
        cp 15
        jr c,ufs1
        xor a
ufs1:   ld (ufcnt),a
        ret

; -------------------------------------------------------------
ufodrw: ld hl,ufospr
        ld a,(ufox)
        ld e,a
        ld d,UFOY
        ld b,UFOH
        jp sprdrw

ufoera: ld hl,ufospr
        ld a,(ufox)
        ld e,a
        ld d,UFOY
        ld b,UFOH
        jp sprera

; --- Tabla de puntuacion del arcade, indexada por el contador de
;     disparos. Cada entrada es BCD: byte bajo y byte alto.
uftab:  defb 000h,001h          ;  100
        defb 050h,000h          ;   50
        defb 050h,000h          ;   50
        defb 000h,001h          ;  100
        defb 050h,001h          ;  150
        defb 000h,001h          ;  100
        defb 000h,001h          ;  100
        defb 050h,000h          ;   50
        defb 000h,003h          ;  300
        defb 000h,001h          ;  100
        defb 000h,001h          ;  100
        defb 000h,001h          ;  100
        defb 050h,000h          ;   50
        defb 050h,001h          ;  150
        defb 000h,001h          ;  100

; --- estado ---
ufon:   defb 0                  ; 1 = OVNI en pantalla
ufox:   defb 0
ufodir: defb UFOSPD             ; sentido de marcha
ufotim: defw UFOWAIT            ; frames hasta la siguiente salida
ufsid:  defb 0                  ; alterna el lado de entrada
ufcnt:  defb 0                  ; disparos del jugador, modulo 15
ufoct:  defb UFODIV             ; frames que faltan para avanzar
ufsval: defw 0                  ; puntuacion que se esta mostrando
ufscol: defb 0                  ; columna donde se muestra
ufstim: defb 0                  ; frames que le quedan
