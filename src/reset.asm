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
