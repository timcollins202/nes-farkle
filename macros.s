;******************************************************************************
; Set the ram address pointer to the specified address
;******************************************************************************
.macro assign_16i dest, value
    LDA #<value
    STA dest + 0
    LDA #>value
    STA dest + 1
.endmacro

;******************************************************************************
; Set the vram address pointer to the specified address
;******************************************************************************
.macro vram_set_address newaddress
    LDA PPU_STATUS
    LDA #>newaddress
    STA PPU_ADDR
    LDA #<newaddress
    STA PPU_ADDR
.endmacro


;******************************************************************************
; Clear the vram address pointer
;******************************************************************************
.macro vram_clear_address
    LDA #0
    STA PPU_ADDR
    STA PPU_ADDR
.endmacro

