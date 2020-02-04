// SPI master

module adc_init (
   input clock,
	input reset,
	input run,
	output reg SCLK,
	output reg SDATA,
	output reg SEN,
	input[15:0] freq
	);
		
	
	// state mashine for initial
	reg [7:0] state, return_state;
	reg [4:0] address;
	reg [10:0] data;
	reg [15:0] word;
	reg [7:0] bit_cnt;
	//
	//wire gain; // Coarse gain 0-3.5dB or 2Vpp - 1.34Vpp maximum range
	wire [2:0] fine_gain = 3'd2; // fain gain 0 - 6 dB
	//							  
	always @(posedge clock)
	begin
	   if (!reset)
		begin
		   state <= 0;
			bit_cnt <= 0;
			SEN <= 1;
			SCLK <= 1;
		end
	   else
	   case (state)	
	   0: begin  // shutdown
		      address <= 5'h00;
				data <= 11'b100_0000_0101;
				return_state <= 1;
				state <= 200;
			end	
	   1: begin
		      address <= 5'h04;
				data <= 11'b00_0000_00000;
				return_state <= 2;
				state <= 200;
			end	
	   2: begin
		      address <= 5'h0A;
				data <= 11'b0_00_000_00000;
				return_state <= 3;
				state <= 200;
			end	
	   3: begin
		      address <= 5'h0C;
				data <= {fine_gain, 8'b0}; // fine gain setting
				return_state <= 4;
				state <= 200;
			end
		4: if (run)
	      begin
			   address <= 5'h00;
		      data <= 11'd0;
				return_state <= 5;
				state <= 200;
			end
		5: if(!run)// working loop
		   begin
			   address <= 5'h00;
				data <= 11'b100_0000_0101;// shutdown
				return_state <= 4;
				state <= 200;  
			end
			
		
		
	 200:	begin word <= {address, data}; SEN <= 0; state <= 201; end
	 201: begin SDATA <= word[15 - bit_cnt]; state <= 202; end
	 202: begin SCLK <= 0; state <= 203; end
	 203: if (bit_cnt != 15) begin bit_cnt <= bit_cnt +1'd1; SCLK <= 1; state <= 201; end
	      else begin bit_cnt <= 0; SEN <= 1; state <= 204; end
	 204: begin SCLK <= 1; state <= return_state; end		
	   endcase	
	
	end
   
	//

	
	
endmodule	
 