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
; El org y el CLEAR del cargador van SIEMPRE juntos: cargar en una
; direccion codigo ensamblado para otra da pantalla negra, porque
; el primer CALL ya salta a donde no hay nada.
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

; El codigo vive entre RAMTOP (CLEAR 24999) y $8000, donde empieza
; el bitmap de pantalla. A 30000 solo quedaban 77 bytes de margen;
; con 25000 hay ~5 KB para lo que falta: OVNI, explosiones,
; oleadas y sonido.
        org 25000

start:  di
        call vinit              ; modo de video y doble buffer
        call sndini             ; volcar los efectos al PEG
        call ybuild             ; la Y del rotulo, derecha e invertida

; -------------------------------------------------------------
; Ciclo de la maquina: atraccion, partida, y vuelta a empezar.
; Ambas rutinas devuelven Z cuando el jugador pide salir.
; -------------------------------------------------------------
mach:   call attmod             ; titulo y tabla de puntuaciones
        jr z,quit
        call newgam
        call gmloop
        jr nz,mach

quit:   call sndoff             ; callar AY y los tres hilos del PEG
        call vdone              ; devolver el ZX81 a su modo normal
        ei
        ret

; -------------------------------------------------------------
; newgam - deja todo listo para una partida desde cero
;
; Hasta que hubo modo de atraccion no hacia falta: el binario se
; cargaba, se jugaba una vez y se salia, asi que el estado inicial
; venia en los propios datos. Con el ciclo cerrado hay que
; devolver a su sitio la oleada, la altura de salida, las vidas y
; los marcadores, o la segunda partida empezaria donde acabo la
; primera.
; -------------------------------------------------------------
newgam: call blclra             ; sin esto, una explosion viva al acabar
        call clrbmp             ; la partida se borraria luego sobre la
                                ; pantalla nueva, mordiendola
        call ayini              ; el AY vuelve de sndoff apagado
        ld hl,0
        ld (score1),hl
        xor a
        ld (gover),a
        ld (shon),a
        ld (exon),a
        ld (mchnot),a
        ld a,1
        ld (mchcnt),a
        ld a,SWY0               ; primera oleada, arriba del todo
        ld (swy0v),a
        ld a,1
        ld (wave),a
        call hdrini             ; rotulos, marcadores y suelo
        call bsdraw             ; los cuatro escudos
        call swinit             ; formacion de 55 aliens
        call plinit             ; nave y vidas
        call bminit             ; ranuras de proyectiles alien
        jp ufoini               ; nave nodriza

; -------------------------------------------------------------
; gmloop - una partida entera, una vuelta por frame (50 Hz).
;
; Todo el trabajo ocurre justo despues del flanco de VSYNC, con
; ~16 ms por delante antes de que el hardware tome la siguiente
; instantanea de HFILE. El presupuesto es holgado: el enjambre
; solo repinta un alien por frame.
;
; Devuelve Z si el jugador pide salir a BASIC, NZ si la partida
; ha terminado y toca volver al modo de atraccion.
; -------------------------------------------------------------
gmloop: call waitvs
        call swstep             ; mueve un alien de la formacion
        call plmove             ; nave del jugador
        call shupd              ; disparo, impactos y erosion
        call bmupd              ; proyectiles alien
        call exupd              ; destello del alien alcanzado
        call blupd              ; explosiones de proyectil
        call ufoupd             ; nave nodriza
        call sndupd             ; marcha de fondo

        ld a,(swleft)           ; formacion despejada
        or a
        call z,nxtwav

        ld a,(swy)              ; el enjambre ha llegado abajo
        cp SWYMAX
        jr nc,gmlinv
        ld a,(gover)            ; sin vidas
        or a
        jr nz,gmlend
        ld a,KRQWE
        in a,(KBPORT)
        and 1                   ; Q = salir
        jr nz,gmloop
        ret                     ; Z: salir a BASIC

gmlinv: ld a,1
        ld (gover),a
gmlend: call hiupd              ; puntuacion maxima
        call govdrw             ; rotulo de fin de partida
        call sndoff             ; silencio mientras se lee
        ld b,150
        call pause
        or 1
        ret                     ; NZ: volver a la atraccion

; -------------------------------------------------------------
; hiupd - se queda con la mejor puntuacion de la sesion
; -------------------------------------------------------------
hiupd:  ld hl,(score1)
        ld de,(hiscor)
        ld a,h
        cp d
        jr c,hiup1
        jr nz,hiup2
        ld a,l
        cp e
        jr c,hiup1
hiup2:  ld (hiscor),hl
hiup1:  ret

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
        include "explode.inc.asm"
        include "ufo.inc.asm"
        include "sound.inc.asm"
        include "attract.inc.asm"

        end
