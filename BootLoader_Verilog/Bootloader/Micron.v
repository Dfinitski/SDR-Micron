

// SDR-Micron Project
// David Fainitski, N7DDC
// 2016  Berlin
// 2019  Seattle




module Micron (
   //
   // USB FT232HQ interface
	inout [7:0] usb_data,
	output n_RD,
	output n_WR,
	input n_RXF,
	input n_TXE,
	output n_SIWU,
	output n_OE,
	input USB_CLK_60MHz,
	//
   // ADC interface AD9649/9629
	input [13:0] ADC_data,
	input ADC_clock,
	input ADC_OF,
	output ADC_SCLK,
	output ADC_SDATA,
	output ADC_SEN,
	//
	// Attenuator
	output ATT_10,
	output ATT_20,
	//
	// BPF
	output [2:0] BPF,
	//
	// I2C master interface to clock generator
	inout SDA,
	inout SCL,
	//
	//  Clock routing
	output _10MHz_out,
	input _10MHz_in,
	input PLL_10MHz,
	output _usb_out,
	input _usb_in,
	//
	// FLASH interface
   output DCLK,
   output DATAOUT,
   input DATAIN,
   output FLASH_NCE,
	//
	// LEDs
	output LED_PWR,
	output LED_CLIP,
	output test_led1,
	output test_led2,
	output test1,
	output test2,
	output test3,
	output test4

	
);
   assign BPF = 1'd0;
	assign ATT_10 = 0;
	assign ATT_20 = 0;
	assign test1 = bl_mode;
	assign test2 = usb_clock;
	assign test3 = m_reset;
	assign test4 = pll2_locked;
	
	assign SDA = 1;
	assign SCL = 1;
	
	//
   assign test_led1 = bl_mode;
	assign test_led2 = b_reset;
	//
	assign LED_PWR = m_reset & pll2_locked;
	assign _10MHz_out = _10MHz_in;
	assign _usb_out = USB_CLK_60MHz;
   //
	//
	wire usb_clock, clock_01, clock_02;
	wire pll1_locked, pll2_locked;
	
	PLL1 pll1 (PLL_10MHz, clock_01, pll1_locked);
	PLL2 pll2 (_usb_in, usb_clock, clock_02, pll2_locked);

   //
	wire m_reset, b_reset;
	master_reset mres (clock_02, pll2_locked, m_reset, b_reset);
   //
	clip_led clip (clock_02, b_reset, bl_mode, LED_CLIP);
	//
	adc_init a_init(clock_01, pll1_locked, ADC_SCLK, ADC_SDATA, ADC_SEN);
	//

   usb_control u_con(usb_clock, m_reset, usb_data, n_RD, n_WR, n_RXF, n_TXE, n_SIWU, n_OE, 	
	                   erase_req, s_num, erase_done, wr_req, wr_done, wr_data, bl_mode);
   //
	wire erase_req, wr_req, erase_done, wr_done;
	wire [4:0] s_num;
	wire [2047:0] wr_data;
	flash flash_inst(.clock(clock_02), .reset(m_reset), .erase_req(erase_req), .s_num(s_num), .write_req(wr_req), .wr_data(wr_data), .erase_done(erase_done),
                   .wr_done(wr_done), .wr_address(start_addr), .DCLK(DCLK), .DATAOUT(DATAOUT), .DATAIN(DATAIN), .FLASH_NCE(FLASH_NCE));
						 
	//
	wire [23:0] start_addr = 24'h0A_00_00; // 10-th sector for FW starting
   wire addr_ready, bl_mode;
	Reconfigure Recon_inst(.reset(b_reset), .clock(clock_02), .BootAddress(start_addr),
					   .control(bl_mode), .CRC_error(), .done(), .addr_ready(1'b1)); 
	
	

	
endmodule 


