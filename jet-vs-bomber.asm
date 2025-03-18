    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Include required files with VCS register memory mapping and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Declare the variables starting from memory address $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80

JetXPos         byte    ; player-0 x-position
JetYPos         byte    ; player-0 y-position
BomberXPos      byte    ; player-1 x-position
BomberYPos      byte    ; player-1 y-position

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start our ROM code at memory address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg Code
    org $F000

Reset:
    CLEAN_START         ; call macro to reset memory and registers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initialize RAM variables and TIA registers 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #10
    sta JetYPos         ; JetYPos = 10
    lda #60
    sta JetXPos         ; JetXPos = 60

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start the main display loop and frame rendering 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Display the VSYNC and VBLACK 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK          ; turn on VBLANK
    sta VSYNC           ; turn on VSYNC
    REPEAT 3
        sta WSYNC       ; display 3 recommended lines of VSYNC
    REPEND
    lda #0
    sta VSYNC           ; turn off VSYNC
    REPEAT 37
        sta WSYNC       ; display the 37 recommended lines of VBLANK
    REPEND
    sta VBLANK          ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Display the 192 visible scanlines of our main game
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:
    lda #$84
    sta COLUBK          ; set background / river color to blue
    lda #$C2
    sta COLUPF          ; set playfield / grass color to green
    lda #%00000001
    sta CTRLPF          ; enable playfield to be reflected, rather than repeated
    lda #$F0            
    sta PF0             ; set PF0 bit pattern
    lda #$FC
    sta PF1             ; set PF1 bit pattern
    lda #0
    sta PF2             ; set PF2 bit pattern

    ldx #192            ; x counts the number of remaining scanlines
.GameLineLoop:
    sta WSYNC
    dex                 ; x--
    bne .GameLineLoop   ; repeat next main game scanline until finished

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Display Overscan
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK          ; turn on VBLANK again
    REPEAT 30
        sta WSYNC       ; display 30 recommended lines of VBLANK Overscan
    REPEND
    lda #0
    sta VBLANK          ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Loop back to start a brand new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame      ; continue to display the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JetSprite
        .byte #%00000000    ;........
        .byte #%00111000    ;..###...
        .byte #%00010000    ;...#....
        .byte #%11111110    ;#######.
        .byte #%01111100    ;.#####..
        .byte #%00111000    ;..###...
        .byte #%00010000    ;...#....
        .byte #%00010000    ;...#....
JetRightTurnSprite
        .byte #%00000000    ;........
        .byte #%00100100    ;..#..#..
        .byte #%01101000    ;.##.#...
        .byte #%00011000    ;...##...
        .byte #%00111000    ;..###...
        .byte #%01011000    ;.#.##...
        .byte #%00001100    ;....##..
        .byte #%00000100    ;.....#..
JetLeftTurnSprite
        .byte #%00000000    ;........
        .byte #%01001000    ;.#..#...
        .byte #%00101100    ;..#.##..
        .byte #%00110000    ;..##....
        .byte #%00111000    ;..###...
        .byte #%01110100    ;.###.#..
        .byte #%01000000    ;.#......
        .byte #%00000000    ;........

BomberSprite
        .byte #%00000000    ;........
        .byte #%00010000    ;...#....
        .byte #%00010000    ;...#....
        .byte #%10111010    ;#.###.#.
        .byte #%11111110    ;#######.
        .byte #%10010010    ;#..#..#.
        .byte #%00010000    ;...#....
        .byte #%00010000    ;...#....
        .byte #%00111000    ;..###...

JetColorFrame
        .byte #$04
        .byte #$04
        .byte #$04
        .byte #$06
        .byte #$06
        .byte #$08
        .byte #$08
        .byte #$08
BomberColorFrame
        .byte #$D4
        .byte #$D2
        .byte #$D2
        .byte #$D4
        .byte #$D2
        .byte #$D2
        .byte #$D0
        .byte #$D4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Complete ROM size with exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC           ; move to position $FFFC
    word Reset          ; write 2 bytes with the program reset address
    word Reset          ; write 2 bytes with the interruption vector