; =============================================================
; text.inc.asm - Texto con el juego de caracteres de la ROM
;
; En modo HiRes no hay generador de caracteres: los glifos se
; copian a mano desde la tabla de la ROM del ZX81 ($1E00, 8
; bytes por caracter). Sirve de andamiaje; la tipografia propia
; del arcade se puede sustituir aqui sin tocar nada mas.
; =============================================================

; -------------------------------------------------------------
; prtchr - imprime un caracter alineado a la celda de 8x8
;   A = codigo ZX81   D = fila (0-23)   E = columna (0-31)
;   preserva DE
; -------------------------------------------------------------
prtchr: ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,GLYPHS
        add hl,bc
        ld (tglf),hl
        push de
        ld a,d
        add a,a
        add a,a
        add a,a
        ld d,a                  ; D = y en pixeles
        ld b,8
pchl:   push bc
        push de
        call pixad
        ex de,hl                ; DE = destino
        ld hl,(tglf)
        ld a,(hl)
        inc hl
        ld (tglf),hl
        ld (de),a
        pop de
        pop bc
        inc d
        djnz pchl
        pop de
        ret

; -------------------------------------------------------------
; prtstr - imprime una cadena terminada en CHEOS
;   HL = cadena   D = fila   E = columna
; -------------------------------------------------------------
prtstr: ld a,(hl)
        cp CHEOS
        ret z
        push hl
        call prtchr
        pop hl
        inc hl
        inc e
        jr prtstr

; -------------------------------------------------------------
; prtbcd - imprime 4 digitos de un marcador en BCD empaquetado
;   HL = marcador (H = millares/centenas, L = decenas/unidades)
;   D = fila   E = columna
; -------------------------------------------------------------
prtbcd: push hl                  ; prtchr usa HL para el glifo
        ld a,h
        call prtbyt
        pop hl
        ld a,l
prtbyt: push af
        rrca
        rrca
        rrca
        rrca
        and 0fh
        add a,CH0
        call prtchr
        inc e
        pop af
        and 0fh
        add a,CH0
        call prtchr
        inc e
        ret

; --- variables ---
tglf:   defw 0                  ; puntero de lectura del glifo
