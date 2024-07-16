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
; Set the vram address pointer to the address specified by the pointer
;******************************************************************************
.macro vram_set_address_i addresspointer

    lda PPU_STATUS
	lda addresspointer + 1
	sta PPU_ADDR
	lda addresspointer + 0
	sta PPU_ADDR

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


;******************************************************************************
; Adds an 8-bit value to a 16-bit value
;******************************************************************************
.macro add_16_8 dest, value

	LDA value
    BMI :+
		CLC
		ADC dest
		STA dest
		LDA dest + 1
		ADC #0
		STA dest + 1
        JMP :++
    :

	CLC
	ADC dest
	STA dest
	LDA dest + 1
	ADC #$FF
	STA dest + 1
    :

.endmacro
