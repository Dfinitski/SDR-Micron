//
//**********************************************************
// USB receive/transmitt data module
// David Fainitski for SDR-Micron project
// 2019
//**********************************************************
//
//
//

module usb_control (
   input usb_clock,  // 60 MHz from USB PHY 
	input reset,
	//
	inout reg [7:0] usb_data,
	output reg n_RD,
	output reg n_WR,
	input n_RXF,
	input n_TXE,
	output reg n_SIWU,
	output reg n_OE,
	//
	input [47:0] adc_mem_data,
	output reg [7:0] adc_mem_addr,
	input _adc_mem_block,
	//
	input [15:0] bs_mem_data,
   output reg [14:0] bs_mem_addr,
   input	_bs_ready,
	//
	input clip,
	//
	output reg rx_on,
	output reg bs_on,
	output reg [7:0] bs_period,
	output reg [7:0] ATT,
	output reg [31:0] rx_freq,
	output reg [7:0] rx_rate
	//
	);
   	
	
   parameter FW1 = "1";
   parameter FW2 = "0";
	
	wire adc_mem_block;
	cdc_sync #(1)
	a_m_b (.siga(_adc_mem_block), .rstb(0), .clkb(usb_clock), .sigb(adc_mem_block)); 

	wire bs_ready;
	cdc_sync #(1)
	b_r (.siga(_bs_ready), .rstb(0), .clkb(usb_clock), .sigb(bs_ready));

	
	// 
	localparam idle      = 5'd0;
	localparam read      = 5'd1;
	localparam read1     = 5'd2;
	localparam read2     = 5'd3;
	localparam write     = 5'd4;
	localparam write1    = 5'd5;
	localparam write2    = 5'd6;
	localparam write3    = 5'd7;
	localparam wait_1    = 5'd8;

	
	`define CMD       buffer_24[(24-0)*8-1 -: 24] // Command from PC
	`define rx_on     buffer_24[(24-3)*8-8]
	`define bs_on     buffer_24[(24-3)*8-8]
	`define rx_rate   buffer_24[(24-4)*8-1 -: 8]
	`define rx_freq   buffer_24[(24-5)*8-1 -: 32]
	`define ATT       buffer_24[(24-9)*8-1 -: 8]
	`define bs_period buffer_24[(24-4)*8-1 -: 8]
	
	reg [4:0] state, return_state;
	reg [8:0] byte_cnt;
	reg [2:0] sub_byte_cnt;
	reg [24*8-1:0] buffer_24;
	reg bs_ready_old;
	reg adc_mem_block_old;
	reg rx_send, bs_send;
	reg [7:0] PN;
	
   //
   wire [8*8-1:0] preamble = 64'h55555555555555d5;
	wire [8*8-1:0] header = rx_send ? {"RX0", FW1, FW2, {7'b0, clip}, 16'b0} :
	                        bs_send ? {"BS0", FW1, FW2, {7'b0, clip}, PN, 8'b0} :
									64'd0;
   //
	
	reg [47:0] adc_mem_buff;
	always @(posedge usb_clock) adc_mem_buff <= adc_mem_data;
	
   always @(negedge reset or negedge usb_clock)
   begin
	   if(!reset)
		begin
		   state <= 0;
			n_OE <= 1;
			n_RD <= 1;
			n_WR <= 1;
			n_SIWU <= 1;
			byte_cnt <= 0;
			sub_byte_cnt <= 0;
			usb_data <= 8'bzzzz_zzzz;
			rx_on <= 0;
			bs_on <= 0;
			rx_rate <= 0;
			rx_freq <= 0;
			adc_mem_block_old <= 0;
			rx_send <= 0;
			bs_send <= 0;
			bs_ready_old <= 0;
			bs_mem_addr <= 0;
			PN <= 0;
			bs_period <= 8'd100;
			rx_freq <= 1'd0;
		end
		else
		case(state)
idle:	begin
         if(n_RXF==0)
			begin
				n_RD <= 0;
			   n_OE <= 0;
			 	usb_data <= 8'bzzzz_zzzz;
			   state <= read;
			end
		   else if(adc_mem_block!=adc_mem_block_old & !n_TXE)
			begin
			   adc_mem_block_old <= adc_mem_block;
			   rx_send <= 1;
			   adc_mem_addr[7] <= adc_mem_block;
			   adc_mem_addr[6:0] <= 7'd0;
			   state <= write;
			end 	
			else if(bs_ready!=bs_ready_old & !n_TXE)
			begin
			   bs_send <= 1;
			   state <= write;
			end
		end	
		//
read: if(n_RXF==1) state <= read2;
      else
      begin	
			if(usb_data==8'h55 & byte_cnt<=6) byte_cnt <= byte_cnt + 1'd1; // detection of 7 bytes of preamble h55
			else if(byte_cnt==7 & usb_data==8'hd5)          //  8th byte, delimitter
			begin
		      byte_cnt <= 0;
				state <= read1;
		   end
		   else byte_cnt <= 0;                   // reset counter if preamble is wrong
		end 
		//
read1:if(byte_cnt<=22)  // receive first 23 bytes of header
	   begin
		  buffer_24[(24-byte_cnt)*8-1 -: 8] <= usb_data; 
		  byte_cnt <= byte_cnt + 1'd1;
		end
		else // 24-nd byte of header
		begin
		  buffer_24[(24-byte_cnt)*8-1 -: 8] <= usb_data;
		  if(`CMD=="RX0")               // Decoding data
		  begin
		    rx_on <= `rx_on;
			 rx_rate <= `rx_rate;
			 rx_freq <= `rx_freq;
			 ATT <= `ATT;
			 state <= read2; 
		  end
		  else if(`CMD=="BS0")
		  begin
		    bs_on <= `bs_on;
			 bs_period <= `bs_period;
			 state <= read2;
		  end
		  // other commands
		  else state <= read2; 
		end
		  //
read2: if(n_RXF==1)
       begin
			 byte_cnt <= 0;
			 state <= idle;
		    n_RD <= 1;
			 n_OE <= 1;
			 usb_data <= 8'b0000_0000;
		 end	 
		 //
		  //
write:  if(n_TXE) begin n_WR <= 1; return_state <= write; state <= wait_1; end
        else
        begin 
		    n_WR <= 0;
          if(byte_cnt<=7) // write 8 bytes of preamble
          begin
			   usb_data <= preamble[(8-byte_cnt)*8-1 -: 8]; 
		      byte_cnt <= byte_cnt + 1'd1;
		    end
		    else if(byte_cnt<=8+6) // send 7 bytes of header
		    begin       
		      usb_data <= header[(8-(byte_cnt-8))*8-1 -: 8]; 
				byte_cnt <= byte_cnt + 1'd1;
		    end
			 else
			 begin // last 8-th byte of header
			   usb_data <= header[(8-(byte_cnt-8))*8-1 -: 8]; 
		      byte_cnt <= 1'd0;
				sub_byte_cnt <= 1'd0;
				if(rx_send)
				begin
				  rx_send <= 0;
				  state <= write1;
				end
		      else if(bs_send) 
				begin
				  bs_send <= 0;
				  state <= write2;
				end  
			 end
		  end
		  //  
		  //
write1: if(n_TXE) begin n_WR <= 1; return_state <= write1; state <= wait_1; end
        else
        begin
		     n_WR <= 0;
		    if(byte_cnt<=491)  // send 492 bytes of rx data 
		    begin
				if(sub_byte_cnt==4)
					adc_mem_addr <= adc_mem_addr + 1'd1;
				if(sub_byte_cnt==5) sub_byte_cnt <= 1'd0;
				else sub_byte_cnt <= sub_byte_cnt + 1'd1;
				usb_data <= adc_mem_buff[(6-sub_byte_cnt)*8-1 -: 8];
				byte_cnt <= byte_cnt + 1'd1;
			 end
			 else
		    begin
		      n_WR <= 1;
				n_SIWU <= 0;
		      state <= write3;
		    end
	     end	  
		  //
		  //
write2: if(n_TXE) begin n_WR <= 1; return_state <= write2; state <= wait_1; end
        else
        begin 
		    n_WR <= 0;
			 //
		    if(byte_cnt<=491) // 492 bytes of data
			 begin
				usb_data <= bs_mem_data[(2-sub_byte_cnt[0])*8-1 -: 8];
				sub_byte_cnt[0] <= ~sub_byte_cnt[0];
				if(sub_byte_cnt) bs_mem_addr <= bs_mem_addr + 1'd1;
				byte_cnt <= byte_cnt + 1'd1;
			 end
		    else
		    begin
				if(PN<66) PN <= PN + 1'd1;
				else 
				begin
				  PN <= 0;
				  bs_mem_addr <= 1'd0;
				  bs_ready_old <= bs_ready; // 67 packets were sent
				end
				n_WR <= 1;
				n_SIWU <= 0;
				
		      state <= write3;
		    end
		  end	  
		  //	
write3: begin
          n_SIWU <= 1;
			 byte_cnt <= 0;
			 sub_byte_cnt <= 0;
          state <= idle;
        end		  	
		 //
wait_1: if(!n_TXE)
        begin
		     n_WR <= 0;
		     state <= return_state;
		  end 

		 
default: begin;
			  n_WR <= 1;
			  byte_cnt <= 0;
			  sub_byte_cnt <= 0;
		     n_RD <= 1;
			  n_OE <= 1;
			  n_SIWU <= 1;
			  usb_data <= 8'b0000_0000;
           state <= idle;
			end  
      endcase		
   //
   end		
	//	
	//
endmodule	






	