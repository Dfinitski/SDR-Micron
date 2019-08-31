//
// cic - A Cascaded Integrator-Comb filter
//
// Copyright (c) 2008 Alex Shovkoplyas, VE3NEA
// Copyright (c) 2013 Phil Harman, VK6PH
// Copyright (c) 2015 Jeremy McDermond, NH6Z
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.


// 2019 - Modified to correct work with decimation rate 5, 8, 10, 12, 20, 40. David Fainitski, N7DDC 

module varcic1 (decimation, clock, in_strobe,  out_strobe, in_data, out_data );

  //design parameters
  parameter STAGES = 3; //  Sections of both Comb and Integrate
  parameter [5:0] IN_WIDTH = 22;
  parameter OUT_WIDTH = 18;

  // derived parameters
  parameter L2MD = 6; // $clog2(MAX_DECIMATION));
  parameter ACC_WIDTH = IN_WIDTH + (STAGES * L2MD);
  
  input [7:0] decimation; 
  
  input clock;
  input in_strobe;
  output reg out_strobe;

  input signed [IN_WIDTH-1:0] in_data;
  output signed[OUT_WIDTH-1:0] out_data;


//------------------------------------------------------------------------------
//                               control
//------------------------------------------------------------------------------
reg [L2MD-1:0] sample_no = 0;

generate
	always @(posedge clock)
		if (in_strobe) 
			if (sample_no == (decimation - 1'd1)) begin
				sample_no <= 0;
				out_strobe <= 1;
			end else begin
				sample_no <= sample_no + 1'd1;
     				out_strobe <= 0;
			end
		else
			out_strobe <= 0;
endgenerate

//------------------------------------------------------------------------------
//                                stages
//------------------------------------------------------------------------------
reg signed [ACC_WIDTH-1:0] integrator_data [1:STAGES];
reg signed [ACC_WIDTH-1:0] comb_data [1:STAGES];
reg signed [ACC_WIDTH-1:0] comb_last [0:STAGES];

always @(posedge clock) begin
	integer index;
	
	//  Integrators
	if(in_strobe) begin
		integrator_data[1] <= integrator_data[1] + in_data;
		for(index = 1; index < STAGES; index = index + 1) begin
			integrator_data[index + 1] <= integrator_data[index] + integrator_data[index+1];
		end
	end

	// Combs
	if(out_strobe) begin
		comb_data[1] <= integrator_data[STAGES] - comb_last[0];
		comb_last[0] <= integrator_data[STAGES];
		for(index = 1; index < STAGES; index = index + 1) begin
			comb_data[index + 1] <= comb_data[index] - comb_last[index];
			comb_last[index] <= comb_data[index]; 
		end
	end
end

//------------------------------------------------------------------------------
//                            output rounding
//------------------------------------------------------------------------------

localparam [4:0] GROWTH5  = 7; //clog2(decimation ** STAGES)
localparam [4:0] GROWTH8  = 9; 
localparam [4:0] GROWTH10 = 10;
localparam [4:0] GROWTH12 = 11; 
localparam [4:0] GROWTH20 = 13;
localparam [4:0] GROWTH40 = 16; 

localparam [5:0] msb5  =  IN_WIDTH + GROWTH5; // of 40
localparam [5:0] msb8  =  IN_WIDTH + GROWTH8;
localparam [5:0] msb10 =  IN_WIDTH + GROWTH10; 
localparam [5:0] msb12 =  IN_WIDTH + GROWTH12;
localparam [5:0] msb20 =  IN_WIDTH + GROWTH20; 
localparam [5:0] msb40 =  IN_WIDTH + GROWTH40;


wire [5:0] msb = decimation==5  ? msb5  :
                 decimation==8  ? msb8  :
                 decimation==10 ? msb10 :
					  decimation==12 ? msb12 :
					  decimation==20 ? msb20 :
					  decimation==40 ? msb40 :
					  msb40;

assign out_data = comb_data[STAGES][msb -: OUT_WIDTH] + comb_data[STAGES][msb - OUT_WIDTH];

endmodule

//__________________________________________________________________________________________________________

// 2019 - Modified to correct work with decimation rate 5, 10, 20. David Fainitski, N7DDC

//__________________________________________________________________________________________________________


module varcic2 (decimation, clock, in_strobe,  out_strobe, in_data, out_data );

  //design parameters
  parameter STAGES = 11; //  Sections of both Comb and Integrate
  parameter [5:0] IN_WIDTH = 18;
  parameter OUT_WIDTH = 24;

  // derived parameters
  parameter L2MD = 5; // $clog2(MAX_DECIMATION));
  parameter ACC_WIDTH = IN_WIDTH + (STAGES * L2MD);
  
  input [6:0] decimation; 
  
  input clock;
  input in_strobe;
  output reg out_strobe;

  input signed [IN_WIDTH-1:0] in_data;
  output signed[OUT_WIDTH-1:0] out_data;


//------------------------------------------------------------------------------
//                               control
//------------------------------------------------------------------------------
reg [L2MD-1:0] sample_no = 0;

generate
	always @(posedge clock)
		if (in_strobe) 
			if (sample_no == (decimation - 1'd1)) begin
				sample_no <= 0;
				out_strobe <= 1;
			end else begin
				sample_no <= sample_no + 1'd1;
     				out_strobe <= 0;
			end
		else
			out_strobe <= 0;
endgenerate

//------------------------------------------------------------------------------
//                                stages
//------------------------------------------------------------------------------
reg signed [ACC_WIDTH-1:0] integrator_data [1:STAGES];
reg signed [ACC_WIDTH-1:0] comb_data [1:STAGES];
reg signed [ACC_WIDTH-1:0] comb_last [0:STAGES];

always @(posedge clock) begin
	integer index;

	//  Integrators
	if(in_strobe) begin
		integrator_data[1] <= integrator_data[1] + in_data;
		for(index = 1; index < STAGES; index = index + 1) begin
			integrator_data[index + 1] <= integrator_data[index] + integrator_data[index+1];
		end
	end

	// Combs
	if(out_strobe) begin
		comb_data[1] <= integrator_data[STAGES] - comb_last[0];
		comb_last[0] <= integrator_data[STAGES];
		for(index = 1; index < STAGES; index = index + 1) begin
			comb_data[index + 1] <= comb_data[index] - comb_last[index];
			comb_last[index] <= comb_data[index]; 
		end
	end
end

//------------------------------------------------------------------------------
//                            output rounding
//------------------------------------------------------------------------------

localparam [5:0] GROWTH5  = 26; //clog2(decimation ** STAGES)
localparam [5:0] GROWTH10 = 36;
localparam [5:0] GROWTH20 = 48;

localparam [6:0] msb5  =  IN_WIDTH + GROWTH5; //of73
localparam [6:0] msb10 =  IN_WIDTH + GROWTH10; 
localparam [6:0] msb20 =  IN_WIDTH + GROWTH20; 


wire [6:0] msb = decimation==5  ? msb5 :
                 decimation==10 ? msb10 :
					  decimation==20 ? msb20 :
					  msb20;

assign out_data = comb_data[STAGES][msb -: OUT_WIDTH] + comb_data[STAGES][msb - OUT_WIDTH];


endmodule

