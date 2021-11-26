// ============================================================================
// KEYWORDS 		: 	DBF_top
// ----------------------------------------------------------------------------
// PURPOSE 			: 	This is TOP module
// ----------------------------------------------------------------------------
// ============================================================================
// REUSE ISSUES
// Reset Strategy	:	Async clear,active low
// Clock Domains	:	clk
// Critical TiminG	:	N/A
// Instantiations	:	N/A
// Synthesizable	:	N/A
// Others			:	N/A
// ****************************************************************************
module DBF_top(
	//clock and reset signal
	input 						SYS_CLK,					//clock, this is system clock
	input 						RESET_N,					//Reset the all signal, active low
	
	//Input port
	input						KEY_WR,						//write signal
	input	[31:0]				KEY,						//KEY
	output						KEY_ALLMOSTFULL,			//key is allmostfull
	//Output port
	output						VALUE_WR,					//write signal
	output	[7:0]				VALUE,						//VALUE
	input						VALUE_ALLMOSTFULL,			//VALUE is allmostfull
	//local bus
	input						local_cs_n,					//chip select, 0<->select, 1<->no select
	input						local_rw,	                //The localbus writing data  
	input	[21:0]				local_addr,	                //The localbus addr
	input	[7:0]				local_wdata,                //1<->writing, 0<->reading
	output	[7:0]				local_rdata,                //The localbud reading data
	output						local_ack_n                 //Completion assert low, active low
	
);
	wire	[31:0]				hash_value_input;			//HASH_VALUE
	wire						hash_value_input_wr;
CRC32h_32bit	CRC32h_32bit_inst(
//----------CLK & RST INPUT-----------
	.clk						(SYS_CLK								),			//The clock come from 
	.reset_n					(RESET_N								),			//hardware reset

//-----------CLK & RST GEN-----------
	.data						(KEY									),			//Origin KEY
	.datavalid					(KEY_WR									),			//key write
	.checksum					(hash_value_input						),			//hash_value
	.crcvalid					(hash_value_input_wr					)			//hash_value_wr
);	
DynamicBloomFilter#(
	.RAMAddWidth				(19										),
	.DataDepth					(524288									)
)DynamicBloomFilter_inst(
	//clock and reset signal
	.Clk						(SYS_CLK								),			//clock, this is synchronous clock
	.Reset_N					(RESET_N								),			//Reset the all signal, active high
	.Tab_reset_n				(RESET_N								),			//clean the table
	//Input port
	.DBF_in_key					(hash_value_input						),			//receive metadata
	.DBF_in_key_wr				(hash_value_input_wr					),			//receive write
	.DBF_out_key_alf			(KEY_ALLMOSTFULL						),			//output ACL allmostfull
	//Output port
	.DBF_out_value				(VALUE									),			//send metadata to DMUX
	.DBF_out_value_wr			(VALUE_WR								),			//receive write to DMUX
	.DBF_in_value_alf			(VALUE_ALLMOSTFULL						),			//output ACL allmostfull
	//local bus
	.local_cs_n					(local_cs_n								),			//chip select, 0<->select, 1<->no select
	.local_rw					(local_rw								),			//The localbus writing data  
	.local_addr					(local_addr								),			//The localbus addr
	.local_wdata				(local_wdata							),			//1<->writing, 0<->reading
	.local_rdata				(local_rdata							),			//The localbud reading data
	.local_ack_n				(local_ack_n							)			//Completion assert low, active low
	
);

endmodule