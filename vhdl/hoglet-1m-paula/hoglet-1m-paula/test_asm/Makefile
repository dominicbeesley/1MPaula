.PHONY:		all clean

ASMTARGETS=	test1m_paula.rom
TARGETS=	$(ASMTARGETS) 

INCS=		
LIBS=		

AS=ca65
LD=ld65
DEPS=hw.inc common.inc os.inc
AR=ar65

.PRECIOUS:	%.o

%rom:	%.cfg

all:		$(TARGETS)


%.rom:		%.o $(LIBS)
		$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map -o $@ -C $(basename $@).cfg $< $(LIBS)
		da65 -S 0xC000 --comments 4 $(basename $@).rom >$(basename $@).da.s


%.o:		%.asm $(DEPS) $(INCS)
		$(AS) -g -l $(basename $@).lst $<



clean:		$(clean_extra)
		$(foreach cln,$(TARGETS), \
		rm -f $(cln) $(basename $(cln)).lst $(basename $(cln)).sym $(basename $(cln)).map $(basename $(cln)).hex $(basename $(cln)).o $(basename $(cln)).da.s \
		)
		rm -f *.o
		rm -f *.rom
		rm -f *.bin



