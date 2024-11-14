;*****************************************************************
; Handle player actions
;*****************************************************************
.segment "CODE"
.proc player_actions
    JSR gamepad_poll                ;read button state
    LDA gamepad
    CMP gamepad_last                ;make sure button state has changed
    BNE :+
        RTS                         ;if not, GTFO
    :

AND #PAD_R
BEQ not_pressing_right
    ;we are pressing right. Make sure we aren't already on right edge
    LDA SELECTOR_1_XPOS         ;get X position of top left selector sprite
    CMP #111                    ;can't go any farther right than this
    BEQ not_pressing_right
        ;we are not on right edge.  Move selector to the next die to the right
        JSR move_selector_right

not_pressing_right:
    LDA gamepad
    AND #PAD_L
    BEQ not_pressing_left
        ;we are pressing left.  Make sure we aren't already at left edge.
        LDA SELECTOR_1_XPOS
        CMP #31                    ;starting X pos is 24 for top right sprite
        BEQ not_pressing_left
            ;we are not on left edge.  Move selector the next die to the left
            JSR move_selector_left

not_pressing_left:
    LDA gamepad
    AND #PAD_D
    BEQ not_pressing_down
        ;we are pressing down.  Make sure we're not already on bottom row.
        LDA SELECTOR_1_YPOS
        CMP #50
        BEQ not_pressing_down
            ;we are pressing down. Move selector down.
            JSR move_selector_down

not_pressing_down:
    LDA gamepad 
    AND #PAD_U
    BEQ not_pressing_up
        ;we are pressing up.  Make sure we're not already on top row.
        LDA SELECTOR_1_YPOS
        CMP #18
        BEQ not_pressing_up 
            ;we are not on top row.  Move selector to top row.
            JSR move_selector_up

not_pressing_up:
    LDA gamepad
    AND #PAD_A
    BEQ not_pressing_a
        ;we are pressing start.  See if we are pre-roll
        LDA gamestate
        CMP #1
        BNE not_pressing_a
            ;we are pressing start pre-roll.  Roll em!
            ;update gamestate
            LDA #1                  ;gamestate 1 = rolling dice
            STA gamestate

            ;testing with 1 die set to 1
            ; JSR roll_dice
            ; LDA #%00111111       ;set all dice to update   
            LDA #1
            STA dicerolls
            LDA #2
            STA dicerolls + 1
            STA dicerolls + 2
            STA dicerolls + 3
            STA dicerolls + 4
            STA dicerolls + 5
            LDA #%00111111
            STA diceupdate
not_pressing_a:

    RTS
.endproc

.proc move_selector_right
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

    RTS
.endproc

.proc move_selector_left
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

    RTS
.endproc

.proc move_selector_down
    CLC
    ADC #32
    STA SELECTOR_1_YPOS 
    LDA SELECTOR_2_YPOS
    CLC
    ADC #32
    STA SELECTOR_2_YPOS
    LDA SELECTOR_3_YPOS
    CLC 
    ADC #32
    STA SELECTOR_3_YPOS
    LDA SELECTOR_4_YPOS
    CLC 
    ADC #32
    STA SELECTOR_4_YPOS    

    RTS
.endproc

.proc move_selector_up
    ;figure out the bottorm row pixel positions first
    SEC
    SBC #32
    STA SELECTOR_1_YPOS
    LDA SELECTOR_2_YPOS
    SEC
    SBC #32
    STA SELECTOR_2_YPOS
    LDA SELECTOR_3_YPOS
    SEC
    SBC #32
    STA SELECTOR_3_YPOS
    LDA SELECTOR_4_YPOS
    SEC
    SBC #32
    STA SELECTOR_4_YPOS

    RTS
.endproc