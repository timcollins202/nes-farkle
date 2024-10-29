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
; Include CHR files
;*****************************************************************
.segment "TILES"
.incbin "chr/farkle-bg.chr"
.incbin "chr/farkle-sp.chr"


;*****************************************************************
; Include external files
;*****************************************************************
.include "lib/neslib.asm"           ;General Purpose NES Library
.include "src/constants.inc"        ;Game-specific constants
.include "src/gameplay.asm"         ;Gameplay logic
.include "src/graphics.asm"         ;Graphics drawing routines
.include "src/nmi.asm"              ;Non-maskable interrupt handler
.include "src/player_actions.asm"   ;Player action handler
.include "src/reset.asm"            ;Reset handler
.include "src/ro_data.asm"          ;Read-only data


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


.segment "OAM"
oam: .res 256           ;OAM sprite data

.segment "BSS"
palette: .res 32        ;current palette buffer


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
    
    ;set our game settings
    LDA #VBLANK_NMI|BG_0000|OBJ_1000
    STA ppu_ctl0
    LDA #BG_ON|OBJ_ON
    STA ppu_ctl1

    ;initialize diceupdate to 0
    LDA #0
    STA diceupdate

    JSR display_title_screen

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

    ;if diceupdate != 0, update dice tiles
    LDA diceupdate
    CMP #0
    BEQ mainloop
    JSR update_dice

    JMP mainloop
.endproc
