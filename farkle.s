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
time:           .res 2  ;time tick counter
lasttime:       .res 1  ;what time was last time it was checked
temp:           .res 10 ;general purpose temp space
paddr:          .res 2  ;16-bit address pointer
score:          .res 3  ;current score
highscore:      .res 3  ;high score
update:         .res 1  ;each bit denotes something needs to update:
                        ;0 = score, 1 = highscore


.segment "OAM"
oam: .res 256           ;OAM sprite data

.include "neslib.s"

.segment "BSS"
palette: .res 32        ;current palette buffer


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
    JSR display_game_screen
    JSR draw_selector

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
.proc display_game_screen
    JSR ppu_off
    JSR clear_nametable

    vram_set_address NAME_TABLE_0_ADDRESS
    LDY #0          ;iterator low byte
loop1:
    LDA playfield_tiles1, y 
    STA PPU_DATA
    INY
    CPY #255
    BNE loop1
    STA PPU_DATA    ;get that last tile in there
    INY             ;roll Y over
loop2:
    LDA playfield_tiles2, y 
    STA PPU_DATA
    INY
    CPY #255
    BNE loop2
    STA PPU_DATA    ;get that last tile in there
    INY             ;roll Y over
loop3:
    LDA playfield_tiles3, y 
    STA PPU_DATA
    INY
    CPY #255
    BNE loop3
    STA PPU_DATA    ;get that last tile in there
    INY             ;roll Y over
    loop4:
    LDA playfield_tiles4, y 
    STA PPU_DATA
    INY
    CPY #255
    BNE loop4
    STA PPU_DATA

    JSR ppu_update  ;wait til screen has been drawn
    RTS
.endproc


;*****************************************************************
; Put player's selector sprite on screen
;*****************************************************************
.segment "CODE"
.proc draw_selector
    ;display the player's selctor in the top left square
    ;set Y position of all 4 parts of the selector (byte 0)
    LDA #32         ;Y position of 24 for top 2
    STA oam
    STA oam + 4     
    LDA #40         ;Y position of 32 for bottom 2
    STA oam + 8
    STA oam + 12
    ;set the tile number used by the sprite (byte 1)
    LDA #$01        ;all 4 corners use the same tile, just rotated
    STA oam + 1
    STA oam + 5
    STA oam + 9
    STA oam + 13
    ;set sprite attributes (byte 2)
    LDA #SPRITE_PALETTE_1  
    STA oam + 2
    LDA #SPRITE_FLIP_HORIZ|SPRITE_PALETTE_1
    STA oam + 6
    LDA #SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA oam + 10
    LDA #SPRITE_FLIP_HORIZ|SPRITE_FLIP_VERT|SPRITE_PALETTE_1
    STA oam + 14
    ;set the X position for all 4 parts of the selector (byte 3)
    LDA #32
    STA oam + 3
    STA oam + 11
    LDA #40
    STA oam + 7
    STA oam + 15

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

playfield_tiles1:
    .byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$05,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$07,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$98,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
playfield_tiles2:
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$08,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$09,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
playfield_tiles3:
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$05,$06,$06,$06,$06,$07,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$0a,$00,$00,$00,$00,$0a,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$08,$06,$06,$06,$06,$09,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
playfield_tiles4:
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$53,$43,$30,$52,$45,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$00,$00,$00,$00,$00,$00,$00,$30,$30,$30,$30,$30,$30,$30,$04,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
    ;attributes
    .byte $15,$05,$15,$05,$15,$05,$05,$45,$11,$00,$11,$00,$11,$00,$00,$44
	.byte $15,$05,$15,$05,$11,$00,$00,$44,$11,$00,$11,$00,$51,$50,$50,$54
	.byte $15,$05,$15,$05,$11,$00,$00,$44,$11,$00,$11,$00,$11,$00,$00,$44
	.byte $55,$55,$55,$55,$11,$00,$00,$44,$05,$05,$05,$05,$05,$05,$05,$05