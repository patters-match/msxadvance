		GBLL DEBUG
		GBLL SAFETY

DEBUG		SETL {FALSE}

;BUILD		SETS "DEBUG"/"GBA"	(defined at cmdline)
;----------------------------------------------------------------------------

YSCALE_EXTRA	EQU 0x03007B00
YSCALE_LOOKUP	EQU YSCALE_EXTRA+0x50
;?				EQU YSCALE_LOOKUP+0x200		; was 0x100

VDP_RAM			EQU 0x02040000-0x4000	;16kB VRAM
EMU_RAM 		EQU VDP_RAM-0x8000		;32kB WRAM
MSXPALBUFF		EQU EMU_RAM-272*2		;MSX palette buffer, also in GBA.h
OAM_BUFFER2 	EQU MSXPALBUFF-0x400
OAM_BUFFER1 	EQU OAM_BUFFER2-0x400
CHR_DECODE		EQU OAM_BUFFER1-256*4
TMAPBUFF		EQU CHR_DECODE-240
DIRTYTILES		EQU TMAPBUFF-512
MEMMAPTBL		EQU DIRTYTILES-8*4
WRMEMTBL_		EQU MEMMAPTBL-8*4
FREQTBL			EQU WRMEMTBL_-4096*2
PCMWAVSIZE		EQU 528
PCMWAV			EQU FREQTBL-PCMWAVSIZE*4
;STATEPTR		EQU PCMWAV-0x6100
END_OF_EXRAM	EQU PCMWAV-0x1000					;-0xA000 room left for code.

DMA0BUFF		EQU 0x6001800
DMA3BUFF		EQU 0x6002000

AGB_IRQVECT		EQU 0x3007FFC
AGB_PALETTE		EQU 0x5000000
AGB_VRAM		EQU 0x6000000
AGB_OAM			EQU 0x7000000
AGB_SRAM		EQU 0xE000000
EMU_SRAM		EQU 0xE004000
DEBUGSCREEN		EQU AGB_VRAM+0x3800

REG_BASE		EQU 0x4000000
REG_DISPCNT		EQU 0x00
REG_DISPSTAT	EQU 0x04
REG_VCOUNT		EQU 0x06
REG_BG0CNT		EQU 0x08
REG_BG1CNT		EQU 0x0A
REG_BG2CNT		EQU 0x0C
REG_BG3CNT		EQU 0x0E
REG_BG0HOFS		EQU 0x10
REG_BG0VOFS		EQU 0x12
REG_BG1HOFS		EQU 0x14
REG_BG1VOFS		EQU 0x16
REG_BG2HOFS		EQU 0x18
REG_BG2VOFS		EQU 0x1A
REG_BG3HOFS		EQU 0x1C
REG_BG3VOFS		EQU 0x1E
REG_WIN0H		EQU 0x40
REG_WIN1H		EQU 0x42
REG_WIN0V		EQU 0x44
REG_WIN1V		EQU 0x46
REG_WININ		EQU 0x48
REG_WINOUT		EQU 0x4A
REG_BLDCNT		EQU 0x50
REG_BLDALPHA	EQU 0x52
REG_BLDY		EQU 0x54
REG_SG1CNT_L	EQU 0x60
REG_SG1CNT_H	EQU 0x62
REG_SG1CNT_X	EQU 0x64
REG_SG2CNT_L	EQU 0x68
REG_SG2CNT_H	EQU 0x6C
REG_SG3CNT_L	EQU 0x70
REG_SG3CNT_H	EQU 0x72
REG_SG3CNT_X	EQU 0x74
REG_SG4CNT_L	EQU 0x78
REG_SG4CNT_H	EQU 0x7c
REG_SGCNT_L		EQU 0x80
REG_SGCNT_H		EQU 0x82
REG_SGCNT_X		EQU 0x84
REG_SGBIAS		EQU 0x88
REG_SGWR0_L		EQU 0x90
REG_FIFO_A_L	EQU 0xA0
REG_FIFO_A_H	EQU 0xA2
REG_FIFO_B_L	EQU 0xA4
REG_FIFO_B_H	EQU 0xA6
REG_DM0SAD		EQU 0xB0
REG_DM0DAD		EQU 0xB4
REG_DM0CNT_L	EQU 0xB8
REG_DM0CNT_H	EQU 0xBA
REG_DM1SAD		EQU 0xBC
REG_DM1DAD		EQU 0xC0
REG_DM1CNT_L	EQU 0xC4
REG_DM1CNT_H	EQU 0xC6
REG_DM2SAD		EQU 0xC8
REG_DM2DAD		EQU 0xCC
REG_DM2CNT_L	EQU 0xD0
REG_DM2CNT_H	EQU 0xD2
REG_DM3SAD		EQU 0xD4
REG_DM3DAD		EQU 0xD8
REG_DM3CNT_L	EQU 0xDC
REG_DM3CNT_H	EQU 0xDE
REG_TM0CNT_L	EQU 0x100
REG_TM0CNT_H	EQU 0x102
REG_TM1CNT_L	EQU 0x104
REG_TM1CNT_H	EQU 0x106
REG_TM2CNT_L	EQU 0x108
REG_TM2CNT_H	EQU 0x10A
REG_TM3CNT_L	EQU 0x10C
REG_TM3CNT_H	EQU 0x10E
REG_IE			EQU 0x200
REG_IF			EQU 0x4000202
REG_P1			EQU 0x4000130
REG_P1CNT		EQU 0x132
REG_WAITCNT		EQU 0x4000204

REG_SIOMULTI0	EQU 0x20 ;+100
REG_SIOMULTI1	EQU 0x22 ;+100
REG_SIOMULTI2	EQU 0x24 ;+100
REG_SIOMULTI3	EQU 0x26 ;+100
REG_SIOCNT		EQU 0x28 ;+100
REG_SIOMLT_SEND	EQU 0x2a ;+100
REG_RCNT		EQU 0x34 ;+100

		;r0,r1,r2=temp regs
z80f		RN r3	;see z80mac.h
z80a		RN r4	;bits 0-15=0
z80bc		RN r5	;bits 0-15=0
z80de		RN r6	;bits 0-15=0
z80hl		RN r7	;bits 0-15=0
cycles		RN r8
z80pc		RN r9
globalptr	RN r10	;=wram_globals* ptr
z80optbl	RN r10
z80sp		RN r11	;bits 0-15=0
z80xy		RN lr	;pointer to IX or IY reg
addy		RN r12	;keep this at r12 (scratch for APCS)
			;r13=SP
			;r14=LR
			;r15=PC
;----------------------------------------------------------------------------

;everything in wram_globals* areas:

 MAP 0,globalptr	;z80.s
opz # 256*4
pzst # 256
writemem_tbl # 8*4
memmap_tbl # 64*4
cpuregs # 8*4
cpuregs2 # 8*4
z80_ix # 4
z80_iy # 4
lastbank # 4
z80_iff1 # 1
z80_iff2 # 1
z80_im # 1
z80_if_ # 1
z80_i # 1
z80_r # 1
z80_temp1 # 1
z80_temp2 # 1
nexttimeout # 4
nexttimeout_ # 4
oldcycles # 4
scanline # 4
scanlinehook # 4
frame # 4
cyclesperscanline # 4
lastscanline # 4
			;gfx.s (wram_globals1)
fpsvalue # 4
AGBjoypad # 4
EMUjoypad # 4
windowtop # 16

adjustblend # 1
twitch # 1
flicker # 1
keyb_on # 1

vramaddr # 4

vdpmode1 # 1
vdpmode2 # 1
nametable # 1
ctoffset # 1
pgoffset # 1
satoffset # 1
sproffset # 1
bdcolor # 1

vdpbuff # 1
toggle # 1
vdpstat # 1
vdpctrl # 1
vdpmode2_bak # 1
minpan # 1
maxpan # 1
ystart # 1		;6 scaled SMS 224 screen starts on this line
sprBank # 1
keyb_scroll # 1
 # 2 ;align
			;cart.s (wram_globals2)
rombase # 4
rombase2k # 4
rombase4k # 4
rombase6k # 4
rombase8k # 4
rombaseAk # 4
rombaseCk # 4
rombaseEk # 4
rambase8k # 4
rambaseAk # 4
rambaseCk # 4
rambaseEk # 4
rommask # 4

romnumber # 4
emuflags # 4

BGoffset1 # 4
BGoffset2 # 4
BGoffset3 # 4
biosbase # 4
BankMap0 # 1
Mapper # 1
cartflags # 1
config # 1
; # 1 ;align

;-----------------------------------------------------------cartflags
SRAM			EQU 0x02 ;save SRAM
;-----------------------------------------------------------emuflags
PALTIMING		EQU 1	;PAL timing =)
COUNTRY			EQU 2	;0=World 1=JAP
NOCPUHACK		EQU 2	;don't use JMP hack
;?				EQU 16
FOLLOWMEM       EQU 32  ;0=follow sprite, 1=follow mem

				;bits 8-15=scale type

UNSCALED_NOAUTO	EQU 0	;display types
UNSCALED_AUTO	EQU 1
SCALED			EQU 2
SCALED_SPRITES	EQU 3

				;bits 16-31=sprite follow val

;----------------------------------------------------------------------------
CYC_SHIFT		EQU 8
CYCLE			EQU 1<<CYC_SHIFT ;one cycle (228*CYCLE cycles per scanline)

;cycle flags- (stored in cycles reg for speed)

CYC_C			EQU 0x01	;Carry bit
CYC_I			EQU 0x04	;IRQ mask
CYC_D			EQU 0x08	;Decimal bit
CYC_V			EQU 0x40	;Overflow bit
CYC_MASK		EQU CYCLE-1	;Mask
;----------------------------------------------------------------------------

		END

