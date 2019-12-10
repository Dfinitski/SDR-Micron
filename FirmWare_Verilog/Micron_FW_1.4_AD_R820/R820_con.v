
// I2C master, R820 comtrol

module R820_con (
   input clock,
	input reset,
	input run,
	output reg vhf, // > 38.3 MHz
	input [31:0] freq,
	output [31:0] freq_hf,
	output reg SDA,
	output reg SCL,
	output reg test1,
	output reg test2
	);
	
	wire [31:0] freq_if = 22'd4000000 - shift;
	assign freq_hf = vhf ? freq_if : freq;
	//
	wire vhf_on = freq[31:16] > 585 & run;
   //
	reg [7:0] state;
	reg [7:0] return_state, ors;
	reg [7:0] data;
	reg [4:0] bit_cnt;
	reg [7:0] i2c_address;
	//
	reg [7:0] reg_addr;
   reg [7:0] reg_data; 
	//
	reg [4:0] rom_addr;
	wire [7:0] rom_data_on, rom_data_off;
	R820_ON_rom rom_on(rom_addr, clock, rom_data_on);
	R820_OFF_rom rom_off(rom_addr, clock, rom_data_off);
	//
	reg [31:0] freq_old;
	reg vhf_on_old;
	reg [31:0] freq_mix;
	reg [31:0] freq_buf;
	reg [19:0] step;
	reg [19:0] shift;
	reg [11:0] N_step;
	reg [7:0] N_INT;
	reg [2:0] SEL_DIV;
	reg [3:0] FRA_DIV;
	reg [3:0] LNA;

	
	always @(posedge clock)
	begin
	   if(!reset)
		begin
		   state <= 0;
			SDA <= 1;
			SCL <= 1;
		   freq_old <= 0;
			vhf_on_old <= 1;
			bit_cnt <= 0;
			vhf <= 0;
			rom_addr <= 1'd0;
			i2c_address <= 8'h34;
			step <= 20'd625000;
		end
		else case (state)
		   0: if(vhf_on != vhf_on_old)
			   begin
				   vhf_on_old <= vhf_on;
               vhf <= 1;
					test1 <= ~test1;
				   state <= 10;
			   end
				else if(vhf & (freq!=freq_old))	
			   begin
				   freq_old <= freq;
					freq_mix <= freq + 22'd4000000;
					test2 <= ~test2;
					if(vhf) state <= 1;	
				end
			1: begin 
				   FRA_DIV <= 1'd0;
					N_step <= 1'd0;
					freq_buf <= freq_mix;
					state <=  state + 1'd1;      
				end	
			2: if(freq_buf>=step) 
			   begin
	            freq_buf <= freq_buf - step;
		         N_step <= N_step + 1'd1;
		      end
	         else
	         begin
				   shift <= freq_buf[19:0];
					state <= state + 1'd1;
	         end			
		   3: begin
	            if(freq_mix[31:16]<16'd843)
					begin
					   SEL_DIV <= 3'd5;
			         N_INT <= {N_step[6:0], 1'b0} - 4'd13;			
					end
					else if(freq_mix[31:16]<16'd1688)
					begin
					   SEL_DIV <= 3'd4;
			         N_INT <= N_step[7:0] - 4'd13;
					end
					else if(freq_mix[31:16]<16'd3376)
					begin
					   SEL_DIV <= 3'd3;
			         N_INT <= N_step[8:1] - 4'd13;
						FRA_DIV[3] <= N_step[0];
					end
					else if(freq_mix[31:16]<16'd6752)
					begin
					   SEL_DIV <= 3'd2;
			         N_INT <= N_step[9:2] - 4'd13;
						FRA_DIV[3] <= N_step[1];
						FRA_DIV[2] <= N_step[0];
					end
					else if(freq_mix[31:16]<16'd13504)
					begin
					   SEL_DIV <= 3'd1;
			         N_INT <= N_step[10:3] - 4'd13;
						FRA_DIV[3] <= N_step[2];
						FRA_DIV[2] <= N_step[1];
						FRA_DIV[1] <= N_step[0];
					end
					else 
					begin
					   SEL_DIV <= 3'd0;
			         N_INT <= N_step[11:4] - 4'd13;
						FRA_DIV[3] <= N_step[3];
						FRA_DIV[2] <= N_step[2];
						FRA_DIV[1] <= N_step[1];
						FRA_DIV[0] <= N_step[0];
					end
					state <= state + 1'd1;
            end	
			4: begin // send mix_div
			      reg_data <= {SEL_DIV, 5'b00100};
					reg_addr <= 16; 
			      return_state <= state + 1'd1;
					state <= 8'd100;
				end
			5: begin // send N_INT
			      reg_data <= {N_INT[1:0], N_INT[7:2]};
					reg_addr <= 20; 
			      return_state <= state + 1'd1;
					state <= 8'd100;   
			   end
			6: begin // send FRA_DIV
			      reg_data <= {FRA_DIV[3:0], 4'b0};
					reg_addr <= 22; 
			      return_state <= state + 1'd1;
					state <= 8'd100;   
			   end	
			7: begin // send LNA gain
			      if(freq_old[31:16]<16'd2288) LNA <= 4'd7;// 150 MHz
					else if(freq_old[31:16]<16'd3814) LNA <= 4'd8; // 250
			      else if(freq_old[31:16]<16'd6103) LNA <= 4'd8; // 400
			      else if(freq_old[31:16]<16'd9155) LNA <= 4'd9;// 600
					else if(freq_old[31:16]<16'd12207) LNA <= 4'd10;// 800
					else if(freq_old[31:16]<16'd13732) LNA <= 4'd12;// 900
					else LNA <= 4'd14;                              // 1000
					reg_data <= {4'b1001, LNA};
					reg_addr <= 5; 
			      return_state <= 8;
					state <= 8'd100; 
		      end
			8: begin 
			      return_state <= 0;
					state <= 8'd100; 
				 end 
				//
		  // R820 initialization registers
		  10: state <= 11;
	     11: begin 
		         if(vhf_on_old) reg_data <= rom_data_on;
					else reg_data <= rom_data_off;
					reg_addr <= rom_addr;
					return_state <= 12;
					state <= 100;
		      end
		  12:	if(rom_addr != 31)
		      begin
				   rom_addr <= rom_addr + 1'd1;
					state <= 10;
				end
				else begin
				   rom_addr <= 0;
					if(vhf_on_old==0) vhf <= 0; 
					state <= 0;
				end
		      // write one register	
	    100: begin SDA <= 0; state <= 101; end // Start condition
	    101: begin SCL <= 0; data <= i2c_address; ors <= 102; state <= 200; end // send the I2C address
	    102: begin data <= reg_addr; ors <= 103; state <= 200; end // set the reg address
		 103: begin data <= reg_data; ors <= 104; state <= 200; end // set the reg data
		 104: begin SDA <= 0; state <= 105; end // Stop condition
		 105: begin SCL <= 1;  state <= 106; end
		 106: begin SDA <= 1; state <= return_state; end
	    //
	    200: begin // transmitt one byte
	            SDA <= data[7-bit_cnt]; 
				   state <= 201;
	         end
	    201: begin SCL <= 1; state <= 202; end //clock
	    202: begin SCL <= 0; state <= 203; end
	    203: if (bit_cnt != 7) begin bit_cnt <= bit_cnt + 1'd1; state <= 200; end
	         else begin bit_cnt <= 0; SDA <= 1; state <= 204; end 
	    204: begin SCL <= 1; state <= 205; end // Ack
       205: begin SCL <= 0; state <= ors; end
		 
		default: state <= 0;
	   endcase	
	end
	
	
	
endmodule	
