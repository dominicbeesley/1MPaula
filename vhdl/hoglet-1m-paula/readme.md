### 1M Paula

The 1M Paula vhdl project makes an Amiga-like soundcard for the BBC micro. It is a cut-down version of the full chipset available on the Dossytronics blitter card. 

The card gives four independant pcm sound channels which may be replayed at different sample rates. This has the adventage over normal sound systems with a fixed rate that the host cpu doesn't have to do filtering or decimation on samples at real time to create different notes.

The programmer can either use DMA techiniques to play back a sample or may program each channel's data register directly for computed effects


