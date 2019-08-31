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
	output reg erase_req,
	output reg [4:0] s_num,
	input erase_done,
	output reg wr_req,
	input wr_done,
	output reg [2047:0] wr_data,  // 256 bytes for writing a page to flash
	//
	output reg bl_mode
	//
	);
			
	
	
	// Read data from USB
	// 
	localparam idle      = 8'd0;
	localparam read      = 8'd1;
	localparam read1     = 8'd2;
	localparam read2     = 8'd3;
	localparam read3     = 8'd4;
	localparam read4     = 8'd5;
	localparam write     = 8'd10;
	localparam write1    = 8'd11;
	localparam write2    = 8'd12;
	localparam write3    = 8'd13;
	localparam write4    = 8'd14;
	
	`define CMD       buffer_24[(24-0)*8-1 -: 24] // Command from PC
	
	reg [7:0] state;
	reg [8:0] byte_cnt;
	reg [24*8-1:0] buffer_24;
	reg send_data;

   reg adc_mem_block_old;
   reg erase_done_old, wr_done_old, send_data_old;
   wire [8*8-1:0] preamble = 64'h55555555555555d5;

	
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
			send_data <= 0;
		   erase_done_old <= 0;
		   wr_done_old <= 0;
		   send_data_old <= 0;
			usb_data <= 8'bzzzz_zzzz;
			bl_mode <= 0;
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
			else if(erase_done!=erase_done_old & !n_TXE)
			begin
			  erase_done_old <= erase_done;
			  state <= write;
			end
			else if(wr_done!=wr_done_old & !n_TXE)
			begin
			  wr_done_old <= wr_done;
			  state <= write;
			end
	      else if(send_data!=send_data_old & !n_TXE)
			begin
			  send_data_old <= send_data;
			  state <= write;
			end
      //
		end	
		//
read: if(n_RXF==1) state <= read3;
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
  read1: if(byte_cnt<=22)  // receive first 23 bytes of header
	      begin
		     buffer_24[(24-byte_cnt)*8-1 -: 8] <= usb_data; 
		     byte_cnt <= byte_cnt + 1'd1;
		   end
		   else // 24-nd byte of header
		   begin
			  buffer_24[(24-byte_cnt)*8-1 -: 8] <= usb_data;
			  if(`CMD=="ERS")               // Decoding data
			  begin
				 s_num <= buffer_24[(24-3)*8-1-3 -: 5]; // Sector Number
				 erase_req <= ~erase_req;
				 state <= read3; 
			  end
			  else if(`CMD=="WPD")
			  begin
				 byte_cnt <= 1'd0;
				 state <= read2;
			  end
           else if(`CMD=="SBL")
			  begin
			    send_data <= ~send_data;
				 bl_mode <= 1;
				 state <= read3;
			  end
			  else if(`CMD=="RFW")
			  begin
				 bl_mode <= 0;
				 state <= read3;
			  end
			  // other commands
			  else begin state <= read3;  end
			end
		  //
 read2: if(byte_cnt<=255)  // receive 256 bytes data for FLASH memory writing
		  begin
		    wr_data[(256-byte_cnt)*8-1] <= usb_data[0]; // LSB is first here 
			 wr_data[(256-byte_cnt)*8-2] <= usb_data[1];
			 wr_data[(256-byte_cnt)*8-3] <= usb_data[2];
			 wr_data[(256-byte_cnt)*8-4] <= usb_data[3];
			 wr_data[(256-byte_cnt)*8-5] <= usb_data[4];
			 wr_data[(256-byte_cnt)*8-6] <= usb_data[5];
			 wr_data[(256-byte_cnt)*8-7] <= usb_data[6];
			 wr_data[(256-byte_cnt)*8-8] <= usb_data[7]; 
		    byte_cnt <= byte_cnt + 1'd1;
		  end 
		  else
		  begin
		    wr_req <= ~wr_req;
		    state <= read3;
		  end
		  //	
read3: if(n_RXF==1)
       begin
			byte_cnt <= 0;
			state <= idle;
			n_RD <= 1;
			n_OE <= 1;
			usb_data <= 8'b0000_0000;
		 end	
		  //
		  //
write: if(!n_TXE)
        begin 
		    n_WR <= 0;
          if(byte_cnt<=6) // write first 7 bytes of preamble
          begin
			   usb_data <= preamble[(8-byte_cnt)*8-1 -: 8]; 
		      byte_cnt <= byte_cnt + 1'd1;
		    end
		    else
		    begin       // Latest 8-th byte of preamble
		      usb_data <= preamble[(8-byte_cnt)*8-1 -: 8]; 
		      byte_cnt <= 1'd0;
			   state <= write1;
		    end
		  end
		  else n_WR <= 1;
		  //  
write1: if(!n_TXE)
        begin 
		    n_WR <= 0;
          if(byte_cnt<=23) // write all the buffer
          begin
		      usb_data <= buffer_24[(24-byte_cnt)*8-1 -: 8];
		      byte_cnt <= byte_cnt + 1'd1;
          end		  
		    else
		    begin
		      n_WR <= 1;
				n_SIWU <= 0;
				byte_cnt <= 0;
		      state <= write2;
		    end
		  end	 
		  else n_WR <= 1;	 
		  //		
write2: begin
          n_SIWU <= 1;
			 state <= idle;
        end	
		 // 
 		//		
default: state <= idle;
      endcase		
   //
   end		
	//	
	//
endmodule	






	