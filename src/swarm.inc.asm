; =============================================================
; swarm.inc.asm - El enjambre de 55 aliens
;
; Fidelidad al arcade: el juego mueve UN SOLO alien por frame,
; recorriendo la formacion de abajo a la izquierda hacia arriba a
; la derecha. De ahi salen dos rasgos caracteristicos del
; original y ninguno de los dos hay que programarlo aparte:
;
;   - El enjambre avanza en oleada, no en bloque.
;   - Al morir aliens el barrido salta las casillas vacias, la
;     pasada completa dura menos y la formacion acelera sola.
;
; La formacion es una rejilla rigida, asi que en vez de guardar
; 55 coordenadas se guardan dos: la posicion de la pasada actual
; (swx/swy) y la de la anterior (opx/opy). Los aliens que ya han
; sido barridos usan la primera y los que aun no, la segunda.
; Lo mismo vale para el fotograma de animacion.
; =============================================================

SWCOLS  equ 11                  ; columnas de la formacion
SWROWS  equ 5                   ; filas
SWDX    equ 16                  ; separacion horizontal
SWDY    equ 16                  ; separacion vertical
SWX0    equ 32                  ; x inicial del enjambre
SWY0    equ 32                  ; y de la fila superior
SWADV  equ 2                   ; avance horizontal por pasada
SWDROP  equ 8                   ; descenso al tocar el borde
SWNUM   equ SWROWS*SWCOLS       ; 55

; -------------------------------------------------------------
; swinit - formacion completa en su posicion de salida
;
; swx/swfrm arrancan ya en el estado "siguiente" y el dibujado
; inicial se hace en opx/opy con el fotograma anterior, de forma
; que la primera pasada mueve de verdad en lugar de repintar.
; -------------------------------------------------------------
swinit: ld a,SWX0
        ld (opx),a
        ld a,SWX0+SWADV
        ld (swx),a
        ld a,SWY0
        ld (opy),a
        ld (swy),a
        ld a,SWADV
        ld (swdir),a
        ld a,1
        ld (swfrm),a
        xor a
        ld (swidx),a
        ld (swrank),a
        ld (swcol),a
        ld (swedge),a
        ld hl,swaliv
        ld b,SWNUM
        ld a,1
swi1:   ld (hl),a
        inc hl
        djnz swi1
        ld a,SWNUM
        ld (swleft),a
        jp swdraw

; -------------------------------------------------------------
; swdraw - dibuja la formacion entera (solo al empezar la oleada)
; -------------------------------------------------------------
swdraw: xor a
        ld (crank),a
        ld hl,swaliv
sdwr:   xor a
        ld (ccol),a
sdwc:   ld a,(hl)
        or a
        jr z,sdwsk
        push hl
        call sdrone
        pop hl
sdwsk:  inc hl
        ld a,(ccol)
        inc a
        ld (ccol),a
        cp SWCOLS
        jr c,sdwc
        ld a,(crank)
        inc a
        ld (crank),a
        cp SWROWS
        jr c,sdwr
        ret

; sdrone - dibuja el alien (crank,ccol) en la posicion anterior
sdrone: call salofs             ; B = desplazamiento y, C = x
        ld a,(opx)
        add a,c
        ld e,a
        ld a,(opy)
        add a,b
        ld d,a
        push de
        ld a,(swfrm)
        xor 1
        call salspr
        pop de
        ld b,8
        jp sprdrw

; -------------------------------------------------------------
; swstep - un frame de enjambre: mueve exactamente un alien vivo
; -------------------------------------------------------------
swstep: ld a,(swleft)
        or a
        ret z                   ; TODO: oleada despejada -> siguiente nivel

sst1:   ld hl,swaliv            ; buscar la siguiente casilla ocupada
        ld a,(swidx)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr nz,sst2
        call snext              ; hueco: se salta sin gastar el frame
        jr sst1

sst2:   ld a,(swrank)
        ld (crank),a
        ld a,(swcol)
        ld (ccol),a
        call salofs
        ld a,b
        ld (coy),a
        ld a,c
        ld (cox),a

        ld a,(opx)              ; --- borrar donde estaba ---
        ld hl,cox
        add a,(hl)
        ld e,a
        ld a,(opy)
        ld hl,coy
        add a,(hl)
        ld d,a
        push de
        ld a,(swfrm)
        xor 1                   ; con el fotograma con el que se pinto
        call salspr
        pop de
        ld b,8
        call sprera

        ld a,(swx)              ; --- dibujar donde toca ahora ---
        ld hl,cox
        add a,(hl)
        ld e,a
        ld (cnx),a
        ld a,(swy)
        ld hl,coy
        add a,(hl)
        ld d,a
        push de
        ld a,(swfrm)
        call salspr
        pop de
        ld b,8
        call sprdrw

        call sedge
        jp snext

; -------------------------------------------------------------
; salofs - desplazamiento del alien (crank,ccol) dentro de la
;          formacion.  B = y, C = x.  Deja crow = fila real.
;          rank 0 es la fila de abajo; row 0 es la de arriba.
; -------------------------------------------------------------
salofs: ld a,(ccol)
        add a,a
        add a,a
        add a,a
        add a,a                 ; col * 16
        ld c,a
        ld a,SWROWS-1
        ld hl,crank
        sub (hl)
        ld (crow),a
        add a,a
        add a,a
        add a,a
        add a,a                 ; row * 16
        ld b,a
        ret

; -------------------------------------------------------------
; salspr - puntero al sprite del alien de la fila crow
;          A = fotograma (0/1)  ->  HL.  Destruye BC y DE.
; -------------------------------------------------------------
salspr: add a,a
        add a,a
        add a,a
        add a,a                 ; fotograma * 16 bytes
        ld e,a
        ld d,0
        ld a,(crow)
        add a,a                 ; indice en una tabla de palabras
        ld l,a
        ld h,0
        ld bc,alrow
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ret

; -------------------------------------------------------------
; sedge - marca si el alien recien movido ha tocado un borde.
;         El giro no ocurre aqui: se aplaza al final de la pasada,
;         igual que en el arcade.
;
;         Solo se comprueba el borde hacia el que se marcha. Si se
;         comprobaran los dos, la pasada de bajada -que no avanza
;         en horizontal- volveria a encontrar el enjambre pegado al
;         borde que acaba de tocar, y bajaria en cada pasada sin
;         llegar a cambiar de sentido.
; -------------------------------------------------------------
sedge:  ld a,(swdir)
        or a
        jp m,sedgl
        ld hl,alwid             ; --- marchando a la derecha ---
        ld a,(crow)
        ld e,a
        ld d,0
        add hl,de
        ld a,(cnx)
        add a,(hl)              ; borde derecho del alien
        cp FLDR
        ret c
        jr sedgy
sedgl:  ld a,(cnx)              ; --- marchando a la izquierda ---
        cp FLDL+1
        ret nc
sedgy:  ld a,1
        ld (swedge),a
        ret

; -------------------------------------------------------------
; snext - avanza el barrido una casilla; al agotar la formacion
;         cierra la pasada
; -------------------------------------------------------------
snext:  ld a,(swcol)
        inc a
        cp SWCOLS
        jr nc,snxrow
        ld (swcol),a
        jr snxi
snxrow: xor a
        ld (swcol),a
        ld a,(swrank)
        inc a
        cp SWROWS
        jr nc,spass
        ld (swrank),a
snxi:   ld hl,swidx
        inc (hl)
        ret

; -------------------------------------------------------------
; spass - fin de pasada: la posicion nueva pasa a ser la vieja,
;         cambia el fotograma y, si alguien toco el borde, el
;         enjambre baja e invierte el sentido
; -------------------------------------------------------------
spass:  xor a
        ld (swidx),a
        ld (swcol),a
        ld (swrank),a
        ld a,(swx)
        ld (opx),a
        ld a,(swy)
        ld (opy),a
        ld a,(swfrm)
        xor 1
        ld (swfrm),a
        ld a,(swedge)
        or a
        jr z,spmove
        xor a                   ; --- pasada de bajada ---
        ld (swedge),a
        ld a,(swdir)
        neg
        ld (swdir),a
        ld a,(swy)
        add a,SWDROP
        ld (swy),a
        ret                     ; al bajar no se avanza en horizontal
spmove: ld a,(swx)              ; --- pasada normal ---
        ld hl,swdir
        add a,(hl)
        ld (swx),a
        ret

; -------------------------------------------------------------
; alhit - busca el alien vivo que ocupa el punto de impacto
;         (bimx,bimy) y lo elimina. Si no hay ninguno, no hace
;         nada: el disparo se pierde igual.
;
; Se recorren las 55 casillas en vez de calcular cual toca. Solo
; se llega aqui cuando ya ha habido impacto, o sea muy de vez en
; cuando, y a cambio la busqueda es obviamente correcta pese a
; que media formacion este en la posicion nueva y media en la
; vieja durante el barrido.
; -------------------------------------------------------------
alhit:  xor a
        ld (crank),a
        ld (ccol),a
        ld (cidx),a
        ld hl,swaliv
ahl1:   ld a,(hl)
        or a
        jr z,ahnxt
        push hl
        call ahtest
        pop hl
        jr nz,ahkill
ahnxt:  inc hl
        ld a,(cidx)
        inc a
        ld (cidx),a
        ld a,(ccol)
        inc a
        cp SWCOLS
        jr nc,ahrow
        ld (ccol),a
        jr ahl1
ahrow:  xor a
        ld (ccol),a
        ld a,(crank)
        inc a
        ld (crank),a
        cp SWROWS
        jr c,ahl1
        ret                     ; ningun alien alcanzado

; -------------------------------------------------------------
; ahtest - NZ si el alien (crank,ccol) contiene el punto de
;          impacto. Deja su posicion en cax/cay y la fila en crow.
;
; La casilla usa la posicion nueva si el barrido ya paso por ella
; en esta pasada (cidx < swidx) y la vieja si todavia no.
; -------------------------------------------------------------
ahtest: call salofs             ; B = desplazamiento y, C = x
        ld a,(cidx)
        ld hl,swidx
        cp (hl)
        jr nc,ahtold
        ld a,(swx)              ; ya barrido: posicion nueva
        add a,c
        ld (cax),a
        ld a,(swy)
        add a,b
        ld (cay),a
        jr ahtbox
ahtold: ld a,(opx)              ; aun sin barrer: posicion anterior
        add a,c
        ld (cax),a
        ld a,(opy)
        add a,b
        ld (cay),a

ahtbox: ld a,(bimy)             ; cay <= bimy < cay+8
        ld hl,cay
        sub (hl)
        cp 8
        jr nc,ahtno
        ld a,(bimx)             ; cax <= bimx < cax+ancho
        ld hl,cax
        sub (hl)
        ld c,a
        ld hl,alwid
        ld a,(crow)
        ld e,a
        ld d,0
        add hl,de
        ld a,c
        cp (hl)
        jr nc,ahtno
        ld a,1
        or a
        ret                     ; NZ = alcanzado
ahtno:  xor a
        ret

; -------------------------------------------------------------
; ahkill - borra el alien de la pantalla, lo marca muerto y suma
;          los puntos de su fila
; -------------------------------------------------------------
ahkill: ld a,(cay)
        ld d,a
        ld a,(cax)
        ld e,a
        push de
        ld a,(cidx)             ; borrar con el fotograma con el
        ld hl,swidx             ; que quedo pintado
        cp (hl)
        ld a,(swfrm)
        jr c,ahk1
        xor 1
ahk1:   call salspr
        pop de
        ld b,8
        call sprera

        ld hl,swaliv
        ld a,(cidx)
        ld e,a
        ld d,0
        add hl,de
        ld (hl),0               ; casilla vacia
        ld hl,swleft
        dec (hl)                ; una menos: el barrido acelera

        ld hl,alpts             ; puntuacion de la fila
        ld a,(crow)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        jp addscr

; -------------------------------------------------------------
; addscr - suma A (BCD) al marcador del jugador 1 y lo repinta
; -------------------------------------------------------------
addscr: ld c,a
        ld hl,score1
        ld a,(hl)
        add a,c
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld hl,(score1)
        ld d,ROWSCR
        ld e,COLS1+2
        jp prtbcd

; --- estado del enjambre ---
swx:    defb SWX0               ; x de la pasada actual
swy:    defb SWY0               ; y de la fila superior, pasada actual
opx:    defb SWX0               ; x de la pasada anterior
opy:    defb SWY0
swdir:  defb SWADV             ; sentido de marcha (+/-)
swidx:  defb 0                  ; casilla del barrido, 0..54
swrank: defb 0                  ; 0 = fila de abajo
swcol:  defb 0                  ; 0..10
swfrm:  defb 1                  ; fotograma de la pasada actual
swedge: defb 0                  ; 1 = alguien toco el borde
swleft: defb SWNUM              ; aliens vivos
swaliv: defs SWNUM              ; 1 = vivo, indexado rank*11+col

; --- scratch del alien en curso ---
crank:  defb 0
ccol:   defb 0
crow:   defb 0
cox:    defb 0
coy:    defb 0
cnx:    defb 0
cidx:   defb 0                  ; indice plano en la busqueda de impacto
cax:    defb 0                  ; posicion del alien examinado
cay:    defb 0
