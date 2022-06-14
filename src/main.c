#include <stdio.h>
#include <string.h>
#include "gba.h"

extern u32 g_emuflags;			//from cart.s
extern u8 *g_BIOSBASE;			//from cart.s
extern u32 joycfg;				//from io.s
extern u32 font;				//from boot.s
extern u32 fontpal;				//from boot.s
extern u32 msx_keyb;			//from boot.s
extern u32 msx_keyb_map;		//from boot.s
extern char g_flicker;			//from gfx.s
extern u32 *vblankfptr;			//from gfx.s
extern u32 vbldummy;			//from gfx.s
extern u32 vblankinterrupt;		//from gfx.s
extern u32 oambufferready;		//from gfx.s
extern u32 AGBinput;			//from gfx.s
extern u32 EMUinput;
       u32 oldinput;

//extern romheader mb_header;

//asm calls
void loadcart(int,int);			//from cart.s
void run(int);
void GFX_init(void);			//gfx.s
//void PaletteTxAll(void);		//gfx.s
void ScalemodeInit(void);		//gfx.s
void Sound_init(void);			//sound.s
void resetSIO(u32);				//io.s
void vbaprint(char *text);		//io.s
void UnCompVram(u32 *source,u32 *destination);		//io.s
void waitframe(void);			//io.s
int CheckGBAVersion(void);		//io.s

void cls(int);
void initpalette(void);
void rommenu(void);
int drawmenu(int);
int getinput(void);
void splash(void);
void drawtext(int,char*,int);
void setdarknessgs(int dark);
void setbrightnessall(int light);
void readconfig(void);			//sram.c

const unsigned __fp_status_arm=0x40070000;
u8 *textstart;//points to first rom (initialized by boot.s)
int roms;//total number of roms

char pogoshell_romname[32];	//keep track of rom name (for state saving, etc)
char rtc=0;
char pogoshell=0;
char gameboyplayer=0;
char gbaversion;
int pogosize=0;			//size of rom if starting from pogoshell

void C_entry() {
	int i;
	vu16 *timeregs=(u16*)0x080000c8;
	u32 temp=(u32)(*(u8**)0x0203FBFC);
	pogoshell=((temp & 0xFE000000) == 0x08000000)?1:0;
	*timeregs=1;
	if(*timeregs & 1) rtc=1;
	gbaversion=CheckGBAVersion();
	vblankfptr=&vbldummy;
	GFX_init();

	if(pogoshell){
		u32 *magptr=(u32*)0x08000000;
		u32 *fileptr;
		char *d;
		char *s=(char*)0x0203fc08;

		while(*magptr!=0xfab0babe && magptr < (u32*)0x0a000000){
			magptr+=0x8000/4;						//Find the filesys root
		}
		magptr+=2;
		fileptr=magptr;

		do s++; while(*s);							//Command name (pce.bin)
		s++;
		if(strncmp(s,"/rom/",5)==0) s+=5;
		while(1){
			s++;									//First Directory
			d=s;									//First Directory
			while(*s!='/' && *s){s++;}				//Argument (/directory/.../romfile.pce)
			if(!*s)
				break;
			*s=0;									//Terminate directory name.
			while(strcmp((char*)magptr,d)){			//find directory
				magptr+=10;
			}
			magptr = (u32*)((u8*)fileptr + magptr[9]);
		}
		while(strcmp((char*)magptr,d)){				//find file
			magptr+=10;
		}
		pogosize=magptr[8];							//file size
		if(strstr(d,"(J)") || strstr(d,"(j)"))		//Check if it's a Japanese rom.
			g_emuflags |= COUNTRY;
		else
			g_emuflags &= ~COUNTRY;
		if(strstr(d,".GG") || strstr(d,".gg"))		//Check if it's a GameGear rom.
			g_emuflags |= GGMODE;
		else
			g_emuflags &= ~GGMODE;

		roms=1;
		if(*(u32*)(textstart)==EMUID) {
			g_BIOSBASE = (*(textstart+16))?textstart+sizeof(romheader):0;
		}
		textstart=(*(u8**)0x0203FBFC)-sizeof(romheader);
		memcpy(pogoshell_romname,d,32);
	}
	else
	{
		u8 *p;

		//splash screen present?
		if(*(u32*)(textstart)!=EMUID) {
			splash();
			textstart+=76800;
		}

		//Find BIOS
		if(*(u32*)(textstart)==EMUID) {
			g_BIOSBASE = 0;
			if(*(textstart+16)){
				g_BIOSBASE = textstart+sizeof(romheader);
				textstart+=*(u32*)(textstart+4)+sizeof(romheader);
			}
		}

		i=0;
		p=textstart;
		while(*(u32*)(p)==EMUID) {	//count roms
			p+=*(u32*)(p+4)+sizeof(romheader);
			i++;
		}
		if(!i)i=1;					//Stop emulator from crashing if there are no ROMS.
		roms=i;
	}
	if(REG_DISPCNT==FORCE_BLANK)	//is screen OFF?
		REG_DISPCNT=0;				//screen ON
	*MEM_PALETTE=0x7FFF;			//white background
	REG_BLDCNT=0x00ff;				//brightness decrease all
	for(i=0;i<17;i++) {
		REG_BLDY=i;					//fade to black
		waitframe();
	}
	*MEM_PALETTE=0;					//black background (avoids blue flash when doing multiboot)
	REG_DISPCNT=0;					//screen ON, MODE0
	vblankfptr=&vblankinterrupt;

	//load font
	UnCompVram(&font,(u32*)0x6002400);
	UnCompVram(&msx_keyb,(u32*)0x6004000);
	memcpy((u32*)0x6006D00,&msx_keyb_map,768);
	readconfig();
	Sound_init();
	rommenu();
}

//show splash screen
void splash() {
	int i;

	REG_DISPCNT=FORCE_BLANK;	//screen OFF
	memcpy((u16*)MEM_VRAM,(u16*)textstart,240*160*2);
	waitframe();
	REG_BG2CNT=0x0000;
	REG_DISPCNT=BG2_EN|MODE3;
	for(i=16;i>=0;i--) {	//fade from white
		setbrightnessall(i);
		waitframe();
	}
	for(i=0;i<150;i++) {	//wait 2.5 seconds
		waitframe();
		if (REG_P1==0x030f){
			gameboyplayer=1;
			gbaversion=3;
		}
	}
}

void rommenu(void) {
	cls(3);
	REG_BG3HOFS=0x0100;				//Screen left
	REG_BG3CNT=0x4600;				//16color 512x256 CHRbase0 SCRbase6 Priority0
	setdarknessgs(16);
	initpalette();
	resetSIO(joycfg&~0xff000000);	//back to 1P

	if(pogoshell)
	{
		loadcart(0,g_emuflags&0x301);		//Also save TV type
		setdarknessgs(0);
	}
	else
	{
		static int selectedrom=0;
		int i,lastselected=-1;
		int key;

		int romz=roms;	//globals=bigger code :P
		int sel=selectedrom;

		oldinput=AGBinput=~REG_P1;

		if(romz>1){
			i=drawmenu(sel);
			loadcart(sel,i|(g_emuflags&0x301));  //(keep old gfxmode)
			lastselected=sel;
			for(i=0;i<8;i++)
			{
				waitframe();
				REG_BG3HOFS=224-i*32;	//Move screen right
			}
			setdarknessgs(7);			//Lighten screen
		}
		do {
			key=getinput();
			if(key&RIGHT) {
				sel+=10;
				if(sel>romz-1) sel=romz-1;
			}
			if(key&LEFT) {
				sel-=10;
				if(sel<0) sel=0;
			}
			if(key&UP)
				sel=sel+romz-1;
			if(key&DOWN)
				sel++;
			selectedrom=sel%=romz;
			if(lastselected!=sel) {
				i=drawmenu(sel);
				loadcart(sel,i|(g_emuflags&0x301));  //(keep old gfxmode)
				lastselected=sel;
			}
			run(0);
		} while(romz>1 && !(key&(A_BTN+B_BTN+START)));
		for(i=1;i<9;i++)
		{
			waitframe();
			setdarknessgs(8-i);		//Lighten screen
			REG_BG3HOFS=i*32;		//Move screen left
			run(0);
		}
		cls(3);	//leave BG3 on for debug output
		while(AGBinput&(A_BTN+B_BTN+START)) {
			AGBinput=0;
			run(0);
		}
	}
	run(1);
}

//return ptr to Nth ROM (including rominfo struct)
u8 *findrom(int n) {
	u8 *p=textstart;
	while(!pogoshell && n--)
		p+=*(u32*)(p+4)+sizeof(romheader);
	return p;
}

//returns options for selected rom
int drawmenu(int sel) {
	int i,j,topline,toprow,romflags=0;
	u8 *p;
	romheader *ri;

	if(roms>20) {
		topline=8*(roms-20)*sel/(roms-1);
		toprow=topline/8;
		j=(toprow<roms-20)?21:20;
	} else {
		toprow=0;
		j=roms;
	}
	p=findrom(toprow);
	for(i=0;i<j;i++) {
		if(roms>1)drawtext(i,(char*)(p+32),i==(sel-toprow)?1:0);
		if(i==sel-toprow) {
			ri=(romheader*)p;
			romflags=(*ri).flags|(*ri).spritefollow<<16;
		}
		p+=*(u32*)(p+4)+sizeof(romheader);
	}
	if(roms>20)
		REG_BG3VOFS=topline%8;
	else
		REG_BG3VOFS=176+roms*4;
	return romflags;
}

int getinput() {
	static int lastdpad,repeatcount=0;
	int dpad;
	int keyhit=(oldinput^AGBinput)&AGBinput;
	oldinput=AGBinput;

	dpad=AGBinput&(UP+DOWN+LEFT+RIGHT);
	if(lastdpad==dpad) {
		repeatcount++;
		if(repeatcount<25 || repeatcount&3)	//delay/repeat
			dpad=0;
	} else {
		repeatcount=0;
		lastdpad=dpad;
	}
	EMUinput=0;	//disable game input
	return dpad|(keyhit&(A_BTN+B_BTN+START));
}


void initpalette(void) {
	//load palette
//	memcpy((void*)0x5000080,&fontpal,64);
	memcpy((void*)(PAL_BUFF+0x80),&fontpal,64);
	oambufferready=1;
}


void cls(int chrmap) {
	int i=0,len=0x200;
	u32 *scr=(u32*)SCREENBASE;
	if(chrmap>=2)
		len=0x400;
	if(chrmap==2)
		i=0x200;
	for(;i<len;i++)				//512x256
		scr[i]=0x01200120;
	REG_BG3VOFS=0;
}

void drawtext(int row,char *str,int hilite) {
	u16 *here=SCREENBASE+row*32;
	int i=0;

	*here=hilite?0x412a:0x4120;
	hilite=(hilite<<12)+0x4100;
	here++;
	while(str[i]>=' ') {
		here[i]=str[i]|hilite;
		i++;
	}
	for(;i<31;i++)
		here[i]=0x0120;
}

void setdarknessgs(int dark) {
	REG_BLDCNT=0x2373;				//darken game screen
//	REG_BLDCNT=0x2243;				//darken game screen
	REG_BLDY=dark;					//Darken screen
	REG_BLDALPHA=(0x10-dark)<<8;	//set blending for OBJ affected BG0
	if(dark > 4){
		g_flicker |= 4;
	}else{
		g_flicker &= ~4;
	}
	ScalemodeInit();
}

void setbrightnessall(int light) {
	REG_BLDCNT=0x00bf;				//brightness increase all
	REG_BLDY=light;
}


