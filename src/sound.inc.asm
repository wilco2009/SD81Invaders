; =============================================================
; sound.inc.asm - Sonido
;
; El interface tiene tres generadores de sonido independientes:
; dos chips AY por hardware (compatibles ZonX-81) y el PEG, que es
; un tercer AY sintetizado dentro del MCU. No comparten registros,
; asi que se pueden usar a la vez sin pisarse.
;
; Reparto:
;
;   AY chip A       marcha de fondo
;   PEG hilo 0      disparo del jugador
;   PEG hilo 1      OVNI
;   PEG hilo 2      explosiones
;
; La marcha va al AY por hardware porque es lo que menos necesita
; del PEG: cuatro tonos fijos, sin envolvente ni ruido, con el
; ritmo marcado desde el bucle de frame. Dejarla ahi libera los
; tres hilos del PEG para los efectos, que si son barridos y
; fundidos, y con ello disparo y OVNI dejan de cortarse.
;
; Los efectos PEG, una vez lanzados, no consumen ni un ciclo del
; Z80: se envian tres bytes al MCU y el efecto suena solo.
;
; Las variables del PEG (V0-V15) son comunes a los tres hilos, asi
; que cada efecto usa las suyas: laser V0-V1, explosiones V4-V5,
; OVNI V2. Compartirlas daria efectos cortandose entre si.
;
; Formato .PEB: cada instruccion son dos bytes en little-endian,
; o sea que 'LD R7,3Eh' (07 3E) se guarda como 3E 07.
; =============================================================

; --- Direcciones en la memoria de programa del PEG (0-255) ---
PGLASR  equ 0                   ; 12 instrucciones
PGEXAL  equ 12                  ; 11
PGEXPL  equ 24                  ; 11
PGUFO   equ 36                  ; 13

MCUTMO  equ 0                   ; 256 sondeos de reloj por byte

; =============================================================
; Marcha de fondo, sobre el AY chip A
; =============================================================

MCHVOL  equ 13                  ; amplitud de la marcha
MCHLEN  equ 6                   ; frames que suena cada nota

; -------------------------------------------------------------
; aywr - escribe E en el registro A del AY chip A
; -------------------------------------------------------------
aywr:   out (AYALAT),a          ; A7=1: seleccionar registro
        ld a,e
        out (AYADAT),a          ; A7=0: escribir el dato
        ret

; -------------------------------------------------------------
; ayini - canal A a tono puro y callado
; -------------------------------------------------------------
ayini:  ld a,7                  ; R7 - habilitacion de canales
        ld e,3eh                ; solo tono A (un bit a 0 activa)
        call aywr
; cae en mchoff para dejarlo en silencio

; -------------------------------------------------------------
; mchoff - callar la nota en curso
;
; Hace falta antes de cualquier pausa larga: mientras la partida
; se detiene (explosion de la nave, cambio de oleada) no se llama
; a sndupd, y sin esto la nota se quedaria sonando fija.
; -------------------------------------------------------------
mchoff: xor a
        ld (mchdur),a
        ld a,8                  ; R8 - amplitud canal A
        ld e,0
        jp aywr

; -------------------------------------------------------------
; sndupd - un frame de marcha
;
; El tempo sale del numero de aliens vivos, que es exactamente lo
; que hacia el arcade: la musica acelera porque queda menos
; formacion, no porque haya un temporizador que la empuje.
; -------------------------------------------------------------
sndupd: ld a,(mchdur)           ; apagar la nota al agotar su duracion
        or a
        jr z,mchu1
        dec a
        ld (mchdur),a
        jr nz,mchu1
        ld a,8
        ld e,0
        call aywr

mchu1:  ld hl,mchcnt            ; siguiente compas
        dec (hl)
        ret nz
        call mchper
        ld a,(mchnot)           ; rotar entre las cuatro notas
        inc a
        and 3
        ld (mchnot),a

        add a,a                 ; dos bytes de periodo por nota
        ld e,a
        ld d,0
        ld hl,mchton
        add hl,de
        ld a,(hl)
        ld e,a
        ld a,0                  ; R0 - periodo bajo canal A
        call aywr
        inc hl
        ld a,(hl)
        ld e,a
        ld a,1                  ; R1 - periodo alto canal A
        call aywr
        ld a,8                  ; R8 - amplitud
        ld e,MCHVOL
        call aywr
        ld a,MCHLEN
        ld (mchdur),a
        ret

; mchper - carga en mchcnt los frames que dura el compas
mchper: ld a,(swleft)
        ld hl,mchtab
mchp1:  cp (hl)
        inc hl
        jr nc,mchp2
        inc hl
        jr mchp1
mchp2:  ld a,(hl)
        ld (mchcnt),a
        ret

; Pares (aliens restantes, frames por compas). Se toma el primero
; cuyo umbral no supere a los aliens vivos; el ultimo es 0 y hace
; de tope.
mchtab: defb 41,30
        defb 31,24
        defb 21,18
        defb 11,13
        defb 6,9
        defb 0,6

; Los cuatro tonos graves descendentes, como periodo del AY
; (byte bajo, byte alto). Calculados para un reloj de AY de
; ~1,625 MHz: periodo = reloj / (16 * frecuencia). Si suenan altos
; o bajos, es aqui donde se ajusta.
mchton: defb 0b3h,002h          ; ~147 Hz
        defb 0dah,002h          ; ~139 Hz
        defb 007h,003h          ; ~131 Hz
        defb 039h,003h          ; ~123 Hz

; =============================================================
; Efectos, sobre el PEG
; =============================================================

; -------------------------------------------------------------
; mcusnd - envia A al MCU y espera a que cambie el bit de reloj
;
; La espera esta acotada a proposito: si el MCU no contestara, un
; bucle incondicional colgaria la partida entera por un efecto de
; sonido. Preferimos perder el sonido antes que el juego.
; -------------------------------------------------------------
mcusnd: push bc
        ld b,a
        in a,(MCUCTL)
        and 80h
        ld c,a                  ; reloj antes de escribir
        ld a,b
        out (MCUDAT),a
        ld b,MCUTMO
mcs1:   in a,(MCUCTL)
        and 80h
        cp c
        jr nz,mcs2              ; ha cambiado: byte aceptado
        djnz mcs1
mcs2:   pop bc
        ret

; -------------------------------------------------------------
; pegld - carga un programa en la memoria del PEG
;         HL = datos, B = longitud en bytes, C = direccion PEG
; -------------------------------------------------------------
pegld:  ld a,CMDLPEG
        call mcusnd
        ld a,c
        call mcusnd             ; direccion de destino
        ld a,b
        call mcusnd             ; longitud
pegl1:  ld a,(hl)
        call mcusnd
        inc hl
        djnz pegl1
        ret

; -------------------------------------------------------------
; pegply - lanza el programa de la direccion A en el hilo C
; -------------------------------------------------------------
pegply: push af
        ld a,CMDPPEG
        call mcusnd
        ld a,c
        call mcusnd
        pop af
        jp mcusnd

; -------------------------------------------------------------
; pegstp - detiene el hilo C
; -------------------------------------------------------------
pegstp: ld a,CMDSPEG
        call mcusnd
        ld a,c
        jp mcusnd

; -------------------------------------------------------------
; sndini - AY listo y efectos volcados al PEG
; -------------------------------------------------------------
sndini: call ayini
        ld ix,pgtab
        ld b,NPROG
sni1:   push bc
        ld l,(ix+0)
        ld h,(ix+1)
        ld b,(ix+2)
        ld c,(ix+3)
        call pegld
        pop bc
        ld de,4
        add ix,de
        djnz sni1
        ret

; -------------------------------------------------------------
; sndoff - silencio total al salir a BASIC
; -------------------------------------------------------------
sndoff: ld a,7
        ld e,3fh                ; AY: todos los canales deshabilitados
        call aywr
        call mchoff
        ld c,0
        call pegstp
        ld c,1
        call pegstp
        ld c,2
        jp pegstp

; -------------------------------------------------------------
; Disparadores de efecto
; -------------------------------------------------------------
sndlas: ld c,0                  ; disparo del jugador
        ld a,PGLASR
        jp pegply

sndufo: ld c,1                  ; zumbido del OVNI
        ld a,PGUFO
        jp pegply

sndufx: ld c,1                  ; callar el OVNI
        jp pegstp

sndexa: ld c,2                  ; explosion de alien
        ld a,PGEXAL
        jp pegply

sndexp: ld c,2                  ; explosion de la nave
        ld a,PGEXPL
        jp pegply

; -------------------------------------------------------------
; Programas PEG
; -------------------------------------------------------------

; --- Laser: barrido de tono de agudo a grave (18 pasos) ---
datlas: defb 03eh,007h, 000h,001h, 00ch,008h, 01eh,020h
        defb 012h,021h, 000h,041h, 00ch,090h, 00ah,030h
        defb 0fch,081h, 000h,008h, 03fh,007h, 010h,0a0h

; --- Explosion de alien: ruido con fundido en 15 pasos (V4) ---
datexa: defb 008h,006h, 037h,007h, 00fh,008h, 064h,090h
        defb 00fh,024h, 084h,041h, 028h,090h, 0fdh,084h
        defb 000h,008h, 03fh,007h, 010h,0a0h

; --- Explosion de la nave: mas grave y mas larga (V5) ---
datexp: defb 014h,006h, 037h,007h, 00fh,008h, 0c8h,090h
        defb 00fh,025h, 085h,041h, 03ch,090h, 0fdh,085h
        defb 000h,008h, 03fh,007h, 010h,0a0h

; --- OVNI: dos tonos alternando 80 veces (V2) ---
datufo: defb 03eh,007h, 00bh,008h, 050h,022h, 001h,001h
        defb 03ch,000h, 023h,090h, 001h,001h, 06eh,000h
        defb 023h,090h, 0f9h,082h, 000h,008h, 03fh,007h
        defb 010h,0a0h

; --- Tabla de volcado: puntero, longitud, direccion PEG ---
pgtab:  defw datlas
        defb 24,PGLASR
        defw datexa
        defb 22,PGEXAL
        defw datexp
        defb 22,PGEXPL
        defw datufo
        defb 26,PGUFO
NPROG   equ 4

; --- estado de la marcha ---
mchcnt: defb 1                  ; frames que faltan para el compas
mchnot: defb 0                  ; nota actual (0-3)
mchdur: defb 0                  ; frames que le quedan a la nota
