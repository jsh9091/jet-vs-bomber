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
Score           byte    ; 2-digit score stored as BCD
Timer           byte    ; 2-digit timer stored as BCD
Temp            byte    ; auxiliary vaiable to store temp score values
OnesDigitOffset word    ; lookup table offset for the score 1's digit
TensDigitOffset word    ; lookup table offset for the score 10's digit
JetSpritePtr    word    ; pointer to player0 sprite lookup table
JetColorPtr     word    ; pointer to player0 color lookup table 
BomberSpritePtr word    ; pointer to player1 sprite lookup table
BomberColorPtr  word    ; pointer to player1 color lookup table
JetAnimOffSet   byte    ; player0 sprite offset for animation
Random          byte    ; radom number generate to set enemy position 
ScoreSprite     byte    ; store the sprite bit pattern for the score
TimerSprite     byte    ; store the sprite bit pattern for the timer
TerrainColor    byte    ; store the color of the terrain
RiverColor      byte    ; store the color of the river

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Declare constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JET_HEIGHT = 8          ; player0 sprite height (# rows in lookup table)
BOMBER_HEIGHT = 9       ; player1 sprite height (# rows in lookup table)
DIGITS_HEIGHT = 5       ; scoreboard digit height (#rows in lookup table)

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
    lda #65
    sta JetXPos         ; JetXPos = 65
    lda #83
    sta BomberYPos      ; BomberYPos = 83
    lda #54
    sta BomberXPos      ; BomberXPos = 54
    lda #%11010100
    sta Random          ; Random = $D4
    lda #0
    sta Score
    sta Timer           ; Score = Timer = 0

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
    REPEAT 33
        sta WSYNC       ; display the recommended lines of VBLANK
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Calculations and tasks performed in the VBLANK 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda JetXPos
    ldy #0
    jsr SetObjectXPos           ; set player0 horizontal position

    lda BomberXPos
    ldy #1
    jsr SetObjectXPos           ; set player1 horizontal postion

    jsr CalculateDigitOffset    ; calculate the scoreboard digit lookup table offset

    sta WSYNC
    sta HMOVE                   ; apply the horizontal offsets previously set

    lda #0
    sta VBLANK          ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Display the scoreboard lines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #0
    sta COLUBK
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta CTRLPF
    sta COLUBK              ; reset TIA resgisters before displaying the score

    lda #$1E
    sta COLUPF              ; set the scoreboard color

    ldx #DIGITS_HEIGHT      ; start X counter with 5 (height of digits)

.ScoreDigitLoop:
    ldy TensDigitOffset     ; get the tens digit offset for the Score
    lda Digits,Y            ; load the bit pattern from the lookup table
    and #$F0                ; mask/remove the graphics for the ones digit 
    sta ScoreSprite         ; save the score tens digit pattern in a variable
    
    ldy OnesDigitOffset     ; get the ones digit offset for the Score 
    lda Digits,Y            ; load the digit bit pattern from the lookup table 
    and #$0F                ; mask/remove the graphics for the tens digit
    ora ScoreSprite         ; merge it with the saved tens digit sprite 
    sta ScoreSprite         ; and save it
    sta WSYNC               ; wait for the end of scanline
    sta PF1                 ; update the playfield to display the Score sprite 

    ldy TensDigitOffset+1   ; get the left digit offset for the Timer
    lda Digits,Y            ; load teh digit pattern from the lookup table
    and #$F0                ; mask/remove the graphics for the ones digit
    sta TimerSprite         ; save the timer tens digit pattern in a variable 

    ldy OnesDigitOffset+1   ; get the ones digit offset for the timer
    lda Digits,Y            ; load digit pattern from lookup table 
    and #$0F                ; mask/remove the grahpics for the tens digit 
    ora TimerSprite         ; merge iwththe saved tens digit graphics 
    sta TimerSprite         ; and save it

    jsr Sleep12Cycles       ; waste some cycles 

    sta PF1                 ; update the playfield for Timer display

    ldy ScoreSprite         ; preload for next scanline
    sta WSYNC               ; wait for next scanline 

    sty PF1                 ; update playfield for the score 
    inc TensDigitOffset
    inc TensDigitOffset+1
    inc OnesDigitOffset
    inc OnesDigitOffset+1   ; increment all digits for the next line of data

    jsr Sleep12Cycles       ; waste some cycles 

    dex                     ; X--
    sta PF1                 ; update the playfield for the Timer display
    bne .ScoreDigitLoop     ; if dex !=0, then branch to ScoreDigitLoop

    sta WSYNC  

    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta WSYNC  
    sta WSYNC  
    sta WSYNC  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Display the 96 visible scanlines of our main game (because 2-line kernal)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:
    lda TerrainColor
    sta COLUPF          ; set the terrain background color

    lda RiverColor
    sta COLUBK          ; set the river background color

    lda #%00000001
    sta CTRLPF          ; enable playfield to be reflected, rather than repeated
    lda #$F0            
    sta PF0             ; set PF0 bit pattern
    lda #$FC
    sta PF1             ; set PF1 bit pattern
    lda #0
    sta PF2             ; set PF2 bit pattern

    ldx #85             ; x counts the number of remaining scanlines
.GameLineLoop:
.AreWeInsideJetSprite:
    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set before subtraction
    sbc JetYPos         ; subtract sprite Y-coordinate
    cmp JET_HEIGHT      ; are we inside the sprite height bounds?
    bcc .DrawSpriteP0   ; if result < SpriteHeight, call the draw routine
    lda #0              ; else, set the lookup index to zero
.DrawSpriteP0: 
    clc                     ; clear carry flag before addition
    adc JetAnimOffSet       ; jump to correct sprite frame address in memory

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

    lda #0
    sta JetAnimOffSet   ; reset sprite animationm to first frame

    sta WSYNC

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
; Process joystick input for player0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckP0Up:
    lda #%00010000      ; player0 joystick up
    bit SWCHA
    bne CheckP0Down     ; if pattern does not match, bypass Up block
    lda JetYPos
    cmp #75             ; if (player 0 Y position > 75)
    bpl CheckP0Down     ;  then, skip increment 
    inc JetYPos         ;  else, incremnt Y
    lda #0
    sta JetAnimOffSet   ; reset sprite animationm to first frame

CheckP0Down:
    lda #%00100000      ; player0 joystick down
    bit SWCHA
    bne CheckP0Left
    lda JetYPos
    cmp #5              ; if (player 0 Y position < 5)
    bmi CheckP0Left     ;  then, skip decrement
    dec JetYPos         ;  else, decrement
    lda #0
    sta JetAnimOffSet   ; reset sprite animationm to first frame

CheckP0Left:
    lda #%01000000      ; player0 joystick left
    bit SWCHA
    bne CheckP0Right    
    lda JetXPos
    cmp #35             ; if (player 0 X position < 35)
    bmi CheckP0Right    ;  then, skip decrement
    dec JetXPos         ;  else, decrement
    lda #16             ; JET_HEIGHT x 2 - TODO: re-write without magic number
    sta JetAnimOffSet   ; set animation offset to the second frame

CheckP0Right:
    lda #%10000000      ; player0 joystick right
    bit SWCHA
    bne NoInput
    lda JetXPos
    cmp #102            ; if (player 0 X position > 102)
    bpl NoInput         ;  then, skip increment 
    inc JetXPos         ;  else, incremnt X
    lda JET_HEIGHT      ; 8
    sta JetAnimOffSet   ; set animation offset to the second frame

NoInput:                ; fallback when no input was performed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Calclation to update the position of bomber for next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateBomberPosition:
    lda BomberYPos
    clc
    cmp #0                      ; compare bomber y position with zero
    bmi .ResetBomberPosition    ; if it is < zero then rest y position to the top
    dec BomberYPos              ; else, decrement eny y positon for next frame
    jmp EndPositionUpdate       ; skip reset
.ResetBomberPosition:
    inc Score                   ; Score++
    inc Timer                   ; Timer++
    jsr GetRandomBomberPos      ; call subroutine for next random x position
                        
EndPositionUpdate:              ; fallback for the position update code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Check for object collision
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckCollisionP0P1:
    lda #%10000000              ; CXPPMM bit 7 detects P0 and P1 collision
    bit CXPPMM                  ; check CXPPMM bit 7 with above pattern
    bne .P0P1Collided          ; if collision between P0 and P1 happened
    jsr SetTerrainRiverColor    ; else, set playfield color 
    jmp EndCollisionCheck      ; else, skip to next check 
.P0P1Collided:
    jsr GameOver                ; call GameOver subroutine

EndCollisionCheck:              ; fallback 
    sta CXCLR                   ; clear all collision flags before the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Loop back to start a brand new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame          ; continue to display the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set the colors for the terrain and river 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetTerrainRiverColor subroutine
    lda #$F0
    sta TerrainColor        ; set color of ground to brown
    lda #$84
    sta RiverColor          ; set river to blue
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutine to handle object horizontal position with fine offset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; A is the target x-coordinate position in pixels of our object
; Y is the object type (0:player0, 1:player1, 2:missile0, 3:missile1, 4:ball)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetObjectXPos subroutine
    sta WSYNC                ; start a fresh new scanline
    sec                      ; make sure carry-flag is set before subtracion
.Div15Loop
    sbc #15                  ; subtract 15 from accumulator
    bcs .Div15Loop           ; loop until carry-flag is clear
    eor #7                   ; handle offset range from -8 to 7
    asl
    asl
    asl
    asl                      ; four shift lefts to get only the top 4 bits
    sta HMP0,Y               ; store the fine offset to the correct HMxx
    sta RESP0,Y              ; fix object position in 15-step increment
    rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Game Over subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameOver subroutine
    lda #$30
    sta TerrainColor        ; set terrian color to red
    sta RiverColor          ; set river color to red

    lda #0
    sta Score               ; Score = 0
    
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutine to generate a linear-feedback shift registar random number.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Generate a LFSR random number
; Diveide the random number by 4 to limit the size of the result to match river.
; Add 30 to compensate for the left green playfield. Bomber stays over river.
; Update Y Postion.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetRandomBomberPos subroutine
    lda Random
    asl
    eor Random
    eor Random
    asl
    asl
    eor Random
    asl
    rol Random              ; performs a series of shifts and bit operations

    lsr
    lsr                     ; divide value by 4 with the 2 right shifts
    sta BomberXPos          ; save it to the variable BomberXPos
    lda #30
    adc BomberXPos          ; adds 30 + BomberXPos for left PF
    sta BomberXPos          ; sets the new value to the bomber x position

    lda #96
    sta BomberYPos          ; reset Y position of bomber
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutine to hanld scoreboard digits to be displayed on screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Convert the high and low nibbles of the vcariable Score and Timer
; into the offsets of digits lookup table so the lookup table. 
;
; For the low nibble we need to multiply by 5.
;  - we can use left shift to perform muliplication by 2
;  - for any number N, the value of N*5 = (N*2*2)+N
;
; For the upper nibble, since its already times 16, we to divide it
; and then multiply by 5:
;   - we can use right shifts to perform division by 2
;  - for any number N, the value of (N/16)*5 = (N/2/2) + (N/2/2/2/2)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalculateDigitOffset subroutine
    ldx #1                   ; X register is the loop counter
.PrepareScoreLoop            ; this will loop twice, first X=1, and then X=0

    lda Score,X              ; load A with Timer (X=1) or Score (X=0)
    and #$0F                 ; remove the tens digit by masking 4 bits 00001111
    sta Temp                 ; save the value of A into Temp
    asl                      ; shift left (it is now N*2)
    asl                      ; shift left (it is now N*4)
    adc Temp                 ; add the value saved in Temp (+N)
    sta OnesDigitOffset,X    ; save A in OnesDigitOffset+1 or OnesDigitOffset

    lda Score,X              ; load A with Timer (X=1) or Score (X=0)
    and #$F0                 ; remove the ones digit by masking 4 bits 11110000
    lsr                      ; shift right (it is now N/2)
    lsr                      ; shift right (it is now N/4)
    sta Temp                 ; save the value of A into Temp
    lsr                      ; shift right (it is now N/8)
    lsr                      ; shift right (it is now N/16)
    adc Temp                 ; add the value saved in Temp (N/16+N/4)
    sta TensDigitOffset,X    ; store A in TensDigitOffset+1 or TensDigitOffset

    dex                      ; X--
    bpl .PrepareScoreLoop    ; while X >= 0, loop to pass a second time

    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutine to waste 12 cycles 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; jsr takes 6 cycles
; rts takes 6 cycles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Sleep12Cycles subroutine
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Digits:
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00110011          ;  ##  ##
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %00100010          ;  #   #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01100110          ; ##  ##
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #

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

JetColorLeftTurn
        .byte #$06;
        .byte #$06;
        .byte #$02;
        .byte #$04;
        .byte #$06;
        .byte #$08;
        .byte #$08;
        .byte #$0A;
JetColorRightTurn
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