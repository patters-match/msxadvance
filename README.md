# MSXAdvance v0.2
This is an MSX1 emulator for the Gameboy Advance by FluBBa, rescued from the [Web Archive](https://web.archive.org/web/20150430211123/http://www.ndsretro.com/gbadown.html). It was a quick and dirty hack from his ColecoVision emulator Cologne. Although MSXAdvance v0.3 and v0.4 were released, they very significantly impacted game compatibility.

### Enhancement
MSXAdvance is a solid emulator which runs very well on GBA. Many of the very best shoot 'em ups in gaming got a start on this system: Nemesis, Nemesis II, Nemesis III, Salamander, Zanac A.I., Twin Bee, Parodius, and R-Type. The SCC sound chip was also very advanced for an 8 bit micro, so these titles remain very playable today.

However, MSXAdvance was always let down by one significant usability issue - you had to manually select the memory mapper for each game or they would hang. And you needed to remember which one, which meant fiddling about in the menu testing just to get each game started. If you weren't regularly using the GBA this would all be forgotten. Not anymore though!

In June 2022 I (patters) forked the sourcecode to [hack in automatic selection of the game ROM mapper type](https://github.com/patters-syno/msxadvance/commit/f35cf8b10784fcf4239b192859dbc4336667a30b). I remember begging for this feature on the PocketHeaven forums back in 2006, and I seem to recall that FluBBa (having moved onto his next project) answered with something like *"it's open source, so you can add that if you really want"*. [Well now I did](https://github.com/patters-syno/msxadvance/releases/tag/v0.2e) :)

My new [Python 3 builder](https://github.com/patters-syno/gba-emu-compilation-builders/blob/main/msxadvance_compile.py) must be used for this feature. In fact it is the builder which detects the appropriate mapper to use and records this choice in a spare byte in the ROM header for retrieval by the emulator. I ported the [algorithm which several other MSX emulators use](https://github.com/openMSX/openMSX/blob/d4c561dd02877825d63a39a28b70bcc760b503e4/src/memory/RomFactory.cc#L72). In the emulator I stole the upper 3 bits of the ```emuflags``` word passed by *main.c* to *cart.s*, meaning that the ```spritefollow``` half-word within is reduced from 16 bits to 13 bits wide. AFAIK this should still work ok (max value is now 8191).

#### Features:
- A lot of games can actually be played.
- Automatic ROM mapper selection greatly improves the game browsing experience.

#### Missing:
- Not all keys are mapped to the GBA.
- Correct sprite collision and overflow.
- Screen mode 3.
- Savestates.

#### Bugs:
- Screen mode 1 is not correct.
- The sound sucks.
- Probably a lot more.

## How to use:
**You must supply a BIOS to be able to run games!**
Run *MSXAdvance.exe* to add roms to the emulator. Use the BIOS tick box to add a BIOS.

A freely available BIOS can be found at http://cbios.sourceforge.net/ (version 0.21 works, newer ones not so much).

When the emulator starts, use Up/Down to select game, then use B or A to start the game selected.

Press L+R at any time to open the menu, A to choose, B (or L+R again) to cancel.

### Default in-game controls:
	D-Pad:	Joystick.
	A & B:	Fire buttons.
	L:	0.
	R:	1.
	Start:	2.
	Select:	3.
	R+Start:Bring up Keyboard.


### Controls:
	Controller->: Settings for controller
		Controller: 1P=Joystick1, 2P=Joystick2, Cursor=Keyboard cursor keys.
		Remapping: Use joypad to select key and press A to confirm.
	Display->: Settings for the display
		Unscaled mode:  L & R buttons scroll the screen up and down.
		Scaling modes:
			Hard:   Every 6th scanline is skipped.
			Normal: Every 5th & 6th scanline is blended.
			Soft:   All lines are blended differently. !Experimental!
		Scaled modes:  Press L+SELECT to change which lines are skipped/blended.
	Other->: Misc settings
		Speed modes:  L+START switches between throttled/unthrottled/slomo mode.
		Sleep:  START+SELECT wakes up from sleep mode (activated from menu or 5/10/30
			minutes of inactivity)


### Advanced:
	EWRAM speed:
		This changes the waitstate on EWRAM between 2 and 1, this can probably
		damage your GBA and definitly uses more power, around 10% speedgain. Use at
		your own risk!

	Link transfer:
		Send a MSX game to another GBA.  The other GBA must be in multiboot receive
		mode (no cartridge inserted, powered on and waiting with the "GAME BOY" logo
		displayed). Only one game can be sent at a time, and only if it's small
		enough to send (approx. 128kB or less). A game can only be sent to one
		Gameboy at a time, disconnect all other gameboys during transfer. Use an
		original Nintendo cable!

### Pogoshell:
Add an empty file and a BIOS. Copy *msx.gba* to the plugin folder then rename it to *msxadvance.mb* (or compress it to ```.mbz```) and add this line to the *pogo.cfg* file:

```rom 1 msxadvance.mb 2```

or

```rom 1 msxadvance.mbz 2```

## Credits:
Huge thanks to Loopy for the incredible PocketNES and the builder, without it this emulator would probably never have been made.

Thanks to:
- Reesy for help with the Z80 emu core
- Some MAME people for the AY38910 info
- Sean Young for the TMS9918 info
- [Charles MacDonald](http://techno-junk.org) for more VDP info


**Fredrik Ahlström**

https://github.com/FluBBaOfWard

https://twitter.com/TheRealFluBBa

