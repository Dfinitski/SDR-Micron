//
// N7DDC, David Fainitski
// project Odyssey-II
// 04.2018
//

/*
 
	EPCS616
	
	Bytes 				= 2M
	Sectors				= 32
	Bytes per sector 	= 65k
	Pages per sector 	= 256
	Number of pages  	= 8192
	Bytes per page   	= 256
	
	Address Range (Byte Addresses in HEX)
	
	Sector	Start    End
	//
	31 		H'1F0000 H'1FFFFF
	30 		H'1E0000 H'1EFFFF
	29 		H'1D0000 H'1DFFFF
	28 		H'1C0000 H'1CFFFF
	27 		H'1B0000 H'1BFFFF
	26 		H'1A0000 H'1AFFFF
	25 		H'190000 H'19FFFF
	24 		H'180000 H'18FFFF
	23 		H'170000 H'17FFFF
	22 		H'160000 H'16FFFF
	21 		H'150000 H'15FFFF
	20 		H'140000 H'14FFFF
	19 		H'130000 H'13FFFF
	18 		H'120000 H'12FFFF
	17 		H'110000 H'11FFFF
	16 		H'100000 H'10FFFF
	15 		H'0F0000 H'0FFFFF
	14 		H'0E0000 H'0EFFFF
	13 		H'0D0000 H'0DFFFF
	12 		H'0C0000 H'0CFFFF
	11 		H'0B0000 H'0BFFFF
	10 		H'0A0000 H'0AFFFF
	 9 		H'090000 H'09FFFF
	 8 		H'080000 H'08FFFF
	 7 		H'070000 H'07FFFF
	 6 		H'060000 H'06FFFF
	 5 		H'050000 H'05FFFF
	 4 		H'040000 H'04FFFF
	 3 		H'030000 H'03FFFF
	 2 		H'020000 H'02FFFF
	 1 		H'010000 H'01FFFF
	 0 		H'000000 H'00FFFF		
		
Each Sector holds 256 Pages each of 256 bytes

*/

	
module flash (
input clock,
input reset,  
input erase_req,
input [4:0] s_num,
input write_req,
input [2047:0] wr_data,
output reg erase_done,
output reg wr_done,
input [23:0] wr_address,
	
	
// FLASH interface
output reg DCLK,
output reg DATAOUT,
input      DATAIN,
output reg FLASH_NCE
);

	
parameter sSendCom   = 8'd50;
parameter sSendCom1  = 8'd51;
parameter sSendCom2  = 8'd52;
parameter sSendCom3  = 8'd53;
parameter sSendAddr  = 8'd60;
parameter sSendAddr1 = 8'd61;
parameter sSendAddr2 = 8'd62;
parameter sSendAddr3 = 8'd63;
parameter sReadSrv   = 8'd70;
parameter sReadSrv1  = 8'd71;
parameter sReadSrv2  = 8'd72;
parameter sReadSts   = 8'd80;
parameter sReadSts1  = 8'd81;
parameter sReadSts2  = 8'd82;
parameter sWriteSrv  = 8'd90;
parameter sWriteSrv1 = 8'd91;
parameter sWriteSrv2 = 8'd92;
parameter sWriteSrv3 = 8'd93;
	
	
reg [15:0] bit_cnt;
reg [7:0] command, status;
reg [23:0] address; 
reg [7:0] state, return_state;
reg erase_req_old, write_req_old;
	
	
always @(posedge clock)
begin
   if(!reset)
	begin
	   erase_done <= 0;
		wr_done <= 0;
		state <= 0;
		return_state <= 0;
		erase_req_old <= 0;
		write_req_old <= 0;
	end
	else
   case (state)
	0: begin
	      DCLK <= 0;
	      DATAOUT <= 0;
	      FLASH_NCE <= 1;
	      if(erase_req != erase_req_old)
		   begin
		      erase_req_old <= erase_req;
			   address[23:0] <= wr_address; // starting address
			   state <= 1'd1;
		   end
		   else if(write_req != write_req_old)
		   begin
		      write_req_old <= write_req;
			   state <= 5'd10;
		   end
	   end
	1: begin  // Erasing 
		    command <= 8'h06; // write enable command
			 return_state <= state + 1'd1;
			 state <= sSendCom;
		end
	2: begin
			 FLASH_NCE <= 1;
			 command <= 8'hD8;      //  erase sector command
			 return_state <= state + 1'd1;
			 state <= sSendCom;				
		end	
	3: begin 
			 return_state <= state + 1'd1;
			 address[23:16] <= wr_address[23:16] + s_num; // sector number
			 state <= sSendAddr;
		end	
	4: begin     // waiting for the finish of erasing
			 FLASH_NCE <= 1;
			 command <= 8'h05;  // read status command
			 return_state <= state + 1'd1;
			 state <= sSendCom; 
	   end
   5: begin
		    return_state <= state + 1'd1;
			 state <= sReadSts;
	   end
   6: if(status[0] == 1)  // erasing is finished ?
		   state <= 8'd4; 
		else
	   begin
		   erase_done <= ~erase_done;
			address <= wr_address; // starting address
		   state <= 1'd0; 
		end	
		//
		//
  10: begin // Writing the page (256 bytes of data)
		   command <= 8'h06; // write enable command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end
  11: begin	 
         FLASH_NCE <= 1;  
			command <= 8'h02;   // writing data command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end 
  12: begin
			return_state <= state + 1'd1; // write address
			state <= sSendAddr; 
		end
  13: begin
		   return_state <= state + 1'd1; // starting to write data
			state <= sWriteSrv;
		end
  14: begin  // waiting for the finish
		   command <= 8'h05;  // read status command
			return_state <= state + 1'd1;
			state <= sSendCom;
		end
  15: begin
		   return_state <= state + 1'd1; // read status
			state <= sReadSts;
	   end
  16: if (status[0] == 1) 
         state <= 8'd14; // check again
		else
	      begin	
			   wr_done <= !wr_done;
				address[23:8] <= address[23:8] + 1'd1; // insrease address for writing next page
			   state <= 1'd0;	
         end			
			// 
         //
 sSendCom :	begin    
               bit_cnt <= 8'd7;
					FLASH_NCE <= 0;
					state <= sSendCom1;
            end
 sSendCom1:	begin
               DATAOUT <= command[bit_cnt]; 
					state <= sSendCom2;
				end
 sSendCom2:	begin
               DCLK <= 1;
				   state <= sSendCom3;
				end
 sSendCom3:	begin
               DCLK <= 0;
				   if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sSendCom1; end
				   else state <= return_state; 
				end
//			
 sSendAddr: begin
               bit_cnt <= 8'd23;
					state <= sSendAddr1;
            end
 sSendAddr1: begin
               DATAOUT <= address[bit_cnt];
					state <= sSendAddr2;
            end				
 sSendAddr2: begin
               DCLK <=1;
					state <= sSendAddr3;
            end
 sSendAddr3: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sSendAddr1; end
					else state <= return_state;
            end	
//
  sReadSts: begin
               bit_cnt <= 8'd7;
					state <= sReadSts1;
            end				
 sReadSts1: begin
               status[bit_cnt] <= DATAIN;
				   DCLK <= 1;	
					state <= sReadSts2;
            end
 sReadSts2: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sReadSts1; end
					else begin FLASH_NCE <= 1; state <= return_state; end
            end
//			
 sWriteSrv: begin
               bit_cnt <= 16'd2047; 
	            state <= sWriteSrv1;			  
            end 
sWriteSrv1: begin
               DATAOUT <= wr_data[bit_cnt];
	            state <= sWriteSrv2;			  
            end 
sWriteSrv2: begin
               DCLK <= 1;
	            state <= sWriteSrv3;			  
            end
sWriteSrv3: begin
               DCLK <= 0;
					if (bit_cnt != 0) begin bit_cnt <= bit_cnt - 1'd1; state <= sWriteSrv1; end
	            else begin FLASH_NCE <= 1; state <= return_state; end		
				end									
//	
			
	default: state <= 1'd0;
	endcase
end	
	
	

endmodule
	