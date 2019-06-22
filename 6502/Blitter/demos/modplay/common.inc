
		.MACRO PRINT MSG
		.SCOPE

		.LOCAL MSGSTR
		.PUSHSEG
		.RODATA
MSGSTR:		.BYTE MSG, 0
		.POPSEG
		pha
		txa
		pha
		ldx	#0
@p_s:		lda	MSGSTR,X
		beq	@p_s2
		jsr	OSASCI
		inx
		bne	@p_s
@p_s2:		pla
		tax
		pla

		.ENDSCOPE
		.ENDMACRO

		.MACRO PRINTL MSG
		.SCOPE

		.LOCAL MSGSTR
		.PUSHSEG
		.RODATA
MSGSTR:		.BYTE MSG, 0
		.POPSEG
		pha
		txa
		pha
		ldx	#0
@s:		lda	MSGSTR,X
		beq	@s2
		jsr	OSASCI
		inx
		bne	@s
@s2:		jsr	OSNEWL
		pla
		tax		
		pla
		.ENDSCOPE
		.ENDMACRO