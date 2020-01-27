

// SDR-Micron Project
// David Fainitski, N7DDC
// 2016  Berlin
// 2019 Seattle




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
   // ADC interface ADS6143
	input [13:0] ADC_data,
	input ADC_clock,
	input ADC_OF,
	//
	// Attenuator
	output ATT_SCLK,
	output ATT_SDATA,
	output ATT_SEN,
	//
	// BPF
	output BPF_0,
	output BPF_1,
	output BPF_2,   
	output VHF,
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
   //assign test_led1 = 0;
	//assign test_led2 = 0;
	assign test1 = 0;
	assign test2 = 0;
	assign test3 = 0;
	assign test4 = 0;

   parameter [7:0] FW1 = "1"; // First digit
	parameter [7:0] FW2 = "4"; // Second digit
	//
	assign LED_PWR = m_reset & pll2_locked;
	//
	assign _10MHz_out = _10MHz_in;
	assign _usb_out = USB_CLK_60MHz;
	//
   assign test_led1 = pll2_locked;
	assign test_led2 = rx_on;
	//
	clkgen_init c_init(clock_02, m_reset, SDA, SCL);
	//
	bpf_ctrl bpf(clock_02, m_reset, rx_freq, rx_freq_hf, BPF_0, BPF_1, BPF_2, VHF);
	//
	wire rx_clock, f_clock, usb_clock, clock_02;
	wire pll1_locked, pll2_locked;
	
	PLL1 pll1 (ADC_clock, rx_clock, f_clock, pll1_locked);
	PLL2 pll2 (_usb_in, usb_clock, clock_02, pll2_locked);

   //
	wire m_reset;     
	master_reset mres (clock_02, pll2_locked, m_reset);
   //
	clip_led clip (clock_02, m_reset, rx_on, ADC_OF, LED_CLIP);
	//
	attenuator attn (clock_02, m_reset, (rx_on | bs_on), att, ATT_SCLK, ATT_SDATA, ATT_SEN);

	//
	wire rx_on, bs_on;
	wire [7:0] att;
	wire[31:0] rx_freq;
   usb_control #(FW1, FW2) u_con(usb_clock, m_reset, usb_data, n_RD, n_WR, n_RXF, n_TXE, n_SIWU, n_OE, 
	                   adc_ram_rd_data, adc_ram_rd_addr, adc_ram_block, bs_ram_rd_data, bs_ram_rd_addr, bs_ready,
	                   LED_CLIP, rx_on, bs_on, bs_period, att, rx_freq, rx_rate);
   //
	
	// Memory for samples, 2 pages per 256 words by 48 bits 
	wire [47:0] adc_ram_wr_data, adc_ram_rd_data;
	wire [7:0] adc_ram_wr_addr, adc_ram_rd_addr;
	wire adc_ram_wen;
	adc_ram ram1 (.data(adc_ram_wr_data), .wraddress(adc_ram_wr_addr), .wrclock(~rx_clock), .wren(adc_ram_wen),
                   	.rdaddress(adc_ram_rd_addr), .rdclock(usb_clock), .q(adc_ram_rd_data));
	//
	// read and register ADC data
	reg [13:0] adc_data_reg;
	always @(posedge rx_clock) adc_data_reg <= ADC_data;
	//
	
   wire adc_ram_block;
	wire [31:0] rx_freq_hf;
	wire [7:0] rx_rate;
	receiver rcv_inst (rx_clock, f_clock, rx_on, VHF, adc_data_reg, rx_freq_hf, rx_rate, 
              	   adc_ram_wr_data, adc_ram_wr_addr, adc_ram_wen, adc_ram_block);
	//
	
	// BS memory for samples, 32768 bytes, 16384 16bit words
	wire [15:0] bs_ram_wr_data, bs_ram_rd_data;
	wire [14:0] bs_ram_wr_addr, bs_ram_rd_addr;
	wire bs_ram_wen;
	bs_ram ram2 (.data({ADC_data, 2'd0}), .wraddress(bs_ram_wr_addr), .wrclock(rx_clock), .wren(!bs_ready), 
	                    .rdaddress(bs_ram_rd_addr), .rdclock(usb_clock), .q(bs_ram_rd_data));	
	//
	wire bs_ready;
	wire [7:0] bs_period;
	wire rawRamReset, rawRamReady;
	bandscope bs_inst (rx_clock, bs_on, bs_period, bs_ready, bs_ram_wr_addr, clock_02);	
	//  

	
endmodule 


