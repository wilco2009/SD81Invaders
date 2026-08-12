; =============================================================
; players.inc.asm - Uno o dos jugadores, por turnos
;
; En el arcade los dos jugadores no comparten partida: alternan.
; Cada uno tiene su marcador, sus vidas, su formacion y sus
; escudos, y el turno pasa al otro cada vez que uno pierde una
; nave. Cuando a uno se le acaban, el otro sigue solo.
;
; Eso obliga a guardar y restaurar el estado entero al cambiar de
; turno, incluidos los escudos: cada jugador los tiene erosionados
; a su manera y no valdria repintarlos enteros. El arcade hacia
; exactamente esto - en su desensamblado estan las rutinas
; RememberShields y RestoreShields.
;
; Lo que se guarda por jugador:
;   - el bloque del enjambre (posiciones, oleada y swaliv)
;   - x de la nave y vidas
;   - el mapa de bits de la banda de escudos
;
; Los marcadores no van en la ranura porque cada uno tiene ya su
; variable fija, que es lo que permite mostrar los dos a la vez.
; =============================================================

PLYSW   equ swaliv-swx+SWNUM    ; bloque del enjambre, contiguo
PLYSP   equ 2                   ; plx y plliv, contiguos
PLYSH   equ BASENB*BASH         ; banda de escudos
PLYSZ   equ PLYSW+PLYSP+PLYSH

PLYMROW equ 12                  ; "PLAYER n" son 8 caracteres,
PLYMCOL equ 12                  ; centrados en 32 columnas

; -------------------------------------------------------------
; plyadr - HL = ranura del jugador C (0 o 1)
; -------------------------------------------------------------
plyadr: ld hl,plyst
        ld a,c
        or a
        ret z
        ld de,PLYSZ
        add hl,de
        ret

; -------------------------------------------------------------
; plysav - guarda el estado vivo en la ranura del jugador C
; -------------------------------------------------------------
plysav: call plyadr
        ex de,hl                ; DE = ranura
        ld hl,swx
        ld bc,PLYSW
        ldir
        ld hl,plx
        ld bc,PLYSP
        ldir
        jp shsave               ; los escudos, desde la pantalla

; -------------------------------------------------------------
; plyld - carga la ranura del jugador de turno y repinta
;
; El turno lo saca de curply y no de C a proposito: entre el
; cambio de turno y la carga hay un plymsg de por medio, y ese C
; no sobrevive ni a la primera rutina de texto.
; -------------------------------------------------------------
plyld:  ld a,(curply)
        ld c,a
        call plyadr
        ld de,swx
        ld bc,PLYSW
        ldir
        ld de,plx
        ld bc,PLYSP
        ldir
        push hl                 ; HL = escudos guardados
        ld d,16                 ; limpiar la zona de juego
        ld b,GNDY-16
        call clrbnd
        call hdrini             ; rotulos, marcadores y suelo
        pop hl
        call shload             ; los escudos tal y como los dejo
        call swdraw             ; su formacion
        call drwliv
        call pldrw
        call bminit
        jp ufoini

; -------------------------------------------------------------
; plyswp - pasa el turno al otro jugador si aun le quedan vidas.
;          Devuelve NZ si ha cambiado.
; -------------------------------------------------------------
plyswp: ld a,(curply)
        ld c,a
        call plysav             ; guardar al que acaba de morir
        ld a,(curply)
        xor 1
        ld c,a
        call plyadr
        ld de,PLYSW+1           ; plliv dentro de la ranura
        add hl,de
        ld a,(hl)
        or a
        ret z                   ; al otro no le quedan: sigue este
        ld a,c
        ld (curply),a
        call plymsg             ; anunciar a quien le toca
        call plyld
        ld a,1
        or a
        ret                     ; NZ: turno cambiado

; -------------------------------------------------------------
; plymsg - "PLAYER n" un momento, sobre la zona de juego despejada
;
; Limpia al entrar y al salir. Lo segundo hace falta porque desde
; newgam no hay nadie detras que repinte: alli solo se dibujan
; cabecera, escudos y formacion, y el cartel se quedaba clavado en
; medio de la pantalla el resto de la partida.
;
; Tambien calla el OVNI. Su zumbido lo lleva un hilo del PEG que
; sigue sonando por su cuenta mientras aqui se espera, y se oia
; por encima del cartel.
; -------------------------------------------------------------
plymsg: call sndufx
        call mchoff
        call plymcl
        ld hl,txply
        ld d,PLYMROW
        ld e,PLYMCOL
        call prtstr
        ld a,(curply)
        inc a
        add a,CH0
        ld d,PLYMROW
        ld e,PLYMCOL+7
        call prtchr
        ld b,90
        call pause
; cae en plymcl para llevarse el cartel

plymcl: ld d,16
        ld b,GNDY-16
        jp clrbnd

txply:  defb CHA+'P'-'A',CHA+'L'-'A',CHA+'A'-'A',CHA+'Y'-'A'
        defb CHA+'E'-'A',CHA+'R'-'A',CHSP,CHEOS

; -------------------------------------------------------------
; plyini - arranca una partida: las dos ranuras con el estado
;          recien montado, y empieza el jugador 1
; -------------------------------------------------------------
plyini: ld c,1
        call plysav
        ld c,0
        call plysav
        xor a
        ld (curply),a
        ret

; -------------------------------------------------------------
; shsave / shload - la banda de escudos, entre pantalla y (DE/HL)
; -------------------------------------------------------------
shsave: ld b,BASH
        ld a,BASEY
        ld (shdrow),a
shs1:   push bc
        push de
        ld a,(shdrow)
        ld d,a
        ld e,BASECL
        call pixad              ; HL = origen en pantalla
        pop de
        ld bc,BASENB
        ldir
        ld hl,shdrow
        inc (hl)
        pop bc
        djnz shs1
        ret

shload: ld b,BASH
        ld a,BASEY
        ld (shdrow),a
shl1:   push bc
        push hl
        ld a,(shdrow)
        ld d,a
        ld e,BASECL
        call pixad              ; HL = destino en pantalla
        ex de,hl                ; DE = pantalla
        pop hl                  ; HL = buffer
        ld bc,BASENB
        ldir
        push hl
        ld hl,shdrow
        inc (hl)
        pop hl
        pop bc
        djnz shl1
        ret

; -------------------------------------------------------------
; scradr - HL = marcador del jugador en curso
; -------------------------------------------------------------
scradr: ld hl,scorp1
        ld a,(curply)
        or a
        ret z
        inc hl
        inc hl
        ret

; -------------------------------------------------------------
; addscr - suma A (BCD de dos digitos) al marcador en curso
; addsc2 - suma DE (BCD de cuatro digitos)
; -------------------------------------------------------------
addscr: ld e,a
        ld d,0
addsc2: push de
        call scradr
        pop de
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = marcador ya sumado
        ld a,(curply)
        or a
        ld e,COLS1+2
        jr z,adsc1
        ld e,COLS2+2
adsc1:  ld d,ROWSCR
        jp prtbcd

; -------------------------------------------------------------
; hiupd - se queda con la mejor puntuacion de la sesion,
;         mirando los marcadores de los dos jugadores
; -------------------------------------------------------------
hiupd:  ld hl,(scorp1)
        call hiup1
        ld hl,(scorp2)
hiup1:  ld de,(hiscor)
        ld a,h
        cp d
        ret c
        jr nz,hiup2
        ld a,l
        cp e
        ret c
hiup2:  ld (hiscor),hl
        ret

; --- estado ---
nplay:  defb 1                  ; jugadores de la partida (1 o 2)
curply: defb 0                  ; a quien le toca (0 o 1)
scorp1: defw 0
scorp2: defw 0
hiscor: defw 0
shdrow: defb 0                  ; fila en curso al copiar escudos
plyst:  defs 2*PLYSZ            ; una ranura por jugador
