; =============================================================
; sound.inc.asm - Sonido por el PEG del SD81 Booster
;
; El PEG es una maquina virtual dentro del interface con acceso
; directo a los registros del AY y tres hilos paralelos. Una vez
; lanzado un efecto no consume ni un ciclo del Z80, asi que el
; sonido sale practicamente gratis dentro del presupuesto de
; frame.
;
; Reparto de hilos:
;   0 - marcha de fondo
;   1 - disparo del jugador y OVNI
;   2 - explosiones
;
; Con solo tres hilos, disparar corta el zumbido del OVNI. Es la
; unica concesion: el resto no se pisa.
;
; Las variables del PEG (V0-V15) son comunes a los tres hilos, asi
; que cada efecto usa las suyas: laser V0-V1, explosiones V4-V5,
; OVNI V2. Compartirlas daria efectos cortandose entre si.
;
; Formato .PEB: cada instruccion son dos bytes en little-endian,
; o sea que 'LD R7,3Eh' (07 3E) se guarda como 3E 07.
; =============================================================

; --- Direcciones en la memoria de programa del PEG (0-255) ---
PGNOTE  equ 0                   ; 4 notas x 7 instrucciones
PGLASR  equ 28                  ; 12
PGEXAL  equ 40                  ; 11
PGEXPL  equ 52                  ; 11
PGUFO   equ 64                  ; 13

MCUTMO  equ 0                   ; 256 sondeos de reloj por byte

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
; sndini - vuelca todos los efectos a la memoria del PEG
; -------------------------------------------------------------
sndini: ld ix,pgtab
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
; sndupd - marcha de fondo: una nota por compas
;
; El tempo sale del numero de aliens vivos, que es exactamente lo
; que hacia el arcade: la musica acelera porque queda menos
; formacion, no porque haya un temporizador que la empuje.
; -------------------------------------------------------------
sndupd: ld hl,mchcnt
        dec (hl)
        ret nz
        call mchper             ; recargar el compas
        ld a,(mchnot)           ; rotar entre las cuatro notas
        inc a
        and 3
        ld (mchnot),a
        ld b,a
        add a,a
        add a,a
        add a,a                 ; nota * 8
        sub b                   ; nota * 7 instrucciones
        add a,PGNOTE
        ld c,0                  ; hilo de la marcha
        jp pegply

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

; -------------------------------------------------------------
; Disparadores de efecto
; -------------------------------------------------------------
sndlas: ld c,1                  ; disparo del jugador
        ld a,PGLASR
        jp pegply

sndexa: ld c,2                  ; explosion de alien
        ld a,PGEXAL
        jp pegply

sndexp: ld c,2                  ; explosion de la nave
        ld a,PGEXPL
        jp pegply

sndufo: ld c,1                  ; zumbido del OVNI
        ld a,PGUFO
        jp pegply

sndufx: ld c,1                  ; callar el OVNI
        jp pegstp

; -------------------------------------------------------------
; Programas PEG
; -------------------------------------------------------------

; --- Las cuatro notas de la marcha, graves y descendentes ---
; LD R7,3Eh / LD R1,ph / LD R0,pl / LD R8,13 / WAIT 120 /
; LD R8,0 / HALT
datnot: defb 03eh,007h, 000h,001h, 0d0h,000h, 00dh,008h
        defb 078h,090h, 000h,008h, 010h,0a0h
        defb 03eh,007h, 003h,001h, 000h,000h, 00dh,008h
        defb 078h,090h, 000h,008h, 010h,0a0h
        defb 03eh,007h, 003h,001h, 038h,000h, 00dh,008h
        defb 078h,090h, 000h,008h, 010h,0a0h
        defb 03eh,007h, 003h,001h, 074h,000h, 00dh,008h
        defb 078h,090h, 000h,008h, 010h,0a0h

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
pgtab:  defw datnot
        defb 56,PGNOTE
        defw datlas
        defb 24,PGLASR
        defw datexa
        defb 22,PGEXAL
        defw datexp
        defb 22,PGEXPL
        defw datufo
        defb 26,PGUFO
NPROG   equ 5

; --- estado de la marcha ---
mchcnt: defb 1                  ; frames que faltan para el compas
mchnot: defb 0                  ; nota actual (0-3)
