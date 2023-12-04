// ============================================================================
// KEYWORDS 		: 	DynamicBloomFilter
// ----------------------------------------------------------------------------
// PURPOSE 			: 	
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
//`define testbeach								//Define is test or FPGA model
module DynamicBloomFilter
#(parameter
	RAMAddWidth						= 10,						//The RAM address width
	DataDepth						= 1024						//The RAM data depth
)
(
	//clock and reset signal
	input 							Clk,						//clock, this is synchronous clock
	input 							Reset_N,					//Reset the all signal, active high
	input							Tab_reset_n,				//clean the table
	//Input port
	input		[31:0]				DBF_in_key,					//receive metadata
	input							DBF_in_key_wr,				//receive write
	output							DBF_out_key_alf,			//output ACL allmostfull
	//Output port
	output	reg	[7:0]				DBF_out_value,				//send metadata to DMUX
	output	reg						DBF_out_value_wr,			//receive write to DMUX
	input							DBF_in_value_alf,			//output ACL allmostfull
	//local bus
	input							local_cs_n,					//chip select, 0<->select, 1<->no select
	input							local_rw,	                //The localbus writing data  
	input		[21:0]				local_addr,	                //The localbus addr
	input		[7:0]				local_wdata,                //1<->writing, 0<->reading
	output	reg	[7:0]				local_rdata,                //The localbud reading data
	output	reg						local_ack_n                //Completion assert low, active low

);
//wire and register

	//wire
	wire							check_key_empty;			//fifo empty
	wire		[3:0]				check_key_usedw;			//fifo usedword
	wire							table_reset_n;				//table clean
	reg								check_key_rd;				//fifo read 
	wire		[31:0]				check_key_q;				//fifo data
	reg			[2:0]				count;						//count the read-signal
	reg			[1:0]				chip_select_ram;			//restore the chip_select
	//----------------------ram--------------------------//
	reg			[RAMAddWidth-1:0]	ram0_addr_a;					//ram a-port address
	reg			[RAMAddWidth-1:0]	ram0_addr_b;					//ram b-port address
	reg			[7:0]				ram0_data_a;					//ram a-port data
	reg			[7:0]				ram0_data_b;					//ram b-port data
	reg								ram0_rden_a;					//read a-port 
	reg								ram0_rden_b;					//read b-port 
	reg								ram0_wren_a;					//write a-port
	reg								ram0_wren_b;					//write b-port
	wire		[7:0]				ram0_out_a;						//data a-port
	wire		[7:0]				ram0_out_b;						//data b-port

	reg			[RAMAddWidth-1:0]	ram1_addr_a;					//ram a-port address
	reg			[RAMAddWidth-1:0]	ram1_addr_b;					//ram b-port address
	reg			[7:0]				ram1_data_a;					//ram a-port data
	reg			[7:0]				ram1_data_b;					//ram b-port data
	reg								ram1_rden_a;					//read a-port 
	reg								ram1_rden_b;					//read b-port 
	reg								ram1_wren_a;					//write a-port
	reg								ram1_wren_b;					//write b-port
	wire		[7:0]				ram1_out_a;						//data a-port
	wire		[7:0]				ram1_out_b;						//data b-port

	reg			[RAMAddWidth-1:0]	ram2_addr_a;					//ram a-port address
	reg			[RAMAddWidth-1:0]	ram2_addr_b;					//ram b-port address
	reg			[7:0]				ram2_data_a;					//ram a-port data
	reg			[7:0]				ram2_data_b;					//ram b-port data
	reg								ram2_rden_a;					//read a-port 
	reg								ram2_rden_b;					//read b-port 
	reg								ram2_wren_a;					//write a-port
	reg								ram2_wren_b;					//write b-port
	wire		[7:0]				ram2_out_a;						//data a-port
	wire		[7:0]				ram2_out_b;						//data b-port
	//-------------------state------------------------//
	reg			[3:0]				lookup_state;				//look up state
	localparam						idle_s 		=	4'h0,
									pharse_1_s	=	4'h1,
									pharse_2_s	=	4'h2,
									pharse_3_s	=	4'h3,
									pharse_4_s	=	4'h4,
									wait_1_s	=	4'h5,
									wait_2_s	=	4'h6,
									read_s		=	4'h7;
									
	reg			[3:0]				localbus_state;				//localbus state
	localparam						idle_d 		=	4'h0,
									read_d		=	4'h1,
									write_d		=	4'h2,
									wait_1_d	=	4'h3,
									wait_2_d	=	4'h4,
									rec_data_d	=	4'h5,
									wait_cs_d	=	4'h6,
									inital_d	=	4'h7;
	assign table_reset_n 						= Tab_reset_n & Reset_N;				//Tab_reset_n is software clean, Reset_N is hardward clean
	assign DBF_out_key_alf						= &check_key_usedw[3:0];					//send out allmostfull
//local bus control the ram
always @ (posedge Clk or negedge table_reset_n)
begin
   if (~table_reset_n)																	//reset is coming
   begin
		local_ack_n							<= 1'b1;									//clean all signal								
		local_rdata							<= 8'b0;									//clean all signal
		ram0_addr_b							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram0_data_b							<= 8'b0;									//clean all signal
		ram0_rden_b							<= 1'b0;									//clean all signal
		ram0_wren_b							<= 1'b0;									//clean all signal
		ram1_addr_b							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram1_data_b							<= 8'b0;									//clean all signal
		ram1_rden_b							<= 1'b0;									//clean all signal
		ram1_wren_b							<= 1'b0;									//clean all signal
		ram2_addr_b							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram2_data_b							<= 8'b0;									//clean all signal
		ram2_rden_b							<= 1'b0;									//clean all signal
		ram2_wren_b							<= 1'b0;									//clean all signal
		chip_select_ram						<= 2'b0;									//clean all signal
		localbus_state						<= idle_d;									//clean all signal
   end
   else 
   begin
		case(localbus_state)
			idle_d:																		//start state
			begin
				local_ack_n					<= 1'b1;									//clean all signal
				ram0_addr_b					<= {(RAMAddWidth){1'b0}};					//clean all signal
				ram0_data_b					<= 8'b0;									//clean all signal
				ram0_rden_b					<= 1'b0;									//clean all signal
				ram0_wren_b					<= 1'b0;									//clean all signal
				ram1_addr_b					<= {(RAMAddWidth){1'b0}};					//clean all signal
				ram1_data_b					<= 8'b0;									//clean all signal
				ram1_rden_b					<= 1'b0;									//clean all signal
				ram1_wren_b					<= 1'b0;									//clean all signal
				ram2_addr_b					<= {(RAMAddWidth){1'b0}};					//clean all signal
				ram2_data_b					<= 8'b0;									//clean all signal
				ram2_rden_b					<= 1'b0;									//clean all signal
				ram2_wren_b					<= 1'b0;									//clean all signal
				chip_select_ram				<= 2'b0;									//clean all signal
				if(local_cs_n == 1'b0)													//local bus chip select
				begin
					if(local_rw == 1'b1)												//1: wirte, 0:read
						localbus_state		<= write_d;									//goto write
					else
						localbus_state		<= read_d;									//goto read
				end
				else
				begin
					localbus_state			<= idle_d;									//waiting cs
				end
			end
			write_d:begin																	//write data to ram.
				case(local_addr[21:20])
				2'b00:begin																	//write RAM0
					ram0_addr_b					<= local_addr[RAMAddWidth-1:0];				//send write-address
					ram0_data_b					<= local_wdata;								//send write-data
					ram0_wren_b					<= 1'b1;									//send write-signal
				end
				2'b01:begin																	//write RAM1
					ram1_addr_b					<= local_addr[RAMAddWidth-1:0];				//send write-address
					ram1_data_b					<= local_wdata;								//send write-data
					ram1_wren_b					<= 1'b1;									//send write-signal
				end
				2'b10:begin																	//write RAM2
					ram2_addr_b					<= local_addr[RAMAddWidth-1:0];				//send write-address
					ram2_data_b					<= local_wdata;								//send write-data
					ram2_wren_b					<= 1'b1;									//send write-signal
				end
				default:begin																//default is RAM0
					ram0_addr_b					<= local_addr[RAMAddWidth-1:0];				//send write-address
					ram0_data_b					<= local_wdata;								//send write-data
					ram0_wren_b					<= 1'b1;									//send write-signal
				end
				endcase
				local_ack_n						<= 1'b0;									//assert ack
				localbus_state					<= wait_cs_d;								//goto waiting
			end
			read_d:	begin																	//read control signal, send to ram
				chip_select_ram					<= local_addr[21:20];						//restore the chip_select
				case(local_addr[21:20])
				2'b00:begin																	//read RAM0
					ram0_addr_b					<= local_addr[RAMAddWidth-1:0];				//send read-address
					ram0_rden_b					<= 1'b1;									//send read-signal				end
				end
				2'b01:begin																	//read RAM1
					ram1_addr_b					<= local_addr[RAMAddWidth-1:0];				//send read-address
					ram1_rden_b					<= 1'b1;									//send read-signal				end
				end
				2'b10:begin																	//read RAM2
					ram2_addr_b					<= local_addr[RAMAddWidth-1:0];				//send read-address
					ram2_rden_b					<= 1'b1;									//send read-signal				end
				end
				default:begin																//default is RAM0
					ram0_addr_b					<= local_addr[RAMAddWidth-1:0];				//send read-address
					ram0_rden_b					<= 1'b1;									//send read-signal				end
				end
				endcase
				localbus_state					<= wait_1_d;								//waiting read-data
			end
			wait_1_d: begin																//wait the ram
				ram0_rden_b					<= 1'b0;									//clean read signal
				ram1_rden_b					<= 1'b0;									//clean read signal
				ram2_rden_b					<= 1'b0;									//clean read signal
				localbus_state				<= wait_2_d;								//waiting read-data
			end
			wait_2_d: begin																//wait the ram
				localbus_state				<= rec_data_d;								//waiting read-data
			end
			rec_data_d:begin															//read data form ram, send the ack signal
				case(chip_select_ram)
				2'b00:begin																//read RAM0
					local_rdata					<= ram0_out_b;							//read data
				end
				2'b01:begin																//read RAM1
					local_rdata					<= ram1_out_b;							//read data
				end
				2'b10:begin																//read RAM2
					local_rdata					<= ram2_out_b;							//read data
				end
				default:begin															//default is RAM0
					local_rdata					<= ram0_out_b;							//read data
				end
				endcase
				local_ack_n					<= 1'b0;									//assert ack
				localbus_state				<= wait_cs_d;								//goto waiting
			end
			wait_cs_d: begin															//wait the cs
				ram0_rden_b					<= 1'b0;									//clean read signal
				ram0_wren_b					<= 1'b0;									//clean write signal
				ram1_rden_b					<= 1'b0;									//clean read signal
				ram1_wren_b					<= 1'b0;									//clean write signal
				ram2_rden_b					<= 1'b0;									//clean read signal
				ram2_wren_b					<= 1'b0;									//clean write signal
				if (local_cs_n == 1'b1)	begin											//The cs is high
					local_ack_n				<= 1'b1;									//The ack is low
					localbus_state			<= idle_d;									//goto idle
				end
				else begin																//The cs is low
					localbus_state			<= wait_cs_d;								//waiting cs
				end
			end
			default:
					localbus_state			<= idle_d;									//goto idle
			endcase
   end
end

//look up the ram
always @(posedge Clk or negedge Reset_N)
	if (~Reset_N) begin
		DBF_out_value_wr					<= 1'b0;									//clean all signal
		DBF_out_value						<= 8'b0;									//clean all signal
		ram0_addr_a							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram0_data_a							<= 8'b0;									//clean all signal
		ram0_rden_a							<= 1'b0;									//clean all signal
		ram0_wren_a							<= 1'b0;									//clean all signal
		ram1_addr_a							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram1_data_a							<= 8'b0;									//clean all signal
		ram1_rden_a							<= 1'b0;									//clean all signal
		ram1_wren_a							<= 1'b0;									//clean all signal
		ram2_addr_a							<= {(RAMAddWidth){1'b0}};					//clean all signal
		ram2_data_a							<= 8'b0;									//clean all signal
		ram2_rden_a							<= 1'b0;									//clean all signal
		ram2_wren_a							<= 1'b0;									//clean all signal
		check_key_rd						<= 1'b0;									//clean all signal
		count								<= 3'd0;									//clean all signal
		lookup_state						<= idle_s;									//clean all signal
	end
	else begin
		case(lookup_state)
		idle_s: begin																	
			DBF_out_value_wr					<= 1'b0;								//clean signal
			DBF_out_value						<= 8'b0;								//clean signal
			ram0_rden_a							<= 1'b0;								//clean signal
			ram1_rden_a							<= 1'b0;								//clean signal
			ram2_rden_a							<= 1'b0;								//clean signal
			ram0_addr_a							<= {(RAMAddWidth){1'b0}};				//clean signal
			ram1_addr_a							<= {(RAMAddWidth){1'b0}};				//clean signal
			ram2_addr_a							<= {(RAMAddWidth){1'b0}};				//clean signal
			if (check_key_empty == 1'b0 && DBF_in_value_alf == 1'b0) begin				//address is coming
				check_key_rd					<= 1'b1;								//read the address fifo
				lookup_state					<= pharse_1_s;							//read-data need 2 cycle from ram 
				count							<= 3'd1;								//counter, record the read cycle
			end
			else begin																	//no address, wait
				check_key_rd					<= 1'b0;								//clean signal
				lookup_state					<= idle_s;								//waiting
			end
		end
		pharse_1_s: begin
			ram0_rden_a							<= 1'b1;								//read the ram0
			ram0_addr_a							<= check_key_q[RAMAddWidth-1:0];		//send the address
			ram1_rden_a							<= 1'b1;								//read the ram1
			ram1_addr_a							<= check_key_q[RAMAddWidth-1:10];		//send the address
			ram2_rden_a							<= 1'b1;								//read the ram2
			ram2_addr_a							<= check_key_q[RAMAddWidth-1:12];		//send the address
			if (check_key_usedw	> 4'h2)	begin											//hash address isn't empty, read
				check_key_rd					<= 1'b1;								//read fifo
				lookup_state					<= pharse_2_s;							//turn to pharse_2_s		
				count							<= count + 3'd1;						//counter=2
			end
			else begin																	//no address, wait data
				check_key_rd					<= 1'b0;								//don't read fifo
				lookup_state					<= wait_1_s;							//counter=1			
			end
		end
		pharse_2_s: begin
			ram0_rden_a							<= 1'b1;								//read the ram0
			ram0_addr_a							<= check_key_q[RAMAddWidth-1:0];		//send the address
			ram1_rden_a							<= 1'b1;								//read the ram1
			ram1_addr_a							<= check_key_q[RAMAddWidth-1:10];		//send the address
			ram2_rden_a							<= 1'b1;								//read the ram2
			ram2_addr_a							<= check_key_q[RAMAddWidth-1:12];		//send the address
			if (check_key_usedw	> 4'h2)	begin											//hash address isn't empty, read
				check_key_rd					<= 1'b1;								//read fifo
				lookup_state					<= pharse_3_s;							//turn to pharse_3_s		
				count							<= count + 3'd1;						//counter=3
			end
			else begin																	//no address, wait data
				check_key_rd					<= 1'b0;								//don't read fifo
				lookup_state					<= wait_2_s;							//counter=2			
			end
		end	
		pharse_3_s: begin
			ram0_rden_a							<= 1'b1;								//read the ram0
			ram0_addr_a							<= check_key_q[RAMAddWidth-1:0];		//send the address
			ram1_rden_a							<= 1'b1;								//read the ram1
			ram1_addr_a							<= check_key_q[RAMAddWidth-1:10];		//send the address
			ram2_rden_a							<= 1'b1;								//read the ram2
			ram2_addr_a							<= check_key_q[RAMAddWidth-1:12];		//send the address
			if (check_key_usedw	> 4'h2)	begin											//hash address isn't empty, read
				check_key_rd					<= 1'b1;								//read fifo
				lookup_state					<= pharse_4_s;							//turn to pharse_4_s		
				count							<= count + 3'd1;						//counter=4
			end
			else begin																	//no address, wait data
				check_key_rd					<= 1'b0;								//don't read fifo
				lookup_state					<= read_s;								//counter=3			
			end
		end	
		pharse_4_s: begin
			ram0_rden_a							<= 1'b1;								//read the ram0
			ram0_addr_a							<= check_key_q[RAMAddWidth-1:0];		//send the address
			ram1_rden_a							<= 1'b1;								//read the ram1
			ram1_addr_a							<= check_key_q[RAMAddWidth-1:10];		//send the address
			ram2_rden_a							<= 1'b1;								//read the ram2
			ram2_addr_a							<= check_key_q[RAMAddWidth-1:12];		//send the address
			//read the data form ram, then send the data
			DBF_out_value_wr					<= 1'b1;								//send the Value valid
			DBF_out_value						<= ram0_out_a ^ ram1_out_a ^ ram2_out_a;//send the Value
			if (check_key_usedw	> 4'h2)begin											//hash address isn't empty, read
				check_key_rd					<= 1'b1;								//read fifo
				lookup_state					<= pharse_4_s;							//countue send
			end
			else begin																	//no address, wait data
				check_key_rd					<= 1'b0;								//don't read fifo
				count							<= count - 3'd1;						//decrease 1
				lookup_state					<= read_s;								//counter=3
			end
		end
		wait_1_s: begin																	//ram have 2 cycle to send data, so wait 2 cycle 
			ram0_rden_a							<= 1'b0;								//clean signal
			ram1_rden_a							<= 1'b0;								//clean signal
			ram2_rden_a							<= 1'b0;								//clean signal
			lookup_state						<= wait_2_s;							//waiting data
		end
		wait_2_s: begin
			ram0_rden_a							<= 1'b0;								//clean signal
			ram1_rden_a							<= 1'b0;								//clean signal
			ram2_rden_a							<= 1'b0;								//clean signal
			lookup_state						<= read_s;								//waiting data
		end
		read_s: begin
			//read the data form ram, then send the data
			DBF_out_value_wr					<= 1'b1;								//send the Value valid
			DBF_out_value						<= ram0_out_a ^ ram1_out_a ^ ram2_out_a;//send the Value
			ram0_rden_a							<= 1'b0;								//clean signal
			ram1_rden_a							<= 1'b0;								//clean signal
			ram2_rden_a							<= 1'b0;								//clean signal
			if (count == 3'd1)	begin 													//all read is empty
				lookup_state					<= idle_s;								//go back
			end			
			else  begin
				count							<= count - 3'd1;						//send 
				lookup_state					<= read_s;								//countine
			end			
		end
		default: begin
			lookup_state						<= idle_s;								//go back
		end
		endcase
	end

//PKT_FIFO
	wire						pkt0_Reset;		
	wire						pkt0_wrclock;	
	wire	[31:0]				pkt0_RamData;	
	wire						pkt0_RamRdreq;	
	wire						pkt0_RamWrreq;	
	wire	[3:0]				pkt0_rdaddress;	
	wire	[3:0]				pkt0_wraddress;	
	wire	[31:0]				pkt0_Ram_q;	
	fifo_top
	#(		.ShowHead			(1							),	//show head model,1<->show head,0<->normal
			.SynMode			(1							),	//1<->SynMode,0<->AsynMode
			.DataWidth			(32							),	//This is data width
			.DataDepth			(16							),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
			.RAMAddWidth		(4							)	//RAM address width, RAMAddWidth= log2(DataDepth).
	)scfifo_32_16_pkt_fifo(
			.aclr				(~Reset_N					),	//Reset the all signal, active high
			.data				(DBF_in_key					),	//The Inport of data 
			.rdclk				(Clk						),	//ASYNC ReadClk
			.rdreq				(check_key_rd				),	//active-high
			.wrclk				(Clk						),	//ASYNC WriteClk, SYNC use wrclk
			.wrreq				(DBF_in_key_wr				),	//active-high
			.q					(check_key_q				),	//The Outport of data
			.rdempty			(check_key_empty			),	//active-high
			.wrfull				(							),	//active-high
			.wrusedw			(check_key_usedw			),	//RAM wrusedword
			.rdusedw			(							),	//RAM rdusedword			
			.Reset				(pkt0_Reset					),	//The signal of reset, active high
			.wrclock			(pkt0_wrclock				),	//ASYNC WriteClk, SYNC use wrclk
			.rdclock			(							),	//ASYNC ReadClk
			.RamData			(pkt0_RamData				),	//RAM input data
			.RamRdreq			(pkt0_RamRdreq				),	//RAM read request
			.RamWrreq			(pkt0_RamWrreq				),	//RAM write request
			.rdaddress			(pkt0_rdaddress				),	//RAM read address
			.wraddress			(pkt0_wraddress				),	//RAM write address
			.Ram_q				(pkt0_Ram_q					)	//RAM output data			
	);

`ifdef testbeach
	xilblksyncram
	#(
					.DataWidth	(32							),	//This is data width	
					.DataDepth	(16							),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(4							)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)
	ram_32_16_pkt0 (
					.clka		(pkt0_wrclock				),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(pkt0_RamWrreq				),	//RAM write address
					.wea		(pkt0_RamWrreq				),	//RAM write address
					.addra		(pkt0_wraddress				),	//RAM read address
					.dina		(pkt0_RamData				),	//RAM input data
					.douta		(							),
					.clkb		(pkt0_wrclock				),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(pkt0_RamRdreq				),  //RAM write request
					.web		(1'b0						),
					.addrb		(pkt0_rdaddress				),  //RAM read request
					.dinb		(32'b0						),
					.doutb		(pkt0_Ram_q					)	//RAM output data				
				);	
`else
	ram_32_16		ram_32_16_pkt0 (
					.clka		(pkt0_wrclock				),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(pkt0_RamWrreq				),	//RAM write address
					.wea		(pkt0_RamWrreq				),	//RAM write address
					.addra		(pkt0_wraddress				),	//RAM read address
					.dina		(pkt0_RamData				),	//RAM input data
					.douta		(							),
					.clkb		(pkt0_wrclock				),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(pkt0_RamRdreq				),  //RAM write request
					.web		(1'b0						),
					.addrb		(pkt0_rdaddress				),  //RAM read request
					.dinb		(32'b0						),
					.doutb		(pkt0_Ram_q					)	//RAM output data				
				);	
`endif				
//--------------------hash ram0----------------------------//

	wire							hash0_clka;		
	wire							hash0_ena;	
	wire							hash0_wea;	
	wire	[RAMAddWidth-1:0]		hash0_addra;		
	wire	[7:0]					hash0_dina;		
	wire	[7:0]					hash0_douta;		
	wire							hash0_clkb;		
	wire							hash0_enb;	
	wire							hash0_web;	
	wire	[RAMAddWidth-1:0]		hash0_addrb;		
	wire	[7:0]					hash0_dinb;		
	wire	[7:0]					hash0_doutb;		

	ASYNCRAM#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)	
	hash_0(
					.aclr		(~Reset_N					),	//Reset the all write signal	
					.address_a	(ram0_addr_a				),	//RAM A port address
					.address_b	(ram0_addr_b				),	//RAM B port assress
					.clock_a	(Clk						),	//Port A clock
					.clock_b	(Clk						),	//Port B clock	
					.data_a		(ram0_data_a				),	//The Inport of data 
					.data_b		(ram0_data_b				),	//The Inport of data 
					.rden_a		(ram0_rden_a				),	//active-high, read signal
					.rden_b		(ram0_rden_b				),	//active-high, read signal
					.wren_a		(ram0_wren_a				),	//active-high, write signal
					.wren_b		(ram0_wren_b				),	//active-high, write signal
					.q_a		(ram0_out_a					),	//The Output of data
					.q_b		(ram0_out_b					),	//The Output of data
					// ASIC RAM
					.reset		(							),	//Reset the RAM, active higt
					.clka		(hash0_clka					),	//Port A clock
					.ena		(hash0_ena					),	//Port A enable
					.wea		(hash0_wea					),	//Port A write
					.addra		(hash0_addra				),	//Port A address
					.dina		(hash0_dina					),	//Port A input data
					.douta		(hash0_douta				),	//Port A output data
					.clkb		(hash0_clkb					),	//Port B clock
					.enb		(hash0_enb					),	//Port B enable
					.web		(hash0_web					),	//Port B write
					.addrb		(hash0_addrb				),	//Port B address
					.dinb		(hash0_dinb					),	//Port B input data
					.doutb		(hash0_doutb				)	//Port B output data	
	);
`ifdef testbeach
	xilblksyncram	
	#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)
	hash0(
					.clka		(hash0_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash0_ena					),	//RAM write address
					.wea		(hash0_wea					),	//RAM write address
					.addra		(hash0_addra				),	//RAM read address
					.dina		(hash0_dina					),	//RAM input data
					.douta		(hash0_douta				),	//RAM output data
					.clkb		(hash0_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash0_enb					),  //RAM write request
					.web		(hash0_web					),	//RAM write address
					.addrb		(hash0_addrb				),  //RAM read request
					.dinb		(hash0_dinb					),	//RAM input data
					.doutb		(hash0_doutb				)	//RAM output data				
				);		
`else
	ram_10_19_8	hash0_inst(
					.clka		(hash0_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash0_ena					),	//RAM write address
					.wea		(hash0_wea					),	//RAM write address
					.addra		(hash0_addra				),	//RAM read address
					.dina		(hash0_dina					),	//RAM input data
					.douta		(hash0_douta				),	//RAM output data
					.clkb		(hash0_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash0_enb					),  //RAM write request
					.web		(hash0_web					),	//RAM write address
					.addrb		(hash0_addrb				),  //RAM read request
					.dinb		(hash0_dinb					),	//RAM input data
					.doutb		(hash0_doutb				)	//RAM output data				
				);
`endif				
//--------------------hash ram1----------------------------//

	wire							hash1_clka;		
	wire							hash1_ena;	
	wire							hash1_wea;	
	wire	[RAMAddWidth-1:0]		hash1_addra;		
	wire	[7:0]					hash1_dina;		
	wire	[7:0]					hash1_douta;		
	wire							hash1_clkb;		
	wire							hash1_enb;	
	wire							hash1_web;	
	wire	[RAMAddWidth-1:0]		hash1_addrb;		
	wire	[7:0]					hash1_dinb;		
	wire	[7:0]					hash1_doutb;		

	ASYNCRAM#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)	
	hash_1(
					.aclr		(~Reset_N					),	//Reset the all write signal	
					.address_a	(ram1_addr_a				),	//RAM A port address
					.address_b	(ram1_addr_b				),	//RAM B port assress
					.clock_a	(Clk						),	//Port A clock
					.clock_b	(Clk						),	//Port B clock	
					.data_a		(ram1_data_a				),	//The Inport of data 
					.data_b		(ram1_data_b				),	//The Inport of data 
					.rden_a		(ram1_rden_a				),	//active-high, read signal
					.rden_b		(ram1_rden_b				),	//active-high, read signal
					.wren_a		(ram1_wren_a				),	//active-high, write signal
					.wren_b		(ram1_wren_b				),	//active-high, write signal
					.q_a		(ram1_out_a					),	//The Output of data
					.q_b		(ram1_out_b					),	//The Output of data
					// ASIC RAM
					.reset		(							),	//Reset the RAM, active higt
					.clka		(hash1_clka					),	//Port A clock
					.ena		(hash1_ena					),	//Port A enable
					.wea		(hash1_wea					),	//Port A write
					.addra		(hash1_addra				),	//Port A address
					.dina		(hash1_dina					),	//Port A input data
					.douta		(hash1_douta				),	//Port A output data
					.clkb		(hash1_clkb					),	//Port B clock
					.enb		(hash1_enb					),	//Port B enable
					.web		(hash1_web					),	//Port B write
					.addrb		(hash1_addrb				),	//Port B address
					.dinb		(hash1_dinb					),	//Port B input data
					.doutb		(hash1_doutb				)	//Port B output data	
	);
`ifdef testbeach
	xilblksyncram	
	#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)
	hash1(
					.clka		(hash1_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash1_ena					),	//RAM write address
					.wea		(hash1_wea					),	//RAM write address
					.addra		(hash1_addra				),	//RAM read address
					.dina		(hash1_dina					),	//RAM input data
					.douta		(hash1_douta				),	//RAM output data
					.clkb		(hash1_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash1_enb					),  //RAM write request
					.web		(hash1_web					),	//RAM write address
					.addrb		(hash1_addrb				),  //RAM read request
					.dinb		(hash1_dinb					),	//RAM input data
					.doutb		(hash1_doutb				)	//RAM output data				
				);
`else
	ram_10_19_8 hash1(
					.clka		(hash1_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash1_ena					),	//RAM write address
					.wea		(hash1_wea					),	//RAM write address
					.addra		(hash1_addra				),	//RAM read address
					.dina		(hash1_dina					),	//RAM input data
					.douta		(hash1_douta				),	//RAM output data
					.clkb		(hash1_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash1_enb					),  //RAM write request
					.web		(hash1_web					),	//RAM write address
					.addrb		(hash1_addrb				),  //RAM read request
					.dinb		(hash1_dinb					),	//RAM input data
					.doutb		(hash1_doutb				)	//RAM output data				
				);
`endif
//--------------------hash ram2----------------------------//

	wire							hash2_clka;		
	wire							hash2_ena;	
	wire							hash2_wea;	
	wire	[RAMAddWidth-1:0]		hash2_addra;		
	wire	[7:0]					hash2_dina;		
	wire	[7:0]					hash2_douta;		
	wire							hash2_clkb;		
	wire							hash2_enb;	
	wire							hash2_web;	
	wire	[RAMAddWidth-1:0]		hash2_addrb;		
	wire	[7:0]					hash2_dinb;		
	wire	[7:0]					hash2_doutb;		

	ASYNCRAM#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)	
	hash_2(
					.aclr		(~Reset_N					),	//Reset the all write signal	
					.address_a	(ram2_addr_a				),	//RAM A port address
					.address_b	(ram2_addr_b				),	//RAM B port assress
					.clock_a	(Clk						),	//Port A clock
					.clock_b	(Clk						),	//Port B clock	
					.data_a		(ram2_data_a				),	//The Inport of data 
					.data_b		(ram2_data_b				),	//The Inport of data 
					.rden_a		(ram2_rden_a				),	//active-high, read signal
					.rden_b		(ram2_rden_b				),	//active-high, read signal
					.wren_a		(ram2_wren_a				),	//active-high, write signal
					.wren_b		(ram2_wren_b				),	//active-high, write signal
					.q_a		(ram2_out_a					),	//The Output of data
					.q_b		(ram2_out_b					),	//The Output of data
					// ASIC RAM
					.reset		(							),	//Reset the RAM, active higt
					.clka		(hash2_clka					),	//Port A clock
					.ena		(hash2_ena					),	//Port A enable
					.wea		(hash2_wea					),	//Port A write
					.addra		(hash2_addra				),	//Port A address
					.dina		(hash2_dina					),	//Port A input data
					.douta		(hash2_douta				),	//Port A output data
					.clkb		(hash2_clkb					),	//Port B clock
					.enb		(hash2_enb					),	//Port B enable
					.web		(hash2_web					),	//Port B write
					.addrb		(hash2_addrb				),	//Port B address
					.dinb		(hash2_dinb					),	//Port B input data
					.doutb		(hash2_doutb				)	//Port B output data	
	);
`ifdef testbeach
	xilblksyncram	
	#(
					.DataWidth	(8							),	//This is data width	
					.DataDepth	(DataDepth					),	//for ASYNC,DataDepth must be 2^n (n>=1). for SYNC,DataDepth is a positive number(>=1)
					.RAMAddWidth(RAMAddWidth				)	//RAM address width, RAMAddWidth= log2(DataDepth).			
	)
	hash2(
					.clka		(hash2_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash2_ena					),	//RAM write address
					.wea		(hash2_wea					),	//RAM write address
					.addra		(hash2_addra				),	//RAM read address
					.dina		(hash2_dina					),	//RAM input data
					.douta		(hash2_douta				),	//RAM output data
					.clkb		(hash2_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash2_enb					),  //RAM write request
					.web		(hash2_web					),	//RAM write address
					.addrb		(hash2_addrb				),  //RAM read request
					.dinb		(hash2_dinb					),	//RAM input data
					.doutb		(hash2_doutb				)	//RAM output data				
				);	
`else
	ram_10_19_8	hash2(
					.clka		(hash2_clka					),	//ASYNC WriteClk, SYNC use wrclk
					.ena		(hash2_ena					),	//RAM write address
					.wea		(hash2_wea					),	//RAM write address
					.addra		(hash2_addra				),	//RAM read address
					.dina		(hash2_dina					),	//RAM input data
					.douta		(hash2_douta				),	//RAM output data
					.clkb		(hash2_clkb					),	//ASYNC WriteClk, SYNC use wrclk
					.enb		(hash2_enb					),  //RAM write request
					.web		(hash2_web					),	//RAM write address
					.addrb		(hash2_addrb				),  //RAM read request
					.dinb		(hash2_dinb					),	//RAM input data
					.doutb		(hash2_doutb				)	//RAM output data				
				);
`endif
endmodule