	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE z80mac.h
	INCLUDE z80.h
	INCLUDE io.h
	INCLUDE gfx.h
	INCLUDE sound.h
	INCLUDE scc.h

	IMPORT findrom		;from main.c
	IMPORT pogoshell	;from main.c
	IMPORT pogosize		;from main.c

	EXPORT loadcart
	EXPORT bg_finish
	EXPORT savestate
	EXPORT loadstate
	EXPORT g_emuflags
	EXPORT romstart
	EXPORT romnum
	EXPORT g_BIOSBASE
	EXPORT g_scaling
	EXPORT g_cartflags
	EXPORT g_config
	EXPORT g_mapper
;-------------------------------------------------------------------------------
 AREA rom_code, CODE, READONLY
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
loadcart ;called from C:  r0=rom number, r1=emuflags
;-------------------------------------------------------------------------------
	stmfd sp!,{r0-r1,r4-r11,lr}

	ldr r1,=findrom
	bl thumbcall_r1
	add r3,r0,#64		;r0 now points to rom image (including header)

	ldr globalptr,=|wram_globals0$$Base|	;need ptr regs init'd

	ldmfd sp!,{r0-r1}
	str r0,romnumber
	str r1,emuflags

	ldr r1,=pogoshell
	ldrb r1,[r1]
	cmp r1,#0
							;r3=rombase til end of loadcart so DON'T FUCK IT UP
	ldrne r1,=pogosize
	ldrne r1,[r1]			;Size from Pogoshell
	ldreq r1,[r3,#-60]		;size of rom in bytes (from rombuilder).
	str r3,rombase			;set rom base
	str r3,rombase2k		;set rom base

	movs r2,r1,lsr#13
	subne r2,r2,#1
	str r2,rommask			;rommask=romsize(8k)-1

	sub r0,r3,#0x4000
	str r0,rombase4k		;set rom base
	str r0,rombase6k		;set rom base
	and r0,r2,#2
	add r0,r3,r0,lsl#13
	sub r0,r0,#0x8000
	str r0,rombase8k		;set rom base
	str r0,rombaseAk		;set rom base
	str r0,rombaseCk		;set rom base
	str r0,rombaseEk		;set rom base

	cmp r1,#0xC000
	bne no48k
	ldrb r0,[r3,#3]			;high byte of start address in msx rom
	and r0,r0,#0xF0
	cmp r0,#0x40
	beq no48k
	str r3,rombase4k		;set rom base
	str r3,rombase6k		;set rom base
	str r3,rombase8k		;set rom base
	str r3,rombaseAk		;set rom base

no48k
	ands r0,r2,r2
	ldreqb r0,[r3,#3]		;high byte of start address in msx rom
	and r0,r0,#0xF0
;	cmp r0,#0x40
;	streq r3,rombase8k
;	streq r3,rombaseAk
	cmp r0,#0x80
	streq r3,rombase4k
	streq r3,rombase6k


	ldr r1,=WRMEMTBL_
	ldr r0,=rom_W
	str r0,[r1],#4			;0 BIOS
	str r0,[r1],#4			;1 Cart1
	str r0,[r1],#4			;2 Cart2
	ldr r0,=ram_W
	str r0,[r1],#4			;3 RAM

	ldr r0,=EMU_RAM-0x8000
	str r0,rambase8k
	str r0,rambaseAk
	str r0,rambaseCk
	str r0,rambaseEk


	ldr r0,=default_scanlinehook
	str r0,scanlinehook

	mov z80pc,#0			;(eliminates any encodePC errors during mapper*init)
	str z80pc,lastbank


	bl InitMapper_
	mov r0,#0xD0
	eor r1,r0,#0xFF
	strb r1,BankMap0
	bl PSLOT_W

	ldr r0,=EMU_RAM			;clear RAM
	mov r1,#0		
	mov r2,#0xC000/4		;32+16kB
	bl memset_

	bl GFX_reset
	bl IO_reset
	bl Sound_reset			;sound
	bl CPU_reset
	ldmfd sp!,{r4-r11,lr}
	bx lr

;----------------------------------------------------------------------------
InitMapper_	;rom paging..
;----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r0,rommask			;rommask=romsize(8k)-1
	cmp r0,#7
	movmi r0,#0
	ldrplb r1,Mapper
	addpl r0,r1,#1
	adr r2,MapperTable
	ldr r3,[r2,r0,lsl#2]
	adr lr,m_ret
	cmp r0,#5
	beq RTYPE_reset
	cmp r0,#6
	beq Mirrored64k_reset
m_ret
	ldr r2,=WRMEMTBL_
	str r3,[r2,#4*1]		;Cart1
	str r3,[r2,#4*2]		;Cart2
	adr r1,writemem_tbl

	ldr r0,[r2,#4*0]		;ROM
	str r0,[r1],#4			;writemem_tbl, ROM, BIOS
	str r0,[r1],#4			;writemem_tbl, ROM
	ldr r0,[r2,#4*1]		;Cart1
	str r0,[r1],#4			;writemem_tbl, ROM, CART
	str r0,[r1],#4			;writemem_tbl, ROM
	str r0,[r1],#4			;writemem_tbl, ROM
	str r0,[r1],#4			;writemem_tbl, ROM
	ldr r0,[r2,#4*3]		;RAM
	str r0,[r1],#4			;writemem_tbl, RAM
	str r0,[r1],#4			;writemem_tbl, RAM

	ldmfd sp!,{lr}
	bx lr

MapperTable
	DCD rom_W,Konami4,Konami5,ASCII8k,ASCII16k,RTYPE,rom_W
;----------------------------------------------------------------------------
Konami4
;----------------------------------------------------------------------------
	ldr r1,rommask			;rommask=romsize(8k)-1
	and r0,r0,r1
	ldr r1,rombase
	add r0,r1,r0,lsl#13
	and addy,addy,#0xF800
	cmp addy,#0x6000		;bankswitch 0x6000
	bne no6k
	sub r0,r0,#0x6000
	str r0,rombase6k
	b BankSwitch1_W
no6k
	cmp addy,#0x8000		;bankswitch 0x8000
	bne no8k
	sub r0,r0,#0x8000
	str r0,rombase8k
	b BankSwitch2_W
no8k
	cmp addy,#0xA000		;bankswitch 0xA000
	bxne lr
	sub r0,r0,#0xA000
	str r0,rombaseAk
	b BankSwitch2_W
;----------------------------------------------------------------------------
Konami5; Mapper + SCC
;----------------------------------------------------------------------------
	ldr r1,rommask			;rommask=romsize-1
	and r1,r1,r0
	ldr r2,rombase
	add r1,r2,r1,lsl#13
	and r2,addy,#0xF800
	cmp r2,#0x5000			;bankswitch 0x4000
	bne no5k
	sub r1,r1,#0x4000
	str r1,rombase4k
	b BankSwitch1_W
no5k
	cmp r2,#0x7000			;bankswitch 0x6000
	bne no7k
	sub r1,r1,#0x6000
	str r1,rombase6k
	b BankSwitch1_W
no7k
	cmp r2,#0x9000			;bankswitch 0x8000
	bne no9k
	sub r1,r1,#0x8000
	str r1,rombase8k
	b BankSwitch2_W
no9k
	cmp r2,#0x9800			;write to SCC
	beq SCC_W
	cmp r2,#0xB000			;bankswitch 0xA000
	bxne lr
	sub r1,r1,#0xA000
	str r1,rombaseAk
	b BankSwitch2_W
;----------------------------------------------------------------------------
ASCII16k
;----------------------------------------------------------------------------
	ldr r1,rommask			;rommask=romsize(8k)-1
	and r0,r0,r1,lsr#1
	ldr r1,rombase
	add r0,r1,r0,lsl#14
	and addy,addy,#0xF800
	cmp addy,#0x6000		;bankswitch 0x4000
	bne asc16_no6k
	sub r0,r0,#0x4000
	str r0,rombase4k
	str r0,rombase6k
	b BankSwitch1_W
asc16_no6k
	cmp addy,#0x7000		;bankswitch 0x8000
	bxne lr
	sub r0,r0,#0x8000
	str r0,rombase8k
	str r0,rombaseAk
	b BankSwitch2_W
;----------------------------------------------------------------------------
ASCII8k
;----------------------------------------------------------------------------
	ldr r1,rommask			;rommask=romsize-1
	and r0,r0,r1
	ldr r1,rombase
	add r0,r1,r0,lsl#13
	and addy,addy,#0xF800
	cmp addy,#0x6000		;bankswitch 0x4000
	bne asc8_no60
	sub r0,r0,#0x4000
	str r0,rombase4k
	b BankSwitch1_W
asc8_no60
	cmp addy,#0x6800		;bankswitch 0x6000
	bne asc8_no68
	sub r0,r0,#0x6000
	str r0,rombase6k
	b BankSwitch1_W
asc8_no68
	cmp addy,#0x7000		;bankswitch 0x8000
	bne asc8_no70
	sub r0,r0,#0x8000
	str r0,rombase8k
	b BankSwitch2_W
asc8_no70
	cmp addy,#0x7800		;bankswitch 0xA000
	bxne lr
	sub r0,r0,#0xA000
	str r0,rombaseAk
	b BankSwitch2_W
;----------------------------------------------------------------------------
RTYPE
;----------------------------------------------------------------------------
	and r0,r0,#0x1F
	and r1,r0,#0x10
	bic r0,r0,r1,lsr#1
	ldr r1,rombase
	add r0,r1,r0,lsl#14
	and addy,addy,#0xF000
	cmp addy,#0x7000		;bankswitch 0x8000
	bxne lr
	sub r0,r0,#0x8000
	str r0,rombase8k
	str r0,rombaseAk
	b BankSwitch2_W
;----------------------------------------------------------------------------
RTYPE_reset
;----------------------------------------------------------------------------
	mov r0,#0x0F			;0x17 ???
	ldr r1,rombase
	add r0,r1,r0,lsl#14
	sub r0,r0,#0x4000
	str r0,rombase4k
	str r0,rombase6k
	b BankSwitch1_W
;----------------------------------------------------------------------------
Mirrored64k_reset
;----------------------------------------------------------------------------
	mov r0,#7
	str r0,rommask			;rommask=romsize(8k)-1

	ldr r0,rombase
	str r0,rombase2k
	str r0,rombase4k
	str r0,rombase6k
	str r0,rombase8k
	str r0,rombaseAk
	str r0,rombaseCk
	str r0,rombaseEk
	stmfd sp!,{lr}
	bl BankSwitch1_W
	ldmfd sp!,{lr}
	b BankSwitch2_W
;-------------------------------------------------------------------------------
savestate	;called from ui.c.
;int savestate(void *here): copy state to <here>, return size
;-------------------------------------------------------------------------------
	stmfd sp!,{r4-r6,globalptr,lr}
	ldr globalptr,=|wram_globals0$$Base|

	ldr r2,rombase
	rsb r2,r2,#0				;adjust rom maps,etc so they aren't based on rombase
	bl fixromptrs				;(so savestates are valid after moving roms around)

;	ldr r6,=STATEPTR			;r6=where state is at
;	mov r6,r0					;r6=where to copy state
	mov r0,#0					;r0 holds total size (return value)

	adr r4,savelst				;r4=list of stuff to copy
	mov r3,#(lstend-savelst)/8	;r3=items in list
ss1	ldmia r4!,{r1,r2}			;r1=what to copy, r2=how much to copy
	add r0,r0,r2
ss0	ldr r5,[r1],#4
	str r5,[r6],#4
	subs r2,r2,#4
	bne ss0
	subs r3,r3,#1
	bne ss1

	ldr r2,rombase
	bl fixromptrs

	ldmfd sp!,{r4-r6,globalptr,lr}
	bx lr

savelst	DCD rominfo,8,EMU_RAM,0x6000,cpustate,104,gfxstate,40
lstend

fixromptrs	;add r2 to some things
	ldr r3,lastbank
	add r3,r3,r2
	str r3,lastbank

	ldr r3,cpuregs+6*4	;Z80 PC
	add r3,r3,r2
	str r3,cpuregs+6*4

	mov pc,lr
;-------------------------------------------------------------------------------
loadstate	;called from ui.c
;void loadstate(int rom#,u32 *stateptr)	 (stateptr must be word aligned)
;-------------------------------------------------------------------------------
	stmfd sp!,{r4-r7,globalptr,lr}
	ldr globalptr,=|wram_globals0$$Base|

	ldr r0,romnumber
;	ldr r6,=STATEPTR			;r6=where state is at
;	mov r6,r1		;r6=where state is at

	ldr r1,[r6]		;emuflags
	bl loadcart		;cart init

	mov r0,#(lstend-savelst)/8	;read entire state
	adr r4,savelst
ls1	ldmia r4!,{r1,r2}
ls0	ldr r5,[r6],#4
	str r5,[r1],#4
	subs r2,r2,#4
	bne ls0
	subs r0,r0,#1
	bne ls1

	ldr r2,rombase		;adjust ptr shit (see savestate above)
	bl fixromptrs

	bl BankSwitch0_W
	bl BankSwitch1_W
	bl BankSwitch2_W

	ldr r0,=DIRTYTILES
	mov r1,#-1
	mov r2,#128
	bl memset_

	ldmfd sp!,{r4-r7,globalptr,lr}
	bx lr



;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
bg_finish	;end of frame...
;-------------------------------------------------------------------------------
	stmfd sp!,{r3-r9,r11,lr}

	mov r3,#AGB_VRAM
	ldr r0,BGoffset2
	add r3,r3,r0,lsl#3
	ldr r6,=0x80008000
	mov r7,r6,lsr#15	;ldr r7,=0x00010001
	ldr r8,=TMAPBUFF
	ldrb r1,[r8,#4]
	ldr r2,=VDP_RAM
	and r1,r1,#0xF
	add r2,r2,r1,lsl#10

	ldrb r0,vdpmode1
	ands r8,r0,#2		;mode2 or 0?
	ldrne r8,=0x01000100
	ldrb r9,pgoffset
	and r9,r9,#3
	eorne r9,r9,#3
	orr r9,r9,r9,lsl#16
	mov r9,r9,lsl#8
	orreq r6,r6,r9
	moveq r9,#0
	mov r11,r6
	

	mov r1,#0
	mov r5,#3
	ldrb r0,vdpmode2
	tst r0,#0x10		;mode1?
	beq bgmode02
	mov r5,#24
	ldr r6,=0x10001000
	bic r11,r11,r6,lsl#3
	orr r11,r11,r6
;-------------------------------------------------------------------------------
bgmode1

bgm1loop2
	mov r4,#16
bgm1loop
	ldrh r0,[r2],#2				;Read from MSX Tilemap RAM
	orr r0,r0,r0,lsl#8
	bic r0,r0,#0xFF00
	orr r0,r0,r11

	str r0,[r3],#4				;Write to GBA Tilemap RAM, behind sprites
	subs r4,r4,#1
	bne bgm1loop
	add r2,r2,#8
	subs r5,r5,#1
	bne bgm1loop2

	ldmfd sp!,{r3-r9,r11,pc}

;-------------------------------------------------------------------------------
 AREA wram_code4, CODE, READWRITE
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;bgchrfinish	;end of frame...
;-------------------------------------------------------------------------------
bgmode02			;fake

bgm2loop2
	mov r4,#16*8
bgm2loop
	ldrh r0,[r2],#2				;Read from MSX Tilemap RAM
	orr r0,r0,r0,lsl#8
	bic r0,r0,#0xFF00
	orr r0,r0,r11

;	str r1,[r3,#0x800]			;Write to GBA Tilemap RAM, BGR color
	str r0,[r3],#4				;Write to GBA Tilemap RAM, behind sprites
	subs r4,r4,#1
	bne bgm2loop
	add r6,r6,r8
	bic r11,r6,r9
	subs r5,r5,#1
	bne bgm2loop2

	ldmfd sp!,{r3-r9,r11,pc}


;----------------------------------------------------------------------------
 AREA wram_globals2, CODE, READWRITE

romstart
	DCD 0 ;rombase
	DCD 0 ;rombase2k
	DCD 0 ;rombase4k
	DCD 0 ;rombase6k
	DCD 0 ;rombase8k
	DCD 0 ;rombaseAk
	DCD 0 ;rombaseCk
	DCD 0 ;rombaseEk

	DCD 0 ;rambase8k
	DCD 0 ;rambaseAk
	DCD 0 ;rambaseCk
	DCD 0 ;rambaseEk
	DCD 0 ;rommask
romnum
	DCD 0 ;romnumber
rominfo                 ;keep emuflags/BGmirror together for savestate/loadstate
g_emuflags	DCB 0 ;emuflags        (label this so UI.C can take a peek) see equates.h for bitfields
g_scaling	DCB SCALED_SPRITES ;(display type)
	% 2   ;(sprite follow val)

	DCD 0 ;BGoffset1
	DCD 0 ;BGoffset2
	DCD 0 ;BGoffset3
g_BIOSBASE
	DCD 0 ;biosbase
	DCB 0 ;BankMap0
g_mapper
	DCB 0 ;Mapper
g_cartflags
	DCB 0 ;cartflags
g_config
	DCB 0		;config, bit 7=BIOS on/off, bit 6=R as Start,
;----------------------------------------------------------------------------
	END

