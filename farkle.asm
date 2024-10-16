;*****************************************************************
; FARKLE - A Dice Game for NES
;*****************************************************************

;*****************************************************************
; Define NES cartridge header
;*****************************************************************
.segment "HEADER"
INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 0 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID 
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding


;*****************************************************************
; Include CHR file
;*****************************************************************
.segment "TILES"
.incbin "farkle-bg.chr"
.incbin "farkle-sp.chr"


;*****************************************************************
; Define vectors
;*****************************************************************
.segment "VECTORS"
.word nmi
.word reset
.word irq


;*****************************************************************
; Reserve memory for variables
;*****************************************************************
.segment "ZEROPAGE"
time:               .res 2  ;time tick counter
lasttime:           .res 1  ;what time was last time it was checked
temp:               .res 10 ;general purpose temp space
paddr:              .res 2  ;16-bit address pointer
score:              .res 3  ;current score
highscore:          .res 3  ;high score
gamestate:          .res 1  ;each bit denotes a gamestate:
                            ;0 = starting roll, 1 = rolling dice, 2 = choosing dice, etc.
update:             .res 1  ;each bit denotes something needs to update:
                            ;0 = score, 1 = highscore
dicerolls:          .res 6  ;outcomes of dice rolls, one die per byte
diceupdate:         .res 1  ;bits 0-5 denote a die that needs to be redrawn.
dicevblankcount:    .res 1  ;tracks how many updates we have done this vblank.


.segment "OAM"
oam: .res 256           ;OAM sprite data

.segment "BSS"
palette: .res 32        ;current palette buffer

;*****************************************************************
; Include external files
;*****************************************************************
.include "neslib.asm"         ;General Purpose NES Library
.include "constants.inc"    ;Game-specific constants


;*****************************************************************
; Main application entry point for starup/reset
;*****************************************************************
.segment "CODE"
.proc reset 
    SEI                 ;mask interrupts
    LDA #0
    STA PPU_CONTROL     ;disable NMI
    STA PPU_MASK        ;disable rendering
    STA APU_DM_CONTROL  ;disable DMC IRQ
    LDA #40
    STA JOYPAD2         ;disable APU frame IRQ

    CLD                 ;disable decimal mode
    LDX #$ff
    TXS                 ;initialize stack

    ;wait for first vblank
    BIT PPU_STATUS
wait_vblank:
    BIT PPU_STATUS
    BPL wait_vblank

    ;clear all RAM to 0
    LDA #0
    LDX #0
clear_ram:              ;set all work RAM to 0
    STA $0000, x
    STA $0100, x
    STA $0200, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    INX
    BNE clear_ram

    ;place sprites offscreen at Y=255
    LDA #255
    LDX #0
clear_oam:
    STA oam, x 
    INX
    INX
    INX
    INX
    BNE clear_oam

wait_vblank2:
    BIT PPU_STATUS
    BPL wait_vblank2

    ; NES is initialized and ready to begin
	; - enable the NMI for graphical updates and jump to our main program
    LDA #%10001000
    STA PPU_CONTROL
    JMP main
.endproc


;*****************************************************************
; NMI Routine - called every vBlank
;*****************************************************************
.segment "CODE"
.proc nmi
    ;save registers
    PHA
    TXA
    PHA
    TYA
    PHA

    INC time    ;increment lower byte of time counter
    BNE :+      ;if we've hit 255, increment upper byte of time counter
        INC time + 1
    :

    BIT PPU_STATUS
    ;transfer sprite OAM data using DMA
    LDA #>oam
    STA SPRITE_DMA

    ;transfer current palette to PPU
    vram_set_address $3f00
    LDX #0      ;transfer the 32 bytes to VRRAM
@loop:
    LDA palette, x 
    STA PPU_DATA
    INX
    CPX #32
    BCC @loop

    ;new graphical updating stuff goes here
    JSR update_dice

    ;write current scroll and control settings to PPU
    LDA #0
    STA PPU_SCROLL
    STA PPU_SCROLL
    LDA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    STA PPU_MASK

    ;flag that the PPU update has been completed
    LDX #0
    STX nmi_ready
    
    ;restore registers and return
    PLA
    TAY
    PLA
    TAX
    PLA

    RTI
.endproc


;*****************************************************************
; IRQ Clock Interrupt Routine     (not used)
;*****************************************************************
.segment "CODE"
irq:
	RTI


;*****************************************************************
; Main application logic section includes the game loop
;*****************************************************************
.segment "CODE"
.proc main
    ;rendering is currently off

    ;initialize palette table
    LDX #0
paletteloop:
    LDA default_palette, x 
    STA palette, x 
    INX
    CPX #32
    BCC paletteloop

    ;initialize diceupdate to 0
    LDA #0
    STA diceupdate

    JSR display_title_screen

    ;set our game settings
    LDA #VBLANK_NMI|BG_0000|OBJ_1000
    STA ppu_ctl0
    LDA #BG_ON|OBJ_ON
    STA ppu_ctl1

    JSR ppu_update

titleloop:
    JSR gamepad_poll
    LDA gamepad
    AND #PAD_START     ;check whether start is pressed
    BEQ titleloop

    ;set our random seed based on the time counter since the title screen was displayed
    LDA time
    STA SEED0
    LDA time + 1
    STA SEED0 + 1
    JSR randomize
    SBC time + 1
    STA SEED2
    JSR randomize
    SBC time
    STA SEED2+1

    ;setup stuff before mainloop goes here
    ;set gamestate to 0 = pre-roll
    LDA #0
    STA gamestate

    JSR display_game_screen
    JSR draw_selector

mainloop:
    LDA time
    CMP lasttime        ;make sure time has actually changed
    BEQ mainloop
    STA lasttime        ;time has changed, so update lasttime

    ;loop calls go here
    JSR player_actions

    JMP mainloop
.endproc


;*****************************************************************
; Display Title Screen
;*****************************************************************
.segment "CODE"
title_text:
.byte "F A R K L E",0

press_start_text:
.byte "PRESS START TO BEGIN",0

title_attributes:
.byte %00000101,%00000101,%00000101,%00000101
.byte %00000101,%00000101,%00000101,%00000101

.proc display_title_screen
    JSR ppu_off
    JSR clear_nametable

    ;write title text
    vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
    assign_16i text_address, title_text
    JSR write_text

    ;write press start text
    vram_set_address(NAME_TABLE_0_ADDRESS + 20 * 32 + 6)   ;a bit lower
    assign_16i text_address, press_start_text
    JSR write_text

    ;set the title text to use the 2nd palette entries
    vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8)
    assign_16i paddr, title_attributes
    LDY #0
loop:
    LDA (paddr), y 
    STA PPU_DATA
    INY
    CPY #8
    BNE loop

    JSR ppu_update      ;wait til the screen has been drawn

    RTS
.endproc


;*****************************************************************
; Display Main Game Screen
;*****************************************************************
.segment "CODE"
score_text:
    .byte "SCORE 0000000",0

.proc display_game_screen
    JSR ppu_off
    JSR clear_nametable

    ;write score at top of screen
    vram_set_address (NAME_TABLE_0_ADDRESS + 2 * 32 + 9)
    assign_16i text_address, score_text
    JSR write_text

    ;make fake dicerolls for starting dice
    LDY #0      ;iterator
    LDX #1      ;value to put into dicerolls
rollloop:
    STX dicerolls, y
    INX
    INY
    CPY #6
    BNE rollloop

    JSR draw_rolled_dice

    JSR ppu_update  ;wait til screen has been drawn
    
    RTS
.endproc


;*****************************************************************
; Put player's selector sprite on screen
;*****************************************************************
.segment "CODE"
.proc draw_selector
    ;display the player's selctor on the leftmost die
    ;set Y position of all 4 parts of the selector (byte 0)
    LDA #49                 ;Y position of 24 for top 2
    STA SELECTOR_1_YPOS
    STA SELECTOR_2_YPOS     
    LDA #85                 ;Y position of 32 for bottom 2
    STA SELECTOR_3_YPOS
    STA SELECTOR_4_YPOS
    ;set the tile number used by the sprite (byte 1)
    LDA #$02                ;all 4 sprites use the same tile, just rotated
    STA SELECTOR_1_TILE
    STA SELECTOR_2_TILE
    STA SELECTOR_3_TILE
    STA SELECTOR_4_TILE
    ;set sprite attributes (byte 2)
    LDA #SPRITE_PALETTE_1  
    STA SELECTOR_1_ATTR
    LDA #SPRITE_FLIP_HORIZ|SPRITE_PALETTE_1
    STA SELECTOR_2_ATTR
    LDA #SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA SELECTOR_3_ATTR
    LDA #SPRITE_FLIP_HORIZ|SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA SELECTOR_4_ATTR
    ;set the X position for all 4 parts of the selector (byte 3)
    LDA #17
    STA SELECTOR_1_XPOS
    STA SELECTOR_3_XPOS
    LDA #25
    STA SELECTOR_2_XPOS
    STA SELECTOR_4_XPOS

    RTS
.endproc


;*****************************************************************
; Handle player actions
;   -move selector
;*****************************************************************
.segment "CODE"
.proc player_actions
    JSR gamepad_poll
    LDA gamepad
    CMP gamepad_last                ;make sure button state has changed
    BNE :+
        RTS                         ;if not, GTFO
    :                       
    AND #PAD_R
    BEQ not_pressing_right
        ;we are pressing right. Make sure we aren't already on right edge
        LDA SELECTOR_1_XPOS         ;get X position of top left selector sprite
        CMP #217                    ;can't go any farther right than this
        BEQ not_pressing_right
        ;we are not on right edge.  Move selector to the next die to the right
            CLC
            ADC #40
            STA SELECTOR_1_XPOS     ;move top left sprite
            LDA SELECTOR_2_XPOS     ;get top right sprite's X position
            CLC
            ADC #40
            STA SELECTOR_2_XPOS    ;move top right sprite
            LDA SELECTOR_3_XPOS    ;get bottom left sprite's X position
            CLC 
            ADC #40
            STA SELECTOR_3_XPOS    ;move bottom left sprite
            LDA SELECTOR_4_XPOS    ;get bottom right sprite's X position
            CLC 
            ADC #40
            STA SELECTOR_4_XPOS    ;move bottom right sprite

not_pressing_right:
    LDA gamepad
    AND #PAD_L
    BEQ not_pressing_left
        ;we are pressing left.  Make sure we aren't already at left edge.
        LDA SELECTOR_1_XPOS
        CMP #17                    ;starting X pos is 24 for top right sprite
        BEQ not_pressing_left
        ;we are not on left edge.  Move selector the next die to the left
            SEC
            SBC #40
            STA SELECTOR_1_XPOS
            LDA SELECTOR_2_XPOS
            SEC
            SBC #40
            STA SELECTOR_2_XPOS
            LDA SELECTOR_3_XPOS
            SEC
            SBC #40
            STA SELECTOR_3_XPOS
            LDA SELECTOR_4_XPOS
            SEC
            SBC #40
            STA SELECTOR_4_XPOS

not_pressing_left:
    LDA gamepad
    AND #PAD_START
    BEQ not_pressing_start
        ;we are pressing start.  See if we are pre-roll
        LDA gamestate
        CMP #0
        BNE not_pressing_start
            ;we are pressing start pre-roll.  Roll em!
            JSR roll_dice
            LDA #%00111111
            STA diceupdate
            ;JSR draw_rolled_dice
not_pressing_start:

    RTS
.endproc


;*****************************************************************
; Roll dice and store outcomes in dicerolls
;*****************************************************************
.segment "CODE"
.proc roll_dice
    ;update gamestate
    LDA #1                  ;gamestate bit 1 = rolling dice
    STA gamestate

    ;generate random numbers
    JSR rand            ;get next random 16 bits in A and Y
    STA temp            ;store them in temp
    STY temp + 1
    JSR rand            ;do it again
    STA temp + 2        ;now we have enough random bytes for 6 dice
    STY temp + 3        ;get the last one for 0/7 mitigation

    ;split each byte into 2 3-byte nibbles and store them on the stack
    LDY #0              ;iterator
splitbytes:
    LDA temp, y         ;get whole byte from temp
    AND #$1f            ;get bottom 3 bytes
    PHA                 ;push them to stack
    LDA temp, y         ;get the whole byte back
    LSR A               ;rotate 3 hi bits to bottom of byte
    LSR A 
    LSR A 
    LSR A
    LSR A
    PHA                 ;push 3 hi bits to stack
    INY
    CPY #3              ;repeat this for each byte in temp
    BNE splitbytes

    ;6 dice rolls are now on stack.  pop each, make sure it is btwn 1-6, and store to dicerolls
    LDY #0              ;iterator
check_for_seven:
    PLA                 ;pull top byte off the stack
    CMP #7          
    BCC check_for_zero
    ;we have a 7. subtract the bottom 2 bits (1-3) of the 3rd temp byte to get it 6 or lower
        LDA temp + 3
        AND #%00000011  ;get bottom 2 bits
        TAX
        LDA #6
    @loop:
        SEC
        SBC #1           ;this loop should decrement A by X
        DEX
        CPX #0
        BNE @loop
        JMP skip
check_for_zero:
    CMP #1
    BCS skip
    ;we have a 0. Add the bottom 2 bits (1-3) of the 3rd temp byte to get it 1 or higher
        LDA temp + 3        
        SEC              ;set carry then rotate left to ensure we don't get a zero
        ROL
        AND #%00000011   ;get just the bottom 2 bits 
skip:
    STA dicerolls, y
    INY
    CPY #6
    BNE check_for_seven

    RTS
.endproc


;*****************************************************************
; Draw rolled dice to the screen
;*****************************************************************
.segment "CODE"
.proc draw_rolled_dice
    LDY dicerolls
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 1)
    JSR draw_die

    LDY dicerolls + 1
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 6)
    JSR draw_die

    LDY dicerolls + 2
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 11)
    JSR draw_die

    LDY dicerolls + 3
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 16)
    JSR draw_die

    LDY dicerolls + 4
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 21)
    JSR draw_die

    LDY dicerolls + 5
    assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 26)
    JSR draw_die
    
    RTS
.endproc

;*****************************************************************
; Check whether we have done 2 dice updates this vblank
;*****************************************************************
; .segment "CODE"
; .proc 


;*****************************************************************
; draw_die  -- Draws a die to screen
;   Inputs: paddr = VRAM address pointer
;           Y = number to put on die
;*****************************************************************
.segment "CODE"
.proc draw_die
    
    vram_set_address_i paddr

    ;figure out what number we are drawing and set X = starting index in dice_tiles
    CPY #1
    BNE :+
        LDX #0      ;X = the index into dice_tiles we will start at
        JMP gotnumber
    :
    CPY #2
    BNE :+
        LDX #16
        JMP gotnumber
    :
    CPY #3
    BNE :+
        LDX #32
        JMP gotnumber
    :
    CPY #4
    BNE :+
        LDX #48
        JMP gotnumber
    :
    CPY #5
    BNE :+
        LDX #64
        JMP gotnumber
    :
    CPY #6
    BNE :+
        LDX #80
    :
gotnumber:          ;at this point we don't need Y anymore

    ;we have starting index in X.  
    LDA #0
    STA temp + 8     ;temp+8 will be big loop iterator
    LDY #0          ;small loop iterator
loop:
    LDA dice_tiles, x 
    STA PPU_DATA
    INX
    INY
    CPY #4
    BNE loop        ;this loop draws one row of the die tiles

    ;add 29 to VRAM address to skip  the start of the next row in the die
    add_16_8 paddr, #32
    vram_set_address_i paddr

    LDY #0          ;reset small loop iterator
    LDA temp + 8
    CLC
    ADC #1          ;increment big loop iterator
    CMP #4          ;run this for 4 rows
    STA temp + 8
    BNE loop

    INC dicevblankcount
    
    RTS
.endproc

;*****************************************************************
; update_dice: Updates dice tiles during vblank
;*****************************************************************
.segment "CODE"
.proc update_dice
    ;check diceupdates to see if we need to redraw any dice
    LDA #0
    CMP diceupdate
    BNE :+                          ;GTFO if diceupdate = 0
        RTS
    :    

    ;dicevblankcount > 2 means we have updated 2 dice this vblank. That's the limit!
@checkdicevblankcount:
    LDA #2            
    CMP dicevblankcount
    BNE :+
        RTS
    :

    LDA #%00000001
    BIT diceupdate                  ;check for an update to die 1
    BEQ @checkdie2
        LDY dicerolls
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 1)
        JSR draw_die
        ;flip byte 0 of diceupdate
        LDA #%00000001
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount
@checkdie2:
    LDA #%00000010          
    BIT diceupdate              ;check for an update to die 2
    BEQ @checkdie3
        LDY dicerolls + 1
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 6)
        JSR draw_die
        ;flip byte 1 of diceupdate
        LDA #%00000010
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount
@checkdie3:
    LDA #%00000100          
    BIT diceupdate              ;check for an update to die 3
    BEQ @checkdie4
        LDY dicerolls + 2
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 11)
        JSR draw_die
        ;flip byte 2 of diceupdate
        LDA #%00000100
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount
@checkdie4:
    LDA #%00001000
    BIT diceupdate              ;check for an update to die 4
    BEQ @checkdie4
        LDY dicerolls + 3
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 16)
        JSR draw_die
        ;flip byte 3 of diceupdate
        LDA #%00001000
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount
@checkdie5:
    LDA #%00010000
    BIT diceupdate              ;check for an update to die 5
    BEQ @checkdie6
        LDY dicerolls + 4
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 21)
        JSR draw_die
        ;flip byte 4 of diceupdate
        LDA #%00010000
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount
@checkdie6:
    LDA #%00100000
    BIT diceupdate          ;check for an update to die 5
    BEQ @donecheckingdice
        LDY dicerolls + 5
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 26)
        JSR draw_die
        ;flip byte 2 of diceupdate
        LDA #%00100000
        EOR diceupdate
        STA diceupdate
        JMP @checkdicevblankcount

@donecheckingdice:
    ; LDA #0
    ; STA diceupdate          ;reset diceupdate to 

    RTS
.endproc


.segment "RODATA"
default_palette:
    ;background
    .byte $0f,$00,$10,$30   
    .byte $0f,$11,$21,$32
    .byte $0f,$05,$16,$27
    .byte $0f,$0b,$1a,$29

    ;sprites
    .byte $0F,$05,$15,$17   
    .byte $0F,$14,$24,$34
    .byte $0F,$1B,$2B,$3B
    .byte $0F,$12,$22,$32

dice_tiles:
    .byte $0b,$0c,$0c,$0d,$0e,$13,$14,$0f,$0e,$15,$16,$0f,$10,$12,$12,$11
    .byte $17,$18,$0c,$0d,$19,$1a,$03,$0f,$0e,$03,$1e,$1c,$10,$12,$1d,$1b
    .byte $17,$18,$0c,$0d,$19,$1f,$21,$0f,$0e,$2e,$1f,$1c,$10,$12,$1d,$1b
    .byte $17,$18,$26,$25,$19,$1a,$2e,$27,$24,$21,$1e,$1c,$22,$23,$1d,$1b
    .byte $17,$18,$26,$25,$19,$1f,$28,$27,$24,$28,$1f,$1c,$22,$23,$1d,$1b
    .byte $17,$18,$26,$25,$2b,$2a,$2d,$2c,$2b,$2a,$2d,$2c,$22,$23,$1d,$1b
