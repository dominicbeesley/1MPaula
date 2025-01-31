
#define BLITCON_ACT_ACT			0x80			
#define BLITCON_ACT_CELL		0x40			
#define BLITCON_ACT_COLLIDE		0x04						

								
#define BLITCON_ACT_MODE_1BBP		0x00			
#define BLITCON_ACT_MODE_2BBP		0x10			
#define BLITCON_ACT_MODE_4BBP		0x20			
#define BLITCON_ACT_MODE_8BBP		0x30			
#define BLITCON_ACT_LINE		0x08			

#define BLITCON_LINE_MAJOR_UPnRIGHT	0x10			
#define BLITCON_LINE_MINOR_CCW		0x20			
								
								

#define BLITCON_EXEC_A			0x01	
#define BLITCON_EXEC_B			0x02	
#define BLITCON_EXEC_C			0x04	
#define BLITCON_EXEC_D			0x08	
#define BLITCON_EXEC_E			0x10	


#define DMACTL_ACT			0x80			

#define DMACTL_EXTEND			0x20			
#define DMACTL_HALT			0x10			
#define DMACTL_STEP_DEST_NONE		0x00			
#define DMACTL_STEP_DEST_UP		0x04			
#define DMACTL_STEP_DEST_DOWN		0x08			
#define DMACTL_STEP_DEST_NOP		0x0C			
#define DMACTL_STEP_SRC_NONE		0x00			
#define DMACTL_STEP_SRC_UP		0x01			
#define DMACTL_STEP_SRC_DOWN		0x02			
#define DMACTL_STEP_SRC_NOP		0x03			

#define DMACTL2_IF			0x80			
#define DMACTL2_IE			0x02			
#define DMACTL2_PAUSE			0x01	


#define DMAC_BLITCON_offs		0x00	
#define DMAC_FUNCGEN_offs		0x01	
#define DMAC_WIDTH_offs			0x02	
#define DMAC_HEIGHT_offs		0x03	
#define DMAC_SHIFT_offs			0x04	
#define DMAC_MASK_FIRST_offs		0x05	
#define DMAC_MASK_LAST_offs		0x06	
#define DMAC_DATA_A_offs		0x07	
#define DMAC_ADDR_A_offs		0x08	
#define DMAC_DATA_B_offs		0x0B	
#define DMAC_ADDR_B_offs		0x0C	
#define DMAC_ADDR_C_offs		0x0F	
#define DMAC_ADDR_D_offs		0x12	
#define DMAC_ADDR_E_offs		0x15	
#define DMAC_STRIDE_A_offs		0x18	
#define DMAC_STRIDE_B_offs		0x1A	
#define DMAC_STRIDE_C_offs		0x1C	
#define DMAC_STRIDE_D_offs		0x1E	

#define DMAC_SND_DATA_offs		0x20	
#define DMAC_SND_ADDR_offs		0x21	
#define DMAC_SND_PERIOD_offs		0x24	
#define DMAC_SND_LEN_offs		0x26	
#define DMAC_SND_STATUS_offs		0x28	
#define DMAC_SND_VOL_offs		0x29	
#define DMAC_SND_REPOFF_offs		0x2A	
#define DMAC_SND_PEAK_offs		0x2C	

#define DMAC_SND_MA_VOL_offs		0x2E	
#define DMAC_SND_SEL_offs		0x2F	

#define DMAC_DMA_CTL_offs		0x30	
#define DMAC_DMA_SRC_ADDR_offs		0x31	
#define DMAC_DMA_DEST_ADDR_offs		0x34	
#define DMAC_DMA_COUNT_offs		0x37	
#define DMAC_DMA_DATA_offs		0x39	
#define DMAC_DMA_CTL2_offs		0x3A	
#define DMAC_DMA_PAUSE_VAL_offs		0x3B	
#define DMAC_DMA_SEL_offs		0x3F	

#define jim_page_DMAC			0xFEFC
#define jim_DMAC			0xFD60	
#define jim_DMAC_BLITCON		(jim_DMAC + DMAC_BLITCON_offs)
#define jim_DMAC_FUNCGEN		(jim_DMAC + DMAC_FUNCGEN_offs)
#define jim_DMAC_WIDTH			(jim_DMAC + DMAC_WIDTH_offs)
#define jim_DMAC_HEIGHT			(jim_DMAC + DMAC_HEIGHT_offs)
#define jim_DMAC_SHIFT			(jim_DMAC + DMAC_SHIFT_offs)
#define jim_DMAC_MASK_FIRST		(jim_DMAC + DMAC_MASK_FIRST_offs)
#define jim_DMAC_MASK_LAST		(jim_DMAC + DMAC_MASK_LAST_offs)
#define jim_DMAC_DATA_A			(jim_DMAC + DMAC_DATA_A_offs)
#define jim_DMAC_ADDR_A			(jim_DMAC + DMAC_ADDR_A_offs)
#define jim_DMAC_DATA_B			(jim_DMAC + DMAC_DATA_B_offs)
#define jim_DMAC_ADDR_B			(jim_DMAC + DMAC_ADDR_B_offs)
#define jim_DMAC_ADDR_C			(jim_DMAC + DMAC_ADDR_C_offs)
#define jim_DMAC_ADDR_D			(jim_DMAC + DMAC_ADDR_D_offs)
#define jim_DMAC_ADDR_E			(jim_DMAC + DMAC_ADDR_E_offs)
#define jim_DMAC_STRIDE_A		(jim_DMAC + DMAC_STRIDE_A_offs)
#define jim_DMAC_STRIDE_B		(jim_DMAC + DMAC_STRIDE_B_offs)
#define jim_DMAC_STRIDE_C		(jim_DMAC + DMAC_STRIDE_C_offs)
#define jim_DMAC_STRIDE_D		(jim_DMAC + DMAC_STRIDE_D_offs)
#define jim_DMAC_SND_DATA		(jim_DMAC + DMAC_SND_DATA_offs)
#define jim_DMAC_SND_ADDR		(jim_DMAC + DMAC_SND_ADDR_offs)
#define jim_DMAC_SND_PERIOD		(jim_DMAC + DMAC_SND_PERIOD_offs)
#define jim_DMAC_SND_LEN		(jim_DMAC + DMAC_SND_LEN_offs)
#define jim_DMAC_SND_STATUS		(jim_DMAC + DMAC_SND_STATUS_offs)
#define jim_DMAC_SND_VOL		(jim_DMAC + DMAC_SND_VOL_offs)
#define jim_DMAC_SND_REPOFF		(jim_DMAC + DMAC_SND_REPOFF_offs)
#define jim_DMAC_SND_PEAK		(jim_DMAC + DMAC_SND_PEAK_offs)
#define jim_DMAC_SND_SEL		(jim_DMAC + DMAC_SND_SEL_offs)
#define jim_DMAC_SND_MA_VOL		(jim_DMAC + DMAC_SND_MA_VOL_offs)
#define jim_DMAC_DMA_CTL		(jim_DMAC + DMAC_DMA_CTL_offs)
#define jim_DMAC_DMA_SRC_ADDR		(jim_DMAC + DMAC_DMA_SRC_ADDR_offs)
#define jim_DMAC_DMA_DEST_ADDR		(jim_DMAC + DMAC_DMA_DEST_ADDR_offs)
#define jim_DMAC_DMA_COUNT		(jim_DMAC + DMAC_DMA_COUNT_offs)
#define jim_DMAC_DMA_DATA		(jim_DMAC + DMAC_DMA_DATA_offs)
#define jim_DMAC_DMA_CTL2		(jim_DMAC + DMAC_DMA_CTL2_offs)
#define jim_DMAC_DMA_PAUSE_VAL		(jim_DMAC + DMAC_DMA_PAUSE_VAL_offs)
#define jim_DMAC_DMA_SEL		(jim_DMAC + DMAC_DMA_SEL_offs)


#define SHEILA_NULA_CTLAUX		0xFE22
#define SHEILA_NULA_PALAUX		0xFE23


#define fred_JIM_PAGE_HI		0xFCFD
#define fred_JIM_PAGE_LO		0xFCFE
#define fred_JIM_DEVNO			0xFCFF


#define JIM_DEVNO_HOG1MPAULA		0xD0
#define JIM_DEVNO_BLITTER		0xD1

