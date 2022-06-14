; SCC/K051649 sound chip emulator for MSX.

	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE io.h

	EXPORT SCC_init
	EXPORT SCC_reset
	EXPORT SCC_set_mixrate
	EXPORT SCC_set_frequency
	EXPORT SCC_W_OFF
	EXPORT SCC_W
	EXPORT SCC_R
	EXPORT SCC_Mixer


 AREA wram_code2, CODE, READWRITE
;----------------------------------------------------------------------------
; r0 = mixerbuffer.
; r1 = sample reg1.
; r2 = sample reg2/volume.
; r3 = mixer reg left.
; r4 -> r8 = pos+freq.
; r9 = mix length
; r10= samplebuffers.
; r11= eor reg
; r12= ...
; lr = return address.
;----------------------------------------------------------------------------
sccmix
;----------------------------------------------------------------------------
sccmixloop
	ldrb r1,[r10,r4,lsr#27]			;Channel 0
	add r4,r4,r4,lsl#16
	ldrb r2,[r10,r4,lsr#27]
	add r4,r4,r4,lsl#16
	orr r1,r2,r1,lsl#16
	eor r1,r11,r1
vol0
	movs r3,#0x00					;volume
	mulne r3,r1,r3


	add r10,r10,#0x20
	ldrb r1,[r10,r5,lsr#27]			;Channel 1
	add r5,r5,r5,lsl#16
	ldrb r2,[r10,r5,lsr#27]
	add r5,r5,r5,lsl#16
	orr r1,r2,r1,lsl#16
	eor r1,r11,r1
vol1
	movs r2,#0x00					;volume
	mlane r3,r1,r2,r3


	add r10,r10,#0x20
	ldrb r1,[r10,r6,lsr#27]			;Channel 2
	add r6,r6,r6,lsl#16
	ldrb r2,[r10,r6,lsr#27]
	add r6,r6,r6,lsl#16
	orr r1,r2,r1,lsl#16
	eor r1,r11,r1
vol2
	movs r2,#0x00					;volume
	mlane r3,r1,r2,r3


	add r10,r10,#0x20
	ldrb r1,[r10,r7,lsr#27]			;Channel 3
	add r7,r7,r7,lsl#16
	ldrb r2,[r10,r7,lsr#27]
	add r7,r7,r7,lsl#16
	orr r1,r2,r1,lsl#16
	eor r1,r11,r1
vol3
	movs r2,#0x00					;volume
	mlane r3,r1,r2,r3


	ldrb r1,[r10,r8,lsr#27]			;Channel 4, same waveform as ch3
	add r8,r8,r8,lsl#16
	ldrb r2,[r10,r8,lsr#27]
	add r8,r8,r8,lsl#16
	orr r1,r2,r1,lsl#16
	eor r1,r11,r1
vol4
	movs r2,#0x00					;volume
	mlane r3,r1,r2,r3


	sub r10,r10,#0x60

;	bic r3,r3,#0x7f
;	orr r3,r3,#0x80
	bic r3,r3,#0x80
	orr r3,r3,#0x7f
	eor r3,r3,r3,ror#24
	strh r3,[r0],#2

	subs r9,r9,#2
	bne sccmixloop

	bx lr
;----------------------------------------------------------------------------

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
SCC_init
;----------------------------------------------------------------------------
;	stmfd sp!,{lr}
;	bl SCC_frequency_calculate
;	ldmfd sp!,{lr}
;----------------------------------------------------------------------------
SCC_reset
;----------------------------------------------------------------------------
	stmfd sp!,{lr}

	adrl r0,SCC_Memory
	mov r1,#0
	mov r2,#0x24					;144/4=0x24
	bl memset_						;clear variables

	ldmfd sp!,{lr}
	bx lr
;----------------------------------------------------------------------------
SCC_set_mixrate						;r0 in. 0 = low, 1 = high
;----------------------------------------------------------------------------
	cmp r0,#0
	moveq r0,#924					;low,  18157Hz
	movne r0,#532					;high, 31536Hz
	str r0,mixrate
	moveq r0,#304					;low
	movne r0,#528					;high
	str r0,mixlength
	bx lr
;----------------------------------------------------------------------------
SCC_set_frequency					;r0=frequency of chip.
;----------------------------------------------------------------------------
	ldr r1,mixrate
	mul r0,r1,r0
	mov r0,r0,lsr#12
	str r0,freqconv					;Frequency conversion (SCCfreq*mixrate)/4096
	bx lr
;----------------------------------------------------------------------------
SCC_frequency_calculate
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r6,lr}
	ldr r6,freqconv					;(SCC/gba)*4096
	ldr r5,=FREQTBL					;Destination
	mov r4,#4096*2
frqloop2
	mov r0,r6
	mov r1,r4
	swi 0x060000					;BIOS Div, r0/r1.
	cmp r4,#7*2
	movmi r0,#0						;to remove real high tones.
;	movmi r0,#0x8000				;to remove real high tones.
	subs r4,r4,#2
	strh r0,[r5,r4]
	bhi frqloop2

	ldmfd sp!,{r4-r6,lr}
	bx lr

;----------------------------------------------------------------------------
SCC_Mixer							;in r0=mixerbuffer
;----------------------------------------------------------------------------
	;update DMA buffer for PCM

	stmfd sp!,{r3-r12,lr}

;--------------------------
	adr r2,SCC_Volume
	ldrb r3,chcontrol

	ands r1,r3,#0x01
	ldrneb r1,ch0volume
	and r1,r1,#0x0F
	ldrb r4,[r2,r1]
	ldr r5,=vol0
	strb r4,[r5]

	ands r1,r3,#0x02
	ldrneb r1,ch1volume
	and r1,r1,#0x0F
	ldrb r4,[r2,r1]
	ldr r5,=vol1
	strb r4,[r5]

	ands r1,r3,#0x04
	ldrneb r1,ch2volume
	and r1,r1,#0x0F
	ldrb r4,[r2,r1]
	ldr r5,=vol2
	strb r4,[r5]

	ands r1,r3,#0x08
	ldrneb r1,ch3volume
	and r1,r1,#0x0F
	ldrb r4,[r2,r1]
	ldr r5,=vol3
	strb r4,[r5]

	ands r1,r3,#0x10
	ldrneb r1,ch4volume
	and r1,r1,#0x0F
	ldrb r4,[r2,r1]
	ldr r5,=vol4
	strb r4,[r5]


	ldr r11,=FREQTBL
	adr r1,pcm0currentaddr			;counters
	ldmia r1,{r4-r9}
	adr r12,ch0freq
;--------------------------
	ldrh r10,[r12],#2
	bic r10,r10,#0xF000
	add r10,r10,r10
	ldrh r1,[r11,r10]
	mov r4,r4,lsr#16
	orr r4,r1,r4,lsl#16
;--------------------------
	ldrh r10,[r12],#2
	bic r10,r10,#0xF000
	add r10,r10,r10
	ldrh r1,[r11,r10]
	mov r5,r5,lsr#16
	orr r5,r1,r5,lsl#16
;--------------------------
	ldrh r10,[r12],#2
	bic r10,r10,#0xF000
	add r10,r10,r10
	ldrh r1,[r11,r10]
	mov r6,r6,lsr#16
	orr r6,r1,r6,lsl#16
;--------------------------
	ldrh r10,[r12],#2
	bic r10,r10,#0xF000
	add r10,r10,r10
	ldrh r1,[r11,r10]
	mov r7,r7,lsr#16
	orr r7,r1,r7,lsl#16
;--------------------------
	ldrh r10,[r12],#2
	bic r10,r10,#0xF000
	add r10,r10,r10
	ldrh r1,[r11,r10]
	mov r8,r8,lsr#16
	orr r8,r1,r8,lsl#16
;--------------------------

	adr r10,ch0wave					;r10 = SCC wavebuffer
	ldr r11,=0x00800080
;	mov r11,r11						;No$GBA breakpoint
	bl sccmix

	adr r0,pcm0currentaddr			;counters
	stmia r0,{r4-r8}

	ldmfd sp!,{r3-r12,pc}
;----------------------------------------------------------------------------
SCC_Volume
	DCB 0,3,7,10,14,17,20,24,27,31,34,37,41,44,48,51
;----------------------------------------------------------------------------
SCC_R
	mov r0,#0xFF
	mov pc,lr
;----------------------------------------------------------------------------
SCC_W_OFF
	bx lr
;----------------------------------------------------------------------------
SCC_W;				0x9800-0x9FFF
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA breakpoint
	and addy,addy,#0xFF
	cmp addy,#0xA0
	bxpl lr
	cmp addy,#0x90
	subpl addy,addy,#0x10
	adr r1,SCC_Memory
	strb r0,[r1,addy]
	bx lr

;----------------------------------------------------------------------------
;SoundVariables

SCC_Memory
ch0wave		% 32
ch1wave		% 32
ch2wave		% 32
ch3wave		% 32
ch0freq		DCW 0
ch1freq		DCW 0
ch2freq		DCW 0
ch3freq		DCW 0
ch4freq		DCW 0
ch0volume	DCB 0
ch1volume	DCB 0
ch2volume	DCB 0
ch3volume	DCB 0
ch4volume	DCB 0
chcontrol	DCB 0

pcm0currentaddr	DCD 0		;current addr
pcm1currentaddr	DCD 0		;current addr
pcm2currentaddr	DCD 0		;current addr
pcm3currentaddr	DCD 0		;current addr
pcm4currentaddr	DCD 0		;current addr
;----------------------------------------------------------------------------
mixlength	DCD 304		;mixlength (528=high, 304=low)
mixrate		DCD 924		;mixrate (532=high, 924=low)
freqconv	DCD 0xC52AD	;Frequency conversion (0x71854=high, 0xC52AD=low) (3580000/mixrate)*4096

;----------------------------------------------------------------------------
	END

