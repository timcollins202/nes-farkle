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

    ;update all 6 dice on screen
    LDA #%00111111
    STA diceupdate

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
;THIS is where we start adding the code to move pip sprites into position

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
    
    RTS
.endproc


;*****************************************************************
; update_dice: Updates dice tiles during vblank
;*****************************************************************
.segment "CODE"
.proc update_dice
    jsr ppu_off

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
        JSR ppu_update
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
        JSR ppu_update
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
        JSR ppu_update
@checkdie4:
    LDA #%00001000
    BIT diceupdate              ;check for an update to die 4
    BEQ @checkdie5
        LDY dicerolls + 3
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 16)
        JSR draw_die
        ;flip byte 3 of diceupdate
        LDA #%00001000
        EOR diceupdate
        STA diceupdate
        JSR ppu_update
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
        JSR ppu_update
@checkdie6:
    LDA #%00100000
    BIT diceupdate              ;check for an update to die 5
    BEQ @donecheckingdice
        LDY dicerolls + 5
        assign_16i paddr, (NAME_TABLE_0_ADDRESS + 7 * 32 + 26)
        JSR draw_die
        ;flip byte 5 of diceupdate
        LDA #%00100000
        EOR diceupdate
        STA diceupdate
        JSR ppu_update

@donecheckingdice:
    RTS
.endproc
