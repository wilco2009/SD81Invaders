; =============================================================
; savegame.inc.asm - Guardar y recuperar la partida en la SD
;
;   S  guarda      L  recupera
;
; Se puede desde dentro de la partida y desde el modo de
; atraccion, que es lo natural al encender la maquina.
;
; Se guarda solo al jugador en curso, asi que una partida
; recuperada siempre se reanuda como de un jugador. Guardar los
; dos con sus dos formaciones y sus dos juegos de escudos serian
; unos 1400 bytes y no compensa.
;
; Lo que va al fichero:
;
;   bloque del enjambre    68 B   posiciones, oleada y swaliv
;   nave y vidas            2 B
;   marcador                2 B
;   escudos               384 B   tal y como esten erosionados
;   linea del suelo        32 B   sus muescas no estan en swaliv
;
; Los proyectiles, el OVNI y las explosiones no se guardan: al
; recuperar se ponen a cero. Congelar una bomba a media caida no
; aporta nada y complica el reparto de ranuras.
;
; Nada se escribe en pantalla hasta haber validado la longitud,
; de modo que un fichero que no existe o que no cuadra deja la
; partida como estaba.
; =============================================================

SGNLEN  equ 11                  ; "INVADERS.SG"
SGGNDB  equ 32                  ; la linea del suelo, fila entera
SGSZ    equ PLYSW+PLYSP+2+PLYSH+SGGNDB
SGLO    equ SGSZ-256*(SGSZ/256)
SGHI    equ SGSZ/256

; -------------------------------------------------------------
; sgkey - teclas de guardar y recuperar durante la partida
;         A = 0 nada, 1 guardar, 2 recuperar
; -------------------------------------------------------------
sgkey:  ld a,KRASD              ; media fila A S D F G
        in a,(KBPORT)
        bit 1,a                 ; S
        jr z,sgk1
        ld a,KRENT              ; media fila ENTER L K J H
        in a,(KBPORT)
        bit 1,a                 ; L
        jr z,sgk2
        xor a
        ret
sgk1:   ld a,1
        ret
sgk2:   ld a,2
        ret

; sgnsnd - el nombre, en codigos ZX81 y con su longitud delante
sgnsnd: ld a,SGNLEN
        call mcusnd
        ld hl,sgname
        ld b,SGNLEN
sgn1:   ld a,(hl)
        call mcusnd
        inc hl
        djnz sgn1
        ret

; =============================================================
; Guardar
; =============================================================

; sgsblk - manda BC bytes desde HL
sgsblk: ld a,(hl)
        call mcusnd             ; preserva BC y no toca HL
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,sgsblk
        ret

; sgssh - manda la banda de escudos leyendola de la pantalla
sgssh:  ld b,BASH
        ld a,BASEY
        ld (sgrow),a
sgsh1:  push bc
        ld a,(sgrow)
        ld d,a
        ld e,BASECL
        call pixad
        ld bc,BASENB
        call sgsblk
        ld hl,sgrow
        inc (hl)
        pop bc
        djnz sgsh1
        ret

; -------------------------------------------------------------
; sgsave - vuelca la partida al fichero
; -------------------------------------------------------------
sgsave: call sgquiet
        ld a,CMDSAVE
        call mcusnd
        call sgnsnd
        ld a,SGLO               ; longitud, byte bajo primero
        call mcusnd
        ld a,SGHI
        call mcusnd

        ld hl,swx               ; el enjambre
        ld bc,PLYSW
        call sgsblk
        ld hl,plx               ; nave y vidas
        ld bc,PLYSP
        call sgsblk
        call scradr             ; marcador del jugador en curso
        ld bc,2
        call sgsblk
        call sgssh              ; escudos
        ld d,GNDY               ; linea del suelo
        ld e,0
        call pixad
        ld bc,SGGNDB
        call sgsblk
        call mcurcv             ; status
        jp mcufast

; =============================================================
; Recuperar
; =============================================================

; sglblk - recibe BC bytes a partir de HL
sglblk: call mcurcv             ; destruye BC y DE
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,sglblk
        ret

; sglsh - recibe la banda de escudos directamente a la pantalla
sglsh:  ld b,BASH
        ld a,BASEY
        ld (sgrow),a
sglsh1: push bc
        ld a,(sgrow)
        ld d,a
        ld e,BASECL
        call pixad
        ld bc,BASENB
        call sglblk
        ld hl,sgrow
        inc (hl)
        pop bc
        djnz sglsh1
        ret

; sgdrop - se traga los bytes que queden en sgcnt
sgdrop: ld hl,(sgcnt)
        ld a,h
        or l
        ret z
        call mcurcv
        ld hl,(sgcnt)
        dec hl
        ld (sgcnt),hl
        jr sgdrop

; -------------------------------------------------------------
; sgload - recupera la partida. NZ si se ha cargado.
;
; La longitud se comprueba antes de tocar la pantalla: si el
; fichero no esta o no cuadra, se consume la respuesta entera y
; se vuelve sin haber estropeado nada. Dejar bytes sin recoger
; descuadraria al MCU para todo lo que viniera despues.
; -------------------------------------------------------------
sgload: call sgquiet
        ld a,CMDLOAD
        call mcusnd
        call sgnsnd
        call mcurcv             ; longitud que anuncia
        ld (sgcnt),a
        call mcurcv
        ld (sgcnt+1),a
        ld a,(sgcnt+1)
        cp SGHI
        jr nz,sgbad
        ld a,(sgcnt)
        cp SGLO
        jr nz,sgbad

        ld hl,swx               ; el enjambre
        ld bc,PLYSW
        call sglblk
        ld hl,plx               ; nave y vidas
        ld bc,PLYSP
        call sglblk
        ld hl,scorp1            ; siempre se reanuda como jugador 1
        ld bc,2
        call sglblk

        xor a                   ; partida de un jugador, desde cero
        ld (curply),a
        ld (gover),a
        ld (scorp2),a
        ld (scorp2+1),a
        ld a,1
        ld (nplay),a

        ld d,16                 ; ya se puede tocar la pantalla
        ld b,GNDY-16
        call clrbnd
        call hdrini             ; ANTES de restaurar el suelo: hdrini
                                ; repinta la linea entera y borraria
                                ; las muescas recien cargadas
        call sglsh              ; escudos, a su sitio
        ld d,GNDY               ; linea del suelo, con sus muescas
        ld e,0
        call pixad
        ld bc,SGGNDB
        call sglblk

        call mcurcv             ; status
        or a
        jr nz,sgbad2

        call swdraw             ; la formacion como estaba
        call drwliv
        call pldrw
        call bminit             ; lo volatil, a cero
        call ufoini
        call blclra
        xor a
        ld (shon),a
        ld (exon),a
        call mcufast
        ld a,1
        or a
        ret                     ; NZ: cargada

sgbad:  call sgdrop             ; longitud rara: tragarse el resto
        call mcurcv             ; y el status
sgbad2: call mcufast
        xor a
        ret                     ; Z: no se ha cargado

; -------------------------------------------------------------
; sgquiet - callar antes de tocar la SD. El acceso a tarjeta se
;           lleva su tiempo y un efecto del PEG seguiria sonando
;           por su cuenta durante toda la espera.
; -------------------------------------------------------------
sgquiet: call sndufx
        call mchoff
        jp mcuslow              ; y darle a la tarjeta su tiempo

; --- datos ---
sgname: defb CHA+'I'-'A',CHA+'N'-'A',CHA+'V'-'A',CHA+'A'-'A'
        defb CHA+'D'-'A',CHA+'E'-'A',CHA+'R'-'A',CHA+'S'-'A'
        defb CHDOT,CHA+'S'-'A',CHA+'G'-'A'
sgcnt:  defw 0                  ; bytes que quedan por recoger
sgrow:  defb 0                  ; fila en curso al copiar escudos
