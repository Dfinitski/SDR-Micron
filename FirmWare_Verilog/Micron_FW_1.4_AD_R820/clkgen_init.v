// I2C master

module clkgen_init (
   input clock,
	input reset,
	inout reg SDA,
	inout reg SCL
	);
	
	
	
	
	reg [7:0] state;
	reg [7:0] return_state;
	reg [7:0] data;
	reg [7:0] bit_cnt;
	wire [7:0] i2c_address = 8'hD4;
	//
	reg [6:0] reg_addr;
   wire [7:0]	reg_data; 
	//
	i2c_rom reg_set(reg_addr, clock, reg_data);
	//
	
	initial 
	begin
	   SCL <= 1'bz;
		SDA <= 1'bz;
	end	
	
	//
   always @(posedge clock)
   begin
	   if (!reset)
		begin
		   state <= 0;
			bit_cnt <= 0;
			reg_addr <= 0;
		end
	   else case (state)
	   0: begin SDA <= 0; state <= 1; end // Start condition
	   1: begin SCL <= 0; data <= i2c_address; return_state <= 2; state <= 200; end // send the address
		2: begin data <= 8'h00; return_state <= 3; state <= 200; end // send the starting address h00
		//
		3: state <= 4;
	   4: begin data <= reg_data; return_state <= 5; state <= 200; end // send data
	   5: if (reg_addr != 105) begin reg_addr <= reg_addr + 1'd1; state <= 3; end
		   else begin reg_addr <= 0; state <= 6; end
		//	
	   6: begin SDA <= 0; state <= 7; end // Stop condition
		7: begin SCL <= 1'bz;  state <= 8; end
		8: begin SDA <= 1'bz; state <= 9; end
		
		9: state <= 9; 
		 //
	 200: begin // transmitt one byte
	         if (data[7 - bit_cnt] == 1) SDA <= 1'bz; else SDA <= 0; // set a bit
				state <= 201;
	      end
	 201: begin SCL <= 1'bz; state <= 202; end //clock
	 202: begin SCL <= 0; state <= 203; end
	 203: if (bit_cnt != 7) begin bit_cnt <= bit_cnt + 1'd1; state <= 200; end
	      else begin bit_cnt <= 0; SDA <= 1'bz; state <= 204; end 
	 204: begin SCL <= 1'bz; state <= 205; end // Ack
    205: begin SCL <= 0; state <= return_state; end	 
	   endcase	
   end	
	
	
endmodule	
