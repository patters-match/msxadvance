	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE gfx.h
	INCLUDE cart.h
	INCLUDE z80mac.h
	INCLUDE z80.h
	INCLUDE ay38910.h

	EXPORT IO_reset
	EXPORT Z80_IN
	EXPORT Z80_OUT
	EXPORT Z80_IN_C
	EXPORT Z80_OUT_C
	EXPORT joycfg
	EXPORT spriteinit
	EXPORT suspend
	EXPORT refreshEMUjoypads
	EXPORT serialinterrupt
	EXPORT resetSIO
	EXPORT thumbcall_r1
	EXPORT gettime
	EXPORT vbaprint
	EXPORT waitframe
	EXPORT UnCompVram
	EXPORT LZ77UnCompVram
	EXPORT HuffUnComp
	EXPORT RLEUnCompVram
	EXPORT CheckGBAVersion
	EXPORT BankSwitch0_W
	EXPORT BankSwitch1_W
	EXPORT BankSwitch2_W
	EXPORT BankSwitch3_W
	EXPORT PSLOT_W
	EXPORT Joystick_R
	EXPORT Joystick_W
	EXPORT g_keymap_L
	EXPORT g_keymap_R
	EXPORT g_keymap_Start
	EXPORT g_keymap_Select
	EXPORT g_CfgKey
	EXPORT Keyboard_Control

	IMPORT AGBinput
;----------------------------------------------------------------------------
 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -
;----------------------------------------------------------------------------

UnCompVram
	ldrb r2,[r0]
	mov r2,r2,lsr#4
	cmp r2,#1
	beq LZ77UnCompVram
	cmp r2,#2
	beq HuffUnComp
	cmp r2,#3
	beq RLEUnCompVram
	bx lr

LZ77UnCompVram
	swi 0x120000
	bx lr

HuffUnComp
	swi 0x130000
	bx lr

RLEUnCompVram
	swi 0x150000
	bx lr


vbaprint
	swi 0xFF0000		;!!!!!!! Doesn't work on hardware !!!!!!!
	bx lr
waitframe
VblWait
	mov r0,#0				;don't wait if not necessary
	mov r1,#1				;VBL wait
	swi 0x040000			; Turn of CPU until VBLIRQ if not too late allready.
	bx lr
CheckGBAVersion
	ldr r0,=0x5AB07A6E		;Fool proofing
	mov r12,#0
	swi 0x0D0000			;GetBIOSChecksum
	ldr r1,=0xABBE687E		;Proto GBA
	cmp r0,r1
	moveq r12,#1
	ldr r1,=0xBAAE187F		;Normal GBA
	cmp r0,r1
	moveq r12,#2
	ldr r1,=0xBAAE1880		;Nintendo DS
	cmp r0,r1
	moveq r12,#4
	mov r0,r12
	bx lr

scaleparms;
	DCD 0x0000,0x0100,0x0122,0x0080,0x0099,OAM_BUFFER1+6
;----------------------------------------------------------------------------
IO_reset
;----------------------------------------------------------------------------
	adr r5,scaleparms		;set sprite scaling params
	ldmia r5,{r0-r5}

	mov r6,#2
scaleloop
	strh r1,[r5],#8				;buffer1, buffer2. scaled normal sprites
	strh r0,[r5],#8
	strh r0,[r5],#8
	strh r2,[r5],#8
		strh r3,[r5],#8			;unscaled double sprites
		strh r0,[r5],#8
		strh r0,[r5],#8
		strh r3,[r5],#40
			strh r3,[r5],#8		;scaled double sprites
			strh r0,[r5],#8
			strh r0,[r5],#8
			strh r4,[r5],#136
		add r5,r5,#0x300
	subs r6,r6,#1
	bne scaleloop


	str r0,joy0state			;r0=0
	ldrb r0,emuflags+1
	;..to spriteinit
;----------------------------------------------------------------------------
spriteinit	;build yscale_lookup tbl (called by ui.c) r0=scaletype
;called by ui.c:  void spriteinit(char scaletype) (pass scaletype in r0 because globals ptr isn't set up to read it)
;----------------------------------------------------------------------------
	ldr r3,=YSCALE_LOOKUP-16
	cmp r0,#SCALED
	bpl si1

;------------------ unscaled
si5
	sub r2,r3,#192-160
	mov r0,#164
si2	strb r0,[r2],#1
	cmp r2,r3
	bne si2

	add r2,r3,#256+16
	mov r0,#-31
si3	strb r0,[r3],#1
	add r0,r0,#1
	cmp r0,#164
	movpl r0,#164
	cmp r2,r3
	bne si3
	bx lr

;------------------ scaled
si1
	ldr r0,=0x00D55555		;5/6
	ldr r1,=0xe5000000		;-(16+16)*0.75
si4	mov r2,r1,lsr#24
	strb r2,[r3],#1
	add r1,r1,r0
	cmp r2,#0xe0
	bne si4
	bx lr
;----------------------------------------------------------------------------
suspend	;called from ui.c and z80.s
;----------------------------------------------------------------------------
	mov r3,#REG_BASE

	ldr r1,=REG_P1CNT
	ldr r0,=0xc00c			;interrupt on start+sel
	strh r0,[r3,r1]

	ldrh r1,[r3,#REG_SGCNT_L]
	strh r3,[r3,#REG_SGCNT_L]	;sound off

	ldrh r0,[r3,#REG_DISPCNT]
	orr r0,r0,#0x80
	strh r0,[r3,#REG_DISPCNT]	;LCD off

	swi 0x030000

	ldrh r0,[r3,#REG_DISPCNT]
	bic r0,r0,#0x80
	strh r0,[r3,#REG_DISPCNT]	;LCD on

	strh r1,[r3,#REG_SGCNT_L]	;sound on

	ldr r1,=REG_P1
susloop
	ldrh r0,[r1]
	and r0,r0,#0xc
	eors r0,r0,#0xc
	bne susloop

	bx lr
;----------------------------------------------------------------------------
gettime	;called from ui.c
;----------------------------------------------------------------------------
	ldr r3,=0x080000c4		;base address for RTC
	mov r1,#1
	strh r1,[r3,#4]			;enable RTC
	mov r1,#7
	strh r1,[r3,#2]			;enable write

	mov r1,#1
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]			;State=Command

	mov r2,#0x65			;r2=Command, YY:MM:DD 00 hh:mm:ss
	mov addy,#8
RTCLoop1
	mov r1,#2
	and r1,r1,r2,lsr#6
	orr r1,r1,#4
	strh r1,[r3]
	mov r1,r2,lsr#6
	orr r1,r1,#5
	strh r1,[r3]
	mov r2,r2,lsl#1
	subs addy,addy,#1
	bne RTCLoop1

	mov r1,#5
	strh r1,[r3,#2]			;enable read
	mov r2,#0
	mov addy,#32
RTCLoop2
	mov r1,#4
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]
	ldrh r1,[r3]
	and r1,r1,#2
	mov r2,r2,lsr#1
	orr r2,r2,r1,lsl#30
	subs addy,addy,#1
	bne RTCLoop2

	mov r0,#0
	mov addy,#24
RTCLoop3
	mov r1,#4
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]
	ldrh r1,[r3]
	and r1,r1,#2
	mov r0,r0,lsr#1
	orr r0,r0,r1,lsl#22
	subs addy,addy,#1
	bne RTCLoop3

	bx lr
;----------------------------------------------------------------------------
resetSIO	;r0=joycfg
;----------------------------------------------------------------------------
	bic r0,r0,#0x0f000000
	str r0,joycfg

	mov r2,#REG_BASE
	add r2,r2,#0x100

	mov r1,#0
	strh r1,[r2,#REG_RCNT]

	tst r0,#0x80000000
	moveq r1,#0x2000
	movne r1,   #0x6000
	addne r1,r1,#0x0002	;16bit multiplayer, 57600bps
	strh r1,[r2,#REG_SIOCNT]

	bx lr
;----------------------------------------------------------------------------
serialinterrupt
;----------------------------------------------------------------------------
	mov r3,#REG_BASE
	add r3,r3,#0x100

	mov r0,#0x1
serWait	subs r0,r0,#1
	bne serWait
	mov r0,#0x100			;time to wait.
	ldrh r1,[r3,#REG_SIOCNT]
	tst r1,#0x80			;Still transfering?
	bne serWait

	tst r1,#0x40			;communication error? resend?
	bne sio_err

	ldr r0,[r3,#REG_SIOMULTI0]	;Both SIOMULTI0&1

	and r2,r0,#0xff00		;From Master
	cmp r2,#0xaa00
	beq resetrequest		;$AAxx means Master GBA wants to restart

	ldr r2,sending
	tst r2,#0x10000
	beq sio_err
	strne r0,received0		;store only if we were expecting something
sio_err
	strb r3,sending+2		;send completed, r3b=0
	bx lr

resetrequest
	ldr r2,joycfg
	strh r0,received0
	orr r2,r2,#0x01000000
	bic r2,r2,#0x08000000
	str r2,joycfg
	bx lr

sending DCD 0
lastsent DCD 0
received0 DCD 0
	LTORG
;----------------------------------------------------------------------------
VKB_Array
	DCW 64*0+0	;Pos
	DCB 0x35	;Key, F1
	DCB 0		;Dummy
	DCB 1		;Go right from this key
	DCB 9		;Go left from this key
	DCB 65		;Go up from this key
	DCB 10		;Go down from this key

	DCW 64*0+3
	DCB 0x36,0	;F2
	DCB 2,0,65,12

	DCW 64*0+6
	DCB 0x37,0	;F3
	DCB 3,1,66,13

	DCW 64*0+9
	DCB 0x38,0	;F4
	DCB 4,2,67,15

	DCW 64*0+12
	DCB 0x39,0	;F5
	DCB 5,3,67,16

	DCW 64*0+16
	DCB 0x3E,0	;Sel
	DCB 6,4,67,18

	DCW 64*0+19
	DCB 0x3C,0	;Stop
	DCB 7,5,67,20

	DCW 64*0+24
	DCB 0x41,0	;Home
	DCB 8,6,68,22

	DCW 64*0+26
	DCB 0x42,0	;Insert
	DCB 9,7,68,23

	DCW 64*0+28
	DCB 0x43,0	;Delete
	DCB 0,8,68,24

;---------------------

	DCW 64*1+0
	DCB 0x3A,0	;Esc
	DCB 11,24,0,25

	DCW 64*1+2
	DCB 0x01,0	;1
	DCB 12,10,0,26

	DCW 64*1+4
	DCB 0x02,0	;2
	DCB 13,11,1,27

	DCW 64*1+6
	DCB 0x03,0	;3
	DCB 14,12,2,28

	DCW 64*1+8
	DCB 0x04,0	;4
	DCB 15,13,2,29

	DCW 64*1+10
	DCB 0x05,0	;5
	DCB 16,14,3,30

	DCW 64*1+12
	DCB 0x06,0	;6
	DCB 17,15,4,31

	DCW 64*1+14
	DCB 0x07,0	;7
	DCB 18,16,4,32

	DCW 64*1+16
	DCB 0x08,0	;8
	DCB 19,17,5,33

	DCW 64*1+18
	DCB 0x09,0	;9
	DCB 20,18,5,34

	DCW 64*1+20
	DCB 0x00,0	;0
	DCB 21,19,6,35

	DCW 64*1+22
	DCB 0x0A,0	;-
	DCB 22,20,6,36

	DCW 64*1+24
	DCB 0x0B,0	;=
	DCB 23,21,7,37

	DCW 64*1+26
	DCB 0x0C,0	;backslash
	DCB 24,22,8,38

	DCW 64*1+28
	DCB 0x3D,0	;<-
	DCB 10,23,9,38

;---------------------

	DCW 64*2+0
	DCB 0x3B,0	;Tab
	DCB 26,38,10,39

	DCW 64*2+3
	DCB 0x26,0	;Q
	DCB 27,25,11,40

	DCW 64*2+5
	DCB 0x2C,0	;W
	DCB 28,26,12,41

	DCW 64*2+7
	DCB 0x1A,0	;E
	DCB 29,27,13,42

	DCW 64*2+9
	DCB 0x27,0	;R
	DCB 30,28,14,43

	DCW 64*2+11
	DCB 0x29,0	;T
	DCB 31,29,15,44

	DCW 64*2+13
	DCB 0x2E,0	;Y
	DCB 32,30,16,45

	DCW 64*2+15
	DCB 0x2A,0	;U
	DCB 33,31,17,46

	DCW 64*2+17
	DCB 0x1E,0	;I
	DCB 34,32,18,47

	DCW 64*2+19
	DCB 0x24,0	;O
	DCB 35,33,19,48

	DCW 64*2+21
	DCB 0x25,0	;P
	DCB 36,34,20,49

	DCW 64*2+23
	DCB 0x0D,0	;[
	DCB 37,35,21,50

	DCW 64*2+25
	DCB 0x0E,0	;]
	DCB 38,36,22,51

	DCW 64*2+27
	DCB 0x3F,0	;Return
	DCB 25,37,23,64

;---------------------

	DCW 64*3+0
	DCB 0x31,0	;Ctrl
	DCB 40,38,25,52

	DCW 64*3+4
	DCB 0x16,0	;A
	DCB 41,39,26,53

	DCW 64*3+6
	DCB 0x28,0	;S
	DCB 42,40,27,54

	DCW 64*3+8
	DCB 0x19,0	;D
	DCB 43,41,28,55

	DCW 64*3+10
	DCB 0x1B,0	;F
	DCB 44,42,29,56

	DCW 64*3+12
	DCB 0x1C,0	;G
	DCB 45,43,30,57

	DCW 64*3+14
	DCB 0x1D,0	;H
	DCB 46,44,31,58

	DCW 64*3+16
	DCB 0x1F,0	;J
	DCB 47,45,32,59

	DCW 64*3+18
	DCB 0x20,0	;K
	DCB 48,46,33,60

	DCW 64*3+20
	DCB 0x21,0	;L
	DCB 49,47,34,61

	DCW 64*3+22
	DCB 0x0F,0	;;
	DCB 50,48,35,62

	DCW 64*3+24
	DCB 0x10,0	;'
	DCB 51,49,36,63

	DCW 64*3+26
	DCB 0x11,0	;~
	DCB 38,50,37,64

;---------------------

	DCW 64*4+0
	DCB 0x30,0	;Shift
	DCB 53,64,39,65

	DCW 64*4+5
	DCB 0x2F,0	;Z
	DCB 54,52,40,66

	DCW 64*4+7
	DCB 0x2D,0	;X
	DCB 55,53,41,66

	DCW 64*4+9
	DCB 0x18,0	;C
	DCB 56,54,42,67

	DCW 64*4+11
	DCB 0x2B,0	;V
	DCB 57,55,43,67

	DCW 64*4+13
	DCB 0x17,0	;B
	DCB 58,56,44,67

	DCW 64*4+15
	DCB 0x23,0	;N
	DCB 59,57,45,67

	DCW 64*4+17
	DCB 0x22,0	;M
	DCB 60,58,46,67

	DCW 64*4+19
	DCB 0x12,0	;,
	DCB 61,59,47,67

	DCW 64*4+21
	DCB 0x13,0	;.
	DCB 62,60,48,67

	DCW 64*4+23
	DCB 0x15,0	;?
	DCB 63,61,49,67

	DCW 64*4+25
	DCB 0x14,0	;/
	DCB 64,62,50,68

	DCW 64*4+27
	DCB 0x30,0	;Shift
	DCB 52,63,51,68

;---------------------

	DCW 64*5+3
	DCB 0x33,0	;Caps
	DCB 66,68,52,1

	DCW 64*5+6
	DCB 0x32,0	;Graph
	DCB 67,65,54,2

	DCW 64*5+9
	DCB 0x40,0	;Space
	DCB 68,66,55,3

	DCW 64*5+25
	DCB 0x34,0	;Code
	DCB 65,67,63,8

;----------------------------------------------------------------------------
Keyboard_Control				;Virtual keyboard
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,lr}

	adr r0,Keyboard_M			;Clear Keyboard Matrix
	mov r1,#-1
	str r1,[r0]
	str r1,[r0,#4]
	str r1,[r0,#8]
	str r1,[r0,#12]

;	ldr r0,AGBjoypad
	ldr r0,=AGBinput
	ldr r0,[r0]
	ldr r1,VKB_OldKeys
	eor r1,r1,r0
	and r1,r1,r0
	str r0,VKB_OldKeys

	ldr r7,=0x6006D00			;keyboard tilemap
	ldr r2,VKB_Pos
	adr r5,VKB_Array
	add r3,r5,r2,lsl#3
	ldrh r4,[r3],#4
	mov r4,r4,lsl#1
	ldrb r6,[r7,r4]				;clear old keytile.
	strh r6,[r7,r4]


	tst r1,#0x10
	ldrneb r2,[r3]
	tst r1,#0x20
	ldrneb r2,[r3,#1]
	tst r1,#0x40
	ldrneb r2,[r3,#2]
	tst r1,#0x80
	ldrneb r2,[r3,#3]
	str r2,VKB_Pos

	add r3,r5,r2,lsl#3
	ldrh r4,[r3]
	mov r4,r4,lsl#1
	ldrh r6,[r7,r4]
	orr r6,r6,#0x4000
	strh r6,[r7,r4]
	
	mov r2,#-1
	str r2,g_CfgKey
	tst r0,#0x01				;A button
	beq nokeypress
	ldrb r4,[r3,#2]
	str r4,g_CfgKey
	adr r2,Keyb_trans
	mov r4,r4,lsl#1
	ldrh r4,[r2,r4]
	adr r2,Keyboard_M
	ldrb r1,[r2,r4,lsr#8]
	bic r1,r1,r4
	strb r1,[r2,r4,lsr#8]
nokeypress
	ldrb r0,Keyb_Row
	tst r0,#0x40				;Capslock light?
	mov r4,#0x288
	ldrb r6,[r7,r4]
	orreq r6,r6,#0x1000
	strh r6,[r7,r4]


	ands r0,r0,#0				;Z=1
	ldmfd sp!,{r4-r7,lr}
	bx lr

VKB_OldKeys	DCD 0
VKB_Pos		DCD 0
g_CfgKey	DCD 0
;----------------------------------------------------------------------------
refreshEMUjoypads	;call every frame
;exits with Z flag clear if update incomplete
;----------------------------------------------------------------------------
	mov r9,lr					;return with this..

	ldrb r0,keyb_scroll
	cmp r0,#96
	beq Keyboard_Control

		ldr r4,frame
		movs r0,r4,lsr#2		;C=frame&2 (autofire alternates every other frame)
	ldr r1,EMUjoypad
	mov r4,r1
	and r0,r1,#0xf0
		ldr r2,joycfg
		andcs r1,r1,r2
		movcss addy,r1,lsr#9	;R?
		andcs r1,r1,r2,lsr#16
	adr addy,rlud2ludr
	ldrb r3,[addy,r0,lsr#4]		;keyboard
	adr addy,rlud2udlr
	ldrb r0,[addy,r0,lsr#4]		;downupleftright, joystick

	ands r5,r1,#3
	cmpne r5,#3
	eorne r5,r5,#3

	tst r2,#0x400				;Swap A/B?
	andne r5,r1,#3
	orr r0,r0,r5,lsl#4			;Button 1 & 2

	adr addy,Keyb_trans
	tst r4,#0x08				;Start
	ldrb r7,g_keymap_Start
	mov r7,r7,lsl#1
	ldrh r7,[addy,r7]
	biceq r7,r7,#0xFF

	tst r4,#0x04				;Select
	ldrb r8,g_keymap_Select
	mov r8,r8,lsl#1
	ldrh r8,[addy,r8]
	biceq r8,r8,#0xFF

	tst r4,#0x100				;R
	ldrb r6,g_keymap_R
	mov r6,r6,lsl#1
	ldrh r6,[addy,r6]
	biceq r6,r6,#0xFF

	tst r4,#0x200				;L
	ldrb r5,g_keymap_L
	mov r5,r5,lsl#1
	ldrh r5,[addy,r5]
	biceq r5,r5,#0xFF

	tst r2,#0xC0000000			;Player2/Keyboard?
	bmi doCursor
	mov r3,#0
	streqb r0,joy0state
	strneb r0,joy1state
doCursor
	mov r3,r3,lsl#4

	adr r0,Keyboard_M			;Clear Keyboard Matrix
	mov r1,#-1
	str r1,[r0]
	str r1,[r0,#4]
	str r1,[r0,#8]
	str r1,[r0,#12]

	ldrb r1,[r0,r5,lsr#8]
	bic r1,r1,r5
	strb r1,[r0,r5,lsr#8]

	ldrb r1,[r0,r6,lsr#8]
	bic r1,r1,r6
	strb r1,[r0,r6,lsr#8]

	ldrb r1,[r0,r7,lsr#8]
	bic r1,r1,r7
	strb r1,[r0,r7,lsr#8]

	ldrb r1,[r0,r8,lsr#8]
	bic r1,r1,r8
	strb r1,[r0,r8,lsr#8]

	ldrb r1,[r0,#8]
	bic r1,r1,r3
	strb r1,[r0,#8]

fin	ands r0,r0,#0				;Z=1
	mov pc,r9

joycfg DCD 0x00ff01ff ;byte0=auto mask, byte1=(saves R), byte2=R auto mask
;bit 31=single/multi, 30=1P/2P, 27=(multi) link active, 24=reset signal received
joy0state	DCB 0
joy1state	DCB 0
joy0extra	DCB 0
joy1extra	DCB 0
rlud2udlr	DCB 0x00,0x08,0x04,0x0C, 0x01,0x09,0x05,0x0D	;GBA2EMU, joystick
			DCB 0x02,0x0A,0x06,0x0E, 0x03,0x0B,0x07,0x0F
rlud2ludr	DCB 0x00,0x08,0x01,0x09, 0x02,0x0A,0x03,0x0B	;GBA2EMU, keyboard
			DCB 0x04,0x0C,0x05,0x0D, 0x06,0x0E,0x07,0x0F
JoySelect	DCB 0
Keyb_Row	DCB 0
			DCB 0,0
Keyboard_M
			DCB 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
			DCB 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF

Keyb_trans	DCW 0x0001,0x0002,0x0004,0x0008,0x0010,0x0020,0x0040,0x0080
			DCW 0x0101,0x0102,0x0104,0x0108,0x0110,0x0120,0x0140,0x0180
			DCW 0x0201,0x0202,0x0204,0x0208,0x0210,0x0220,0x0240,0x0280
			DCW 0x0301,0x0302,0x0304,0x0308,0x0310,0x0320,0x0340,0x0380
			DCW 0x0401,0x0402,0x0404,0x0408,0x0410,0x0420,0x0440,0x0480
			DCW 0x0501,0x0502,0x0504,0x0508,0x0510,0x0520,0x0540,0x0580
			DCW 0x0601,0x0602,0x0604,0x0608,0x0610,0x0620,0x0640,0x0680
			DCW 0x0701,0x0702,0x0704,0x0708,0x0710,0x0720,0x0740,0x0780
			DCW 0x0801,0x0802,0x0804,0x0808,0x0810,0x0820,0x0840,0x0880
;			DCW 0x0901,0x0902,0x0904,0x0908,0x0910,0x0920,0x0940,0x0980
g_keymap_L		DCB 0
g_keymap_R		DCB 0
g_keymap_Start	DCB 0
g_keymap_Select	DCB 0


;----------------------------------------------------------------------------
Joystick_W
;----------------------------------------------------------------------------
	strb r0,JoySelect
	mov pc,lr
;----------------------------------------------------------------------------
Joystick_R
;----------------------------------------------------------------------------
	ldrb r0,JoySelect
	tst r0,#0x40
	ldreqb r0,joy0state
	ldrneb r0,joy1state
	and r0,r0,#0x3F
	eor r0,r0,#0xFF
	mov pc,lr

;----------------------------------------------------------------------------
Cent_W;			0x90, ULA5RA087 Centronic STROBE output (bit 0=0)
;----------------------------------------------------------------------------
	mov pc,lr				;Dummy, Bios writes here.
;----------------------------------------------------------------------------
Keyb_Row_R;		0xAA, Keyb, Casette, LEDs and more
;----------------------------------------------------------------------------
	ldrb r0,Keyb_Row
	mov pc,lr
;----------------------------------------------------------------------------
Keyb_Row_W;		0xAA, Keyb, Casette, LEDs and more
;----------------------------------------------------------------------------
	strb r0,Keyb_Row
	mov pc,lr
;----------------------------------------------------------------------------
PPI_Ctrl_W;		0xAB, control port 0xAA
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA breakpoint
	tst r0,#0x80			;must be 0.
	movne pc,lr
	movs r0,r0,lsr#1		;set/reset?
	and r0,r0,#0x07
	mov r2,#1
	ldrb r1,Keyb_Row
	orrcs r1,r1,r2,lsl r0
	biccc r1,r1,r2,lsl r0
	strb r1,Keyb_Row
	mov pc,lr
;----------------------------------------------------------------------------
Keyboard_R
;----------------------------------------------------------------------------
	ldrb r0,Keyb_Row
	and r0,r0,#0xF
	adr r1,Keyboard_M
	ldrb r0,[r1,r0]
	mov pc,lr
;------------------------------------------------------------------------------
PSLOT_R;		0xA8
;------------------------------------------------------------------------------
	ldrb r0,BankMap0
	mov pc,lr




;----------------------------------------------------------------------------
Z80_IN_C
;----------------------------------------------------------------------------
	mov addy,z80bc,lsr#16
;----------------------------------------------------------------------------
Z80_IN
;----------------------------------------------------------------------------
	and r1,addy,#0xFF
	ldr pc,[pc,r1,lsl#2]
	DCD 0
IN_Table
	DCD empty_IO_R			;0x00
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x10
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x20
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x30
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x40
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x50
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x60
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x70
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x80
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0x90
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD VDPdata_R			;0x98
	DCD VDPstat_R			;0x99
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xA0
	DCD empty_IO_R
	DCD AY38910_Data_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD PSLOT_R				;0xA8
	DCD Keyboard_R			;0xA9
	DCD Keyb_Row_R			;0xAA
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xB0
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xC0
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xD0
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xE0
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

	DCD empty_IO_R			;0xF0
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R
	DCD empty_IO_R

;----------------------------------------------------------------------------
Z80_OUT_C
;----------------------------------------------------------------------------
	mov addy,z80bc,lsr#16
;----------------------------------------------------------------------------
Z80_OUT
;----------------------------------------------------------------------------
	and r1,addy,#0xFF
	ldr pc,[pc,r1,lsl#2]
	DCD 0
OUT_Table
	DCD empty_IO_W			;0x00
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x10
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x20
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x30
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x40
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x50
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x60
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x70
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0x80
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD Cent_W				;0x90
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD VDPdata_W			;0x98
	DCD VDPctrl_W			;0x99
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD AY38910_Index_W		;0xA0
	DCD AY38910_Data_W		;0xA1
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD PSLOT_W				;0xA8, Primary Slot mapper
	DCD empty_IO_W
	DCD Keyb_Row_W			;0xAA
	DCD PPI_Ctrl_W			;0xAB
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0xB0
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0xC0
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0xD0
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0xE0
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W

	DCD empty_IO_W			;0xF0
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W
	DCD empty_IO_W



;----------------------------------------------------------------------------
	INCLUDE visoly.s
 AREA wram_code1, CODE, READWRITE
;-- - - - - - - - - - - - - - - - - - - - - -

thumbcall_r1 bx r1

;------------------------------------------------------------------------------
PSLOT_W;		0xA8
;------------------------------------------------------------------------------
;	mov r11,r11
	stmfd sp!,{r3,lr}
	ldrb r3,BankMap0
	strb r0,BankMap0
	eors r3,r3,r0				;Which Banks are changed?
;	beq noBanking
	tst r3,#0x03
	blne BankSwitch0_W
	tst r3,#0x0C
	blne BankSwitch1_W
	tst r3,#0x30
	blne BankSwitch2_W
	tst r3,#0xC0
	blne BankSwitch3_W
noBanking
	ldmfd sp!,{r3,lr}
	bx lr

;------------------------------------------------------------------------------
BankSwitch0_W					;0x0000-0x3FFF
;------------------------------------------------------------------------------
	ldrb r1,BankMap0
	adr r2,memmap_tbl
	ands r1,r1,#0x03
	ldreq r0,biosbase
	beq Map16k

	ldr r0,rombase
	stmfd sp!,{lr}
	bl Map8k
	ldmfd sp!,{lr}
	ldr r0,rombase2k
	mov r1,r0
	b Map8k_2

;------------------------------------------------------------------------------
BankSwitch1_W					;0x4000-0x7FFF
;------------------------------------------------------------------------------
;	mov r11,r11
	ldrb r1,BankMap0
	adr r2,memmap_tbl+4*16
	ands r1,r1,#0x0C
	ldr r0,biosbase
	beq Map16k
	cmp r1,#0x0C
	beq Map16k

	ldr r0,rombase4k
	stmfd sp!,{lr}
	bl Map8k
	ldmfd sp!,{lr}
	ldr r0,rombase6k
	mov r1,r0
	b Map8k_2

;------------------------------------------------------------------------------
BankSwitch2_W					;0x8000-0xBFFF
;------------------------------------------------------------------------------
	ldrb r1,BankMap0
	ands r1,r1,#0x30

	ldr r2,=WRMEMTBL_			;RAM writeprotection
	ldr r0,[r2,r1,lsr#2]
	adr r2,writemem_tbl
	str r0,[r2,#4*4]
	str r0,[r2,#4*5]

	adr r2,memmap_tbl+4*32

	ldreq r0,biosbase			;Undefined actually.
	beq Map16k
	cmp r1,#0x30
	ldreq r0,rambase8k
	beq Map16k

	ldr r0,rombase8k
	stmfd sp!,{lr}
	bl Map8k
	ldmfd sp!,{lr}
	ldr r0,rombaseAk
	mov r1,r0
	b Map8k_2

;------------------------------------------------------------------------------
BankSwitch3_W					;0xC000-0xFFFF
;------------------------------------------------------------------------------
	ldrb r1,BankMap0
	ands r1,r1,#0xC0

;	ldr r2,=WRMEMTBL_			;RAM writeprotection
;	ldr r0,[r2,r1,lsr#4]
;	adr r2,writemem_tbl
;	str r0,[r2,#4*6]
;	str r0,[r2,#4*7]

	adr r2,memmap_tbl+4*48
	ldr r0,rambaseCk
	b Map16k

	ldr r0,biosbase				;Undefined actually
	cmp r1,#0xC0
	ldreq r0,rambaseCk
	cmp r1,#0x40
	bne Map16k

	ldr r0,rombaseCk
	stmfd sp!,{lr}
	bl Map8k
	ldmfd sp!,{lr}
	ldr r0,rombaseEk
	mov r1,r0
	b Map8k_2

Map16k
	mov r1,r0
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
Map8k_2
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl

;------------------------------------------
flush		;update cpu_pc & lastbank
;------------------------------------------
	ldr r1,lastbank
	sub z80pc,z80pc,r1
	encodePC
	bx lr
;----------------------------------------------------------------------------
Map8k
	mov r1,r0
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	stmia r2!,{r0-r1}			;memmap_tbl
	bx lr
;----------------------------------------------------------------------------
	END
