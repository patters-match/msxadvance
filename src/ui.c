#include <stdio.h>
#include <string.h>

#include "gba.h"

//header files?  who needs 'em :P

void cls(int);		//from main.c
void initpalette(void);
void rommenu(void);
void drawtext(int,char*,int);
void setdarknessgs(int dark);
void setbrightnessall(int light);
extern char *textstart;

int SendMBImageToClient(void);	//mbclient.c

//----asm calls------
void resetSIO(u32);			//io.s
void doReset(void);			//io.s
void suspend(void);			//io.s
void waitframe(void);		//io.s
int gettime(void);			//io.s
void spriteinit(char);		//io.s
void Keyboard_Control(void);//io.s
void debug_(int val,int line);	//gfx.s
void paletteinit(void);		//gfx.s
void ScalemodeInit(void);	//gfx.s
//void PaletteTxAll(void);	//gfx.s
void endframe(void);		//gfx.s
//void scanlinebp_reset(void);//gfx.s
void savestate(void);		//cart.s
void loadstate(void);		//cart.s
void ntsc_pal_reset(void);	//z80.s
//-------------------

extern u32 joycfg;			//from io.s
extern char g_keymap_L;		//from io.s
extern char g_keymap_R;		//from io.s
extern char g_keymap_Start;	//from io.s
extern char g_keymap_Select;//from io.s
extern u32 g_CfgKey;		//from io.s
extern char g_emuflags;		//from cart.s
extern char g_mapper;		//from cart.s
extern char g_scaling;		//from cart.s
extern char g_config;		//from cart.s
extern char *romstart;		//from cart.s
extern char novblankwait;	//from z80.s
extern char sprcollision;	//from z80.s
extern u32 sleeptime;		//from z80.s
extern u32 FPSValue;		//from gfx.s
extern u32 oambufferready;	//from gfx.s
extern char fpsenabled;		//from gfx.s
extern char gammavalue;		//from gfx.s
extern char bcolor;			//from gfx.s border color
extern char g_twitch;		//from gfx.s
extern char g_flicker;		//from gfx.s
extern char g_keybon;		//from gfx.s
extern char g_keybscroll;	//from gfx.s
extern char toprows;		//from gfx.s
extern char SPRS;			//from gfx.s
extern u32 AGBinput;		//from gfx.s

extern char rtc;
extern char pogoshell;
extern char gameboyplayer;
extern char gbaversion;

u8 autoA,autoB;				//0=off, 1=on, 2=R
u8 stime=0;
u8 ewram=0;
u8 autostate=0;

void autoAset(void);
void autoBset(void);
void swapAB(void);
void controller(void);
void vblset(void);
void restart(void);
void exit(void);
void multiboot(void);
void scrolll(int f);
void scrollr(void);
void drawui1(void);
void drawui2(void);
void drawui3(void);
void drawui4(void);
void drawui5(void);
void subui(int menunr);
void ui2(void);
void ui3(void);
void ui4(void);
void textui(void);
void drawclock(void);
void sleep(void);
void sleepset(void);
void fpsset(void);
void brightset(void);
void fadetowhite(void);
void ewramset(void);
void display(void);
void flickset(void);
void soundset(void);
void countryset(void);
void biosset(void);
void rstartset(void);
void selectset(void);
void machineset(void);
void spriteset(void);
void collisionset(void);
void mapperset(void);
void keymapset_L(void);
void keymapset_R(void);
void keymapset_Start(void);
void keymapset_Select(void);
void keymapping(void);

void writeconfig(void);	//sram.c

#define MENU2ITEMS 7			//othermenu items
#define MENU3ITEMS 4			//displaymenu items
#define MENU4ITEMS 8			//controllermenu items
#define CARTMENUITEMS 8			//mainmenuitems when running from cart (not multiboot)
#define MULTIBOOTMENUITEMS 7	//"" when running from multiboot
//const fptr fnlist1[]={autoBset,autoAset,controller,ui3,ui2,textui,multiboot,savestate,loadstate,sleep,restart,exit};
const fptr fnlist1[]={ui4,ui3,ui2,textui,multiboot,sleep,restart,exit};
const fptr fnlist2[]={vblset,fpsset,sleepset,ewramset,collisionset,countryset,mapperset,rstartset,selectset,machineset};
const fptr fnlist3[]={display,flickset,brightset,spriteset};
const fptr fnlist4[]={autoBset,autoAset,controller,swapAB,keymapset_L,keymapset_R,keymapset_Start,keymapset_Select};

int selected;//selected menuitem.  used by all menus.
int mainmenuitems;//? or CARTMENUITEMS, depending on whether saving is allowed
int tm0cnt;			//Used when doing restart

u32 oldkey;//init this before using getmenuinput
u32 getmenuinput(int menuitems) {
	u32 keyhit;
	u32 tmp;
	int sel=selected;

	waitframe();		//(polling REG_P1 too fast seems to cause problems)
	tmp=~REG_P1;
	keyhit=(oldkey^tmp)&tmp;
	oldkey=tmp;
	if(keyhit&UP)
		sel=(sel+menuitems-1)%menuitems;
	if(keyhit&DOWN)
		sel=(sel+1)%menuitems;
	if(keyhit&RIGHT) {
		sel+=10;
		if(sel>menuitems-1) sel=menuitems-1;
	}
	if(keyhit&LEFT) {
		sel-=10;
		if(sel<0) sel=0;
	}
	if((oldkey&(L_BTN+R_BTN))!=L_BTN+R_BTN)
		keyhit&=~(L_BTN+R_BTN);
	selected=sel;
	return keyhit;
}

void ui() {
	int key,oldsel,i;
	ewram=((REG_WRWAITCTL & 0x0F000000) == 0x0E000000)?1:0;

	autoA=joycfg&A_BTN?0:1;
	autoA|=joycfg&(A_BTN<<16)?0:2;
	autoB=joycfg&B_BTN?0:1;
	autoB|=joycfg&(B_BTN<<16)?0:2;

	mainmenuitems=((u32)textstart>0x8000000?CARTMENUITEMS:MULTIBOOTMENUITEMS);//running from rom or multiboot?
	FPSValue=0;					//Stop FPS meter

//	soundvol=REG_SGCNT0_L;
//	REG_SGCNT0_L=0;				//stop sound (GB)
	tm0cnt=REG_TM0CNT;
	REG_TM0CNT=0;				//stop sound (directsound)

	selected=0;
	waitframe();
	REG_BG3HOFS=0x100;
	drawui1();
	initpalette();
	for(i=0;i<8;i++)
	{
		waitframe();
		setdarknessgs(i);		//Darken game screen
		REG_BG3HOFS=224-i*32;	//Move screen right
		REG_BG3VOFS=0;			//Clear V scroll
	}

	oldkey=~REG_P1;			//reset key input
	do {
		drawclock();
		key=getmenuinput(mainmenuitems);
		if(key&(A_BTN)) {
			oldsel=selected;
			fnlist1[selected]();
			selected=oldsel;
		}
		if(key&(A_BTN+UP+DOWN+LEFT+RIGHT))
			drawui1();
	} while(!(key&(B_BTN+R_BTN+L_BTN)));
	writeconfig();			//save any changes
	for(i=1;i<9;i++)
	{
		waitframe();
		setdarknessgs(8-i);	//Lighten screen
		REG_BG3HOFS=i*32;	//Move screen left
	}
	cls(3);
//	PaletteTxAll();			//restore EMU palette
	oambufferready=1;
	while(key&(B_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key=~REG_P1;
	}
//	REG_SGCNT0_L=soundvol;	//resume sound (GB)
	REG_TM0CNT=tm0cnt;		//resume sound (directsound)
}

void textui(void) {
	int key;

	drawui5();
	scrolll(0);
	oldkey=~REG_P1;			//reset key input
	do {
		key=getmenuinput(1);
	} while(!(key&(B_BTN+R_BTN+L_BTN)));
	scrollr();
	while(key&(B_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key=~REG_P1;
	}
}

void subui(int menunr) {
	int key,oldsel;

	selected=0;
	if(menunr==2)drawui2();
	if(menunr==3)drawui3();
	if(menunr==4)drawui4();
	scrolll(0);
	oldkey=~REG_P1;			//reset key input
	do {
		if(menunr==2)key=getmenuinput(MENU2ITEMS);
		if(menunr==3)key=getmenuinput(MENU3ITEMS);
		if(menunr==4)key=getmenuinput(MENU4ITEMS);
		if(key&(A_BTN)) {
			oldsel=selected;
			if(menunr==2)fnlist2[selected]();
			if(menunr==3)fnlist3[selected]();
			if(menunr==4)fnlist4[selected]();
			selected=oldsel;
		}
		if(key&(A_BTN+UP+DOWN+LEFT+RIGHT)) {
			if(menunr==2)drawui2();
			if(menunr==3)drawui3();
			if(menunr==4)drawui4();
		}
	} while(!(key&(B_BTN+R_BTN+L_BTN)));
	scrollr();
	while(key&(B_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key=~REG_P1;
	}
}

void ui2() {
	subui(2);
}
void ui3() {
	subui(3);
}
void ui4() {
	subui(4);
}

void text(int row,char *str) {
	drawtext(row+10-mainmenuitems/2,str,selected==row);
}
void text2(int row,char *str) {
	drawtext(35+row+2,str,selected==row);
}


//trying to avoid using sprintf...  (takes up almost 3k!)
void strmerge(char *dst,char *src1,char *src2) {
	if(dst!=src1)
		strcpy(dst,src1);
	strcat(dst,src2);
}

char *const autotxt[]={"OFF","ON","with R"};
char *const vsynctxt[]={"ON","Force","OFF","SLOWMO"};
char *const sleeptxt[]={"5min","10min","30min","OFF"};
char *const brightxt[]={"I","II","III","IIII","IIIII"};
char *const memtxt[]={"Normal","Turbo"};
char *const hostname[]={"Crap","Prot","GBA","GBP","NDS"};
char *const ctrltxt[]={"1P","2P","Cursor"};
char *const disptxt[]={"UNSCALED","UNSCALED (Auto)","SCALED","SCALED (w/sprites)"};
char *const scaletxt[]={"Hard","Normal","Soft"};
char *const mapertxt[]={"Konami4","Konami5","ASCII8k","ASCII16k","RTYPE","64kMirror"};
char *const cntrtxt[]={"NTSC","PAL"};
const char keybtxt[]="   0   1   2   3   4   5   6   7\
   8   9   -   =   \\   [   ]   ;\
   `   '   ,   .   /   ?   A   B\
   C   D   E   F   G   H   I   J\
   K   L   M   N   O   P   Q   R\
   S   T   U   V   W   X   Y   Z\
ShftCtrlGrph CapCode  F1  F2  F3\
  F4  F5 Esc TabStop  BS Sel Ret\
SpceHome Ins DelLeft  UpDownRght";
//char *const keybtxt[24]={"0","1","2","3","4","5","6","7",
//						"8","9","-","=","\\","[","]",";",
//						"1","1","1","1","1","1","1","1"};
char *const soundtxt[]={"OFF","ON","ON(Mixer)"};
char *const emuname[]={"      MSXAdvance ","         PogoMSX "};
void drawui1() {
	int i=0;
	char str[30];

	cls(1);
	drawtext(18,"     FluBBa Power 2022!",0);
	if(pogoshell) i=1;
	strmerge(str,emuname[i],"V0.2 on ");
	strmerge(str,str,hostname[gbaversion]);
	drawtext(19,str,0);

	text(0,"Controller->");
	text(1,"Display->");
	text(2,"Other Settings->");
	text(3,"Help->");
	text(4,"Link Transfer");
//	text(5,"SaveState");
//	text(6,"LoadState");
	text(5,"Sleep");
	text(6,"Restart");
	if(mainmenuitems!=MULTIBOOTMENUITEMS) {
		text(7,"Exit");
	}
}

void drawui2() {
	char str[30];

	cls(2);
	drawtext(32,"       Other Settings",0);
	strmerge(str,"VSync: ",vsynctxt[novblankwait]);
	text2(0,str);
	strmerge(str,"FPS-Meter: ",autotxt[fpsenabled]);
	text2(1,str);
	strmerge(str,"Autosleep: ",sleeptxt[stime]);
	text2(2,str);
	strmerge(str,"EWRAM speed: ",memtxt[ewram]);
	text2(3,str);
	strmerge(str,"Fake Spritecollision: ",autotxt[(sprcollision>>5)&1]);
	text2(4,str);
	strmerge(str,"TV Type: ",cntrtxt[g_emuflags&1]);
	text2(5,str);
	strmerge(str,"Mapper Type: ",mapertxt[g_mapper&7]);
	text2(6,str);
//	strmerge(str,"Use Select as Reset: ",autotxt[(g_config>>5)&1]);
//	text2(7,str);
//	strmerge(str,"Use BIOS: ",autotxt[(g_config>>7)&1]);
//	text2(8,str);
}

void drawui3() {
	char str[30];

	cls(2);
	drawtext(32,"      Display Settings",0);
	strmerge(str,"Display: ",disptxt[g_scaling&3]);
	text2(0,str);
	strmerge(str,"Scaling: ",scaletxt[g_flicker&3]);
	text2(1,str);
	strmerge(str,"Gamma: ",brightxt[gammavalue]);
	text2(2,str);
	strmerge(str,"Perfect Sprites: ",autotxt[SPRS]);
	text2(3,str);
}

void drawui4() {
	char str[30];
	char fix[7]="\0\0\0\0\0";

	cls(2);
	drawtext(32,"    Controller Settings",0);
	strmerge(str,"B autofire: ",autotxt[autoB]);
	text2(0,str);
	strmerge(str,"A autofire: ",autotxt[autoA]);
	text2(1,str);
	strmerge(str,"Controller: ",ctrltxt[joycfg>>30]);
	text2(2,str);
	strmerge(str,"Swap A-B:   ",autotxt[(joycfg>>10)&1]);
	text2(3,str);
	strncpy(fix,&keybtxt[g_keymap_L*4],4);
	strmerge(str,"Map L to.....: ",fix);
	text2(4,str);
	strncpy(fix,&keybtxt[g_keymap_R*4],4);
	strmerge(str,"Map R to.....: ",fix);
	text2(5,str);
	strncpy(fix,&keybtxt[g_keymap_Start*4],4);
	strmerge(str,"Map Start to.: ",fix);
	text2(6,str);
	strncpy(fix,&keybtxt[g_keymap_Select*4],4);
	strmerge(str,"Map Select to: ",fix);
	text2(7,str);
}

void drawui5() {
	cls(2);
	drawtext(32,"     Help instructions",0);
	drawtext(34,"DPad:   Move character",0);
	drawtext(35,"B:      Left Button",0);
	drawtext(36,"A:      Right Button",0);
	drawtext(37,"Start:  Button 1",0);
	drawtext(38,"L:      Button *",0);
	drawtext(39,"R:      Button #",0);
	drawtext(48," MSX Emulator",0);
	drawtext(49," Mighty ruler",0);
}

void drawclock() {

    char str[30];
    char *s=str+20;
    int timer,mod;

    if(rtc)
    {
	strcpy(str,"                    00:00:00");
	timer=gettime();
	mod=(timer>>4)&3;				//Hours.
	*(s++)=(mod+'0');
	mod=(timer&15);
	*(s++)=(mod+'0');
	s++;
	mod=(timer>>12)&15;				//Minutes.
	*(s++)=(mod+'0');
	mod=(timer>>8)&15;
	*(s++)=(mod+'0');
	s++;
	mod=(timer>>20)&15;				//Seconds.
	*(s++)=(mod+'0');
	mod=(timer>>16)&15;
	*(s++)=(mod+'0');

	drawtext(0,str,0);
    }
}

void autoAset() {
	autoA++;
	joycfg|=A_BTN+(A_BTN<<16);
	if(autoA==1)
		joycfg&=~A_BTN;
	else if(autoA==2)
		joycfg&=~(A_BTN<<16);
	else
		autoA=0;
}

void autoBset() {
	autoB++;
	joycfg|=B_BTN+(B_BTN<<16);
	if(autoB==1)
		joycfg&=~B_BTN;
	else if(autoB==2)
		joycfg&=~(B_BTN<<16);
	else
		autoB=0;
}

void controller() {					//see io.s: refreshEMUjoypads
	u32 i=joycfg+0x40000000;
	if(i>=0xC0000000)
		i&=~0xc0000000;
	resetSIO(i);					//reset link state
}

void sleepset() {
	stime++;
	if(stime==1)
		sleeptime=60*60*10;			// 10min
	else if(stime==2)
		sleeptime=60*60*30;			// 30min
	else if(stime==3)
		sleeptime=0x7F000000;		// 360days...
	else if(stime>=4){
		sleeptime=60*60*5;			// 5min
		stime=0;
	}
}

void vblset() {
	novblankwait++;
	novblankwait &=3;
}

void fpsset() {
	fpsenabled = (fpsenabled^1)&1;
}

void brightset() {
	gammavalue++;
	if (gammavalue>4) gammavalue=0;
	paletteinit();
//	PaletteTxAll();					//make new palette visible
	endframe();
	initpalette();
}

void multiboot() {
	int i;
	cls(1);
	drawtext(9,"          Sending...",0);
	i=SendMBImageToClient();
	if(i) {
		if(i<3)
			drawtext(9,"         Link error.",0);
		else
			drawtext(9,"  Game is too big to send.",0);
		if(i==2) drawtext(10,"       (Check cable?)",0);
		for(i=0;i<90;i++)			//wait a while
			waitframe();
	}
}

void restart() {
	writeconfig();					//save any changes
	scrolll(1);
	REG_TM0CNT=tm0cnt;				//resume sound (directsound)
	__asm {mov r0,#0x3007f00}		//stack reset
	__asm {mov sp,r0}
	rommenu();
}
void exit() {
	writeconfig();					//save any changes
	fadetowhite();
	REG_DISPCNT=FORCE_BLANK;		//screen OFF
	REG_BG0HOFS=0;
	REG_BG0VOFS=0;
	REG_BLDCNT=0;					//no blending
	(*(u8**)0x0203FBFC)=0;			//Pogo reset.
	doReset();
}

void sleep() {
	fadetowhite();
	suspend();
	setdarknessgs(7);				//restore screen
	while((~REG_P1)&0x3ff) {
		waitframe();				//(polling REG_P1 too fast seems to cause problems)
	}
}
void fadetowhite() {
	int i;
	for(i=7;i>=0;i--) {
		setdarknessgs(i);			//go from dark to normal
		waitframe();
	}
	for(i=0;i<17;i++) {				//fade to white
		setbrightnessall(i);		//go from normal to white
		waitframe();
	}
}

void scrolll(int f) {
	int i;
	for(i=0;i<9;i++)
	{
		if(f) setdarknessgs(8+i);	//Darken screen
		REG_BG3HOFS=i*32;			//Move screen left
		waitframe();
	}
}
void scrollr() {
	int i;
	for(i=8;i>=0;i--)
	{
		waitframe();
		REG_BG3HOFS=i*32;			//Move screen right
	}
	cls(2);							//Clear BG3
}

void ewramset() {
	ewram^=1;
	if(ewram==1){
		REG_WRWAITCTL = (REG_WRWAITCTL & ~0x0F000000) | 0x0E000000;		//1 waitstate, overclocked
	}else{
		REG_WRWAITCTL = (REG_WRWAITCTL & ~0x0F000000) | 0x0D000000;		//2 waitstates, normal
	}
}

void swapAB() {
	joycfg^=0x400;
}

void display() {
	g_scaling=(g_scaling+1)&3;
	spriteinit(g_scaling);
	endframe();
	initpalette();
	ScalemodeInit();
}

void flickset() {
	int i;
	i = g_flicker&4;
	g_flicker=(g_flicker+1)&3;
	if(g_flicker > 2){
		g_flicker=0;
		g_twitch=0;
	}
	g_flicker|=i;
	ScalemodeInit();
}

void countryset() {
	g_emuflags = g_emuflags^1;
	ntsc_pal_reset();
}

void mapperset() {
	if(++g_mapper > 4){
		g_mapper=0;
	}
}

void machineset() {
	g_emuflags^=4;
}

void biosset() {
	g_config^=0x80;
}

void rstartset() {
	g_config^=0x40;
}

void selectset() {
	g_config^=0x20;
}

void spriteset() {
	SPRS^=1;
}

void collisionset() {
	sprcollision^=0x20;
}

void keymapset_L() {
	keymapping();
	g_keymap_L=g_CfgKey;
}
void keymapset_R() {
	keymapping();
	g_keymap_R=g_CfgKey;
}
void keymapset_Start() {
	keymapping();
	g_keymap_Start=g_CfgKey;
}
void keymapset_Select() {
	keymapping();
	g_keymap_Select=g_CfgKey;
}

void keymapping() {
	int key;
	key = ~REG_P1;
	g_keybon = 2;
	g_keybscroll = 96;
	cls(2);

	while(key&A_BTN) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key = ~REG_P1;
	}
	while(!(key&A_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key = ~REG_P1;
		AGBinput = key;
		Keyboard_Control();
	}
	g_keybon = 0;
	g_keybscroll = 0;
}

void soundset() {
}
