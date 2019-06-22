; (c) Dossytronics 2017
; test harness ROM for VHDL testbench for MEMC mk2
; makes a 4k ROM

		.include	"common.inc"
		.include	"hw.inc"

JIM_DEVNO	:=	$D0

vec_nmi		:=	$D00

		.ZEROPAGE
ZP_PTR:		.RES 2

		.CODE

sample_data:	.byte 0, $1F, $3F, $5F, $7F, $80, $C0, $D0

mos_handle_res:
		sei
		lda	#$40
		sta	vec_nmi

		; wait for rst to finish
		ldx	#50
rstlp:		dex
		bpl	rstlp

		; disable jim
		lda	#11
		sta	fred_JIM_DEVNO
		lda	fred_JIM_DEVNO

		; test jim interface
		lda	#JIM_DEVNO
		sta	fred_JIM_DEVNO
		lda	fred_JIM_DEVNO

		lda	#0
		sta	fred_JIM_PAGE_HI
		sta	fred_JIM_PAGE_LO
		lda	fred_JIM_PAGE_HI
		lda	fred_JIM_PAGE_LO



		ldx	#7
@1:		lda	sample_data,X
		sta	JIM,X
		dex
		bpl	@1

		lda	#<jim_page_DMAC
		sta	fred_JIM_PAGE_LO
		lda	#>jim_page_DMAC
		sta	fred_JIM_PAGE_HI


		; play sound
		lda	#0
		sta	jim_DMAC_SND_SEL
		sta	jim_DMAC_SND_DATA
		sta	jim_DMAC_SND_DATA+1
		sta	jim_DMAC_SND_DATA+2
		sta	jim_DMAC_SND_PERIOD
		sta	jim_DMAC_SND_LEN
		sta	jim_DMAC_SND_REPOFF
		sta	jim_DMAC_SND_REPOFF+1
		lda	#20
		sta	jim_DMAC_SND_PERIOD+1
		lda	#8
		sta	jim_DMAC_SND_LEN+1
		lda	#$FF
		sta	jim_DMAC_SND_VOL
		lda	#SND_CTL_ACT+SND_CTL_REPEAT
		sta	jim_DMAC_SND_STATUS


		; disable jim
		lda	#11
		sta	fred_JIM_DEVNO
		lda	fred_JIM_DEVNO

		ldx	#3
@3:		txa
		lda	JIM,X
		dex
		bne	@3


		ldx	#0
@44:		dex
		bne	@44


		lda	#$FF
		sta	$FEFF				;; simulation  end
here:		jmp	here

mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   vec_nmi                         ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END
