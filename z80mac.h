						;ARM flags
PSR_S EQU 0x00000008	;Negative
PSR_Z EQU 0x00000004	;Zero
PSR_C EQU 0x00000002	;Carry
PSR_V EQU 0x00000001	;Overflow/Parity
PSR_P EQU 0x00000001	;Overflow/Parity

PSR_H EQU 0x00000010	;half carry
PSR_n EQU 0x00000080	;add or sub?


					;Z80 flags
SF EQU 2_10000000	;Sign (negative)
ZF EQU 2_01000000	;Zero
YF EQU 2_00100000	;Y (unused)
HF EQU 2_00010000	;half carry
XF EQU 2_00001000	;X (unused)
PF EQU 2_00000100	;Overflow/Parity
VF EQU 2_00000100	;Overflow/Parity
NF EQU 2_00000010	;was the last opcode + or -
CF EQU 2_00000001	;carry


	MACRO		;translate z80pc from Z80 PC to rom offset
	encodePC
	and r1,z80pc,#0xFC00
	adr r2,memmap_tbl
	ldr r0,[r2,r1,lsr#8]
	str r0,lastbank
	add z80pc,z80pc,r0
	MEND

	MACRO		;translate z80pc from zeropage Z80 PC to rom offset
	encodePC_IRQ
	ldr r0,memmap_tbl
	str r0,lastbank
	add z80pc,addy,r0
	MEND

	MACRO		;translate z80pc from z80hl to rom offset
	encodePC_HL
	and r1,z80hl,#0xFC000000
	adr r2,memmap_tbl
	ldr r0,[r2,r1,lsr#24]
	str r0,lastbank
	add z80pc,r0,z80hl,lsr#16
	MEND

	MACRO		;pack Z80 flags into r0
	encodeFLG
	and r0,z80f,#PSR_H
	and r1,z80f,#PSR_S|PSR_Z
	orr r0,r0,r1,lsl#4
	movs r1,z80f,lsl#31
	orrmi r0,r0,#VF
	and r1,z80f,#PSR_n
	adc r0,r0,r1,lsr#6					;NF & CF
	MEND

	MACRO		;unpack Z80 flags from r0
	decodeFLG
	and z80f,r0,#HF
	tst r0,#CF
	orrne z80f,z80f,#PSR_C
	and r1,r0,#SF|ZF
	movs r0,r0,lsl#30
	adc z80f,z80f,r1,lsr#4				;also sets V/P Flag.
	orrmi z80f,z80f,#PSR_n
	MEND


	MACRO
	fetch $count
	subs cycles,cycles,#$count*CYCLE
	ldrplb r0,[z80pc],#1
	ldrpl pc,[z80optbl,r0,lsl#2]
	ldr pc,nexttimeout
	MEND

	MACRO
	eatcycles $count
	sub cycles,cycles,#$count*CYCLE
	MEND

	MACRO
	readmem8
	and r0,addy,#0xFC00
	adr r2,memmap_tbl
	ldr r0,[r2,r0,lsr#8]
	ldrb r0,[r0,addy]
	MEND

	MACRO
	readmem8BC
	and r0,z80bc,#0xFC000000
	adr r2,memmap_tbl
	ldr r0,[r2,r0,lsr#24]
	ldrb r0,[r0,z80bc,lsr#16]
	MEND

	MACRO
	readmem8DE
	and r0,z80de,#0xFC000000
	adr r2,memmap_tbl
	ldr r0,[r2,r0,lsr#24]
	ldrb r0,[r0,z80de,lsr#16]
	MEND

	MACRO
	readmem8HL
	and r0,z80hl,#0xFC000000
	adr r2,memmap_tbl
	ldr r0,[r2,r0,lsr#24]
	ldrb r0,[r0,z80hl,lsr#16]
	MEND

	MACRO
	readmem16 $reg
	readmem8
	mov $reg,r0,lsl#16
	add addy,addy,#1
	and r0,addy,#0xFC00
	ldr r0,[r2,r0,lsr#8]
	ldrb r0,[r0,addy]
	orr $reg,$reg,r0,lsl#24
	MEND

	MACRO
	writemem8
	and r1,addy,#0xE000
	adr r2,writemem_tbl
	adr lr,%F0
	ldr pc,[r2,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
0				;out: r0,r1,r2,addy=?
	MEND

	MACRO
	writemem8BC
	mov addy,z80bc,lsr#16
	writemem8
	MEND

	MACRO
	writemem8DE
	mov addy,z80de,lsr#16
	writemem8
	MEND

	MACRO
	writemem8HL
	mov addy,z80hl,lsr#16
	writemem8
	MEND

	MACRO
	writemem16 $reg
	mov r0,$reg,lsr#16
	writemem8
	add addy,addy,#1
	mov r0,$reg,lsr#24
	writemem8
	MEND

	MACRO
	copymem8HL_DE
	readmem8HL
	writemem8DE
	MEND

	MACRO
	CalcIXd
	ldrsb r1,[z80pc],#1
	ldr addy,[z80xy]
	add addy,addy,r1,lsl#16
	mov addy,addy,lsr#16
	MEND

;----------------------------------------------------------------------------

;	MACRO
;	push16
;	str r0,[sp,#-4]!
;	ldr addy,z80sp
;	sub addy,addy,#0x00020000
;	str addy,z80sp
;	mov addy,addy,lsr#16
;	and r1,addy,#0xE000
;	adr r2,writemem_tbl
;	adr lr,%F0
;	and r0,r0,#0xff
;	ldr pc,[r2,r1,lsr#11]
;0
;	ldr r0,[sp],#4
;	ldr addy,z80sp
;	add addy,addy,#0x00010000
;	mov addy,addy,lsr#16
;	and r1,addy,#0xE000
;	adr r2,writemem_tbl
;	adr lr,%F1
;	mov r0,r0,lsr#8
;	ldr pc,[r2,r1,lsr#11]
;1
;	MEND		;r1,r2=?

	MACRO
	push16		;push r0
	sub z80sp,z80sp,#0x00020000
	and r1,z80sp,#0xFC000000
	adr r2,memmap_tbl
	ldr r2,[r2,r1,lsr#24]
	strb r0,[r2,z80sp,lsr#16]
	add r1,z80sp,#0x00010000
	mov r0,r0,lsr#8
	strb r0,[r2,r1,lsr#16]
	MEND		;r1,r2=?

	MACRO
	pop16 $x		;pop BC,DE,HL,PC & r0
	and r0,z80sp,#0xFC000000
	adr r1,memmap_tbl
	ldr r1,[r1,r0,lsr#24]
	ldrb $x,[r1,z80sp,lsr#16]
	add z80sp,z80sp,#0x00010000
	ldrb r1,[r1,z80sp,lsr#16]
	add z80sp,z80sp,#0x00010000
	orr $x,$x,r1,lsl#8
	MEND		;r0,r1=?

	MACRO
	popAF			;pop AF
	and r0,z80sp,#0xFC000000
	adr r1,memmap_tbl
	ldr r1,[r1,r0,lsr#24]
	ldrb r0,[r1,z80sp,lsr#16]
	add z80sp,z80sp,#0x00010000
	ldrb z80a,[r1,z80sp,lsr#16]
	add z80sp,z80sp,#0x00010000
	mov z80a,z80a,lsl#24
	MEND		;r0=flags,r1=?
;----------------------------------------------------------------------------

	MACRO
	opADC
	movs z80f,z80f,lsr#2				;get C
	subcs r0,r0,#0x100
	eor z80f,r0,z80a,lsr#24				;prepare for check of half carry
	adcs z80a,z80a,r0,ror#8
	mrs r0,cpsr							;S,Z,V&C
	eor z80f,z80f,z80a,lsr#24
	and z80f,z80f,#PSR_H				;H, correct
	orr z80f,z80f,r0,lsr#28
	MEND

	MACRO
	opADCA
	movs z80f,z80f,lsr#2				;get C
	orrcs z80a,z80a,#0x00800000
	adds z80a,z80a,z80a
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	tst z80a,#0x10000000				;H, correct
	orrne z80f,z80f,#PSR_H
	fetch 4
	MEND

	MACRO
	opADCH $x
	mov r0,$x,lsr#24
	opADC
	fetch 4
	MEND

	MACRO
	opADCL $x
	movs z80f,z80f,lsr#2				;get C
	adc r0,$x,$x,lsr#15
	orrcs z80a,z80a,#0x00800000
	mov r1,z80a,lsl#4					;Prepare for check of half carry
	adds z80a,z80a,r0,lsl#23
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	cmn r1,r0,lsl#27
	orrcs z80f,z80f,#PSR_H				;H, correct
	fetch 4
	MEND

	MACRO
	opADCb
	opADC
	MEND
;---------------------------------------

	MACRO
	opADD $x,$y
	mov r1,z80a,lsl#4					;Prepare for check of half carry
	adds z80a,z80a,$x,lsl#$y
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	cmn r1,$x,lsl#$y+4
	orrcs z80f,z80f,#PSR_H
	MEND

	MACRO
	opADDA
	adds z80a,z80a,z80a
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	tst z80a,#0x10000000				;H, correct
	orrne z80f,z80f,#PSR_H
	fetch 4
	MEND

	MACRO
	opADDH $x
	and r0,$x,#0xFF000000
	opADD r0,0
	fetch 4
	MEND

	MACRO
	opADDL $x
	opADD $x,8
	fetch 4
	MEND

	MACRO
	opADDb 
	opADD r0,24
	MEND
;---------------------------------------

	MACRO
	opADC16 $x
	movs z80f,z80f,lsr#2				;get C
	adc r0,z80a,$x,lsr#15
	orrcs z80hl,z80hl,#0x00008000
	mov r1,z80hl,lsl#4
	adds z80hl,z80hl,r0,lsl#15
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	cmn r1,r0,lsl#19
	orrcs z80f,z80f,#PSR_H
	fetch 15
	MEND

	MACRO
	opADC16HL
	movs z80f,z80f,lsr#2				;get C
	orrcs z80hl,z80hl,#0x00008000
	adds z80hl,z80hl,z80hl
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	tst z80hl,#0x10000000				;H, correct.
	orrne z80f,z80f,#PSR_H
	fetch 15
	MEND

	MACRO
	opADD16 $y,$x
	mov r1,$y,lsl#4						;Prepare for check of half carry
	adds $y,$y,$x
	bic z80f,z80f,#PSR_C+PSR_H+PSR_n
	orrcs z80f,z80f,#PSR_C
	cmn r1,$x,lsl#4
	orrcs z80f,z80f,#PSR_H
	MEND

	MACRO
	opADD16_2 $x
	adds $x,$x,$x
	bic z80f,z80f,#PSR_C+PSR_H+PSR_n
	orrcs z80f,z80f,#PSR_C
	tst $x,#0x10000000					;H, correct.
	orrne z80f,z80f,#PSR_H
	MEND
;---------------------------------------

	MACRO
	opAND $x,$y
	and z80a,z80a,$x,lsl#$y
	adr r0,pzst
	ldrb z80f,[r0,z80a,lsr#24]			;get PZS
	orr z80f,z80f,#PSR_H				;set PSR_H
	MEND

	MACRO
	opANDA
	adr r0,pzst
	ldrb z80f,[r0,z80a,lsr#24]			;get PZS
	orr z80f,z80f,#PSR_H				;set PSR_H
	fetch 4
	MEND

	MACRO
	opANDH $x
	opAND $x,0
	fetch 4
	MEND

	MACRO
	opANDL $x
	opAND $x,8
	fetch 4
	MEND

	MACRO
	opANDb
	opAND r0,24
	MEND
;---------------------------------------

	MACRO
	opBIT $x
	and z80f,z80f,#PSR_C				;keep C
	orr z80f,z80f,#PSR_H				;set H
	mov r0,r0,lsr#3
	tst $x,r1,lsl r0					;r0 0x08-0x0F
	orreq z80f,z80f,#PSR_Z|PSR_P		;Z & P
	fetch 8
	MEND

	MACRO
	opBITH $x
	mov r1,#0x00010000
	opBIT $x
	MEND

	MACRO
	opBITL $x
	mov r1,#0x00000100
	opBIT $x
	MEND

	MACRO
	opBIT7H $x
	and z80f,z80f,#PSR_C				;keep C
	tst $x,#0x80000000					;bit 7
	orreq z80f,z80f,#PSR_H+PSR_Z+PSR_P	;H,Z & P
	orrne z80f,z80f,#PSR_H+PSR_S		;H & sign on "BIT 7,x"
	fetch 8
	MEND

	MACRO
	opBIT7L $x
	and z80f,z80f,#PSR_C				;keep C
	tst $x,#0x00800000					;bit 7
	orreq z80f,z80f,#PSR_H+PSR_Z+PSR_P	;H,Z & P
	orrne z80f,z80f,#PSR_H+PSR_S		;H & sign on "BIT 7,x"
	fetch 8
	MEND

	MACRO
	opBITmem $x
	readmem8
	and z80f,z80f,#PSR_C				;keep C
	orr z80f,z80f,#PSR_H				;set H
	tst r0,#1<<$x						;bit x
	orreq z80f,z80f,#PSR_Z|PSR_P		;Z & P
	fetch 12
	MEND

	MACRO
	opBIT7mem
	readmem8
	and z80f,z80f,#PSR_C				;keep C
	tst r0,#0x80						;bit x
	orreq z80f,z80f,#PSR_H+PSR_Z+PSR_P	;H,Z & P
	orrne z80f,z80f,#PSR_H+PSR_S		;H & sign on "BIT 7,x"
	fetch 12
	MEND
;---------------------------------------

	MACRO
	opCP $x,$y
	mov r1,z80a,lsl#4					;prepare for check of half carry
	cmp z80a,$x,lsl#$y
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	eor z80f,z80f,#PSR_C|PSR_n			;invert C and set n
	cmp r1,$x,lsl#$y+4
	orrcc z80f,z80f,#PSR_H
	MEND

	MACRO
	opCPA
	mov z80f,#PSR_Z|PSR_n				;set Z & n
	fetch 4
	MEND

	MACRO
	opCPH $x
	and r0,$x,#0xFF000000
	opCP r0,0
	fetch 4
	MEND

	MACRO
	opCPL $x
	opCP $x,8
	fetch 4
	MEND

	MACRO
	opCPb
	opCP r0,24
	MEND
;---------------------------------------

	MACRO
	opDEC8 $x							;for A and memory
	and z80f,z80f,#PSR_C				;save carry
	orr z80f,z80f,#PSR_n				;set n
	tst $x,#0x0f000000
	orreq z80f,z80f,#PSR_H
	subs $x,$x,#0x01000000
	orrmi z80f,z80f,#PSR_S
	orrvs z80f,z80f,#PSR_V
	orreq z80f,z80f,#PSR_Z
	MEND

	MACRO
	opDEC8H $x							;for B, D & H
	and z80f,z80f,#PSR_C				;save carry
	orr z80f,z80f,#PSR_n				;set n
	tst $x,#0x0f000000
	orreq z80f,z80f,#PSR_H
	subs $x,$x,#0x01000000
	orrmi z80f,z80f,#PSR_S
	orrvs z80f,z80f,#PSR_V
	tst $x,#0xff000000					;Z
	orreq z80f,z80f,#PSR_Z
	MEND

	MACRO
	opDEC8L $x							;for C, E & L
	mov $x,$x,ror#24
	opDEC8H $x
	mov $x,$x,ror#8
	MEND

	MACRO
	opDEC8b								;for memory
	mov r0,r0,lsl#24
	opDEC8 r0
	mov r0,r0,lsr#24
	MEND

	MACRO
	opDEC16 $x
	sub $x,$x,#0x00010000
	MEND
;---------------------------------------

	MACRO
	opINC8 $x
	and z80f,z80f,#PSR_C				;save carry, clear n
	adds $x,$x,#0x01000000
	orrmi z80f,z80f,#PSR_S
	orrvs z80f,z80f,#PSR_V
	orrcs z80f,z80f,#PSR_Z				;when going from 0xFF to 0x00 carry is set.
	tst $x,#0x0f000000					;h
	orreq z80f,z80f,#PSR_H
	MEND

	MACRO
	opINC8H $x							;for B, D & H
	opINC8 $x
	MEND

	MACRO
	opINC8L $x							;for C, E & L
	mov $x,$x,ror#24
	opINC8 $x
	mov $x,$x,ror#8
	MEND

	MACRO
	opINC8b								;for memory
	mov r0,r0,lsl#24
	opINC8 r0
	mov r0,r0,lsr#24
	MEND

	MACRO
	opINC16 $x
	add $x,$x,#0x00010000
	MEND
;---------------------------------------

	MACRO
	opINrC
	bl Z80_IN_C							;uses z80bc
	adr r1,pzst
	ldrb r1,[r1,r0]						;get PZS
	and z80f,z80f,#PSR_C				;keep C
	orr z80f,z80f,r1
	MEND
;---------------------------------------

	MACRO
	opLDIM16
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1,lsl#8
	MEND

	MACRO
	opLDIM8H $x
	ldrb r0,[z80pc],#1
	and $x,$x,#0x00ff0000
	orr $x,$x,r0,lsl#24
	MEND

	MACRO
	opLDIM8L $x
	ldrb r0,[z80pc],#1
	and $x,$x,#0xff000000
	orr $x,$x,r0,lsl#16
	MEND
;---------------------------------------

	MACRO
	opOR $x,$y
	orr z80a,z80a,$x,lsl#$y
	adr r1,pzst
	ldrb z80f,[r1,z80a,lsr#24]			;get PZS
	MEND

	MACRO
	opORA
	adr r1,pzst
	ldrb z80f,[r1,z80a,lsr#24]			;get PZS
	fetch 4
	MEND

	MACRO
	opORH $x
	and r0,$x,#0xFF000000
	opOR r0,0
	fetch 4
	MEND

	MACRO
	opORL $x
	opOR $x,8
	fetch 4
	MEND

	MACRO
	opORb
	opOR r0,24
	MEND
;---------------------------------------

	MACRO
	opOUTCr
	bl Z80_OUT_C
	fetch 12
	MEND

	MACRO
	opOUTCrH $x
	mov r0,$x,lsr#24
	opOUTCr
	MEND

	MACRO
	opOUTCrL $x
	mov r0,$x,lsr#16
;	and r0,r0,#0xFF
	opOUTCr
	MEND
;---------------------------------------

	MACRO
	opRES $x
	mov r0,r0,lsr#3
	bic $x,$x,r1,lsl r0					;r0 0x10-0x17
	MEND

	MACRO
	opRESH $x
	mov r1,#0x00000100
	opRES $x
	fetch 8
	MEND

	MACRO
	opRESL $x
	mov r1,#0x00000001
	opRES $x
	fetch 8
	MEND

	MACRO
	opRESmem $x
	readmem8
	bic r0,r0,#1<<$x					;bit ?
	writemem8
	fetch 15
	MEND
;---------------------------------------

	MACRO
	opRL $x,$y,$z
	movs $x,$y,lsl#$z
	tst z80f,#PSR_C						;doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne $x,$x,#0x01000000
;	and r2,z80f,#PSR_C
;	orr $x,$x,r2,lsl#23
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opRLA
	opRL z80a,z80a,1
	fetch 8
	MEND

	MACRO
	opRLH $x
	and r0,$x,#0xFF000000				;mask high to r0
	adds $x,$x,r0
	tst z80f,#PSR_C						;doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne $x,$x,#0x01000000
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opRLL $x
	opRL r0,$x,9
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsr#8
	fetch 8
	MEND

	MACRO
	opRLb
	opRL r0,r0,25
	mov r0,r0,lsr#24
	MEND
;---------------------------------------

	MACRO
	opRLC $x,$y,$z
	movs $x,$y,lsl#$z
	orrcs $x,$x,#0x01000000
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opRLCA
	opRLC z80a,z80a,1
	fetch 8
	MEND

	MACRO
	opRLCH $x
	and r0,$x,#0xFF000000				;mask high to r0
	adds $x,$x,r0
	orrcs $x,$x,#0x01000000
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opRLCL $x
	opRLC r0,$x,9
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsr#8
	fetch 8
	MEND

	MACRO
	opRLCb
	opRLC r0,r0,25
	mov r0,r0,lsr#24
	MEND
;---------------------------------------

	MACRO
	opRR $x,$y,$z
	movs $x,$y,lsr#$z
	tst z80f,#PSR_C						;doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne $x,$x,#0x00000080
;	and r1,z80f,#PSR_C
;	orr $x,$x,r1,lsl#6
	adr r1,pzst
	ldrb z80f,[r1,$x]					;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opRRA
	orr z80a,z80a,z80f,lsr#1			;get C
	movs z80a,z80a,ror#25
	mov z80a,z80a,lsl#24
	adr r1,pzst
	ldrb z80f,[r1,z80a,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opRRH $x
	orr r0,$x,z80f,lsr#1				;get C
	movs r0,r0,ror#25
	and $x,$x,#0x00FF0000				;mask out low
	orr $x,$x,r0,lsl#24
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opRRL $x
	and r0,$x,#0x00FF0000				;mask out low to r0
	opRR r0,r0,17
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsl#16
	fetch 8
	MEND

	MACRO
	opRRb
	opRR r0,r0,1
	MEND
;---------------------------------------

	MACRO
	opRRC $x,$y,$z
	movs $x,$y,lsr#$z
	orrcs $x,$x,#0x00000080
	adr r1,pzst
	ldrb z80f,[r1,$x]					;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opRRCA
	opRRC z80a,z80a,25
	mov z80a,z80a,lsl#24
	fetch 8
	MEND

	MACRO
	opRRCH $x
	opRRC r0,$x,25
	and $x,$x,#0x00FF0000				;mask out low
	orr $x,$x,r0,lsl#24
	fetch 8
	MEND

	MACRO
	opRRCL $x
	and r0,$x,#0x00FF0000				;mask low to r0
	opRRC r0,r0,17
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsl#16
	fetch 8
	MEND

	MACRO
	opRRCb
	opRRC r0,r0,1
	MEND
;---------------------------------------

	MACRO
	opSBC
	eor z80f,z80f,#PSR_C				;invert C
	movs z80f,z80f,lsr#2				;get C
	subcc r0,r0,#0x100
	eor z80f,r0,z80a,lsr#24				;prepare for check of H
	sbcs z80a,z80a,r0,ror#8
	mrs r0,cpsr
	eor z80f,z80f,z80a,lsr#24
	and z80f,z80f,#PSR_H				;H, correct
	orr z80f,z80f,r0,lsr#28				;S,Z,V&C
	eor z80f,z80f,#PSR_C|PSR_n			;invert C and set n.
	MEND

	MACRO
	opSBCA
	movs z80f,z80f,lsr#2				;get C
	movcc z80a,#0x00000000
	movcs z80a,#0xFF000000
	movcc z80f,#PSR_n+PSR_Z
	movcs z80f,#PSR_n+PSR_S+PSR_C+PSR_H
	fetch 4
	MEND

	MACRO
	opSBCH $x
	mov r0,$x,lsr#24
	opSBC
	fetch 4
	MEND

	MACRO
	opSBCL $x
	mov r0,$x,lsl#8
	eor z80f,z80f,#PSR_C				;invert C
	movs z80f,z80f,lsr#2				;get C
	sbccc r0,r0,#0xFF000000
	mov r1,z80a,lsl#4					;prepare for check of H
	sbcs z80a,z80a,r0
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	eor z80f,z80f,#PSR_C|PSR_n			;invert C and set n.
	cmp r1,r0,lsl#4
	orrcc z80f,z80f,#PSR_H				;H, correct
	fetch 4
	MEND

	MACRO
	opSBCb
	opSBC
	MEND
;---------------------------------------

	MACRO
	opSBC16 $x
	eor z80f,z80f,#PSR_C				;invert C.
	movs z80f,z80f,lsr#2				;get C
	sbc r1,r1,r1						;set r1 to -1 or 0.
	orr r0,$x,r1,lsr#16
	mov r1,z80hl,lsl#4					;prepare for check of H
	sbcs z80hl,z80hl,r0
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	eor z80f,z80f,#PSR_C|PSR_n			;invert C and set n.
	cmp r1,r0,lsl#4
	orrcc z80f,z80f,#PSR_H
	fetch 15
	MEND

	MACRO
	opSBC16HL
	movs z80f,z80f,lsr#2				;get C
	mov z80hl,#0x00000000
	subcs z80hl,z80hl,#0x00010000
	movcc z80f,#PSR_n+PSR_Z
	movcs z80f,#PSR_n+PSR_S+PSR_C+PSR_H
	fetch 15
	MEND
;---------------------------------------

	MACRO
	opSET $x
	mov r0,r0,lsr#3
	and r0,r0,#7
	orr $x,$x,r1,lsl r0					;r0 0-7
	MEND

	MACRO
	opSETH $x
	mov r1,#0x01000000
	opSET $x
	fetch 8
	MEND

	MACRO
	opSETL $x
	mov r1,#0x00010000
	opSET $x
	fetch 8
	MEND

	MACRO
	opSETmem $x
	readmem8
	orr r0,r0,#1<<$x					;bit ?
	writemem8
	fetch 15
	MEND
;---------------------------------------

	MACRO
	opSLA $x,$y,$z
	movs $x,$y,lsl#$z
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opSLAA
	opSLA z80a,z80a,1
	fetch 8
	MEND

	MACRO
	opSLAH $x
	and r0,$x,#0xFF000000				;mask high to r0
	adds $x,$x,r0
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opSLAL $x
	opSLA r0,$x,9
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsr#8
	fetch 8
	MEND

	MACRO
	opSLAb
	opSLA r0,r0,25
	mov r0,r0,lsr#24
	MEND
;---------------------------------------

	MACRO
	opSLL $x,$y,$z
	movs $x,$y,lsl#$z
	orr $x,$x,#0x01000000
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opSLLA
	opSLL z80a,z80a,1
	fetch 8
	MEND

	MACRO
	opSLLH $x
	and r0,$x,#0xFF000000				;mask high to r0
	adds $x,$x,r0
	orr $x,$x,#0x01000000
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opSLLL $x
	opSLL r0,$x,9
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsr#8
	fetch 8
	MEND

	MACRO
	opSLLb
	opSLL r0,r0,25
	mov r0,r0,lsr#24
	MEND
;---------------------------------------

	MACRO
	opSRA $x,$y
	movs $x,$y,asr#25
	and $x,$x,#0xFF
	adr r1,pzst
	ldrb z80f,[r1,$x]					;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opSRAA
	movs r0,z80a,asr#25
	mov z80a,r0,lsl#24
	adr r1,pzst
	ldrb z80f,[r1,z80a,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opSRAH $x
	movs r0,$x,asr#25
	and $x,$x,#0x00FF0000				;mask out low
	orr $x,$x,r0,lsl#24
	adr r1,pzst
	ldrb z80f,[r1,$x,lsr#24]			;get PZS
	orrcs z80f,z80f,#PSR_C
	fetch 8
	MEND

	MACRO
	opSRAL $x
	mov r0,$x,lsl#8
	opSRA r0,r0
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsl#16
	fetch 8
	MEND

	MACRO
	opSRAb
	mov r0,r0,lsl#24
	opSRA r0,r0
	MEND
;---------------------------------------

	MACRO
	opSRL $x,$y,$z
	movs $x,$y,lsr#$z
	adr r1,pzst
	ldrb z80f,[r1,$x]					;get PZS
	orrcs z80f,z80f,#PSR_C
	MEND

	MACRO
	opSRLA
	opSRL z80a,z80a,25
	mov z80a,z80a,lsl#24
	fetch 8
	MEND

	MACRO
	opSRLH $x
	opSRL r0,$x,25
	and $x,$x,#0x00FF0000				;mask out low
	orr $x,$x,r0,lsl#24
	fetch 8
	MEND

	MACRO
	opSRLL $x
	mov r0,$x,lsl#8
	opSRL r0,r0,25
	and $x,$x,#0xFF000000				;mask out high
	orr $x,$x,r0,lsl#16
	fetch 8
	MEND

	MACRO
	opSRLb
	opSRL r0,r0,1
	MEND
;---------------------------------------

	MACRO
	opSUB $x,$y
	mov r1,z80a,lsl#4 					;Prepare for check of half carry
	subs z80a,z80a,$x,lsl#$y
	mrs z80f,cpsr						;S,Z,V&C
	mov z80f,z80f,lsr#28
	eor z80f,z80f,#PSR_C|PSR_n			;invert C and set n
	cmp r1,$x,lsl#$y+4
	orrcc z80f,z80f,#PSR_H
	MEND

	MACRO
	opSUBA
	mov z80a,#0
	mov z80f,#PSR_Z|PSR_n				;set Z & n
	fetch 4
	MEND

	MACRO
	opSUBH $x
	and r0,$x,#0xFF000000
	opSUB r0,0
	fetch 4
	MEND

	MACRO
	opSUBL $x
	opSUB $x,8
	fetch 4
	MEND

	MACRO
	opSUBb
	opSUB r0,24
	MEND
;---------------------------------------

	MACRO
	opXOR $x,$y
	eor z80a,z80a,$x,lsl#$y
	adr r0,pzst
	ldrb z80f,[r0,z80a,lsr#24]			;get PZS
	MEND

	MACRO
	opXORA
	mov z80a,#0							;clear A.
	mov z80f,#PSR_Z|PSR_P				;Z & P
	fetch 4
	MEND

	MACRO
	opXORH $x
	and r0,$x,#0xFF000000
	opXOR r0,0
	fetch 4
	MEND

	MACRO
	opXORL $x
	opXOR $x,8
	fetch 4
	MEND

	MACRO
	opXORb
	opXOR r0,24
	MEND
;---------------------------------------
	END
