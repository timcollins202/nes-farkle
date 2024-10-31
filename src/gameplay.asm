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
; New Update Dice
;*****************************************************************

;diceupdate will use bits 0-5 to store which dice have been kept
;when player selects a die to keep, flip corresponding bit in diceupdate to 1
;add corresponding value from dicerolls to keptdice array

;New update_dice will check whether diceupdate is 0
;if so, exit
;using X as iterator
;loop:
;check if diceupdate[0] is 1
;   if not, ROR diceupdate
;       INX
;       BNE loop
;   if so, call draw_die using x as index into a jump table
;       which points to 6 routines to draw pips in 1-6 arrangements 
;           each routine checks dicerolls, X to

;we track which die we update by the loop iterator, X
;   call draw_die on X=0.  see dicerolls[0] = 3.
;   set starting sprite locations for die 0
;   call routine that draws 3 pips.

