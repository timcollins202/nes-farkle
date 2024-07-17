;*****************************************************************
; neslib.s: NES Function Library
;*****************************************************************

; Define PPU Registers
PPU_CONTROL = $2000         ; PPU Control Register 1 (Write)
PPU_MASK = $2001            ; PPU Control Register 2 (Write)
PPU_STATUS = $2002          ; PPU Status Register (Read)
PPU_SPRRAM_ADDRESS = $2003  ; PPU SPR-RAM Address Register (Write)
PPU_SPRRAM_IO = $2004       ; PPU SPR-RAM I/O Register (Write)
PPU_SCROLL = $2005   ; PPU VRAM Address Register 1 (Write)
PPU_ADDR = $2006   ; PPU VRAM Address Register 2 (Write)
PPU_DATA = $2007         ; VRAM I/O Register (Read/Write)
SPRITE_DMA = $4014          ; Sprite DMA Register

; Define PPU control register masks
NT_2000 = $00       ; nametable location
NT_2400 = $01
NT_2800 = $02
NT_2C00 = $03

VRAM_DOWN = $04     ; increment VRAM pointer by row

OBJ_0000 = $00 
OBJ_1000 = $08
OBJ_8X16 = $20

BG_0000 = $00  
BG_1000 = $10

VBLANK_NMI = $80    ; enable NMI

BG_OFF = $00        ; turn background off
BG_CLIP = $08       ; clip background
BG_ON = $0A         ; turn background on

OBJ_OFF = $00       ; turn objects off
OBJ_CLIP = $10      ; clip objects
OBJ_ON = $14        ; turn objects on

; Define APU Registers
APU_DM_CONTROL = $4010  ; APU Delta Modulation Control Register (Write)
APU_CLOCK = $4015       ; APU Sound/Vertical Clock Signal Register (Read/Write)

; Joystick/Controller values
JOYPAD1 = $4016     ; Joypad 1 (Read/Write)
JOYPAD2 = $4017     ; Joypad 2 (Read/Write)

; Gamepad bit values
PAD_A      = $01
PAD_B      = $02
PAD_SELECT = $04
PAD_START  = $08
PAD_U      = $10
PAD_D      = $20
PAD_L      = $40
PAD_R      = $80

; Useful PPU memory addresses
NAME_TABLE_0_ADDRESS		= $2000
ATTRIBUTE_TABLE_0_ADDRESS	= $23C0
NAME_TABLE_1_ADDRESS		= $2400
ATTRIBUTE_TABLE_1_ADDRESS	= $27C0

.segment "ZEROPAGE"

nmi_ready:		.res 1 ; set to 1 to push a PPU frame update, 
					   ;        2 to turn rendering off next NMI
ppu_ctl0:		.res 1 ; PPU Control Register 2 Value
ppu_ctl1:		.res 1 ; PPU Control Register 2 Value

.include "macros.s"

;*****************************************************************
; wait_frame: waits until the next NMI occurs
;*****************************************************************
.segment "CODE"

.proc wait_frame
    INC nmi_ready
@loop:
    LDA nmi_ready
    BNE @loop
    RTS 
.endproc

;*****************************************************************
; ppu_update: waits until next NMI, turns rendering on (if not already), 
; uploads OAM, palette, and nametable update to PPU
;*****************************************************************
.segment "CODE"

.proc ppu_update
    LDA ppu_ctl0
    ORA #VBLANK_NMI
    STA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    ORA #OBJ_ON|BG_ON
    STA ppu_ctl1
    JSR wait_frame
    RTS
.endproc

;*****************************************************************
; ppu_off: waits until next NMI, turns rendering off 
; (now safe to write PPU directly via PPU_DATA)
;*****************************************************************
.segment "CODE"

.proc ppu_off
    JSR wait_frame
    LDA ppu_ctl0
    AND #%01111111
    STA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    AND #%11100001
    STA ppu_ctl1
    STA PPU_MASK
    RTS
.endproc

;*****************************************************************
; clear_nametable: clears the first name table
;*****************************************************************
.segment "CODE"

.proc clear_nametable
    LDA PPU_STATUS      ;reset address latch
    LDA #$20            ;set PPU address to $2000
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR

    ;empty the nametable
    LDA #0
    LDY #30             ;clear 30 rows
    rowloop:
        LDX #32         ;clear 32 columns
        columnloop:
            STA PPU_DATA
            DEX
            BNE columnloop
        DEY 
        BNE rowloop
    
    ;empty the attribute table
    LDX #64             ;attribute table is 64 bytes
    loop:
        STA PPU_DATA
        DEX
        BNE loop
    RTS
.endproc

.segment "ZEROPAGE"
gamepad:        .res 1 ;store the current gamepad state

;*****************************************************************
; gamepad_poll: this reads the gamepad state into the variable labelled "gamepad"
; This only reads the first gamepad, and also if DPCM samples are played they can
; conflict with gamepad reading, which may give incorrect results.
;*****************************************************************
.segment "CODE"

.proc gamepad_poll
    ;strobe the gamepad to latch current button state
    LDA #1
    STA JOYPAD1
    LDA #0
    STA JOYPAD1
    ;read 8 bytes from JOYPAD1
    LDX #8
loop:
    PHA
    LDA JOYPAD1
    ;combine low two bits and store in carry bit
    AND #%00000011
    CMP #%00000001
    PLA 
    ;rotate carry into gamepad variable
    ROR A 
    DEX
    BNE loop
    STA gamepad
    RTS
.endproc

;*****************************************************************
; write_text: This writes a section of text to the screen
; text_address - points to the text to write to the screen
; PPU address has been set
;*****************************************************************
.segment "ZEROPAGE"
text_address:       .res 2 ;set to the address of the text to write

.segment "CODE"
.proc write_text
    LDY #0
loop:
    LDA (text_address), y ;get the byte at the current source address
    BEQ exit              ;exit when we encounter a zero in the text
    STA PPU_DATA          ;write the byte to VRAM
    INY
    JMP loop
exit:
    RTS
.endproc


;*****************************************************************
; randomize: Get a random value from the current SEED values
;*****************************************************************
.segment "ZEROPAGE"
SEED0:  .res 2
SEED2:  .res 2

;simple shift based random number
.segment "CODE"
.proc randomize
    LDA SEED0
    LSR
    ROL SEED0 + 1
    BCC @noeor
    EOR #$B4
@noeor:
    STA SEED0
    EOR SEED0 + 1
    RTS
.endproc

;Linear Frequency random numbers
;results in a (lo) and y (hi)
.proc rand
    JSR rand64k     ; Factors of 65536: 3 5 17 257
    JSR rand32k     ; Factors of 32767; 7 31 151
    LDA SEED0 + 1   ;combine the other seed values
    EOR SEED2 + 1
    TAY             ;save the hi byte
    LDA SEED0       ;mix up low bytes of SEED0
    EOR SEED2       ;and SEED2 to combine both
    RTS
.endproc

.proc rand64k
	LDA SEED0+1
	ASL
	ASL
	EOR SEED0+1
	ASL
	EOR SEED0+1
	ASL
	ASL
	EOR SEED0+1
	ASL
	ROL SEED0	; shift this left, "random" bit comes from low
	ROL SEED0+1
	RTS
.endproc

.proc rand32k
	LDA SEED2+1
	ASL
	EOR SEED2+1
	ASL
	ASL
	ROR SEED2	; shift this right, random bit comes from high
	ROL SEED2+1
	RTS
.endproc

;*****************************************************************
; collision_test: Check whether two objects have hit each other
; Returns: Carry flag set if objects have hit each other
;*****************************************************************
.segment "ZEROPAGE"
cx1:    .res 1  ;object 1 X position
cy1:    .res 1  ;object 1 Y position
cw1:    .res 1  ;object 1 width
ch1:    .res 1  ;object 1 height

cx2:    .res 1  ;object 2 X position
cy2:    .res 1  ;object 2 Y position
cw2:    .res 1  ;object 2 width
ch2:    .res 1  ;object 2 height

.segment "CODE"
.proc collision_test
    CLC
    LDA cx1     ;get object 1 x
    ADC cw1     ;add object 1 width to it
    CMP cx2     ;is obj 2 to the right of obj 1 plus its width?
    BCC @exit
    CLC
    LDA cx2     ;get obj 2 x
    ADC cw2     ;add obj 2 width to it
    CMP cx1     ;is obj 2 to the left of obj 1?
    BCC @exit
    CLC
    LDA cy1     ;get object 1 y
    ADC ch1     ;add obj 1 height
    CMP cy2     ;is obj 1 below obj 1 plus its height?
    BCC @exit
    CLC 
    LDA cy2     ;get object 2 y
    ADC ch2     ;add obj 2 height
    CMP cy1     ;is obj 2 above obj 1?
    BCC @exit
    
    SEC         ;we have hit, set carry flag and exit
    RTS
@exit:
    CLC         ;clear carry flag and exit
    RTS
.endproc   


;*****************************************************************
;  0-99 Decimal to digit conversion
;  A = number to convert
; Outputs:
; X = decimal tens
; A = decimal ones
;*****************************************************************
.segment "CODE"
.proc dec99_to_bytes
    LDX #0
    CMP #50         ;A = 0-99
    BCC try20
    SBC #50
    LDX #5
    BNE try20

div20:
    INX 
    INX 
    SBC #20

try20:
    CMP #20
    BCS div20

try10:
    CMP #10
    BCC @finished
    SBC #10
    INX

@finished:
    ;X = decimal tens
    ;A = decmial ones
    RTS
.endproc