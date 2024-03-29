# MSXAdvance v0.2
This is an MSX1 emulator for the Gameboy Advance by FluBBa, rescued from the [Web Archive](https://web.archive.org/web/20150430211123/http://www.ndsretro.com/gbadown.html). It was originally a quick and dirty hack of his ColecoVision emulator Cologne since both systems have a Z80 CPU and the same VDP.

Many of the very best shoot 'em up series in gaming got a start on the MSX1:
- Nemesis, Nemesis 2, Nemesis 3
- Salamander
- Zanac A.I.
- Twin Bee
- Parodius
- Fantasy Zone
- R-Type

All of which remain very playable today, and run well on MSXAdvance.

However, until now MSXAdvance was let down by one significant usability issue - you had to manually select the ROM mapper for each game (hidden away in the Other Settings menu), and you also had to restart the emulator once you had changed it. Furthermore you need to remember which mapper for each game.

### Enhancement

In June 2022 I (patters) forked the source code to [hack in automatic selection of the game ROM mapper type](https://github.com/patters-syno/msxadvance/commit/f35cf8b10784fcf4239b192859dbc4336667a30b).

My new [Python 3 builder](https://github.com/patters-syno/gba-emu-compilation-builders/blob/main/msxadvance_compile.py) must be used for this feature. In fact it is the builder which detects the appropriate mapper to use and records this choice in a spare byte in the ROM header for retrieval by the emulator. I implemented the same [algorithm which several other MSX emulators use](https://github.com/openMSX/openMSX/blob/d4c561dd02877825d63a39a28b70bcc760b503e4/src/memory/RomFactory.cc#L72) to scan the ROM for likely bank switch instructions and rank the observed destination addresses.

To minimise the changes needed to the emulator ARM ASM code I repurposed the upper 3 bits of the *emuflags* 4 byte word passed by [**main.c**](https://github.com/patters-syno/msxadvance/blob/c5bc51b4790c69fe379a4d0c38080f4403e250f2/src/main.c#L287) to [**cart.s**](https://github.com/patters-syno/msxadvance/blob/dd25ee15dc011c7afd860dff211327ff40182a2a/src/cart.s#L44), meaning that the *spritefollow* half-word within is reduced from 16 bits to 13 bits wide. The rarely-used sprite follow feature will still function but the max value is now limited to 8191.

Although MSXAdvance v0.3 and v0.4 were released, they very significantly impacted game compatibility, which is why I forked v0.2.

## How to use:
!! YOU MUST SUPPLY A BIOS TO BE ABLE TO RUN GAMES !!

Run **msxadvance_compile.py** to add roms to the emulator.

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
Add an empty file and a BIOS. Copy **msx.gba** to the plugin folder then rename it to **msxadvance.mb** (or compress it to ```.mbz```) and add this line to the **pogo.cfg** file:

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

