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
