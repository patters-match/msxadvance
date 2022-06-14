	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE io.h

	EXPORT AY38910_reset
	EXPORT AY38910_set_mixrate
	EXPORT AY38910_set_frequency
;	EXPORT updatesound
	EXPORT soundmode
	EXPORT AY38910_W_OFF
	EXPORT AY38910_Index_W
	EXPORT AY38910_Data_W
	EXPORT AY38910_Data_R
	EXPORT Vbl_AY38910_1
	EXPORT Vbl_AY38910_2

NSEED	 	EQU 0x00001			;Noise Seed
WFEED	 	EQU 0x12000			;White Noise Feedback
 AREA wram_code2, CODE, READWRITE
;----------------------------------------------------------------------------
; r0 = mixer reg.
; r1 -> r4 = pos+freq.
; r5 = noise generator.
; r6 = ch volumes, ch disable.
; r7 = mixerbuffer.
; r8 = mix length.
; r9 = scrap
; r11= scrap
; r12= scrap
; lr = return address.
;----------------------------------------------------------------------------
mixer
;----------------------------------------------------------------------------
mixloop

	adds r4,r4,r4,lsl#16
	movcss r5,r5,lsr#1
	eorcs r5,r5,#WFEED

	tst r5,#1
	orrne r9,r6,#0x38000000
	moveq r9,r6
volF
	mov r0,#0x80
	add r1,r1,r1,lsl#16
	orr r12,r1,r6,lsl#7
	tst r12,r9,lsl#4
	addmi r0,r0,r6

	add r2,r2,r2,lsl#16
	orr r12,r2,r6,lsl#6
	tst r12,r9,lsl#3
	addmi r0,r0,r6,lsr#8

	add r3,r3,r3,lsl#16
	orr r12,r3,r6,lsl#5
	tst r12,r9,lsl#2
	addmi r0,r0,r6,lsr#16

	strb r0,[r7],#1

	subs r8,r8,#1
	bne mixloop

	bx lr
;----------------------------------------------------------------------------

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
AY38910_reset
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r7,lr}
	mov r1,#REG_BASE

;	ldrh r0,[r1,#REG_SGBIAS]
;	bic r0,r0,#0xc000				;just change bits we know about.
;	orr r0,r0,#0x8000				;PWM 7-bit 131.072kHz
;	strh r0,[r1,#REG_SGBIAS]

	ldr r2,soundmode				;if r2=0, no sound.
	cmp r2,#1
;	ldr r3,=psg_write_ptr
;	adrmi r0,AY38910_W_OFF
;	adreq r0,AY38910_W
;	str r0,[r3],#4
;	str r0,[r3]

	movmi r0,#0
	ldreq r0,=0x0b040000			;stop all channels, output ratio=1/4 range for noise.  use directsound A, timer 0
	str r0,[r1,#REG_SGCNT_L]

	moveq r0,#0x80
	strh r0,[r1,#REG_SGCNT_X]		;sound master enable

									;triangle reset
	mov r0,#0
	str r0,[r1,#REG_SG3CNT_L]		;sound3 disable, mute, write bank 0

									;Mixer channels
	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop, Left channel
	add r0,r1,#REG_FIFO_A_L			;DMA1 destination..
	str r0,[r1,#REG_DM1DAD]
	ldr r0,pcmptr0
	str r0,[r1,#REG_DM1SAD]			;DMA1 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 start


	add r1,r1,#REG_TM0D				;timer 0 controls sample rate:
	mov r0,#0
	str r0,[r1]						;stop timer 0
	ldr r3,mixrate					; 924=Low, 532=High.
	mov r2,#0x10000					;frequency = 0
	subeq r0,r2,r3					;frequency = 0x1000000/r3 Hz
	orreq r0,r0,#0x800000			;timer 0 on
	str r0,[r1],#4

	bl frequency_calculate

	adrl r0,SoundVariables
	mov r1,#0
	mov r2,#9						;36/4=9
	bl memset_						;clear variables
	str r1,ch0volume				;silence

	ldmfd sp!,{r3-r7,lr}
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
	subs r4,r4,#2
	strh r0,[r5,r4]
	bhi frqloop2

	ldmfd sp!,{r4-r6,lr}
	bx lr

;----------------------------------------------------------------------------
Vbl_AY38910_1
;----------------------------------------------------------------------------
	ldr r0,soundmode				;if r2=0, no sound.
	cmp r0,#0
	bxeq lr


	mov r1,#REG_BASE
	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop
	ldr r2,pcmptr0
	str r2,[r1,#REG_DM1SAD]			;DMA1 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 go

	ldr r1,pcmptr1
	str r1,pcmptr0
	str r2,pcmptr1

	bx lr
;----------------------------------------------------------------------------
Vbl_AY38910_2
;----------------------------------------------------------------------------
	;update DMA buffer for PCM
	ldr r0,soundmode				;if r0=0, no sound.
	cmp r0,#0
	bxeq lr

	stmfd sp!,{r3-r9,r11,r12,lr}
PSGMixer
	adrl r0,ch0freq
	ldmia r0,{r1-r7}		;load freq,addr,rng, vol & pcmptr0
;--------------------------
	ldr r8,mixlength
	bl mixer

	adrl r0,ch0freq
	stmia r0,{r1-r5}		;writeback freq,addr,rng

	ldmfd sp!,{r3-r9,r11,r12,pc}

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
	DCD AY38910_regF_w
;----------------------------------------------------------------------------
AY38910_Data_R
	ldrb r1,regindex
	cmp r1,#0xE
	bpl Joystick1_R
	adr r0,ayregs
	ldrb r0,[r0,r1]
	bx lr
;----------------------------------------------------------------------------
AY38910_reg0_w
;----------------------------------------------------------------------------
AY38910_reg1_w
	bic r1,r1,#1
	ldrh r0,[r2,r1]
	ldr r2,=FREQTBL
	mov r0,r0,lsl#1
	ldrh r0,[r2,r0]
	strh r0,ch0freq
	bx lr
;----------------------------------------------------------------------------
AY38910_reg2_w
;----------------------------------------------------------------------------
AY38910_reg3_w
	bic r1,r1,#1
	ldrh r0,[r2,r1]
	ldr r2,=FREQTBL
	mov r0,r0,lsl#1
	ldrh r0,[r2,r0]
	strh r0,ch1freq
	bx lr
;----------------------------------------------------------------------------
AY38910_reg4_w
;----------------------------------------------------------------------------
AY38910_reg5_w
	bic r1,r1,#1
	ldrh r0,[r2,r1]
	ldr r2,=FREQTBL
	mov r0,r0,lsl#1
	ldrh r0,[r2,r0]
	strh r0,ch2freq
	bx lr
;----------------------------------------------------------------------------
AY38910_reg6_w
	ldr r2,=FREQTBL
	and r0,r0,#0x1F
	mov r0,r0,lsl#1
	ldrh r0,[r2,r0]
	strh r0,ch3freq
	bx lr
;----------------------------------------------------------------------------
AY38910_reg7_w
	strb r0,ch_disable
	bx lr
;----------------------------------------------------------------------------
AY38910_reg8_w
	and r0,r0,#0xF
	adr r2,Attenuation
	ldrb r0,[r2,r0]
	strb r0,ch0volume
	bx lr
;----------------------------------------------------------------------------
AY38910_reg9_w
	and r0,r0,#0xF
	adr r2,Attenuation
	ldrb r0,[r2,r0]
	strb r0,ch1volume
	bx lr
;----------------------------------------------------------------------------
AY38910_regA_w
	and r0,r0,#0xF
	adr r2,Attenuation
	ldrb r0,[r2,r0]
	strb r0,ch2volume
	bx lr
;----------------------------------------------------------------------------
AY38910_regB_w
;----------------------------------------------------------------------------
AY38910_regC_w
;----------------------------------------------------------------------------
AY38910_regD_w
;----------------------------------------------------------------------------
AY38910_regE_w
;----------------------------------------------------------------------------
AY38910_regF_w
	bx lr
;----------------------------------------------------------------------------

RegMask
	DCB 0xFF,0x0F,0xFF,0x0F,0xFF,0x0F,0x1F,0xFF, 0x1F,0x1F,0x1F,0xFF,0xFF,0x0F,0xFF,0xFF

Attenuation
	DCB 0x00,0x01,0x01,0x01,0x02,0x03,0x04,0x05,0x08,0x0B,0x0F,0x15,0x1E,0x2A,0x3C,0x55
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

ch0volume	DCB 0
ch1volume	DCB 0
ch2volume	DCB 0
ch_disable	DCB 0

pcmptr0 DCD PCMWAV
pcmptr1 DCD PCMWAV+PCMWAVSIZE
;----------------------------------------------------------------------------
IO_PORTA_IN		DCD 0
IO_PORTB_IN		DCD 0
IO_PORTA_OUT	DCD 0
IO_PORTB_OUT	DCD 0

soundmode		DCD 1		;soundmode (OFF/ON)
mixrate			DCD 924		;mixrate (532=high, 924=low), (mixrate=0x1000000/mixer_frequency)
mixlength		DCD 304		;mixlength (528=high, 304=low)
freqconv		DCD 0		;Frequency conversion (AY38910freq*mixrate)/4096

;----------------------------------------------------------------------------
	END

