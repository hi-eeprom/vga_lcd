/////////////////////////////////////////////////////////////////////
////                                                             ////
////  Top Level Test Bench                                       ////
////                                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/cores/vga_lcd/   ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Rudolf Usselmann                         ////
////                    rudi@asics.ws                            ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: sync_check.v,v 1.1 2001-08-21 05:42:32 rudi Exp $
//
//  $Date: 2001-08-21 05:42:32 $
//  $Revision: 1.1 $
//  $Author: rudi $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//
//
//
//                        

`timescale 1ns / 10ps

module sync_check(	pclk, rst, enable, hsync, vsync, csync, blanc,
			hpol, vpol, cpol, bpol,
			thsync, thgdel, thgate, thlen,
			tvsync, tvgdel, tvgate, tvlen);

input		pclk, rst, enable, hsync, vsync, csync, blanc;
input		hpol, vpol, cpol, bpol;
input	[7:0]	thsync, thgdel;
input	[15:0]	thgate, thlen;
input	[7:0]	tvsync, tvgdel;
input	[15:0]	tvgate, tvlen;


time		last_htime;
reg		hvalid;
time		htime;
time		hhtime;

time		last_vtime;
reg		vvalid;
time		vtime;
time		vhtime;

wire	[31:0]	htime_exp;
wire	[31:0]	hhtime_exp;
wire	[31:0]	vtime_exp;
wire	[31:0]	vhtime_exp;

wire		hcheck;
wire		vcheck;

wire	[31:0]	bh_start;
wire	[31:0]	bh_end;
wire	[31:0]	bv_start;
wire	[31:0]	bv_end;

integer		bdel1;
reg		bval1;
reg		bval;
integer		bdel2;
wire		bcheck;

parameter	clk_time = 40;

assign hcheck = enable;
assign vcheck = enable;
assign hhtime_exp = (thsync + 1) * clk_time;
assign htime_exp  = (thlen + 2) * clk_time;
assign vhtime_exp = (htime_exp * (tvsync + 1));
assign vtime_exp  = htime_exp * (tvlen+2);

always @(posedge pclk)
	if(!rst | !enable)
	   begin
		hvalid = 0;
		vvalid = 0;
	   end

// Verify HSYNC Timing
always @(hsync)
   if(hcheck)
      begin
	if(hsync == ~hpol)
	   begin
		htime = $time - last_htime;
		if(hvalid & (htime != htime_exp))
			$display("HSYNC length ERROR: Expected: %0d Got: %0d (%0t)",
				htime_exp, htime, $time);
		last_htime = $time;
		hvalid = 1;
	   end

	if(hsync == hpol)
	   begin
		hhtime = $time - last_htime;
		if(hvalid & (hhtime != hhtime_exp))
			$display("HSYNC Pulse ERROR: Expected: %0d Got: %0d (%0t)",
				hhtime_exp, hhtime, $time);
	   end
      end

// Verify VSYNC Timing
always @(vsync)
   if(vcheck)
      begin
	if(vsync == ~vpol)
	   begin
		vtime = $time - last_vtime;
		if(vvalid & (vtime != vtime_exp))
			$display("VSYNC length ERROR: Expected: %0d Got: %0d (%0t)",
				vtime_exp, vtime, $time);
		last_vtime = $time;
		vvalid = 1;
	   end

	if(vsync == vpol)
	   begin
		vhtime = $time - last_vtime;
		if(vvalid & (vhtime != vhtime_exp))
			$display("VSYNC Pulse ERROR: Expected: %0d Got: %0d (%0t)",
				vhtime_exp, vhtime, $time);
	   end
      end

// Verify BLANC Timing
assign bv_start = tvsync   + tvgdel + 2;
assign bv_end   = bv_start + tvgate + 2;

assign bh_start = thsync   + thgdel + 1;
assign bh_end   = bh_start + thgate + 2;

assign bcheck = enable;

always @(vsync)
	if(vsync == ~vpol)
		bdel1 = 0;

always @(hsync)
	if(hsync == ~hpol)
		bdel1 = bdel1 + 1;

always @(bdel1)
	bval1 = (bdel1 > bv_start) & (bdel1 < bv_end);

always @(hsync)
	if(hsync == ~hpol)
		bdel2 = 0;

always @(posedge pclk)
	bdel2 = bdel2 + 1;

initial bval = 1;
always @(bdel2)
	bval = !(bval1 & (bdel2 > bh_start) & (bdel2 < bh_end));

always @(bval or blanc)
	#2
	if(enable)
	if(((blanc ^ bpol) != bval) & bcheck)
		$display("BLANK ERROR: Expected: %0d Got: %0d (%0t)",
			bval, (blanc ^ bpol), $time);

// verify CSYNC
always @(csync or vsync or hsync)
	if(enable)
	if( (csync ^ cpol) != ( (vsync ^ vpol) | (hsync ^ hpol) ) )
		$display("CSYNC ERROR: Expected: %0d Got: %0d (%0t)",
		( (vsync ^ vpol) | (hsync ^ hpol) ), (csync ^ cpol), $time);


endmodule

