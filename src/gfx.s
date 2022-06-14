	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE cart.h
	INCLUDE io.h
	INCLUDE z80.h
	INCLUDE z80mac.h
	INCLUDE sound.h

	EXPORT GFX_init
	EXPORT GFX_reset
	EXPORT debug_
	EXPORT AGBinput
	EXPORT EMUinput
	EXPORT paletteinit
;	EXPORT PaletteTxAll
	EXPORT newframe
	EXPORT endframe
	EXPORT VDPstat_R
	EXPORT VDPctrl_W
	EXPORT VDPdata_R
	EXPORT VDPdata_W
	EXPORT gfxstate
	EXPORT gammavalue
	EXPORT oambufferready
	EXPORT g_twitch
	EXPORT g_flicker
	EXPORT g_keybon
	EXPORT g_keybscroll
	EXPORT fpsenabled
	EXPORT FPSValue
	EXPORT PAL60
	EXPORT SPRS
	EXPORT vbldummy
	EXPORT vblankfptr
	EXPORT vblankinterrupt
	EXPORT AdjustSet
	EXPORT ScalemodeInit

	IMPORT RumbleInterrupt
	IMPORT StartRumbleComs

 AREA rom_code, CODE, READONLY

;----------------------------------------------------------------------------
GFX_init	;(called from main.c) only need to call once
;----------------------------------------------------------------------------
	mov addy,lr

	mov r1,#0xffffff00		;build chr decode tbl
	ldr r2,=CHR_DECODE		;0x400
ppi
	mov r0,#0
	tst r1,#0x01
	orrne r0,r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi

	mov r1,#REG_BASE
	mov r0,#0x0008
	strh r0,[r1,#REG_DISPSTAT]	;vblank en

	add r2,r1,#REG_IE
	mov r0,#-1
	strh r0,[r2,#2]			;stop pending interrupts
	ldr r0,=irqhandler
	str r0,[r1,#-4]			;=AGB_IRQVECT
	ldr r0,=0x10A1			;key,serial,timer2,vblank. (serial interrupt=0x80)
	strh r0,[r2]
	mov r0,#1
	strh r0,[r2,#8]			;master irq enable

	ldr r0,=0x00C1EB84		;5244, pre *64. for 50Hz timing
	str r0,[r1,#REG_TM2CNT_L]

	bx addy
;----------------------------------------------------------------------------
GFX_reset	;called with CPU reset
;----------------------------------------------------------------------------
	str lr,[sp,#-4]!

	ldr r0,=gfxstate
	mov r1,#0
	mov r2,#5				;5*4
	bl memset_				;clear GFX regs

	str r1,windowtop

	mov r1,#0x00			;0x16
	bl VDPreg0_W
	mov r1,#0x00			;0x20
	bl VDPreg1_W
	mov r1,#0xFF
	bl VDPreg2_W			;nametable

;------------------------------------------------------------------------------
SetHeight
	mov r0,#0
	mov r1,#32		;maxpan
	strb r0,minpan
	strb r1,maxpan
;------------------------------------------------------------------------------

	mov r0,#0x0000
	str r0,BGoffset1
	mov r0,#0x0100
	str r0,BGoffset2
	mov r0,#0x0200
	str r0,BGoffset3

	ldr r0,=VDP_RAM
	mov r0,r0,ror#14
	str r0,vramaddr

	mov r0,#AGB_VRAM
	mov r1,#0
	mov r2,#0x900
	bl memset_				;clear VRAM
	add r0,r0,#0x6800
	mov r1,#0
	mov r2,#0x140
	bl memset_				;clear keyb map

	mov r0,#AGB_OAM
	mov r1,#0x2a0
	mov r2,#0x100
	bl memset_				;no stray sprites please
	ldr r0,=OAM_BUFFER1
	mov r2,#0x200
	bl memset_
	bl paletteinit			;do palette mapping
	bl ScalemodeInit

	ldr pc,[sp],#4


;----------------------------------------------------------------------------
paletteinit;	r0-r3 modified.
;called by ui.c:  void map_palette(char gammavalue)
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r8,lr}
	ldrb r1,gammavalue	;gamma value = 0 -> 4
MapSG_Pal
	adr r7,KB_Palette
	ldr r6,=MSXPALBUFF
	mov r4,#32
SG_preloop				;Keyboard colors
	ldrh r0,[r7],#2
	strh r0,[r6],#2
	subs r4,r4,#1
	bne SG_preloop

	adr r7,SG_Palette
	ldr r8,=AGB_PALETTE+0x202
	ldr r6,=MSXPALBUFF+0x100
	mov r4,#16
nomapSG					;map rrrrrrrrggggggggbbbbbbbb  ->  0bbbbbgggggrrrrr
	ldrb r0,[r7,#2]		;Blue ready
	bl gammaconvert
	mov r5,r0

	ldrb r0,[r7,#1]		;Green ready
	bl gammaconvert
	orr r5,r0,r5,lsl#5

	ldrb r0,[r7],#3		;Red ready
	bl gammaconvert
	orr r5,r0,r5,lsl#5

	strh r5,[r6],#2
	strh r5,[r8],#0x20
	subs r4,r4,#1
	bne nomapSG

	ldmfd sp!,{r4-r8,lr}
	bx lr

;----------------------------------------------------------------------------
KB_Palette
	DCW 0x0000, 0x73BD, 0x5F5B, 0x0842, 0x6B9D, 0x6B7B, 0x42D7, 0x4AF9
	DCW 0x4F19, 0x5719, 0x39EF, 0x7BFF, 0x10A5, 0x4A73, 0x294A, 0x0000
;Capslock light
	DCW 0x0000, 0x73BD, 0x5F5B, 0x0842, 0x6B9D, 0x6B7B, 0x42D7, 0x4AF9
	DCW 0x4F19, 0x5719, 0x001A, 0x7BFF, 0x10A5, 0x1CFF, 0x208F, 0x0000
;----------------------------------------------------------------------------
SG_Palette
	DCB 0,0,0,     0,0,0,       36,218,36,   109,255,109, 36,36,255, 72,109,255,  182,36,36,   72,218,255
	DCB 255,36,36, 255,109,109, 218,218,36, 218,218,145,  36,145,36, 218,72,182,  182,182,182, 255,255,255
;	DCB 0,0,0,     0,0,0,       33,200,66,   94,220,120,  84,85,237, 125,118,252, 212,82,77,   66,235,245
;	DCB 252,85,84, 255,121,120, 212,193,84,  230,206,128, 33,176,59, 201,91,186,  204,204,204, 255,255,255
;----------------------------------------------------------------------------
gprefix
	orr r0,r0,r0,lsl#2
gprefix2
	orr r0,r0,r0,lsl#4
;----------------------------------------------------------------------------
gammaconvert;	takes value in r0(0-0xFF), gamma in r1(0-4),returns new value in r0=0x1F
;----------------------------------------------------------------------------
	rsb r2,r0,#0x100
	mul r3,r2,r2
	rsb r2,r3,#0x10000
	rsb r3,r1,#4
	orr r0,r0,r0,lsl#8
	mul r2,r1,r2
	mla r0,r3,r0,r2
	mov r0,r0,lsr#13

	bx lr
;----------------------------------------------------------------------------
AdjustSet
;----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	ldrb r2,adjustblend
	subs r2,r2,#1
	movmi r2,#4
	strb r2,adjustblend

	bl ScalemodeInit
	ldmfd sp!,{r0-r3,lr}
	bx lr
;----------------------------------------------------------------------------
ScalemodeInit;
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,r10,lr}
	ldr globalptr,=|wram_globals0$$Base|
	ldrb r0,emuflags+1
	cmp r0,#SCALED
	bmi vblalpha

	ldr r0,=DMA0BUFF	;setup DMA buffer for scrolling:
	mov r1,#160
	mov r2,#8
	mov r3,#8
	mov r4,#0
	mov r5,#0
	ldrb r7,flicker
	tst r7,#1
	moveq r4,#0x10000
	movne r5,#0x10000
	tst r7,#4
	addne r3,r3,#1			;adjust second horizontaly.
	movne r4,#0x10000
	movne r5,#0x00000
	tst r7,#6
	addne r3,r3,#0x10000
	tst r7,#2
	moveq r6,#0
	movne r6,#1
	ldr r7,=bh0
	strb r6,[r7],#8
	mov r6,r6,lsl#4
	strb r6,[r7]
	

vblscaled					;(scaled)
		ldrb r7,adjustblend
		cmp r7,#0
		beq scl2
		cmp r7,#2
		bmi scl3
		beq scl4
		cmp r7,#4
		bmi scl5
scl1
		str r2,[r0],#4
		str r3,[r0],#4
scl2
		str r2,[r0],#4
		str r3,[r0],#4
scl3
		str r2,[r0],#4
		str r3,[r0],#4
scl4
		str r2,[r0],#4
		str r3,[r0],#4
scl5
		add r3,r3,r5
		str r2,[r0],#4
		str r3,[r0],#4

		add r2,r2,#0x10000
		add r3,r3,r4

	subs r1,r1,#5
	bpl scl1

vblalpha
	ldr r0,=DMA3BUFF	;setup DMA buffer for scrolling:
	mov r1,#160

	ldrb r7,flicker
	cmp r7,#1
	adrmi r6,BlendTable0
	adreq r6,BlendTable1
	adrhi r6,BlendTable2
	tst r7,#4
	adrne r6,BlendTable3
	ldmia r6,{r2-r6}

		ldrb r7,adjustblend
		cmp r7,#0
		beq alph2
		cmp r7,#2
		bmi alph3
		beq alph4
		cmp r7,#4
		bmi alph5

alph1
	strh r2,[r0],#2
alph2
	strh r3,[r0],#2
alph3
	strh r4,[r0],#2
alph4
	strh r5,[r0],#2
alph5
	strh r6,[r0],#2

	subs r1,r1,#5
	bpl alph1

	ldmfd sp!,{r4-r7,r10,lr}
	bx lr
BlendTable0
	DCD 0x0010,0x0010,0x0010,0x0010,0x0010
BlendTable1
	DCD 0x0010,0x0010,0x0010,0x0010,0x0808
BlendTable2
	DCD 0x030D,0x050B,0x0808,0x0B05,0x0D03
BlendTable3
	DCD 0x0404,0x0404,0x0404,0x0404,0x0404

;----------------------------------------------------------------------------
PaletteTxAll		; Called from ui.c
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,lr}
	ldr r4,=0x1FFE			;mask
	ldr r2,=EMU_RAM+0x2040
	add r3,r2,#0x100
;	ldr r7,=MAPPED_RGB
	ldr r5,=MSXPALBUFF


	ldmfd sp!,{r4-r9,lr}
	bx lr

;----------------------------------------------------------------------------
showfps_		;fps output, r0-r3=used.
;----------------------------------------------------------------------------
	ldrb r0,fpschk
	subs r0,r0,#1
	movmi r0,#59
	strb r0,fpschk
	bxpl lr					;End if not 60 frames has passed

;	str lr,[sp,#-4]!
;	ldr r1,=StartRumbleComs
;	adr lr,ret_
;	bx r1
ret_
;	ldr lr,[sp],#4

	ldrb r0,fpsenabled
	tst r0,#1
	bxeq lr					;End if not enabled

	ldr r0,fpsvalue
	cmp r0,#0
	bxeq lr					;End if fps==0, to keep it from appearing in the menu
	mov r1,#0
	str r1,fpsvalue

	mov r1,#100
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	add r0,r0,#0x30
	strb r0,fpstext+5
	mov r0,r1
	mov r1,#10
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	add r0,r0,#0x30
	strb r0,fpstext+6
	add r1,r1,#0x30
	strb r1,fpstext+7
	

	adr r0,fpstext
	ldr r2,=DEBUGSCREEN
;	add r2,r2,r1,lsl#6
db1
	ldrb r1,[r0],#1
	orr r1,r1,#0x4100
	strh r1,[r2],#2
	tst r2,#0xE
	bne db1

	bx lr
;----------------------------------------------------------------------------
fpstext		DCB "FPS:    "
fpsenabled	DCB 0
fpschk		DCB 0
gammavalue	DCB 0
bcolor		DCB 0
;----------------------------------------------------------------------------
debug_		;debug output, r0=val, r1=line, r2=used.
;----------------------------------------------------------------------------
; [ DEBUG
	ldr r2,=DEBUGSCREEN
	add r2,r2,r1,lsl#6
db0
	mov r0,r0,ror#28
	and r1,r0,#0x0f
	cmp r1,#9
	addhi r1,r1,#7
	add r1,r1,#0x30
	orr r1,r1,#0x4100
	strh r1,[r2],#2
	tst r2,#15
	bne db0
; ]
	bx lr
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	AREA wram_code1, CODE, READWRITE
irqhandler	;r0-r3,r12 are safe to use
;----------------------------------------------------------------------------
	mov r2,#REG_BASE
	mov r3,#REG_BASE
	ldr r1,[r2,#REG_IE]!
	and r1,r1,r1,lsr#16	;r1=IE&IF
	ldrh r0,[r3,#-8]
	orr r0,r0,r1
	strh r0,[r3,#-8]

		;---these CAN'T be interrupted
		ands r0,r1,#0x80
		strneh r0,[r2,#2]		;IF clear
;		bne RumbleInterrupt
		bne serialinterrupt
		;---

		;---these CAN be interrupted
		ands r0,r1,#0x01
		ldrne r12,vblankfptr
		bne jmpintr
		;----
		adreq r12,irq0
		moveq r0,r1		;if unknown interrupt occured clear it.
jmpintr
	strh r0,[r2,#2]		;IF clear

	mrs r3,spsr
	stmfd sp!,{r3,lr}
	mrs r3,cpsr
	bic r3,r3,#0x9f
	orr r3,r3,#0x1f			;--> Enable IRQ . Set CPU mode to System.
	msr cpsr_cf,r3
	stmfd sp!,{lr}
	adr lr,irq0

	mov pc,r12


irq0
	ldmfd sp!,{lr}
	mrs r3,cpsr
	bic r3,r3,#0x9f
	orr r3,r3,#0x92        		;--> Disable IRQ. Set CPU mode to IRQ
	msr cpsr_cf,r3
	ldmfd sp!,{r0,lr}
	msr spsr_cf,r0
vbldummy
	bx lr
;----------------------------------------------------------------------------
vblankfptr DCD vbldummy			;later switched to vblankinterrupt
PAL60		DCB 0
SPRS		DCB 0				;SpriteScanning On/Off
			DCB 0
			DCB 0
vblankinterrupt;
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,globalptr,lr}
	ldr globalptr,=|wram_globals0$$Base|

	bl Vbl_Sound_1
	bl showfps_
;	ldr r0,emuflags
;	tst r0,#PALTIMING
;	beq nopal60
;	ldrb r0,PAL60
;	subs r0,r0,#1
;	movmi r0,#5
;	strb r0,PAL60
;nopal60

	ldrb r0,keyb_on
	ands r0,r0,#2
	moveq r0,#-2
	ldrb r1,keyb_scroll
	adds r1,r1,r0
	movmi r1,#0
	cmp r1,#96
	movpl r1,#96
	strb r1,keyb_scroll

	ldrb r0,emuflags+1
	cmp r0,#SCALED
	bhs vbl8
vblunscaled
	ldr r2,=DMA0BUFF	;setup DMA buffer for scrolling:
	mov r3,#160
	mov r6,#8

	ldr r1,windowtop+12
	orr r1,r6,r1,lsl#16
vbl7
	str r1,[r2],#4
	str r1,[r2],#4
	str r1,[r2],#4
	subs r3,r3,#1
	bhi vbl7
vbl8


	mov r1,#REG_BASE
	strh r1,[r1,#REG_DM0CNT_H]		;DMA0 stop
	strh r1,[r1,#REG_DM3CNT_H]		;DMA3 stop

	add r2,r1,#REG_DM3SAD

	ldr r0,oambufferready
	cmp r0,#0
	ldrne r3,dmaoambuffer			;DMA3 src, OAM transfer:
	movne r4,#AGB_OAM				;DMA3 dst
	movne r6,#0x84000000			;noIRQ 32bit incsrc incdst
	orrne r5,r6,#0x100				;128 sprites (1024 bytes)
	stmneia r2,{r3-r5}				;DMA3 go

	ldrne r3,=MSXPALBUFF			;DMA3 src, Palette transfer:
	movne r4,#AGB_PALETTE			;DMA3 dst
	orrne r5,r6,#0x88				;272 words (544 bytes)
	stmneia r2,{r3-r5}				;DMA3 go
	mov r0,#0
	str r0,oambufferready

	ldr r3,=DMA0BUFF				;setup HBLANK DMA for display scroll:
	add r4,r1,#REG_BG0HOFS			;set 1st value manually, HBL is AFTER 1st line
	ldmia r3!,{r5-r6}
	stmia r4,{r5-r6}
	add r2,r1,#REG_DM0SAD
	ldr r5,=0xA6600002				;noIRQ hblank 32bit repeat incsrc inc_reloaddst
	stmia r2,{r3-r5}				;DMA0 go

	ldr r3,=DMA3BUFF				;setup HBLANK DMA for alpha blending:
	add r4,r1,#REG_BLDALPHA			;set 1st value manually, HBL is AFTER 1st line
	ldrh r5,[r3],#2
	strh r5,[r4]
	add r2,r1,#REG_DM3SAD
	ldr r5,=0xA2600001				;noIRQ hblank 16bit repeat incsrc inc_reloaddst
	stmia r2,{r3-r5}				;DMA3 go

	ldrb r0,keyb_scroll
	strh r0,[r1,#REG_BG2VOFS]

	ldr r2,BGoffset1
	add r0,r2,#0x0A
	strh r0,[r1,#REG_BG0CNT]
	strh r0,[r1,#REG_BG1CNT]
	ldr r0,=0x0D05
	strh r0,[r1,#REG_BG2CNT]
	mov r0,#0x4600
	strh r0,[r1,#REG_BG3CNT]

	ldr r0,=0x1F40					;1d sprites, OBJ, BG0/1/2/3 enable. mode0.
	ldrb r2,vdpmode2_bak
	tst r2,#0x40
	biceq r0,r0,#0x1300				;Turn off sprites and bg
	tst r2,#0x10					;mode1?
	bicne r0,r0,#0x1000				;Turn off sprites
	strh r0,[r1,#REG_DISPCNT]		;set value manually

exit_vbl
	bl Vbl_Sound_2
	ldmfd sp!,{r4-r9,globalptr,pc}

;------------------------------------------------------------------------------
newframe	;called before line 0	(r0-r9 safe to use)
;------------------------------------------------------------------------------
	mov r0,#-1
	str r0,scanline			;reset scanline count
	mov r0,#0
	str r0,nametableline

	bx lr

;------------------------------------------------------------------------------
endframe	;called just before screen end (~line 192)	(r0,r2 safe to use)
;------------------------------------------------------------------------------
	stmfd sp!,{r1,r3-r9,r11,lr}

	ldr r0,=default_scanlinehook
	str r0,scanlinehook

	ldrb r0,nametable
	mov addy,#224
	bl NT_finnish
	bl bg_finish
;--------------------------
	bl sprDMA_do_m2
;--------------------------
;	bl PaletteTxAll
;--------------------------


	ldr r2,=MSXPALBUFF
	ldrb r0,bdcolor
	and r1,r0,#0x0F
	add r3,r2,#0x100
	add r1,r3,r1,lsl#1
	ldrh r1,[r1]
	strh r1,[r2]

	and r1,r0,#0xF0
	add r1,r3,r1,lsr#3
	ldrh r1,[r1]
	strh r1,[r2,#34]

	mrs r5,cpsr
	orr r1,r5,#0x80			;--> Disable IRQ.
	msr cpsr_cf,r1

	ldr r0,dmaoambuffer
	ldr r1,tmpoambuffer
	str r0,tmpoambuffer
	str r1,dmaoambuffer

	adrl r0,BGoffset1
	ldmib r0,{r1-r2}		;load with pre increment
	ldr r3,BGoffset1
	stmia r0,{r1-r3}		;store with post increment

	mov r0,#1
	str r0,oambufferready

	adrl r0,windowtop		;load wtop, store in wtop+4.......load wtop+8, store in wtop+12
	ldmia r0,{r1-r3}		;load with post increment
	stmib r0,{r1-r3}		;store with pre increment

	msr cpsr_cf,r5			;--> restore mode,Enable IRQ.


	ldrb r4,novblankwait
	cmp r4,#2
	beq l03
l01
	ldr r0,emuflags
	tst r0,#PALTIMING
	moveq r1,#0x01			;VBL wait
	movne r1,#0x20			;Timer2 wait

	cmp r4,#1
	movne r0,#0				;wait for vblank if it hasn't allready happened.
	moveq r0,#1				;wait for next vblank.
	swi 0x040000			; Turn of CPU until IRQ if not too late allready.
	cmp r4,#3				;Check for slomo
	moveq r4,#0
	beq l01
l03

	bl Transfer_VRAM_m2
	ldmfd sp!,{r1,r3-r9,r11,lr}
	bx lr
;------------------------------------------------------------------------------
VDPctrl_W
;------------------------------------------------------------------------------
	ldrb r1,toggle
	eors r1,r1,#1
	strb r1,toggle

	ldr r1,vramaddr
	and r0,r0,#0xFF
	biceq r1,r1,#0xFC000000
	bicne r1,r1,#0x03FC0000
	orreq r1,r1,r0,lsl#26
	orrne r1,r1,r0,lsl#18
	str r1,vramaddr
	movne pc,lr

	movs r2,r0,lsr#6
	strb r2,vdpctrl
	ldr pc,[pc,r2,lsl#2]
	DCD 0
VDPdest
	DCD VDPctrl0_W
	DCD VDPctrl1_W
	DCD VDPctrl2_W
	DCD VDPctrl2_W
;------------------------------------------------------------------------------
VDPctrl0_W					;set read address, fill buffer.
;------------------------------------------------------------------------------
	mov r0,r1,ror#18
	ldrb r0,[r0]
	strb r0,vdpbuff
	add r1,r1,#0x00040000
	str r1,vramaddr
VDPctrl1_W
	mov pc,lr
;------------------------------------------------------------------------------
VDPctrl2_W
;------------------------------------------------------------------------------
	mov r1,r1,lsr#18
	and r0,r0,#0x7
	ldr pc,[pc,r0,lsl#2]
	DCD 0
VDPregs
	DCD VDPreg0_W
	DCD VDPreg1_W
	DCD VDPreg2_W
	DCD VDPreg3_W
	DCD VDPreg4_W
	DCD VDPreg5_W
	DCD VDPreg6_W
	DCD VDPreg7_W

;------------------------------------------------------------------------------
VDPreg0_W
;------------------------------------------------------------------------------
	strb r1,vdpmode1
	mov pc,lr
;------------------------------------------------------------------------------
VDPreg1_W
;------------------------------------------------------------------------------
	strb r1,vdpmode2
	mov pc,lr
;------------------------------------------------------------------------------
VDPreg2_W
;------------------------------------------------------------------------------
	ldrb r0,nametable
	strb r1,nametable

	ldr addy,scanline	;addy=scanline
NT_finnish
;	add addy,addy,#1	;maybe check cycles and add 2 sometimes?
	cmp addy,#192
	movhi addy,#192
	adr r2,nametableline
	swp r1,addy,[r2]	;r1=lastline, lastline=scanline

	ldr r2,=TMAPBUFF
	add r1,r2,r1
	add r2,r2,addy
nt1
	strb r0,[r2],#-1	;fill backwards from scanline to lastline
	cmp r2,r1
	bpl nt1
	mov pc,lr

nametableline DCD 0 ;..was when?

;------------------------------------------------------------------------------
VDPreg3_W						;Color Table - offset
;------------------------------------------------------------------------------
	ldrb r0,ctoffset
	strb r1,ctoffset
	eor r0,r0,r1
	ands r0,r0,#0x80
	moveq pc,lr
DT_clear
;	mov r11,r11
	and r1,r1,#0x80
	mov r2,#0x40
	ldr r0,=DIRTYTILES
	add r0,r0,r1,lsl#1
	mov r1,#0x00000000
	b memset_
;------------------------------------------------------------------------------
VDPreg4_W						;Pattern Generator Table - offset
;------------------------------------------------------------------------------
	and r1,r1,#7
	ldrb r0,pgoffset
	strb r1,pgoffset
	eor r0,r0,r1
	ands r0,r0,#4
	moveq pc,lr
	mov r1,r1,lsl#5
	b DT_clear
;------------------------------------------------------------------------------
VDPreg5_W						;Sprite Attribute Table - offset
;------------------------------------------------------------------------------
	strb r1,satoffset
	mov pc,lr
;------------------------------------------------------------------------------
VDPreg6_W						;Sprite tiles - offset
;------------------------------------------------------------------------------
	and r1,r1,#7
	ldrb r0,sproffset
	strb r1,sproffset
	cmp r0,r1
	moveq pc,lr

	mov r2,#0x10
	ldr r0,=DIRTYTILES
	add r0,r0,r1,lsl#6
	mov r1,#0x00000000
	b memset_
;------------------------------------------------------------------------------
VDPreg7_W						;Backdrop/Text Color
;------------------------------------------------------------------------------
	strb r1,bdcolor
	mov pc,lr

;------------------------------------------------------------------------------
VDPdata_W
;------------------------------------------------------------------------------
	strb z80a,toggle
	strb r0,vdpbuff
	ldr r1,vramaddr
	add r2,r1,#0x00040000
	str r2,vramaddr

	mov r2,r1,ror#18
	strb r0,[r2]

	ldr r2,=DIRTYTILES
	strb z80a,[r2,r1,lsr#23]
	mov pc,lr
;------------------------------------------------------------------------------
VDPdata_R
;------------------------------------------------------------------------------
	strb z80a,toggle
	ldr r1,vramaddr
	add r0,r1,#0x00040000
	str r0,vramaddr
	mov r1,r1,ror#18
	ldrb r1,[r1]
	ldrb r0,vdpbuff
	strb r1,vdpbuff

	mov pc,lr
;------------------------------------------------------------------------------
VDPstat_R
;------------------------------------------------------------------------------
;	mov r11,r11					;No$GBA breakpoint
	strb z80a,toggle
	ldrb r0,vdpstat
	strb z80a,vdpstat

	mov pc,lr

;----------------------------------------------------------------------------
;sprDMA_do			;Called from endframe. YATX
;----------------------------------------------------------------------------
PRIORITY EQU 0x800				;0x800=AGB OBJ priority 2

;----------------------------------------------------------------------------
sprDMA_do_m2					;Called from endframe.
;----------------------------------------------------------------------------
	ldr r2,tmpoambuffer			;Destination

	ldr addy,=VDP_RAM
	ldrb r0,satoffset
	and r1,r0,#0x7F
	add addy,addy,r1,lsl#7

	ldr r1,emuflags
	and r5,r1,#0x300
	cmp r5,#SCALED_SPRITES*256
	movne r6,#0
	moveq r6,#0x100				;r6= scale obj

	ldrb r0,vdpmode2
	movs r0,r0,lsl#31			;double pixels/16x16 size
	orrmi r6,r6,r6,lsl#18		;scaling param
	orrmi r6,r6,#0x00000300		;scaling+double
	orrmi r6,r6,#0x02000000		;scaling param
	orrcs r6,r6,#0x00008000		;16x16 size

	mov r0,#0
	ldrb r4,ystart				;first scanline?
	cmp r5,#UNSCALED_AUTO*256	;do autoscroll
	bhi dm2_1
	movle r4,#0
	bne dm2_0
;	ldr r3,AGBjoypad
;	ands r3,r3,#0x300
;	eornes r3,r3,#0x300
;	bne dm2_0					;stop if L or R pressed (manual scroll)
	ldrb r0,[addy,r1,lsr#16]	;follow sprite
;	tst r1,#FOLLOWMEM
;	ldreqb r0,[addy,r1,lsr#16]		;follow sprite
;	ldrneb r0,[cpu_zpage,r1,lsr#16]	;follow memory
	sub r0,r0,#0x60
	adds r0,r0,r0,asr#3
	movmi r0,#0
	ldrb r1,maxpan
	cmp r0,r1
	movpl r0,r1
	str r0,windowtop
dm2_0
	ldr r0,windowtop+8
dm2_1
	add r4,r4,r0
	ldr r5,=YSCALE_LOOKUP
	tst r6,r6,lsl#11			;16x16 size + scaling?
	subne r5,r5,#3
	sub r5,r5,r4
	mov r8,#32					;number of sprites
	mov r7,#PRIORITY+0x300
	mov r1,#0x04000000
dm2_2
	ldr r4,[addy],#4			;TMS9918 OBJ, r0=Ypos.
	mov r0,r4,lsl#24
	cmp r0,#0xD0000000
	beq dm2_3					;skip the rest if sprite Y=208
	and r9,r4,#0xFF00
	rsb r9,r1,r9,lsl#15
	tst r4,#0x80000000			;EC early clock, x -=32.
	subne r9,r9,#0x10000000

	add r0,r0,#0x10000000
	ldrb r0,[r5,r0,lsr#24]		;y = scaled y
	orr r0,r0,r6				;size plus scaling?
	tst r4,#0xF000000			;Color 0 sprite = invisible.
	moveq r0,#0x2a0				;double, y=160
	orr r3,r0,r9,lsr#7
	str r3,[r2],#4				;store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	mov r4,r4,ror#24
	orr r3,r7,r4,lsr#24			;tiles + tileoffset + priority
	orr r3,r3,r4,lsl#12			;palette
	tst r6,#0x00008000			;16x16 size?
	bicne r3,r3,#3				;only even tiles in 16x16 mode
	strh r3,[r2],#4				;store OBJ Atr 2. Pattern, palette.

	moveq r0,#0x2a0				;double, y=160
	addne r3,r3,#2				;tile+2
	addne r9,r9,#0x04000000
	tstne r6,#0x00000200		;zoom?
	addne r9,r9,#0x04000000
	orr r0,r0,r9,lsr#7
	str r0,[r2],#4				;store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.
	strh r3,[r2],#4				;store OBJ Atr 2. Pattern, palette.

	subs r8,r8,#1
	bne dm2_2
	bx lr

dm2_3
	mov r0,#0x2a0				;double, y=160
dm2_4
	str r0,[r2],#8
	str r0,[r2],#8
	subs r8,r8,#1
	bne dm2_4
	bx lr

;----------------------------------------------------------------------------
T_data
	DCD DIRTYTILES
VDP_RAM_ptr
	DCD VDP_RAM
	DCD CHR_DECODE
	DCD AGB_VRAM+0x08000		;BGR tiles
	DCD AGB_VRAM+0x14000		;SPR tiles
;----------------------------------------------------------------------------
Transfer_VRAM_m0
;----------------------------------------------------------------------------
	ldrb r0,vdpmode2
	tst r0,#0x10
	bne	Transfer_VRAM_m1

	add r11,r5,r1,lsl#6
	ldrb r9,[r4,r1,lsl#1]
	orr r0,r9,#0x0F
	strb r0,[r4,r1,lsl#1]
	orr r9,r9,r9,lsl#8
	orr r9,r9,r9,lsl#16
	add r5,r5,r2,lsl#11
	add r4,r4,r2,lsl#6
	adr r10,tileloop2_4
	mov r1,#0
tileloop0_0
	ldr r0,=0x0F0F0F0F
	ldr addy,[r4]
	orr r2,addy,r0
	str r2,[r4],#4
	and addy,addy,r9
	tst addy,#0x0000000F
	addne r1,r1,#0x20
	bleq tileloop0_2
	tst addy,#0x00000F00
	addne r1,r1,#0x20
	bleq tileloop0_2
	tst addy,#0x000F0000
	addne r1,r1,#0x20
	bleq tileloop0_2
	tst addy,#0x0F000000
	addne r1,r1,#0x20
	bleq tileloop0_2
	cmp r1,#0x2000
	bne tileloop0_0

	b tileloop_spr
;----------------------------------------------------------------------------
Transfer_VRAM_m1
;----------------------------------------------------------------------------
	add r11,r5,r1,lsl#6
	add r5,r5,r2,lsl#11
	add r4,r4,r2,lsl#6
	mov r1,#0
	ldrb r9,bdcolor
tileloop1_0
	ldr r0,=0x0F0F0F0F
	ldr addy,[r4]
	orr r2,addy,r0
	str r2,[r4],#4
	tst addy,#0x0000000F
	addne r1,r1,#0x20
	bleq tileloop1_2
	tst addy,#0x00000F00
	addne r1,r1,#0x20
	bleq tileloop1_2
	tst addy,#0x000F0000
	addne r1,r1,#0x20
	bleq tileloop1_2
	tst addy,#0x0F000000
	addne r1,r1,#0x20
	bleq tileloop1_2
	cmp r1,#0x2000
	bne tileloop1_0

	ldmfd sp!,{r10,r11,pc}
;----------------------------------------------------------------------------
Transfer_VRAM_m2
;----------------------------------------------------------------------------
	ldrb r0,vdpmode1
	ldrb r2,vdpmode2
	tst r2,#0x40				;Screen on?
	moveq pc,lr
	stmfd sp!,{r10,r11,lr}
	adr r1,T_data
	ldmia r1,{r4-r7}
	ldr r8,=0x11111111
	ldrb r1,ctoffset
	ldrb r2,pgoffset
	and r2,r2,#0x04
	tst r0,#0x02
	beq	Transfer_VRAM_m0

	and r1,r1,#0x80
	add r11,r5,r1,lsl#6
	add r9,r4,r1,lsl#1
	add r5,r5,r2,lsl#11
	add r4,r4,r2,lsl#6
	adr r10,tileloop2_2
	mov r1,#0

tileloop2_0
	ldr r0,=0x0F0F0F0F
	ldr addy,[r4]
	orr r2,addy,r0
	str r2,[r4],#4
	ldr r2,[r9]
	and addy,addy,r2
	orr r2,r2,r0
	str r2,[r9],#4
	tst addy,#0x0000000F
	addne r1,r1,#0x20
	bleq tileloop2_2
	tst addy,#0x00000F00
	addne r1,r1,#0x20
	bleq tileloop2_2
	tst addy,#0x000F0000
	addne r1,r1,#0x20
	bleq tileloop2_2
	tst addy,#0x0F000000
	addne r1,r1,#0x20
	bleq tileloop2_2
	cmp r1,#0x1800
	bne tileloop2_0


;-----------------------------------------------------
tileloop_spr					;Mode0, 2 & 3 sprites.
;-----------------------------------------------------
	ldr globalptr,=|wram_globals0$$Base|	;need ptr regs init'd
	ldr r9,=0xF0F0F0F0
	ldrb r1,sproffset
	and r1,r1,#0x07
	mov r1,r1,lsl#11
	ldr r4,T_data
	ldr r5,VDP_RAM_ptr
	add r4,r4,r1,lsr#5
	add r7,r7,#0xE000						;Sprites @ 0x06016000
	sub r7,r7,r1,lsl#2
	add r8,r1,#0x800
tileloop2_1
	ldr addy,[r4]
	orr r2,addy,r9
	str r2,[r4],#4
	tst addy,#0x000000F0
	addne r1,r1,#0x20
	bleq tileloop2_3
	tst addy,#0x0000F000
	addne r1,r1,#0x20
	bleq tileloop2_3
	tst addy,#0x00F00000
	addne r1,r1,#0x20
	bleq tileloop2_3
	tst addy,#0xF0000000
	addne r1,r1,#0x20
	bleq tileloop2_3
	cmp r1,r8
	bne tileloop2_1

	ldmfd sp!,{r10,r11,pc}

;----------------------------------------------------------------------------
tileloop1_2
	ldrb r0,[r5,r1]
	ldr r0,[r6,r0,lsl#2]
	str r0,[r7,r1,lsl#2]
	add r1,r1,#1
	tst r1,#0x1F
	bne tileloop1_2

	mov pc,lr

;----------------------------------------------------------------------------
tileloop0_2
	bic r2,r1,#0x1800
	ldrb r2,[r11,r2,lsr#6]
	b tileloop2_4

tileloop2_2
	ldrb r2,[r11,r1]
;--------------------- !Test for Blending!
;	ldr r0,=vdpregs+7
;	ldrb r0,[r0]
;	ands r0,r0,#0xF
;	moveq r0,#1
;	mov r0,#1
	tst r2,#0x0F
bh0	orreq r2,r2,#0x01
	tst r2,#0xF0
bh1	orreq r2,r2,#0x10
;----------------------

tileloop2_4
	ldrb r0,[r5,r1]

	ldr r0,[r6,r0,lsl#2]
	ands r3,r2,#0x10
	movne r3,r0
	tst r2,#0x20
	orrne r3,r3,r0,lsl#1
	tst r2,#0x40
	orrne r3,r3,r0,lsl#2
	tst r2,#0x80
	orrne r3,r3,r0,lsl#3

	eor r0,r0,r8

	tst r2,#0x01
	orrne r3,r3,r0
	tst r2,#0x02
	orrne r3,r3,r0,lsl#1
	tst r2,#0x04
	orrne r3,r3,r0,lsl#2
	tst r2,#0x08
	orrne r3,r3,r0,lsl#3

	str r3,[r7,r1,lsl#2]
	add r1,r1,#1
	tst r1,#0x1F
	movne pc,r10

	mov pc,lr

;----------------------------------------------------------------------------
tileloop2_3
	ldrb r0,[r5,r1]
	ldr r0,[r6,r0,lsl#2]
	str r0,[r7,r1,lsl#2]
	add r1,r1,#1
	tst r1,#0x1F
	bne tileloop2_3

	mov pc,lr

;----------------------------------------------------------------------------


tmpoambuffer	DCD OAM_BUFFER1
dmaoambuffer	DCD OAM_BUFFER2

smsoamptr		DCD 0
oambufferready	DCD 0
;----------------------------------------------------------------------------
	AREA wram_globals1, CODE, READWRITE

FPSValue
	DCD 0
AGBinput			;this label here for main.c to use
	DCD 0 			;AGBjoypad (why is this in gfx.s again?  um.. i forget)
EMUinput
	DCD 0			;EMUjoypad (this is what the EMU sees)
	DCD 0			;windowtop
wtop
	DCD 0,0,0		;windowtop  (this label too)   L/R scrolling in unscaled mode
	DCB 4			;adjustblend
g_twitch
	DCB 0			;twitch
g_flicker
	DCB 1			;flicker
g_keybon
	DCB 0			;keyb_on

gfxstate
	DCD 0 ;vramaddr
vdpregs
	DCB 0 ;vdpmode1
	DCB 0 ;vdpmode2
	DCB 0 ;nametable
	DCB 0 ;ctoffset
	DCB 0 ;pgoffset
	DCB 0 ;satoffset
	DCB 0 ;sproffset
	DCB 0 ;bdcolor

	DCB 0 ;vdpbuff
	DCB 0 ;toggle
	DCB 0 ;vdpstat		VBlank + spr stat
	DCB 0 ;vdpctrl
	DCB 0 ;vdpmode2_bak
	DCB 0 ;minpan
	DCB 0 ;maxpan
	DCB 0 ;ystart
	DCB 0 ;sprBank

g_keybscroll
	DCB 0 ;keyb_scroll,		keyboard scroll value
;...update load/savestate if you move things around in here
;----------------------------------------------------------------------------
	END

