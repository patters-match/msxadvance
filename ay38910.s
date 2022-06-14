; AY38910 sound chip emulator for MSX.

	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE io.h

	EXPORT AY38910_init
	EXPORT AY38910_reset
	EXPORT AY38910_set_mixrate
	EXPORT AY38910_set_frequency
	EXPORT AY38910_W_OFF
	EXPORT AY38910_Index_W
	EXPORT AY38910_Data_W
	EXPORT AY38910_Data_R
	EXPORT AY38910_Mixer

NSEED	 	EQU 0x00001			;Noise Seed
WFEED	 	EQU 0x12000			;White Noise Feedback

 AREA wram_code2, CODE, READWRITE
;----------------------------------------------------------------------------
; r0 = mixerbuffer.
; r1 -> r4 = pos+freq.
; r5 = noise generator.
; r6 = envelope addr
; r7 = envelope freq
; r8 = ch disable, envelope type.
; r9 = mix length.
; r10= mixer reg.
; r11= scrap
; r12= scrap
; lr = env volume
; lr = return address.
;----------------------------------------------------------------------------
mixer
;----------------------------------------------------------------------------
mixloop
	tst r6,r8,lsl#15				;env Hold
	subpl r6,r6,r7
	movmi r6,#0x80000000
	and r11,r6,#0x78000000
	and r12,r6,r8,lsl#14			;env ALT
	eors r12,r12,r8,lsl#13			;env ATT
	eormi r11,r11,#0x78000000

	adr r12,Attenuation
	ldrb lr,[r12,r11,lsr#27]

	adds r4,r4,r4,lsl#16
	movcss r5,r5,lsr#1
	eorcs r5,r5,#WFEED

	tst r5,#1
	orrne r11,r8,#0x38000000
	moveq r11,r8
volF
	mov r10,#0x80
	add r1,r1,r1,lsl#16
	orr r12,r1,r11,lsl#7
	tst r12,r11,lsl#4
ch0vol
	addmi r10,r10,#0x00

	add r2,r2,r2,lsl#16
	orr r12,r2,r11,lsl#6
	tst r12,r11,lsl#3
ch1vol
	addmi r10,r10,#0x00

	add r3,r3,r3,lsl#16
	orr r12,r3,r11,lsl#5
	tst r12,r11,lsl#2
ch2vol
	addmi r10,r10,#0x00

	strb r10,[r0],#1

	subs r9,r9,#1
	bne mixloop

;	bx lr
	b mix_ret
;----------------------------------------------------------------------------
Attenuation
	DCB 0x00,0x01,0x01,0x01,0x02,0x03,0x04,0x05,0x08,0x0B,0x0F,0x15,0x1E,0x2A,0x3C,0x55
;----------------------------------------------------------------------------

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
AY38910_init
;----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl frequency_calculate
	ldmfd sp!,{lr}
;----------------------------------------------------------------------------
AY38910_reset
;----------------------------------------------------------------------------
	stmfd sp!,{lr}

	mov r3,#0
reg_loop
	mov r0,r3
	bl AY38910_Index_W
	mov r0,#0
	bl AY38910_Data_W
	add r3,r3,#1
	cmp r3,#0xE
	bne reg_loop


	ldmfd sp!,{lr}
	bx lr

;----------------------------------------------------------------------------
AY38910_set_mixrate					;r0 in. 0 = low, 1 = high
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
AY38910_set_frequency				;r0=frequency of chip.
;----------------------------------------------------------------------------
	ldr r1,mixrate
	mul r0,r1,r0
	mov r0,r0,lsr#12
	str r0,freqconv					;Frequency conversion (AY38910freq*mixrate)/4096
	bx lr
;----------------------------------------------------------------------------
frequency_calculate
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r6,lr}
	ldr r6,freqconv					;(AY38910/gba)*4096
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
AY38910_Mixer						;in r0=mixerbuffer
;----------------------------------------------------------------------------
	;update DMA buffer for AY38910

	stmfd sp!,{r3-r12,lr}

	adrl r10,ch0freq
	ldmia r10,{r1-r9}		;load freq,addr,rng,env, vol & mixlen
;--------------------------
	b mixer
mix_ret

	adrl r0,ch0freq
	stmia r0,{r1-r6}		;writeback freq,addr,rng,env

	ldmfd sp!,{r3-r12,pc}

;----------------------------------------------------------------------------
AY38910_W_OFF
	bx lr
;----------------------------------------------------------------------------
AY38910_Index_W
	and r1,r0,#0xF
	strb r1,regindex
	bx lr
;----------------------------------------------------------------------------
AY38910_Data_W
	ldrb r1,regindex
	adr r2,RegMask
	ldrb r2,[r2,r1]
	and r0,r0,r2
	adr r2,ayregs
	strb r0,[r2,r1]
	ldr pc,[pc,r1,lsl#2]
	DCD 0
aytable
	DCD AY38910_reg0_w
	DCD AY38910_reg1_w
	DCD AY38910_reg2_w
	DCD AY38910_reg3_w
	DCD AY38910_reg4_w
	DCD AY38910_reg5_w
	DCD AY38910_reg6_w
	DCD AY38910_reg7_w
	DCD AY38910_reg8_w
	DCD AY38910_reg9_w
	DCD AY38910_regA_w
	DCD AY38910_regB_w
	DCD AY38910_regC_w
	DCD AY38910_regD_w
	DCD AY38910_regE_w
	DCD Joystick_W
;	DCD AY38910_regF_w
;----------------------------------------------------------------------------
AY38910_Data_R
	ldrb r1,regindex
	cmp r1,#0xE
	bpl Joystick_R
	mov r11,r11
	adr r0,ayregs
	ldrb r0,[r0,r1]
	bx lr
;----------------------------------------------------------------------------
RegMask
	DCB 0xFF,0x0F,0xFF,0x0F,0xFF,0x0F,0x1F,0xFF, 0x1F,0x1F,0x1F,0xFF,0xFF,0x0F,0xFF,0xFF

AttenuationCode
	addmi r10,r10,#0x00
	addmi r10,r10,#0x01
	addmi r10,r10,#0x01
	addmi r10,r10,#0x01
	addmi r10,r10,#0x02
	addmi r10,r10,#0x03
	addmi r10,r10,#0x04
	addmi r10,r10,#0x05
	addmi r10,r10,#0x08
	addmi r10,r10,#0x0B
	addmi r10,r10,#0x0F
	addmi r10,r10,#0x15
	addmi r10,r10,#0x1E
	addmi r10,r10,#0x2A
	addmi r10,r10,#0x3C
	addmi r10,r10,#0x55
AttenuationCode0x10
	addmi r10,r10,lr

;----------------------------------------------------------------------------
AY38910_reg1_w
AY38910_reg3_w
AY38910_reg5_w
	bic r1,r1,#1
;----------------------------------------------------------------------------
AY38910_reg0_w
AY38910_reg2_w
AY38910_reg4_w
	ldrh r0,[r2,r1]
	ldr r2,=FREQTBL
	mov r0,r0,lsl#1
	ldrh r0,[r2,r0]
	adr r2,ch0freq
	add r2,r2,r1
	strh r0,[r2,r1]
	bx lr
;----------------------------------------------------------------------------
AY38910_reg6_w
	ldr r2,=FREQTBL
	mov r0,r0,lsl#1
	cmp r0,#14
	movmi r0,#0x8000
	ldrplh r0,[r2,r0]
	adr r2,ch0freq
	add r2,r2,r1
	strh r0,[r2,r1]
	bx lr
;----------------------------------------------------------------------------
AY38910_reg7_w
	strb r0,ch_disable
	bx lr
;----------------------------------------------------------------------------
AY38910_reg8_w
	ands r1,r0,#0x10
	andeq r1,r0,#0xF
	adr r2,AttenuationCode
	ldr r0,[r2,r1,lsl#2]
	ldr r2,=ch0vol
	str r0,[r2]
	bx lr
;----------------------------------------------------------------------------
AY38910_reg9_w
	ands r1,r0,#0x10
	andeq r1,r0,#0xF
	adr r2,AttenuationCode
	ldr r0,[r2,r1,lsl#2]
	ldr r2,=ch1vol
	str r0,[r2]
	bx lr
;----------------------------------------------------------------------------
AY38910_regA_w
	ands r1,r0,#0x10
	andeq r1,r0,#0xF
	adr r2,AttenuationCode
	ldr r0,[r2,r1,lsl#2]
	ldr r2,=ch2vol
	str r0,[r2]
	bx lr
;----------------------------------------------------------------------------
AY38910_regB_w
AY38910_regC_w
	ldrb r0,ayregs+0xB
	ldrb r1,ayregs+0xC
	orr r0,r0,r1,lsl#8
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA breakpoint
;	cmp r0,#0x1000
;	bmi noshit
;noshit
;	ldr r2,=FREQTBL
;	mov r0,r0,lsl#1
;	ldrh r0,[r2,r0]

	movs r1,r0
	moveq r0,#0x80000000
	beq nodivide
	ldr r0,freqconv					;(AY38910/gba)*4096
	mov r0,r0,lsl#10
	stmfd sp!,{r3}
	swi 0x060000					;BIOS Div, r0/r1.
	ldmfd sp!,{r3}
nodivide
	str r0,envfreq
	bx lr
;----------------------------------------------------------------------------
AY38910_regD_w
	cmp r0,#4
	movmi r0,#9
	cmp r0,#8
	movmi r0,#0xF
	strb r0,env_type
	mov r0,#0x78000000
	str r0,envaddr
	bx lr
;----------------------------------------------------------------------------
AY38910_regE_w
;----------------------------------------------------------------------------
AY38910_regF_w
	bx lr
;----------------------------------------------------------------------------
SoundVariables
regindex	DCB 0
			% 3
ayregs		% 16

;----------------------------------------------------------------------------
ch0freq		DCW 0		;freq,addr, rng/noisefb & volume need to be like this for the mixer start.
ch0addr		DCW 0
ch1freq 	DCW 0
ch1addr		DCW 0
ch2freq 	DCW 0
ch2addr		DCW 0
ch3freq 	DCW 0
ch3addr		DCW 0

rng			DCD NSEED	;noise generator
envaddr		DCD 0		;envelope generator
envfreq		DCD 0		;envelope frequency

			DCB 0
			DCB 0
env_type	DCB 0
ch_disable	DCB 0

mixlength	DCD 304		;mixlength (528=high, 304=low)
;----------------------------------------------------------------------------
IO_PORTA_IN		DCD 0
IO_PORTB_IN		DCD 0
IO_PORTA_OUT	DCD 0
IO_PORTB_OUT	DCD 0

mixrate			DCD 924		;mixrate (532=high, 924=low), (mixrate=0x1000000/mixer_frequency)
freqconv		DCD 0		;Frequency conversion (AY38910freq*mixrate)/4096

;----------------------------------------------------------------------------
	END

