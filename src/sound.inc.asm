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
PGLASR  equ 0                   ; 11 instrucciones
PGUFO   equ 12                  ; 12
PGEXAL  equ 24                  ; 10
PGEXPL  equ 36                  ; 10
PGSIL   equ 48                  ; 2
PGSOFF  equ 52                  ; 5

; Un canal del PEG por hilo, para que no se estorben:
;
;   hilo 0  disparo      canal A, tono   R0/R1, R8
;   hilo 1  OVNI         canal B, tono   R2/R3, R9
;   hilo 2  explosiones  canal C, ruido  R6,    R10
;
; R7 (habilitacion) es un registro UNICO para los tres canales, de
; modo que un efecto no puede apagarlo al terminar sin callar
; tambien a los otros dos. Cada efecto lo deja en PEGMIX al
; empezar -operacion idempotente, da igual quien llegue primero- y
; al acabar solo pone a cero SU amplitud.
;
; Ademas, STOP_PEG detiene el programa pero no toca los registros
; del AY: si un efecto continuo se corta a media ejecucion, su
; nota se queda sonando fija. Por eso existe PGSIL, que se lanza
; sobre el hilo despues de pararlo.
PEGMIX  equ 1ch                 ; tono A, tono B y ruido C activos

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
sndupd: ld a,(demoon)           ; la demo va en silencio
        or a
        ret nz
        ld a,(mchdur)           ; apagar la nota al agotar su duracion
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
; (byte bajo, byte alto). Reloj del AY 1,625 MHz, de modo que
; periodo = 1625000 / (16 * frecuencia).
;
; Bajados media octava respecto a la primera version: media octava
; es dividir la frecuencia por raiz de dos, o sea multiplicar el
; periodo por 1,4142. El registro de periodo son 12 bits, asi que
; el tope es 4095 y aqui sobra sitio de sobra.
mchton: defb 0d1h,003h          ; 977  -> ~104 Hz
        defb 008h,004h          ; 1032 ->  ~98 Hz
        defb 048h,004h          ; 1096 ->  ~93 Hz
        defb 08fh,004h          ; 1167 ->  ~87 Hz

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
        ld e,3fh                ; AY hardware: todo deshabilitado
        call aywr
        call mchoff
        ld c,0                  ; parar los tres hilos del PEG...
        call pegstp
        ld c,1
        call pegstp
        ld c,2
        call pegstp
        ld c,0                  ; ...y callar su AY, que pararlos
        ld a,PGSOFF             ; no apaga los registros
        jp pegply

; -------------------------------------------------------------
; Disparadores de efecto
; -------------------------------------------------------------
; Los cuatro salen por sndgo, que es donde se filtra la demo: la
; maquina jugando sola va en silencio.
sndlas: ld c,0                  ; disparo del jugador
        ld a,PGLASR
        jr sndgo

sndufo: ld c,1                  ; zumbido del OVNI
        ld a,PGUFO
        jr sndgo

sndexa: ld c,2                  ; explosion de alien
        ld a,PGEXAL
        jr sndgo

sndexp: ld c,2                  ; explosion de la nave
        ld a,PGEXPL

sndgo:  push af
        ld a,(demoon)
        or a
        pop af
        ret nz
        jp pegply

; Callar el OVNI: pararlo no basta, porque STOP_PEG deja los
; registros del AY como estuvieran y la nota se queda sonando.
; Hay que lanzarle encima el silenciador del canal B. Este no se
; filtra por demo: parar algo que no suena no hace daño, y asi no
; puede quedarse un zumbido colgado.
sndufx: ld c,1
        call pegstp
        ld c,1
        ld a,PGSIL
        jp pegply

; -------------------------------------------------------------
; Programas PEG
; -------------------------------------------------------------

; --- Laser: canal A, barrido de agudo a grave en 18 pasos (V0,V1)
;     LD R7,1Ch / LD R1,0 / LD R8,12 / LD V0,30 / LD V1,18 /
;     bucle: LD R0,V0 / WAIT 12 / ADD V0,10 / DJNZ V1 /
;     LD R8,0 / HALT
datlas: defb 01ch,007h, 000h,001h, 00ch,008h, 01eh,020h
        defb 012h,021h, 000h,041h, 00ch,090h, 00ah,030h
        defb 0fch,081h, 000h,008h, 010h,0a0h

; --- OVNI: canal B, dos tonos alternando 70 veces (V2) ---
; Cada vuelta son 70 ms, o sea 4,9 s en total, algo por encima de
; los 4,5 s que tarda el OVNI en cruzar. Tiene que cubrir el cruce
; entero o se quedaria mudo a media travesia; pasarse no importa,
; porque al retirarlo se le lanza el silenciador.
datufo: defb 01ch,007h, 00bh,009h, 046h,022h, 001h,003h
        defb 03ch,002h, 023h,090h, 001h,003h, 06eh,002h
        defb 023h,090h, 0f9h,082h, 000h,009h, 010h,0a0h

; --- Explosion de alien: canal C, ruido con fundido de 15 (V4) ---
datexa: defb 01ch,007h, 008h,006h, 00fh,00ah, 064h,090h
        defb 00fh,024h, 0a4h,041h, 028h,090h, 0fdh,084h
        defb 000h,00ah, 010h,0a0h

; --- Explosion de la nave: canal C, mas grave y mas larga (V5) ---
datexp: defb 01ch,007h, 014h,006h, 00fh,00ah, 0c8h,090h
        defb 00fh,025h, 0a5h,041h, 03ch,090h, 0fdh,085h
        defb 000h,00ah, 010h,0a0h

; --- Silenciador del canal B, para cortar el OVNI en seco ---
;     LD R9,0 / HALT
datsil: defb 000h,009h, 010h,0a0h

; --- Silencio total del AY del PEG, al salir a BASIC ---
;     LD R8,0 / LD R9,0 / LD R10,0 / LD R7,3Fh / HALT
datsof: defb 000h,008h, 000h,009h, 000h,00ah, 03fh,007h
        defb 010h,0a0h

; --- Tabla de volcado: puntero, longitud, direccion PEG ---
pgtab:  defw datlas
        defb 22,PGLASR
        defw datufo
        defb 24,PGUFO
        defw datexa
        defb 20,PGEXAL
        defw datexp
        defb 20,PGEXPL
        defw datsil
        defb 4,PGSIL
        defw datsof
        defb 10,PGSOFF
NPROG   equ 6

; --- estado de la marcha ---
mchcnt: defb 1                  ; frames que faltan para el compas
mchnot: defb 0                  ; nota actual (0-3)
mchdur: defb 0                  ; frames que le quedan a la nota
