//
// David Fainitski, 2019
//  for SDR Micron project


module receiver (
	input clock,
	input rx_on,
	input signed [13:0] adc_data,
   //
	input [31:0] _rx_freq,
	input [7:0] _rx_rate,
	//
   output reg [47:0] mem_data,
	output reg [7:0] mem_addr,
	output reg mem_wen,
	output mem_block,
	output test1,
	output test2
);
   
assign test1 = rx_on;    
assign test2 = decim_avail;	
	
assign mem_block = ~mem_addr[7];

wire [7:0] rx_rate;
cdc_sync #(8)
	r_r (.siga(_rx_rate), .rstb(0), .clkb(clock), .sigb(rx_rate));
	
wire [31:0] rx_freq;
cdc_sync #(32)
	r_f (.siga(_rx_freq), .rstb(0), .clkb(clock), .sigb(rx_freq));
	
// RX phase count
localparam M2 = 32'd1876499845;  // B57 = 2^57.   M2 = B57/76800000
//localparam M2 = 32'd1172812403;  // B57 = 2^57.   M2 = B57/122880000
localparam M3 = 32'd16777216;   // M3 = 2^24, used to round the result
wire [63:0] ratio = rx_freq * M2 + M3;
wire [31:0] rx_tune_phase = ratio[56:25];

// Select CIC decimation rates based on sample_rate
reg [6:0] rate0, rate1;

always @(rx_rate)				
begin 
	case (rx_rate)	
	0: begin rate0 <= 7'd40;   rate1 <= 7'd20; end // 48k
	1: begin rate0 <= 7'd20;   rate1 <= 7'd20; end // 96k	 
	2: begin rate0 <= 7'd10;   rate1 <= 7'd20; end // 192k	  
	3: begin rate0 <= 7'd8;	   rate1 <= 7'd20; end // 240k  
	4: begin rate0 <= 7'd5;	   rate1 <= 7'd20; end // 384k
	5: begin rate0 <= 7'd8;	   rate1 <= 7'd10; end // 480k
	6: begin rate0 <= 7'd12;	rate1 <= 7'd5;  end // 640k
	7: begin rate0 <= 7'd10;	rate1 <= 7'd5;  end // 768k
	8: begin rate0 <= 7'd8;	   rate1 <= 7'd5;  end // 960k
	9: begin rate0 <= 7'd5;	   rate1 <= 7'd5;  end // 1536k
	default:
	begin    rate0 <= 7'd40;   rate1 <= 7'd20; end
	endcase
end 

//------------------------------------------------------------------------------
//                               cordic
//------------------------------------------------------------------------------
wire signed [21:0] cordic_outdata_I;
wire signed [21:0] cordic_outdata_Q;

cordic cordic_inst(
  .reset(!rx_on),
  .clock(clock),
  .in_data({adc_data, 2'b0}),    //16 bit 
  .frequency(rx_tune_phase),     //32 bit
  .out_data_I(cordic_outdata_I), //22 bit
  .out_data_Q(cordic_outdata_Q)
  );

// Receive CIC filters 
wire decimA_avail;
wire signed [17:0] decimA_real, decimA_imag;

//I channel
varcic1 
 cic_inst_I2(.decimation(rate0),
				 .clock(clock), 
				 .in_strobe(1'b1),
				 .out_strobe(decimA_avail),
				 .in_data(cordic_outdata_I),
				 .out_data(decimA_real)
				 );
				 
//Q channel
varcic1 
 cic_inst_Q2(.decimation(rate0),
				 .clock(clock), 
				 .in_strobe(1'b1),
				 .out_strobe(),
				 .in_data(cordic_outdata_Q),
				 .out_data(decimA_imag)
				 );			
			
//-----------------------------------------------------------------------------------------

wire decimB_avail;
wire signed [23:0] decimB_real, decimB_imag;

varcic2 
 varcic_inst_I1(.decimation(rate1),
				 .clock(clock), 
				 .in_strobe(decimA_avail),
				 .out_strobe(decimB_avail),
				 .in_data(decimA_real),
				 .out_data(decimB_real)
				 );
				 

//Q channel
varcic2 
 varcic_inst_Q1(.decimation(rate1),
				 .clock(clock), 
				 .in_strobe(decimA_avail),
				 .out_strobe(),
				 .in_data(decimA_imag),
				 .out_data(decimB_imag)
				 );
				 	  

wire signed [23:0]decim_real;
wire signed [23:0]decim_imag;
wire decim_avail;		
			
// Polyphase decimate by 2 FIR Filter
firX2R2 fir3 (!rx_on, clock, decimB_avail, decimB_real, decimB_imag, decim_avail, decim_imag, decim_real);			
			

//----------------------------------------------------------------------------------
//                       state machine for receiver
//----------------------------------------------------------------------------------	
	
   reg [3:0] rx_state;	
	reg [15:0] Q_mem;
	reg [31:0] IQ_mem;
	
	localparam sRx	   	= 0;
	localparam sRx1		= 1;
	localparam sRx2		= 2;
	localparam sRx3		= 3;
	localparam sRx4		= 4;
	localparam sRx5		= 5;
	localparam sRx6		= 6;

	//	
	always @(posedge clock)
	begin
      if (!rx_on)	
		begin
			mem_addr <= 8'd128; // write to second page first
			mem_wen <= 0;
			rx_state <= sRx;
		end
		else case (rx_state)
		sRx: if(decim_avail) 	
		begin  
			if(rx_rate!=8 && rx_rate !=9) // 24 bit processing	
			begin
			   mem_data <= {decim_real, decim_imag}; 
				mem_wen <= 1'd1;
			   rx_state <= sRx5;
			end
			else // 16 bit processing
			begin
				IQ_mem <= {decim_real[23:8], decim_imag[23:8]};
			   rx_state <= sRx1;
			end
		end 	
		sRx1: if(decim_avail)
		begin
		   mem_data <= {IQ_mem, decim_real[23:8]}; 
			mem_wen <= 1'd1;
			Q_mem <= {decim_imag[23:8]}; 
			rx_state <= sRx2;
		end
		sRx2:
		begin
		   mem_wen <= 1'd0;
			mem_addr <= mem_addr + 1'd1;
			rx_state <= sRx3;
		end
		sRx3: if(decim_avail)
		begin
			mem_data <= {Q_mem, decim_real[23:8], decim_imag[23:8]}; 
			mem_wen <= 1'd1;
			rx_state <= sRx4;
		end
		sRx4:
		begin
			mem_wen <= 1'd0;
			rx_state <= sRx5;
		end
		sRx5:
		begin
         if (mem_addr[6:0]!=81) 
			begin 
			   mem_addr <= mem_addr + 1'd1;
				rx_state <= sRx; 
			end	
			else 
			begin
			   mem_addr[7] <= ~mem_addr[7]; 
			   mem_addr[6:0] <= 0;  
			   rx_state <= sRx; 
			end
		end
		default: rx_state <= sRx;
		endcase
   end // always
	//
endmodule 
//