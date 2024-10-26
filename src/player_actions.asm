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
not_pressing_start:

    RTS
.endproc
