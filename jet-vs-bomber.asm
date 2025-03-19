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
JetSpritePtr    word    ; pointer to player0 sprite lookup table
JetColorPtr     word    ; pointer to player0 color lookup table 
BomberSpritePtr word    ; pointer to player1 sprite lookup table
BomberColorPtr  word    ; pointer to player1 color lookup table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Declare constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JET_HEIGHT = 8          ; player0 sprite height (# rows in lookup table)
BOMBER_HEIGHT = 9       ; player1 sprite height (# rows in lookup table)

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
    lda #83
    sta BomberYPos      ; BomberYPos = 83
    lda #54
    sta BomberXPos      ; BomberXPos = 54

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initialize the pointer to the correct lookup table adresses 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #<JetSprite
    sta JetSpritePtr        ; lo-byte pointer for jet sprite lookup table
    lda #>JetSprite
    sta JetSpritePtr+1      ; hi-byte pionter for jet sprite lookup table

    lda #<JetColor
    sta JetColorPtr         ; lo-byte pointer for jet color lookup table 
    lda #>JetColor
    sta JetColorPtr+1       ; hi-byte pointer for jet color lookup table 
    
    lda #<BomberSprite
    sta BomberSpritePtr     ; lo-byte pointer for bomber sprite lookup table
    lda #>BomberSprite
    sta BomberSpritePtr+1   ; hi-byte pionter for bomber sprite lookup table

    lda #<BomberColor
    sta BomberColorPtr      ; lo-byte pointer for bomber color lookup table 
    lda #>BomberColor
    sta BomberColorPtr+1    ; hi-byte pointer for bomber color lookup table 
    

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
; Display the 96 visible scanlines of our main game (because 2-line kernal)
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

    ldx #96             ; x counts the number of remaining scanlines
.GameLineLoop:
.AreWeInsideJetSprite:
    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set before subtraction
    sbc JetYPos         ; subtract sprite Y-coordinate
    cmp JET_HEIGHT      ; are we inside the sprite height bounds?
    bcc .DrawSpriteP0   ; if result < SpriteHeight, call the draw routine
    lda #0              ; else, set the lookup index to zero
.DrawSpriteP0: 
    tay                     ; load Y so we can work with the pointer
    lda (JetSpritePtr),Y    ; load player0 bitmap data from lookup table
    sta WSYNC               ; wait for scanline
    sta GRP0                ; set graphics for player0
    lda (JetColorPtr),Y     ; load player color from lookup table
    sta COLUP0              ; set color of player0 

.AreWeInsideBomberSprite:
    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set before subtraction
    sbc BomberYPos      ; subtract sprite Y-coordinate
    cmp BOMBER_HEIGHT      ; are we inside the sprite height bounds?
    bcc .DrawSpriteP1   ; if result < SpriteHeight, call the draw routine
    lda #0              ; else, set the lookup index to zero
.DrawSpriteP1: 
    tay                     ; load Y so we can work with the pointer

    lda #%00000101          ; max stretch
    sta NUSIZ1              ; stretch player 1 sprite

    lda (BomberSpritePtr),Y ; load player1 bitmap data from lookup table
    sta WSYNC               ; wait for scanline
    sta GRP1                ; set graphics for player1
    lda (BomberColorPtr),Y  ; load player color from lookup table
    sta COLUP1              ; set color of player1 

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
        .byte #%00101000    ;..#.#...
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
        .byte #%01010100    ;.#.#.#..
        .byte #%11111110    ;#######.
        .byte #%11111110    ;#######.
        .byte #%01010100    ;.#.#.#..
        .byte #%00010000    ;...#....
        .byte #%00010000    ;...#....
        .byte #%00111000    ;..###...

JetColor
        .byte #$06;
        .byte #$06;
        .byte #$02;
        .byte #$04;
        .byte #$06;
        .byte #$08;
        .byte #$08;
        .byte #$0A;
BomberColor
        .byte #$00
        .byte #$D4
        .byte #$D0
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