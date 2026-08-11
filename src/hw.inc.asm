; =============================================================
; hw.inc.asm - Constantes de hardware del SD81 Booster
; =============================================================

; --- Registros de control (POKE) ---
HFILEL  equ 2043            ; direccion del fichero de pantalla, byte bajo
HFILEH  equ 2044            ; direccion del fichero de pantalla, byte alto
SFMODE  equ 2045            ; selector de modo Superfast
DBUFR   equ 2057            ; control del doble buffer

; --- Valores de SFMODE ---
SFTEXT  equ 170             ; Superfast texto
SFNATV  equ 171             ; Superfast HiRes nativo (formato ZX81)
SFSPEC  equ 172             ; Superfast HiRes Spectrum
SFOFF   equ 85              ; desactivar Superfast

; --- Valores de DBUFR ---
DBUFON  equ 168             ; +B : doble buffer AUTO, front buffer = bloque B
DBUFMAN equ 200             ; +B : doble buffer MANUAL
DBUFOFF equ 85              ; desactivar doble buffer

; --- Puertos ---
VSPORT  equ 0afh            ; bit 0 = VSYNC
MCUDAT  equ 0a7h            ; puerto de datos del MCU
MCUCTL  equ 0afh            ; control del MCU: bit 7 = reloj (mismo que VSPORT)

; --- Los dos AY hardware, compatibles ZonX-81 ---
; A7 hace de linea BC1: A7=1 selecciona registro, A7=0 escribe dato.
; A3 elige chip: 1 = chip A (ZonX-81 estandar), 0 = chip B (SD81).
; El PEG no usa ninguno de los dos: es un tercer AY dentro del MCU.
AYALAT  equ 0dfh            ; chip A - seleccion de registro
AYADAT  equ 01fh            ; chip A - escritura de dato
AYBLAT  equ 0c6h            ; chip B - seleccion de registro
AYBDAT  equ 006h            ; chip B - escritura de dato

; --- Comandos del MCU ---
CMDLPEG equ 40              ; LOAD_PEG:  1B dir + 1B long + datos
CMDPPEG equ 41              ; PLAY_PEG:  1B hilo + 1B dir
CMDSPEG equ 42              ; STOP_PEG:  1B hilo
CHROMA  equ 7fefh           ; Chroma81: bit 5 = color ON, bits 0-3 = borde
CHRON   equ 20h             ; activar color, borde negro
KBPORT  equ 0feh            ; teclado (A15..A8 seleccionan la media fila)

; --- Mapa de memoria de video ---
; HFILE en el bloque 4 ($8000): bitmap 6144 bytes + atributos 768 bytes.
; El front buffer usa el bloque 5, privado del hardware.
SCRBAS  equ 8000h
SCRLO   equ 000h
SCRHI   equ 080h
ATTBAS  equ 9800h
FRONTB  equ 5

; --- Atributos (formato Spectrum: brillo*64 + papel*8 + tinta) ---
BRIGHT  equ 64
INKBLK  equ 0
INKRED  equ 2
INKGRN  equ 4
INKWHT  equ 7

; --- Medias filas del teclado ZX81 (valor en A antes de IN A,(0FEh)) ---
KRSHZ   equ 0feh            ; SHIFT Z X C V
KRASD   equ 0fdh            ; A S D F G
KRQWE   equ 0fbh            ; Q W E R T
KR123   equ 0f7h            ; 1 2 3 4 5
KR098   equ 0efh            ; 0 9 8 7 6
KRPOI   equ 0dfh            ; P O I U Y
KRENT   equ 0bfh            ; ENTER L K J H
KRSPC   equ 07fh            ; SPACE . M N B

; --- Codigos de caracter del ZX81 (juego de la ROM en $1E00) ---
CHSP    equ 0               ; espacio
CHQUE   equ 15              ; ?
CHGT    equ 18              ; >
CHLT    equ 19              ; <
CHEQ    equ 20              ; =
CHMIN   equ 22              ; -
CHAST   equ 23              ; *
CH0     equ 28              ; '0' .. '9' = 28..37
CHA     equ 38              ; 'A' .. 'Z' = 38..63
CHEOS   equ 255             ; terminador de cadena
GLYPHS  equ 1e00h           ; juego de caracteres de la ROM
