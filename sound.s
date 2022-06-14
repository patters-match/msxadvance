	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE io.h
	INCLUDE ay38910.h
	INCLUDE scc.h

	EXPORT Sound_init
	EXPORT Sound_reset
	EXPORT soundmode
	EXPORT Vbl_Sound_1
	EXPORT Vbl_Sound_2


;----------------------------------------------------------------------------

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
Sound_init
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r5,lr}
	mov r5,#REG_BASE

;	ldrh r0,[r5,#REG_SGBIAS]
;	bic r0,r0,#0xc000				;just change bits we know about.
;	orr r0,r0,#0x8000				;PWM 7-bit 131.072kHz
;	strh r0,[r5,#REG_SGBIAS]

	ldr r2,soundmode				;if r2=0, no sound.
	cmp r2,#1

	movmi r0,#0
	ldreq r0,=0xbb0c0000			;use directsound A&B->L&R, 100% volume, timer 0. CRAP!
;	ldreq r0,=0xbb000000			;use directsound A&B->L&R, 50% volume, timer 0
;	ldreq r0,=0x9a0c0000			;use directsound A->L & B->R, 100% volume, timer 0
	str r0,[r5,#REG_SGCNT_L]

	moveq r0,#0x80
	strh r0,[r5,#REG_SGCNT_X]		;sound master enable

	mov r0,#0						;triangle reset
	str r0,[r5,#REG_SG3CNT_L]		;sound3 disable, mute, write bank 0

									;Mixer channels
	strh r5,[r5,#REG_DM1CNT_H]		;DMA1 stop, AY38910
	strh r5,[r5,#REG_DM2CNT_H]		;DMA2 stop, SCC
	add r0,r5,#REG_FIFO_A_L			;DMA1 destination..
	str r0,[r5,#REG_DM1DAD]
	add r0,r5,#REG_FIFO_B_L			;DMA2 destination..
	str r0,[r5,#REG_DM2DAD]
	ldr r0,pcmptr0
	str r0,[r5,#REG_DM1SAD]			;DMA1 src=..
	add r0,r0,#PCMWAVSIZE*2
	str r0,[r5,#REG_DM2SAD]			;DMA2 src=..
;	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
;	strh r0,[r5,#REG_DM1CNT_H]		;DMA1 start
;	strh r0,[r5,#REG_DM2CNT_H]		;DMA2 start

	mov r4,#1
	cmp r4,#0
	moveq r0,#924					;low,  18157Hz
	movne r0,#532					;high, 31536Hz
	str r0,mixrate

	mov r0,r4
	bl AY38910_set_mixrate			;sound, 0=low, 1=high mixrate
	ldr r0,=3579545
	bl AY38910_set_frequency		;sound, chip frequency
	bl AY38910_init					;sound

	mov r0,r4
	bl SCC_set_mixrate				;sound, 0=low, 1=high mixrate
	ldr r0,=3579545
	bl SCC_set_frequency			;sound, chip frequency
	bl SCC_init						;sound


	ldr r2,soundmode				;if r2=0, no sound.
	cmp r2,#1

	add r1,r5,#REG_TM0CNT_L			;timer 0 controls sample rate:
	mov r0,#0
	str r0,[r1]						;stop timer 0
	ldr r3,mixrate					; 924=Low, 532=High.
	mov r2,#0x10000					;frequency = 0
	subeq r0,r2,r3					;frequency = 0x1000000/r3 Hz
	orreq r0,r0,#0x800000			;timer 0 on
	str r0,[r1]


	ldmfd sp!,{r3-r5,lr}
	bx lr

;----------------------------------------------------------------------------
Sound_reset
;----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl AY38910_reset				;sound
	bl SCC_reset					;sound
	ldmfd sp!,{lr}
	bx lr

;----------------------------------------------------------------------------
Vbl_Sound_1
;----------------------------------------------------------------------------
	ldr r0,soundmode				;if r0=0, no sound.
	cmp r0,#0
	moveq pc,lr


	mov r1,#REG_BASE
	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop
	strh r1,[r1,#REG_DM2CNT_H]		;DMA2 stop
	ldr r2,pcmptr0
	str r2,[r1,#REG_DM1SAD]			;DMA1 src=..
	add r0,r2,#PCMWAVSIZE*2
	str r0,[r1,#REG_DM2SAD]			;DMA2 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 go
	strh r0,[r1,#REG_DM2CNT_H]		;DMA2 go

	ldr r1,pcmptr1
	str r1,pcmptr0
	str r2,pcmptr1

	mov pc,lr
;----------------------------------------------------------------------------
Vbl_Sound_2
;----------------------------------------------------------------------------
	;update DMA buffer for PCM
	ldr r0,soundmode				;if r0=0, no sound.
	cmp r0,#0
	moveq pc,lr

	stmfd sp!,{lr}
	ldr r0,pcmptr0
	bl AY38910_Mixer
	ldr r0,pcmptr0
	add r0,r0,#PCMWAVSIZE*2
	bl SCC_Mixer
	ldmfd sp!,{pc}




soundmode	DCD 1		;soundmode (OFF/ON)
mixrate		DCD 924		;mixrate (532=high, 924=low)
;mixlength	DCD 304		;mixlength (528=high, 304=low)

pcmptr0 DCD PCMWAV
pcmptr1 DCD PCMWAV+PCMWAVSIZE

;----------------------------------------------------------------------------
	END

