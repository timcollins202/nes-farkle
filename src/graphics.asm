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
.proc display_game_screen
    JSR ppu_off
    JSR clear_nametable

    vram_set_address (NAME_TABLE_0_ADDRESS)

    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;draw upper chunk of playfield tiles
    LDY #0          ;iterator
loop1:
    LDA playfield_upper_1, y
    STA PPU_DATA
    INY
    CPY #255         ;32 tiles in a row
    BNE loop1
    STA PPU_DATA     ;get that last tile in there

    ;reset iterator and draw second chunk
    INY             ;roll over
loop2:
    LDA playfield_upper_2, y
    STA PPU_DATA
    INY
    CPY #64
    BNE loop2

    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;draw lower text box
    JSR draw_lower_text_box
    
    ;draw 2 rows of bg filler tile
    JSR draw_bg_filler_row
    JSR draw_bg_filler_row

    ;load attribute table
    vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS)
    LDY #0      ;iterator
loop3:
    LDA playfield_attr, y 
    STA PPU_DATA
    INY
    CPY #64
    BNE loop3

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
    LDA #18                 ;Y position of 24 for top 2  was 49
    STA SELECTOR_1_YPOS
    STA SELECTOR_2_YPOS     
    LDA #51                 ;Y position of 32 for bottom 2
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
    LDA #31
    STA SELECTOR_1_XPOS
    STA SELECTOR_3_XPOS
    LDA #39
    STA SELECTOR_2_XPOS
    STA SELECTOR_4_XPOS

    RTS
.endproc

;*****************************************************************
; draw_bg_filler_row  -- Draws a row of background filler tiles
;   Inputs: Set VRAM address before calling this subroutine
;*****************************************************************
.segment "CODE"
.proc draw_bg_filler_row    
    LDA #$04        ;background filler tile
    LDY #0          ;iterator
loop:
    STA PPU_DATA
    INY
    CPY #32         ;32 tiles in a row
    BNE loop

    RTS
.endproc

;*****************************************************************
; draw_lower_text_box  -- Draws the empty lower text box
;   Inputs: Set VRAM address before calling this subroutine
;*****************************************************************
.segment "CODE"
.proc draw_lower_text_box
    LDX #0          ;big iterator
    LDY #0          ;small iterator

    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$05
    STA PPU_DATA
upper_line:
    LDA #$06
    STA PPU_DATA
    INY
    CPY #26         ;26 horiz line tiles form top of box
    BNE upper_line
    LDA #$07
    STA PPU_DATA
    LDA #$04
    STA PPU_DATA
    STA PPU_DATA

    ;draw middle rows
    LDY #0          ;reset Y, top row is done
draw_row:
    CPX #12
    BEQ row_done
    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$0a        ;vertical line tile
    STA PPU_DATA
    LDA #0          ;blank tile
blank_space:
    STA PPU_DATA
    INY
    CPY #26
    BNE blank_space
    LDY #0          ;reset Y
    LDA #$0a        ;vertical line tile
    STA PPU_DATA
    LDA #$04        ;bg filler tile
    STA PPU_DATA
    STA PPU_DATA
    INX     
    CPX #12
    BNE draw_row
row_done:

    LDA #$04
    STA PPU_DATA
    STA PPU_DATA
    LDA #$08        ;bottom left corner
    STA PPU_DATA
    LDX #0          ;reset iterators
    LDY #0
    LDA #$06        ;horiz line tile
lower_line:
    STA PPU_DATA
    INY 
    CPY #26
    BNE lower_line
    LDA #$09        ;bottom right corner
    STA PPU_DATA
    LDA #$04        ;background filler tile
    STA PPU_DATA
    STA PPU_DATA

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

    ;TODO- can this be a lookup table?
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
;THIS is where we start adding the code to move pip sprites into position***************

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
; update_dice: Updates dice pip sprites based on bits set in diceupdate
;*****************************************************************
.segment "CODE"
.proc update_dice
    ;if diceupdate is 0, GTFO
    LDA diceupdate
    CMP #0
    BNE :+
        RTS           
    :

    LDY #0              ;iterator   
loop:
    LDA #%00000001
    AND diceupdate      ;is diceupdate[0] a 1?
    BNE update_pips     ;if so, we will draw the value at dicerolls, y on die number y
rotate:
    LSR diceupdate      ;if not, rotate diceupdate and check the next byte
    INY
    CPY #6              ;do this 6 times for 6 dice
    BEQ done
    JMP loop

update_pips:
;make sure registers arent getting clobbered here
    LDX dicerolls, y    ;put the number we will be drawing in X
    TYA
    PHA                 ;preserve Y on stack
    JSR draw_pips
    PLA
    TAY                 ;get Y back off the stack
    JMP rotate
    
done:
    LDA #0
    STA diceupdate      ;make sure diceupdate gets reset to 0
    RTS
.endproc


;*****************************************************************
; draw_pips:  Place pip sprites on dice
;   Inputs: Y is which die we are drawing on, 0-5
;           X is the number we are drawing
;*****************************************************************
.segment "CODE"
.proc draw_pips
    ;set temp 4 & 5 to our starting X and Y coordinates
    ;then jump to the appropriate pip routine based on X
    LDA pip_starting_positions_x, y 
    STA temp + 4
    LDA pip_starting_positions_y, y 
    STA temp + 5

    ;clear out the die we are about to draw to    
    JSR clear_die    

    ;calculate jump address and jump to it
    TXA
    ASL 
    TAX                         ;shift X so we get an even index
    LDA pip_jump_table, x           
    STA paddr
    LDA pip_jump_table + 1, x 
    STA paddr+1
    JMP (paddr)
.endproc

clear_die:
    TXA
    PHA             ;preserve x on the stack

    ;use temp + 7 as iterator
    LDA #0
    STA temp + 7

    ;loop over sprites and remove any inside this die's boundaries
    LDX #184    ;shadow oam byte for Ypos of the last pip sprite, +4 so we can subtract in loop
@loop:
    TXA
    SEC
    SBC #4
    TAX
    LDA oam, x 
    CMP bottom_boundaries_ypos, y  ;is the sprite above the bottom of the die?
    BCC @bottom_hit
        JMP @continue  
@bottom_hit:
    ;the sprite is over the bottom of the die.  Check if its below the top
    CMP top_boundaries_ypos, y 
    BCS @top_hit
        JMP @continue
@top_hit:
    ;the sprite is on the correct row.  Check if its left of the right side
    INX
    INX
    INX                         ;get X up to the Xpos of the sprite
    LDA oam, x 
    CMP right_boundaries_xpos, y  
    BCC @right_hit  
        DEX
        DEX
        DEX            ;get back to the Ypos so we don't break the subtraction above
        JMP @continue
@right_hit:
    ;it could also be in a die to the left. Check if its right of the left side
    CMP left_boundaries_xpos, y 
    BCS @remove_sprite
        DEX
        DEX
        DEX
        JMP @continue
@remove_sprite:
    ;You are on our die, sir! Begone! 
    DEX
    DEX
    DEX 
    LDA #255
    STA oam, x 
@continue:
    LDA temp + 7    ;increment iterator
    CLC
    ADC #1
    STA temp + 7
    CMP #42         ;do this 42 times
    BNE @loop
@done:
    PLA             ;put x back from stack
    TAX
    RTS

find_available_pip_sprite:
    LDX #184        ;shadow oam byte for Ypos of the last pip sprite, +4 so we can subtract in loop
@loop:
    TXA
    SEC
    SBC #4
    TAX
    LDA oam, x 
    CMP #255        ;if the Ypos != 255, sprite is not in use
    BNE @loop
    RTS             ;this puts the oam offset for the first free pip's Ypos in X

draw_pips_one:
    ;find an offscreen pip sprite
    JSR find_available_pip_sprite
    ;we have the correct oam offset for the first free pip sprite in X
    LDA temp + 5    ;starting Ypos for the die
    CLC
    ADC #8          ;add 8 to Ypos
    STA oam, x 
    INX
    INX
    INX
    LDA temp + 4    ;starting Xpos for the die
    ADC #8
    STA oam, x 
    RTS

draw_pips_two:
    JSR find_available_pip_sprite
    LDA temp + 5     ;starting Ypos
    CLC
    ADC #2
    STA oam, x
    INX
    INX
    INX
    LDA temp + 4    ;starting Xpos
    ADC #2
    STA oam, x      ;first pip is placed, let's do the second
    JSR find_available_pip_sprite 
    LDA temp + 5    ;starting Ypos
    ADC #24
    STA oam, x
    INX
    INX
    INX
    LDA temp + 4    ;starting Xpos
    ADC #24
    STA oam, X
    RTS
    

;*****************************************************************
; OLD
; update_dice: Updates dice tiles during vblank
;*****************************************************************
.segment "CODE"
.proc update_dice_OLD
    JSR ppu_off

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
