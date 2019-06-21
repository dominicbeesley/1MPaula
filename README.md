# 1MPaula

A VHDL implementation of an Amiga-like sound card for the BBC Micro series using the Hoglet 1MHz bus FPGA hardware.

Documentation for programming the hardware can be found at:
* [general overview](vhdl/hoglet-1m-paula/readme.md) 
* [sound specific](vhdl/chipset_fb/sound.md)

The release folder contains pre-built .bit and .mcs files for programming the board and a .ssd containing a pre-built modplayer demo

Known omissions and problems:
- master volume doesn't work
- no filtering
- no inter-channel modulation
- sample rate is close to but not identical to Amiga PAL rate due to lack of granularity of Xilinx PLL
- JIM usage clashes with devices that do not adhere to the new [JIM spec](https://raw.githubusercontent.com/dominicbeesley/DataCentre/master/jim-spec-2019.txt)


(c) 2019 Dominic Beesley / Dossytronics
