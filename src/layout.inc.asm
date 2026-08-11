; =============================================================
; layout.inc.asm - Geometria del campo de juego
;
; El arcade es una pantalla vertical de 224x256. Aqui el campo
; ocupa 224 px de ancho (x 16..239) manteniendo la escala
; horizontal 1:1 del original, y el eje vertical se comprime a
; las 192 lineas disponibles conservando el orden y las
; proporciones de las bandas.
; =============================================================

FLDL    equ 16                  ; borde izquierdo del campo
FLDR    equ 240                 ; borde derecho del campo

; --- Bandas verticales ---
ROWLBL  equ 0                   ; fila de texto de los rotulos
ROWSCR  equ 1                   ; fila de texto de los marcadores
UFOY    equ 18                  ; banda del OVNI
BASEY   equ 136                 ; escudos (16 px de alto)
PLY     equ 160                 ; nave del jugador
GNDY    equ 176                 ; linea de suelo
ROWLIV  equ 23                  ; fila de texto de vidas y creditos

; --- Nave del jugador ---
PLW     equ 13                  ; ancho en pixeles
PLXMIN  equ FLDL
PLXMAX  equ FLDR-PLW
PLX0    equ 122                 ; centrada al empezar
PLLIV0  equ 3                   ; vidas iniciales

; y del enjambre a la que se considera invasion: la fila de abajo
; alcanza la altura de la nave
SWYMAX  equ PLY-64-8

; --- Columnas de texto de los tres marcadores ---
COLS1   equ 1
COLHI   equ 12
COLS2   equ 23
