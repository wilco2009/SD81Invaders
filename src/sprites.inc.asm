; =============================================================
; sprites.inc.asm - Graficos del arcade de 1978
;
; Formato: 2 bytes por linea (celda de 16 px), bit 7 = pixel
; izquierdo. Los sprites mas estrechos van alineados a la
; izquierda y rellenos de ceros por la derecha.
;
; Cada alien ocupa 32 bytes: frame 0 seguido de frame 1. La
; animacion es de dos fotogramas y cambia cuando el alien se
; mueve, igual que en el original.
;
; Extraidos de la ROM original de Taito (romset MAME 'invaders',
; los cuatro ficheros unidos como $0000-$1FFF):
;
;   $1C00 pulpo A     $1C30 pulpo B
;   $1C10 cangrejo A  $1C40 cangrejo B
;   $1C20 calamar A   $1C50 calamar B
;   $1C60 nave        $1D68 OVNI
;
; El video del arcade va girado, de modo que en la ROM cada byte
; es una columna de 8 pixeles y el bit 7 es el de arriba. Aqui se
; guardan por filas, dos bytes por linea, y recortados a la
; izquierda: el mismo desplazamiento para los dos fotogramas de
; cada tipo, o la animacion daria un salto lateral.
; =============================================================

; --- Squid / calamar - fila superior, 30 puntos - 8x8 ---
sqda:   defb 00011000b,00000000b
        defb 00111100b,00000000b
        defb 01111110b,00000000b
        defb 11011011b,00000000b
        defb 11111111b,00000000b
        defb 00100100b,00000000b
        defb 01011010b,00000000b
        defb 10100101b,00000000b

        defb 00011000b,00000000b
        defb 00111100b,00000000b
        defb 01111110b,00000000b
        defb 11011011b,00000000b
        defb 11111111b,00000000b
        defb 01011010b,00000000b
        defb 10000001b,00000000b
        defb 01000010b,00000000b

; --- Crab / cangrejo - filas 2 y 3, 20 puntos - 11x8 ---
crba:   defb 00100000b,10000000b
        defb 10010001b,00100000b
        defb 10111111b,10100000b
        defb 11101110b,11100000b
        defb 11111111b,11100000b
        defb 01111111b,11000000b
        defb 00100000b,10000000b
        defb 01000000b,01000000b

        defb 00100000b,10000000b
        defb 00010001b,00000000b
        defb 00111111b,10000000b
        defb 01101110b,11000000b
        defb 11111111b,11100000b
        defb 10111111b,10100000b
        defb 10100000b,10100000b
        defb 00011011b,00000000b

; --- Octopus / pulpo - filas 4 y 5, 10 puntos - 12x8 ---
octa:   defb 00001111b,00000000b
        defb 01111111b,11100000b
        defb 11111111b,11110000b
        defb 11100110b,01110000b
        defb 11111111b,11110000b
        defb 00011001b,10000000b
        defb 00110110b,11000000b
        defb 11000000b,00110000b

        defb 00001111b,00000000b
        defb 01111111b,11100000b
        defb 11111111b,11110000b
        defb 11100110b,01110000b
        defb 11111111b,11110000b
        defb 00111001b,11000000b
        defb 01100110b,01100000b
        defb 00110000b,11000000b

; --- Nave del jugador - 13x8 ---
plship: defb 00000010b,00000000b
        defb 00000111b,00000000b
        defb 00000111b,00000000b
        defb 01111111b,11110000b
        defb 11111111b,11111000b
        defb 11111111b,11111000b
        defb 11111111b,11111000b
        defb 11111111b,11111000b

; --- OVNI / nave nodriza - 16x7 ---
ufospr: defb 00000111b,11100000b
        defb 00011111b,11111000b
        defb 00111111b,11111100b
        defb 01101101b,10110110b
        defb 11111111b,11111111b
        defb 00111001b,10011100b
        defb 00010000b,00001000b

; --- Tabla fila -> tipo de alien (fila 0 = la de arriba) ---
alrow:  defw sqda               ; fila 0 - calamar   30 pts
        defw crba               ; fila 1 - cangrejo  20 pts
        defw crba               ; fila 2 - cangrejo  20 pts
        defw octa               ; fila 3 - pulpo     10 pts
        defw octa               ; fila 4 - pulpo     10 pts

; --- Ancho real en pixeles, por fila (para tocar el borde) ---
alwid:  defb 8,11,11,12,12

; --- Puntuacion por fila, en BCD (pendiente de usar) ---
alpts:  defb 30h,20h,20h,10h,10h
