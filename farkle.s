;*****************************************************************
; FARKLE - An NES Dice Game
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
.incbin "farkle.chr"


;*****************************************************************
; Define vectors
;*****************************************************************
.segment "VECTORS"
.word nmi
.word reset
.word irq


;*****************************************************************
; Define variables
;*****************************************************************
.segment "ZEROPAGE"
time:           .res 2  ;time tick counter
lasttime:       .res 1  ;what time was last time it wsa checked
temp:           .res 10
score:          .res 3  ;player's current score
update:         .res 1  ;0 = score, 1 = highscore
highscore:      .res 3

.segment "OAM"
oam: .res 256       ;OAM sprite data

.include "neslib.s"

.segment "BSS"
palette: .res 32    ;current palette buffer


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

    ;setup stuff before mainloop goes here
    JSR disaplay_game_screen

mainloop:
    LDA time
    CMP lasttime        ;make sure time has actually changed
    BEQ mainloop
    STA lasttime        ;time has changed, so update lasttime

    ;loop calls go here

    JMP mainloop
.endproc


;*****************************************************************
; Display Title Screen
;*****************************************************************
.segment "ZEROPAGE"
paddr:  .res 2 ;16-bit address pointer

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
    vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)    ;this calculates a nametable address 5 rows down screen
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
.proc disaplay_game_screen
    JSR ppu_off
    JSR clear_nametable

    ;draw 2 lines of background tile across top of screen
    vram_set_address (NAME_TABLE_0_ADDRESS)
    LDX #0
    LDY #0
loop:
    LDA #$04        ;tile number of blue backdrop tile
    STA PPU_DATA
    INY
    CPY #32
    BNE loop
    INX
    LDY #0
    CPX #2          ;run the above loop 2 times
    BNE loop

    ;TODO set attributes here

    JSR ppu_update  ;wait til screen has been drawn
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
    .byte $0F,$28,$21,$11   
    .byte $0F,$14,$24,$34
    .byte $0F,$1B,$2B,$3B
    .byte $0F,$12,$22,$32




