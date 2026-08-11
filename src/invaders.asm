; =============================================================
; SPACE INVADERS  -  ZX81 + SD81 Booster
; Replica del arcade de Taito de 1978
;
; Requiere el SD81 Booster: usa el modo Superfast HiRes Spectrum
; (256x192 monocromo con atributos de color Chroma81) y el doble
; buffer por hardware, de modo que el Z80 queda libre para la
; logica del juego y la imagen nunca se parte.
;
; Ensamblar con zmac (ver build.bat). Cargar desde BASIC:
;
;   10 FAST
;   20 LOAD THEN CLEAR 24999
;   30 LOAD FAST 'INVADERS.BIN' CODE 25000
;   40 RAND USR 25000
;   50 SLOW
;
; OJO: esta rama usa 25000, no 30000. El org y el CLEAR van
; siempre juntos - cargar en una direccion codigo ensamblado para
; otra da pantalla negra, porque el primer CALL ya se va a donde
; no hay nada.
;
; El FAST de la linea 10 tampoco es opcional: en SLOW sigue activo
; el generador de NMI del ZX81, que el DI de aqui no puede parar
; por ser no enmascarable, y el temporizado se va al traste.
;
; Controles: 5 = izquierda   8 = derecha   0 = disparo   Q = salir
; =============================================================

; --- constantes (solo equates, no generan codigo) ---
        include "hw.inc.asm"
        include "layout.inc.asm"

; El codigo vive entre RAMTOP y $8000, donde empieza el bitmap de
; pantalla. Con org 30000 solo quedaban 77 bytes de margen; a
; 25000 (con CLEAR 24999) hay ~5 KB para lo que falta: OVNI,
; explosiones, oleadas y sonido.
        org 25000

start:  di
        call vinit              ; modo de video y doble buffer
        call hdrini             ; rotulos, marcadores y suelo
        call bsdraw             ; los cuatro escudos
        call swinit             ; formacion de 55 aliens
        call plinit             ; nave y vidas
        call bminit             ; ranuras de proyectiles alien

; -------------------------------------------------------------
; Bucle principal: una vuelta por frame (50 Hz).
;
; Todo el trabajo ocurre justo despues del flanco de VSYNC, con
; ~16 ms por delante antes de que el hardware tome la siguiente
; instantanea de HFILE. El presupuesto es holgado: el enjambre
; solo repinta un alien por frame.
; -------------------------------------------------------------
main:   call waitvs
        call swstep             ; mueve un alien de la formacion
        call plmove             ; nave del jugador
        call shupd              ; disparo, impactos y erosion
        call bmupd              ; proyectiles alien

        ; TODO: OVNI y su puntuacion segun el numero de disparos
        ; TODO: explosion de alien y de nave
        ; TODO: oleadas sucesivas
        ; TODO: sonido - marcha de fondo en un hilo PEG

        ld a,(swy)              ; el enjambre ha llegado abajo
        cp SWYMAX
        jr nc,mainvd
        ld a,(gover)            ; sin vidas
        or a
        jr nz,mainov
        ld a,KRQWE
        in a,(KBPORT)
        and 1                   ; Q = salir
        jr nz,main
        jr quit

mainvd: ld a,1
        ld (gover),a
mainov: call govdrw             ; rotulo de fin de partida
movwt:  ld a,KRQWE
        in a,(KBPORT)
        and 1                   ; esperar a Q
        jr nz,movwt

quit:   call vdone              ; devolver el ZX81 a su modo normal
        ei
        ret

; -------------------------------------------------------------
; govdrw - rotulo de fin de partida
; -------------------------------------------------------------
govdrw: ld hl,txtgov
        ld d,12
        ld e,11
        jp prtstr

; -------------------------------------------------------------
; hdrini - cabecera fija de la pantalla
; -------------------------------------------------------------
hdrini: ld hl,txts1
        ld d,ROWLBL
        ld e,COLS1
        call prtstr
        ld hl,txthi
        ld d,ROWLBL
        ld e,COLHI
        call prtstr
        ld hl,txts2
        ld d,ROWLBL
        ld e,COLS2
        call prtstr

        ld hl,(score1)
        ld d,ROWSCR
        ld e,COLS1+2
        call prtbcd
        ld hl,(hiscor)
        ld d,ROWSCR
        ld e,COLHI+2
        call prtbcd
        ld hl,(score2)
        ld d,ROWSCR
        ld e,COLS2+2
        call prtbcd

; linea de suelo: 28 bytes = x 16..239
        ld d,GNDY
        ld e,FLDL/8
        ld b,(FLDR-FLDL)/8
        jp hline

; --- rotulos ---
txts1:  defb CHA+'S'-'A',CHA+'C'-'A',CHA+'O'-'A',CHA+'R'-'A'
        defb CHA+'E'-'A',CHLT,CH0+1,CHGT,CHEOS
txthi:  defb CHA+'H'-'A',CHA+'I'-'A',CHMIN,CHA+'S'-'A',CHA+'C'-'A'
        defb CHA+'O'-'A',CHA+'R'-'A',CHA+'E'-'A',CHEOS
txts2:  defb CHA+'S'-'A',CHA+'C'-'A',CHA+'O'-'A',CHA+'R'-'A'
        defb CHA+'E'-'A',CHLT,CH0+2,CHGT,CHEOS
txtgov: defb CHA+'G'-'A',CHA+'A'-'A',CHA+'M'-'A',CHA+'E'-'A',CHSP
        defb CHA+'O'-'A',CHA+'V'-'A',CHA+'E'-'A',CHA+'R'-'A',CHEOS

; --- marcadores, en BCD empaquetado de 4 digitos ---
score1: defw 0
score2: defw 0
hiscor: defw 0

; -------------------------------------------------------------
        include "video.inc.asm"
        include "text.inc.asm"
        include "sprites.inc.asm"
        include "swarm.inc.asm"
        include "player.inc.asm"
        include "shot.inc.asm"
        include "shield.inc.asm"
        include "bomb.inc.asm"

        end
