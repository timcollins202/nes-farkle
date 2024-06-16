.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
nametable_pointer: .res 2

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
	LDA #$00
	STA $2005
	STA $2005
  RTI
.endproc

.import reset_handler

.export main
.proc main
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; write sprite data
  LDX #$00
load_sprites:
  LDA sprites,X
  STA $0200,X
  INX
  CPX #$10
  BNE load_sprites

; write nametables
;Set starting address for load_playfield
LDA $24
STA >nametable_pointer
LDA $00
STA <nametable_pointer

LDX $00
load_playfield:
LDA PPUSTATUS
LDA >nametable_pointer, X
STA PPUADDR
LDA <nametable_pointer, X
STA PPUADDR
LDA playfield, X
STA PPUDATA
CPX 

; finally, attribute table
LDA PPUSTATUS
LDA #$23
STA PPUADDR
LDA #$c2
STA PPUADDR
LDA #%01000000
STA PPUDATA

LDA PPUSTATUS
LDA #$23
STA PPUADDR
LDA #$e0
STA PPUADDR
LDA #%00001100
STA PPUDATA

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

LDA #%10010000  ; turn on NMIs, sprites use first pattern table
STA PPUCTRL
LDA #%00011110  ; turn on screen
STA PPUMASK

forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
.include "rodata.inc"

.segment "CHR"
.incbin "farkle.chr"
