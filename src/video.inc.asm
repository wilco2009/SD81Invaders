; =============================================================
; video.inc.asm - Modo de video, sincronismo y blitter de sprites
;
; Modo Superfast HiRes Spectrum: la FPGA refresca la pantalla sin
; robar ciclos al Z80, y el doble buffer hardware toma una
; instantanea completa de HFILE en cada blanking vertical.
; =============================================================

; -------------------------------------------------------------
; vinit - configura HFILE, limpia, pinta atributos y activa el modo
; -------------------------------------------------------------
vinit:  ld a,SCRLO
        ld (HFILEL),a
        ld a,SCRHI
        ld (HFILEH),a
        call clrbmp
        call clratt
        ld bc,CHROMA
        ld a,CHRON              ; color Chroma81 ON, borde negro
        out (c),a
        ld a,SFSPEC
        ld (SFMODE),a           ; Superfast HiRes Spectrum
        ld a,DBUFON+FRONTB      ; doble buffer AUTO, front = bloque 5
        ld (DBUFR),a
        ret

; -------------------------------------------------------------
; vdone - restaura el ZX81 al modo normal antes de volver a BASIC
; -------------------------------------------------------------
vdone:  ld a,DBUFOFF
        ld (DBUFR),a
        ld a,SFOFF
        ld (SFMODE),a
        ld bc,CHROMA
        xor a
        out (c),a
        ret

; -------------------------------------------------------------
; waitvs - espera el flanco de subida del VSYNC (bit 0, puerto $AF)
;
; A partir de aqui hay ~16 ms hasta la siguiente instantanea: todo
; el borrado y redibujado debe caber en esa ventana.
;
; La espera esta acotada a proposito. Si el core o el emulador no
; implementan el bit de VSYNC, el puerto devuelve siempre el mismo
; valor y una espera incondicional colgaria el juego con la imagen
; congelada. Al agotarse la cuenta se marca el puerto como no
; disponible y se pasa a un retardo fijo de un frame: se pierde el
; sincronismo y aparece tearing, pero el juego corre.
; -------------------------------------------------------------
VSTMO   equ 4000                ; sondeos por fase (~3 frames)
VSDLY   equ 2000                ; retardo de respaldo (~16 ms)

waitvs: ld a,(vsok)
        or a
        jr z,vsfree             ; puerto ya descartado
        ld bc,VSTMO
wvs1:   in a,(VSPORT)
        rrca
        jr nc,wvs1b             ; fuera del vsync: esperar el flanco
        dec bc
        ld a,b
        or c
        jr nz,wvs1
        jr vsfail
wvs1b:  ld bc,VSTMO
wvs2:   in a,(VSPORT)
        rrca
        ret c                   ; flanco de subida del VSYNC
        dec bc
        ld a,b
        or c
        jr nz,wvs2
vsfail: xor a
        ld (vsok),a             ; no hay VSYNC utilizable
vsfree: ld bc,VSDLY
vsd1:   dec bc
        ld a,b
        or c
        jr nz,vsd1
        ret

vsok:   defb 1                  ; 1 = el puerto $AF da VSYNC

; -------------------------------------------------------------
; clrbmp - borra los 6144 bytes del bitmap
; -------------------------------------------------------------
clrbmp: ld hl,SCRBAS
        ld de,SCRBAS+1
        ld bc,6143
        ld (hl),0
        ldir
        ret

; -------------------------------------------------------------
; clratt - bandas de color al estilo de la lamina del arcade:
;   filas  0-1   blanco  - marcadores
;   filas  2-3   rojo    - banda del OVNI
;   filas  4-16  blanco  - enjambre
;   filas 17-23  verde   - escudos, nave y suelo
; -------------------------------------------------------------
clratt: ld hl,ATTBAS
        ld de,2*32
        ld a,BRIGHT+INKWHT
        call attfil
        ld de,2*32
        ld a,BRIGHT+INKRED
        call attfil
        ld de,13*32
        ld a,BRIGHT+INKWHT
        call attfil
        ld de,7*32
        ld a,BRIGHT+INKGRN
        call attfil
        ret

; attfil - rellena DE bytes con el atributo A desde HL
;          deja HL justo detras de la banda rellenada
attfil: ld c,a
attf1:  ld (hl),c
        inc hl
        dec de
        ld a,d
        or e
        jr nz,attf1
        ret

; -------------------------------------------------------------
; pixad - direccion del byte de pantalla de un pixel
;
;   D = fila (0-191)   E = columna en bytes (0-31)  ->  HL
;
; Formato Spectrum: H = base | (y7y6)>>3 | y2y1y0
;                   L = (y5y4y3)<<2 | x
; -------------------------------------------------------------
pixad:  ld a,d
        and 0c0h
        rrca
        rrca
        rrca
        ld h,a
        ld a,d
        and 7
        or h
        or SCRHI
        ld h,a
        ld a,d
        and 38h
        add a,a
        add a,a
        or e
        ld l,a
        ret

; -------------------------------------------------------------
; sprdrw / sprera - blitter de sprites con desplazamiento a pixel
;
;   HL = datos del sprite (2 bytes por linea, bit 7 = pixel izquierdo)
;   D  = y (0-191)
;   E  = x (0-255)
;   B  = alto en lineas
;
; sprdrw dibuja con OR. sprera borra AND NOT: quita exactamente los
; pixeles del sprite, no un rectangulo. Es lo que permite el barrido
; en oleada del enjambre sin que un alien mutile a su vecino, que
; esta a solo 16 px y todavia no se ha movido.
;
; Invariante: x <= 232, para que la ventana de 3 bytes nunca cruce
; el final de la linea de barrido (columna+2 <= 31).
; -------------------------------------------------------------
sprdrw: ld a,1
        jr sprgo
sprera: xor a
sprgo:  ld (bmode),a
        ld (bsrc),hl
        ld a,b
        ld (bcnt),a
        ld a,e
        and 7
        ld (bshf),a
        ld a,e
        rrca
        rrca
        rrca
        and 1fh
        ld e,a                  ; E = columna en bytes

sprlin: push de
        call pixad              ; HL = destino
        push hl
        ld hl,(bsrc)
        ld b,(hl)               ; B = byte izquierdo del sprite
        inc hl
        ld c,(hl)               ; C = byte derecho
        inc hl
        ld (bsrc),hl
        pop hl
        ld d,0                  ; D = arrastre hacia el tercer byte
        ld a,(bshf)
        or a
        jr z,sprput
sprsh:  srl b
        rr c
        rr d
        dec a
        jr nz,sprsh

sprput: ld a,(bmode)
        or a
        jr z,spreb
        ld a,(hl)               ; --- OR: dibujar ---
        or b
        ld (hl),a
        inc l
        ld a,(hl)
        or c
        ld (hl),a
        inc l
        ld a,(hl)
        or d
        ld (hl),a
        jr sprnx
spreb:  ld a,b                  ; --- AND NOT: borrar ---
        cpl
        and (hl)
        ld (hl),a
        inc l
        ld a,c
        cpl
        and (hl)
        ld (hl),a
        inc l
        ld a,d
        cpl
        and (hl)
        ld (hl),a

sprnx:  pop de
        inc d
        ld a,(bcnt)
        dec a
        ld (bcnt),a
        jr nz,sprlin
        ret

; -------------------------------------------------------------
; pixtst - NZ si el pixel (E = x, D = y) esta encendido
;          preserva DE
;
; La deteccion de impactos se hace leyendo la propia pantalla, que
; es donde ya esta todo dibujado. Asi el disparo choca con lo que
; se ve, sin llevar una lista aparte de lo que hay en cada sitio.
; -------------------------------------------------------------
pixtst: push de
        ld a,e
        and 7
        ld b,a                  ; B = bit dentro del byte
        ld a,e
        rrca
        rrca
        rrca
        and 1fh
        ld e,a
        call pixad
        ld a,80h                ; mascara = 80h >> B
        inc b
ptm1:   dec b
        jr z,ptm2
        rrca
        jr ptm1
ptm2:   and (hl)
        pop de
        ret

; -------------------------------------------------------------
; clrbnd - borra B lineas completas de pantalla desde la linea D
; -------------------------------------------------------------
clrbnd: push bc
        push de
        ld e,0
        call pixad
        ld b,32
cbn1:   ld (hl),0
        inc l
        djnz cbn1
        pop de
        pop bc
        inc d
        djnz clrbnd
        ret

; -------------------------------------------------------------
; hline - linea horizontal solida
;   D = y, E = columna inicial en bytes, B = ancho en bytes
; -------------------------------------------------------------
hline:  call pixad
hlin1:  ld (hl),0ffh
        inc l
        djnz hlin1
        ret

; --- variables del blitter ---
bsrc:   defw 0                  ; puntero de lectura del sprite
bmode:  defb 0                  ; 1 = OR, 0 = AND NOT
bshf:   defb 0                  ; desplazamiento en pixeles (0-7)
bcnt:   defb 0                  ; lineas pendientes
