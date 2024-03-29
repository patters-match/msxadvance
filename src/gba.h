#ifndef GBA_HEADER
#define GBA_HEADER

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long u32;

typedef volatile unsigned char vu8;
typedef volatile unsigned short vu16;
typedef volatile unsigned long vu32;

typedef void (*fptr)(void);

#define COUNTRY 2					//Japan
#define GGMODE 4
#define EMUID 0x1A4C4F43			// "COL",0x1A
//#define EMUID 0x1A534D53			// "SMS",0x1A

typedef struct {
	u32 identifier;
	u32 filesize;
	u32 flags;
	u32 spritefollow;
	u32 reserved[4];
	char name[32];
} romheader;	

#define MEM_PALETTE (u16*)0x5000000
#define MEM_VRAM (u16*)0x6000000
#define MEM_OAM (u32*)0x7000000
#define MEM_SRAM (u8*)0xE000000
#define PAL_BUFF (u8*)0x2040000-0xC220	//from equates.h
#define INTR_VECT *(u32*)0x3007FFC
#define SCREENBASE (u16*)0x6003000

#define REG_DISPCNT *(vu32*)0x4000000
#define MODE0 0
#define MODE1 1
#define MODE2 2
#define MODE3 3
#define MODE4 4
#define MODE5 5
#define OBJ_H_STOP 0x20
#define OBJ_1D 0x40
#define FORCE_BLANK 0x80
#define BG0_EN 0x100
#define BG1_EN 0x200
#define BG2_EN 0x400
#define BG3_EN 0x800
#define OBJ_EN 0x1000
#define WINDOW0_EN 0x2000
#define WINDOW1_EN 0x4000
#define OBJ_WINDOW_EN 0x8000

#define REG_DISPSTAT *(vu16*)0x4000004
#define SCANLINE *(vu8*)0x4000005
#define VBLANK 1
#define HBLANK 2
#define VCOUNT_HIT 4
#define V_IRQ 8
#define H_IRQ 16
#define VCOUNT_IRQ 32

#define REG_BG0HOFS *(u16*)0x4000010
#define REG_BG0VOFS *(u16*)0x4000012
#define REG_BG1HOFS *(u16*)0x4000014
#define REG_BG1VOFS *(u16*)0x4000016
#define REG_BG2HOFS *(u16*)0x4000018
#define REG_BG2VOFS *(u16*)0x400001a
#define REG_BG3HOFS *(u16*)0x400001c
#define REG_BG3VOFS *(u16*)0x400001e
#define REG_BG0CNT *(u16*)0x4000008
#define REG_BG1CNT *(u16*)0x400000a
#define REG_BG2CNT *(u16*)0x400000c
#define REG_BG3CNT *(u16*)0x400000e
#define COLOR16 0x0000
#define COLOR256 0x0080
#define SIZE256x256 0x0000
#define SIZE512x256 0x4000
#define SIZE256x512 0x8000
#define SIZE512x512 0xC000

#define REG_VCOUNT *(volatile u16*)0x4000006

#define REG_IE *(vu16*)0x4000200
#define REG_IF *(vu16*)0x4000202
#define REG_IME *(vu16*)0x4000208

#define REG_P1 *(vu16*)0x4000130
#define A_BTN 1
#define B_BTN 2
#define SELECT 4
#define START 8
#define RIGHT 16
#define LEFT 32
#define UP 64
#define DOWN 128
#define R_BTN 256
#define L_BTN 512

#define REG_DM0CNT_H *(u16*)0x40000ba
#define REG_DM1CNT_H *(u16*)0x40000c6
#define REG_DM2CNT_H *(u16*)0x40000d2
#define REG_DM3CNT_H *(u16*)0x40000de
#define REG_BLDCNT *(u16*)0x4000050
#define REG_BLDALPHA *(u16*)0x4000052
#define REG_BLDY *(u16*)0x4000054
#define REG_SGCNT0_L *(u16*)0x4000080
#define REG_SGBIAS *(u16*)0x4000088
#define REG_BG2X *(u32*)0x4000028
#define REG_BG2Y *(u32*)0x400002c
#define REG_BG2PA *(u16*)0x4000020
#define REG_BG2PB *(u16*)0x4000022
#define REG_BG2PC *(u16*)0x4000024
#define REG_BG2PD *(u16*)0x4000026

#define REG_SIODATA32 *(vu32*)0x4000120
#define REG_SIOMULTI0 *(vu16*)0x4000120
#define REG_SIOMULTI1 *(vu16*)0x4000122
#define REG_SIOMULTI2 *(vu16*)0x4000124
#define REG_SIOMULTI3 *(vu16*)0x4000126
#define REG_SIOCNT *(vu16*)0x4000128
#define REG_SIOMLT_SEND *(vu16*)0x400012a
#define REG_RCNT *(vu16*)0x4000134
#define REG_TM0CNT *(vu16*)0x4000102
#define REG_WRWAITCTL *(vu32*)0x04000800

#endif

