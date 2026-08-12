; =============================================================
; hiscore.inc.asm - La puntuacion maxima, guardada en la SD
;
; Esto no estaba en el arcade: alli el record se perdia al apagar
; la maquina. Aqui sobrevive en un fichero HISCORE.HI de dos
; bytes, en el mismo directorio desde el que se cargo el juego.
;
; La extension no es decorativa y no puede omitirse: un nombre sin
; ella se trata como .P, o sea como un programa BASIC, y los dos
; bytes no sobrevivirian al viaje. Tampoco vale cualquiera - .ROM
; carga en la direccion 0 y resetea la maquina, y .WAV se
; reproduce. .HI no significa nada para el MCU, que es justo lo
; que se busca: que devuelva los bytes tal cual.
;
; El nombre va en ASCII, no en codigos ZX81: al otro lado hay una
; FAT32.
;
; Protocolo, como el del PEG: se escriben bytes en el puerto de
; datos ($A7) y el bit 7 del de control ($AF) se invierte con
; cada operacion, sea de lectura o de escritura. Hay que esperar
; ese cambio antes de la siguiente.
;
; Todas las esperas estan acotadas. Un record que no se guarda es
; un fastidio; una partida colgada porque el MCU no contesta, no.
; =============================================================

HSNLEN  equ 10                  ; "HISCORE.HI"

; -------------------------------------------------------------
; mcurcv - recibe un byte del MCU. Destruye BC y DE.
;
; El dato ya esta puesto cuando se entra: lo garantiza la espera
; de la operacion anterior. Se lee primero y despues se aguarda
; el cambio de reloj, que es el MCU diciendo que ya tiene listo
; lo siguiente.
;
; El plazo es de 16 bits y no de 8 como en mcusnd, porque aqui se
; espera al MCU trabajando: un SAVE toca la tarjeta de verdad y
; tarda milisegundos, no microsegundos.
; -------------------------------------------------------------
mcurcv: in a,(MCUCTL)
        and 80h
        ld d,a                  ; reloj antes de leer
        in a,(MCUDAT)
        ld e,a                  ; el dato
        ld bc,0                 ; 65536 sondeos
mrc1:   in a,(MCUCTL)
        and 80h
        cp d
        jr nz,mrc2              ; ha cambiado
        dec bc
        ld a,b
        or c
        jr nz,mrc1
mrc2:   ld a,e
        ret

; -------------------------------------------------------------
; hsnsnd - envia el nombre precedido de su longitud, que es como
;          el MCU espera todas las cadenas
; -------------------------------------------------------------
hsnsnd: ld a,HSNLEN
        call mcusnd
        ld hl,hsname
        ld b,HSNLEN
hsn1:   ld a,(hl)
        call mcusnd             ; preserva BC y no toca HL
        inc hl
        djnz hsn1
        ret

; -------------------------------------------------------------
; hsload - lee el record de la SD al arrancar
;
; Se consume la respuesta entera pase lo que pase, incluido el
; status, aunque el contenido no sirva. Dejar bytes sin recoger
; descuadraria al MCU para todo lo que viniera despues, que en
; este juego es el volcado de los efectos al PEG.
; -------------------------------------------------------------
hsload: ld a,CMDLOAD
        call mcusnd
        call hsnsnd
        xor a
        ld (hsok),a
        call mcurcv             ; longitud, byte bajo
        ld (hscnt),a
        call mcurcv             ; byte alto
        ld (hscnt+1),a
        ld hl,(hscnt)
        ld a,h
        or l
        jr z,hsst               ; sin datos: no habia fichero

        call mcurcv
        ld (hsval),a
        call hsdec
        jr z,hsst
        call mcurcv
        ld (hsval+1),a
        ld a,1
        ld (hsok),a             ; ya hay dos bytes buenos
        call hsdec
        jr z,hsst
hsdrp:  call mcurcv             ; lo que sobre, a la basura
        call hsdec
        jr nz,hsdrp

hsst:   call mcurcv             ; status
        or a
        ret nz                  ; no se pudo leer: el record queda a 0
        ld a,(hsok)
        or a
        ret z
        ld hl,(hsval)
        ld (hiscor),hl
        ret

; hsdec - una unidad menos en hscnt; Z cuando se agota
hsdec:  ld hl,(hscnt)
        dec hl
        ld (hscnt),hl
        ld a,h
        or l
        ret

; -------------------------------------------------------------
; hssave - escribe el record en la SD
; -------------------------------------------------------------
hssave: ld a,CMDSAVE
        call mcusnd
        call hsnsnd
        ld a,2                  ; longitud del bloque
        call mcusnd
        xor a
        call mcusnd
        ld a,(hiscor)
        call mcusnd
        ld a,(hiscor+1)
        call mcusnd
        jp mcurcv               ; status, que llega tras tocar la SD

; --- datos ---
hsname: defb 'H','I','S','C','O','R','E','.','H','I'
hsval:  defw 0                  ; lo leido del fichero
hscnt:  defw 0                  ; bytes que quedan por recoger
hsok:   defb 0                  ; 1 = se leyeron los dos bytes
hsnew:  defb 0                  ; 1 = el record ha cambiado
