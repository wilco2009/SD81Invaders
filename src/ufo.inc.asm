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
UFOSPD  equ 2                   ; px por frame
UFOMIN  equ 9                   ; aliens minimos para que aparezca
UFOWAIT equ 1200                ; frames entre apariciones (~24 s)

; -------------------------------------------------------------
; ufoini - sin OVNI y con la primera aparicion programada
; -------------------------------------------------------------
ufoini: xor a
        ld (ufon),a
        ld (ufsid),a
        ld (ufcnt),a
        ld hl,UFOWAIT
        ld (ufotim),hl
        ret

; -------------------------------------------------------------
; ufoupd - un frame de OVNI
; -------------------------------------------------------------
ufoupd: ld a,(ufon)
        or a
        jr z,ufowt

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
        ld a,(ufox)             ; destello donde estaba
        ld (cax),a
        ld a,UFOY
        ld (cay),a
        call exset
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
        call addsc2
        jp ufokil

; -------------------------------------------------------------
; ufshot - un disparo mas en la cuenta, modulo 15
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
