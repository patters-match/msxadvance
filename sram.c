#include <string.h>
#include "gba.h"

#define STATEID 0x57a731dd

#define SRAMSAVE 1
#define CONFIGSAVE 2

extern u8 Image$$RO$$Limit;
extern u8 g_cartflags;		//(from SMS header)
extern char g_keymap_L;		//(io.s) key remapping
extern char g_keymap_R;		//(io.s) key remapping
extern char g_keymap_Start;	//(io.s) key remapping
extern char g_keymap_Select;//(io.s) key remapping
extern char g_scaling;		//(cart.s) current display mode
extern char g_config;		//(cart.s) current bios setting
extern char g_flicker;		//(gfx.s)
extern char gammavalue;		//(gfx.s) current gammavalue
extern char sprcollision;	//(z80.s) sprite collision on/off
//extern u32 soundmode;		//(sound.s) current soundmode
extern u8 stime;			//from main.c
extern u8 *textstart;		//from main.c

extern char pogoshell;

//int totalstatesize;		//how much SRAM is used

//-------------------
void sleepset(void);						//ui.c
//u8 *findrom(int);
//void cls(void);							//main.c
//void drawtext(int,char*,int);
//void waitframe(void);
//u32 getmenuinput(int);
void writeconfig(void);
//void setup_sram_after_loadstate(void);

//extern int roms;							//main.c
//extern int selected;						//ui.c
//extern char pogoshell_romname[32];		//main.c
//----asm stuff------
//int savestate(void*);						//cart.s
//void loadstate(int,void*);				//cart.s
void bytecopy_(u8 *dst,u8 *src,int count);	//memory.s

//extern u8 *romstart;						//from cart.s
//extern u32 romnum;						//from cart.s
//extern u32 frametotal;					//from z80.s
//-------------------

typedef struct {		//(modified stateheader)
	u16 size;
	u16 type;	//=CONFIGSAVE
	char displaytype;
	char gammavalue;
	char soundmode;
	char sleep;
	char config;
	char bcolor;
	char key_L;
	char key_R;
	char key_Start;
	char key_Select;
	char reserved1;
	char reserved2;
	u32 sram_checksum;	//checksum of rom using SRAM e000-ffff	
	u32 zero;	//=0
	char reserved3[32];  //="CFG"
} configdata;

//we have a big chunk of memory starting at Image$$RO$$Limit free to use
#define BUFFER1 (&Image$$RO$$Limit)


//quick & dirty rom checksum
u32 checksum(u8 *p) {
	u32 sum=0;
	int i;
	for(i=0;i<128;i++) {
		sum+=*p|(*(p+1)<<8)|(*(p+2)<<16)|(*(p+3)<<24);
		p+=128;
	}
	return sum;
}


int using_flashcart() {
	return (u32)textstart&0x8000000;
}


const configdata configtemplate={
	sizeof(configdata),
	CONFIGSAVE,
	0x13,					//Display/Scalemode
	2,						//Gamma
	0,						//Soundmode
	0,						//Sleep
	0x40,					//Config
	0,						//BColor
	0,						//Key L
	1,						//Key R
	2,						//Key Start
	3,						//Key Select
	0,						//Reserved
	0,						//Reserved
	0,						//Checksum
	0,						//Zero
	"CFG"
};

void writeconfig() {
	configdata *cfg;
	int j;

	if(!using_flashcart())
		return;

	cfg=(configdata*)(BUFFER1);

	cfg->config      = g_config;			//store current bios setting
	j = g_scaling&0xF;						//store current display mode
	j |= (g_flicker & 0x3)<<4;				//store current scale mode
	cfg->displaytype = j;					//store current display type
	cfg->gammavalue  = gammavalue;			//store current gammavalue
	cfg->key_L       = g_keymap_L;			//store current key L
	cfg->key_R       = g_keymap_R;			//store current key R
	cfg->key_Start   = g_keymap_Start;		//store current key Start
	cfg->key_Select  = g_keymap_Select;		//store current key Select
//	cfg->soundmode   = (char)soundmode;		//store current soundmode
	j = stime & 0xF;						//store current autosleep time
	j |= ((sprcollision & 0x20)^0x20);		//store current sprite collision
	cfg->sleep = j;

	bytecopy_((u8*)MEM_SRAM+0x2000,(u8*)cfg,sizeof(configdata));
}

void readconfig() {
	int j;
	configdata *cfg;
	if(!using_flashcart())
		return;

	cfg=(configdata*)(BUFFER1);

	bytecopy_((u8*)cfg,(u8*)MEM_SRAM+0x2000,sizeof(configdata));

	if(cfg->type!=CONFIGSAVE || cfg->size!=sizeof(configdata)){
		memcpy(BUFFER1,&configtemplate,sizeof(configdata));
	}
	g_config	    = cfg->config;			//restore bios setting
	gammavalue	    = cfg->gammavalue;		//restore gamma value
	g_keymap_L      = cfg->key_L;			//restore key L
	g_keymap_R      = cfg->key_R;			//restore key R
	g_keymap_Start  = cfg->key_Start;		//restore key Start
	g_keymap_Select = cfg->key_Select;		//restore key Select
//	soundmode	    = (u32)cfg->soundmode;
	j			    = cfg->displaytype;
	g_scaling	    = j&0xF;				//restore display mode
	g_flicker	    = (j & 0x30)>>4;		//restore scale mode
	j = cfg->sleep;
	sprcollision = ((j & 0x20)^0x20);		//restore sprite collision
	stime = ((j-1) & 0x3);					//restore autosleep time
	sleepset();
}

