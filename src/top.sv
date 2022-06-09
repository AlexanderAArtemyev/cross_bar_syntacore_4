// dummy top for synthesis
`include "vars.svh"
module dummy_top(
            input               clk,
            input               reset,
            input        [5:0]  d_in[3:0],
            output logic [5:0]  d_out[3:0]
            );

    BUS                 m_bus[3:0] ();
    BUS                 s_bus[3:0] ();
    
    cross_bar dut ( clk, reset,
                m_bus[3:0],
                s_bus[3:0]
                );

    master m0(m_bus[0], d_in[0][5:2], d_out[0][1:0]);
    master m1(m_bus[1], d_in[1][5:2], d_out[1][1:0]);
    master m2(m_bus[2], d_in[2][5:2], d_out[2][1:0]);
    master m3(m_bus[3], d_in[3][5:2], d_out[3][1:0]);
    
    slave s0(s_bus[0], d_in[0][1:0], d_out[0][5:2]);
    slave s1(s_bus[1], d_in[1][1:0], d_out[1][5:2]);
    slave s2(s_bus[2], d_in[2][1:0], d_out[2][5:2]);
    slave s3(s_bus[3], d_in[3][1:0], d_out[3][5:2]);

endmodule

(* DONT_TOUCH = "yes" *)
module master   (
                BUS.slv             to_s_bus,
                input        [3:0]  d_in,
                output logic [1:0]  d_out
                );
   

    assign to_s_bus.req = d_in[0];
    assign to_s_bus.addr = {d_in[1:0],{30{d_in[3]}}};
    assign to_s_bus.cmd = d_in[2];
    assign to_s_bus.wdata = {8{d_in[3:0]}};
    
    assign d_out[0] = !to_s_bus.ack;
    assign d_out[1] = &to_s_bus.rdata;

endmodule

module slave    (
                BUS.mstr            to_m_bus,
                input        [1:0]  d_in,
                output logic [3:0]  d_out
                );



    assign to_m_bus.ack = d_in[0];
    assign to_m_bus.rdata = {16{d_in[1:0]}};

    assign d_out[0] = !to_m_bus.req;
    assign d_out[1] = &to_m_bus.addr;
    assign d_out[2] = !to_m_bus.cmd;
    assign d_out[3] = &to_m_bus.wdata;
endmodule