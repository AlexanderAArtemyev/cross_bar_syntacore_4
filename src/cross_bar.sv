//  0.1 - 4 port cross-bar
//  Explanation:  4 masters / 4 slaves commutator for read/write operations
//  Comments: rdata comes next clock after ack

`include "vars.svh"
`timescale  1ns/1ps

module cross_bar    #(parameter N = Nr) (
                    input       clk,
                    input       reset,
                    BUS.mstr    m_bus [3:0],
                    BUS.slv     s_bus [3:0]
                    );

    logic [3:0]   m_ack [3:0];              // vector with chosen master from each slave
    logic [3:0]   s_rdata_ack [3:0];        // vector that shows for wich master rdata comes from slave
    logic [3:0]   m_rdata_ack [3:0];        // vector that shows from wich slave rdata comes to master
    logic [N-1:0] s_rdata [3:0];

    arbiter_4 #(.N(N), .M(0)) arb0 (clk, reset, m_bus[3:0], m_ack[0], s_rdata_ack[0], s_bus[0]);
    arbiter_4 #(.N(N), .M(1)) arb1 (clk, reset, m_bus[3:0], m_ack[1], s_rdata_ack[1], s_bus[1]);
    arbiter_4 #(.N(N), .M(2)) arb2 (clk, reset, m_bus[3:0], m_ack[2], s_rdata_ack[2], s_bus[2]);
    arbiter_4 #(.N(N), .M(3)) arb3 (clk, reset, m_bus[3:0], m_ack[3], s_rdata_ack[3], s_bus[3]);

    generate
        genvar i;
        for (i=0; i < 4; i=i+1) begin
            assign m_bus[i].ack = m_ack[0][i] || m_ack[1][i] || m_ack[2][i] || m_ack[3][i];
        end
    endgenerate

    generate
        genvar j;
        for (j=0; j < 4; j=j+1) begin
            assign m_rdata_ack[j] = {s_rdata_ack[3][j], s_rdata_ack[2][j], s_rdata_ack[1][j], s_rdata_ack[0][j]};
        end
    endgenerate

    assign s_rdata = {s_bus[3].rdata, s_bus[2].rdata, s_bus[1].rdata, s_bus[0].rdata};
    mux4 #(.N(N)) mux0 (m_rdata_ack[0], s_rdata, m_bus[0].rdata);
    mux4 #(.N(N)) mux1 (m_rdata_ack[1], s_rdata, m_bus[1].rdata);
    mux4 #(.N(N)) mux2 (m_rdata_ack[2], s_rdata, m_bus[2].rdata);
    mux4 #(.N(N)) mux3 (m_rdata_ack[3], s_rdata, m_bus[3].rdata);

    // Assertions block
    // Warning if any ack delayed more then 3 clocks
    property pr_l(bit req, bit ack);
        @(negedge clk) req |-> ##[0:3] ack;
    endproperty

    l_1: assert property(pr_l(m_bus[0].req, m_bus[0].ack))  
                else $warning("!! Ack time of m0 fail!");
    l_2: assert property(pr_l(m_bus[1].req, m_bus[1].ack))  
                else $warning("!! Ack time of m1 fail!");
    l_3: assert property(pr_l(m_bus[2].req, m_bus[2].ack))  
                else $warning("!! Ack time of m2 fail!");
    l_4: assert property(pr_l(m_bus[3].req, m_bus[3].ack))  
                else $warning("!! Ack time of m3 fail!");
endmodule


module arbiter_4    #(parameter N = Nr,
                      parameter M = 0)                      // M number of slave
                    ( 
                    input               clk,
                    input               reset,
                    BUS.mstr            m_bus [3:0],
                    output logic [3:0]  m_ack,
                    output logic [3:0]  m_rdata_ack,
                    BUS.slv             s_bus
                    );
    
    logic [1:0] s_addr = M;
    logic [3:0] m_req;
    logic [3:0] m_addr;
    logic [3:0] m_to_s;                                     // Vector of masters requests to slave
    logic [3:0] m_ch;                                       // Vector of masters with requests yet not taken
    logic [1:0] cnt, next_cnt;
    logic [3:0] ack_en;
    logic       conc;
    logic [1:0] sum;
    
    assign m_addr = {(m_bus[3].addr[N-1:N-2] == s_addr),
                     (m_bus[2].addr[N-1:N-2] == s_addr),
                     (m_bus[1].addr[N-1:N-2] == s_addr),
                     (m_bus[0].addr[N-1:N-2] == s_addr)};
    
    assign m_req = {m_bus[3].req, m_bus[2].req, m_bus[1].req, m_bus[0].req};

    assign m_to_s = m_req & m_addr;

    always_comb begin                                       // check for concurency
        sum = m_ch[3] + m_ch[2] + m_ch[1] + m_ch[0];
        conc = (sum > 1);   
    end

    always_ff @(posedge clk or negedge reset) begin         // concurent request counter
        if(!reset) begin
            cnt <= 0;
        end
        else if (conc) begin            
            if (s_bus.ack) begin
                cnt <= next_cnt;
            end 
        end
        else
            cnt <= 0;
    end

    always_comb begin
        case(cnt)
            2'b00: m_ch = m_to_s;
            2'b01: m_ch = {1'b0,   m_to_s[2:0]};
            2'b10: m_ch = {2'b00,  m_to_s[1:0]};
            2'b11: m_ch = {3'b000, m_to_s[0]};
            default: m_ch = m_to_s;
        endcase 
    end

    always_comb begin                                            // priority block for multiple requests
        casez(m_ch)
            4'b1???: begin 
                        s_bus.req   = m_bus[3].req;
                        s_bus.addr  = m_bus[3].addr;
                        s_bus.cmd   = m_bus[3].cmd;
                        s_bus.wdata = m_bus[3].wdata;
                        ack_en = 4'b1000;
                        next_cnt = 1;
            end    
            4'b01??: begin
                        s_bus.req   = m_bus[2].req;
                        s_bus.addr  = m_bus[2].addr;
                        s_bus.cmd   = m_bus[2].cmd;
                        s_bus.wdata = m_bus[2].wdata;
                        ack_en = 4'b0100;
                        next_cnt = 2;
            end
            4'b001?: begin 
                        s_bus.req   = m_bus[1].req;
                        s_bus.addr  = m_bus[1].addr;
                        s_bus.cmd   = m_bus[1].cmd;
                        s_bus.wdata = m_bus[1].wdata;
                        ack_en = 4'b0010;
                        next_cnt = 3;
            end
            4'b0001: begin
                        s_bus.req   = m_bus[0].req;
                        s_bus.addr  = m_bus[0].addr;
                        s_bus.cmd   = m_bus[0].cmd;
                        s_bus.wdata = m_bus[0].wdata;
                        ack_en = 4'b0001;
                        next_cnt = 0;
            end
            default: begin
                        s_bus.req = 0;
                        s_bus.addr = 0;
                        s_bus.cmd = 0;
                        s_bus.wdata = 0;
                        ack_en = 4'b0000;
                        next_cnt = 0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge reset) begin
        if(!reset) begin
            m_rdata_ack <= 0;
        end
        else begin
            m_rdata_ack <= ack_en & {!m_bus[3].cmd, !m_bus[2].cmd, !m_bus[1].cmd, !m_bus[0].cmd};
        end
    end
    
    always_comb begin
        m_ack = ack_en & {4{s_bus.ack}};
    end
endmodule


module mux4 #(parameter N = 32 )
            (
            input        [3:0]   m_rdata_ack,
            input        [N-1:0] s_rdata [3:0],
            output logic [N-1:0] m_rdata
            );
    always_comb begin : rdata
        casez(m_rdata_ack)
            4'b0001: m_rdata = s_rdata[0];
            4'b0010: m_rdata = s_rdata[1];
            4'b0100: m_rdata = s_rdata[2];
            4'b1000: m_rdata = s_rdata[3];
            default: m_rdata = 32'b0;
        endcase
    end
endmodule