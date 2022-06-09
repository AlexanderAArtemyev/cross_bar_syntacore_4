// 4 port cross-bar testbench
// Comment: - read/write operations checked 
//          (slave ack generates from slave req)

`include "../src/vars.svh"

module cross_bar_tb ();
    parameter           N = Nr;                     // length of data/addr bus
    parameter           P = 64;                     // number of test_vectors

    BUS                 m_bus[3:0] ();
    BUS                 s_bus[3:0] ();

    logic [8+(3*N)-1:0] testv[3:0] [P-1:0];         // test vectors for each crossbar 
                                                    // (master: req, addr, cmd, wdata, slave: rdata)
    logic               clk;
    logic               reset;
    int                 i[3:0];
    int                 n_i[3:0];

    always begin
        #5; clk = 0; #5; clk = 1;
    end

    cross_bar dut ( clk, reset,
                    m_bus[3:0],
                    s_bus[3:0]
                  );

    // next test vector taken when master recieve ack or if no req in current test-vector
    data_change #(.P(P)) ch0 (i[0], clk, reset, m_bus[0].req, m_bus[0].ack, n_i[0]);
    data_change #(.P(P)) ch1 (i[1], clk, reset, m_bus[1].req, m_bus[1].ack, n_i[1]);
    data_change #(.P(P)) ch2 (i[2], clk, reset, m_bus[2].req, m_bus[2].ack, n_i[2]);
    data_change #(.P(P)) ch3 (i[3], clk, reset, m_bus[3].req, m_bus[3].ack, n_i[3]);

    // for basic test assume that slave ack appears immediately with slave req 
    assign s_bus[0].ack = s_bus[0].req; 
    assign s_bus[1].ack = s_bus[1].req;
    assign s_bus[2].ack = s_bus[2].req;
    assign s_bus[3].ack = s_bus[3].req;
    
    data_check #(.N(N)) check_m0 (2'b00, i[0], clk, reset, m_bus[0], s_bus[3:0]);
    data_check #(.N(N)) check_m1 (2'b01, i[1], clk, reset, m_bus[1], s_bus[3:0]);
    data_check #(.N(N)) check_m2 (2'b10, i[2], clk, reset, m_bus[2], s_bus[3:0]);
    data_check #(.N(N)) check_m3 (2'b11, i[3], clk, reset, m_bus[3], s_bus[3:0]);
    
    task load_file();
        $display("Loading tesvectors");
        $readmemh("vectors0.mem", testv[0]); 
        $readmemh("vectors1.mem", testv[1]);      
        $readmemh("vectors2.mem", testv[2]);      
        $readmemh("vectors3.mem", testv[3]);                                                
    endtask

    task parse_data(
                    input  logic [8+(3*N)-1:0]  t,
                    output logic                req,
                    output logic [N-1:0]        addr,
                    output logic                cmd,
                    output logic [N-1:0]        wdata,
                    output logic [N-1:0]        rdata
                    );
        
        {req, addr, cmd, wdata, rdata} = 
        {t[3*N+4], t[3*N+3 -: N], t[2*N], t[2*N-1:N], t[N-1:0]};
    endtask

    always_comb begin : dataparser
        {i[3], i[2], i[1], i[0]} = {n_i[3], n_i[2], n_i[1], n_i[0]};
        parse_data(testv[0][i[0]], m_bus[0].req, m_bus[0].addr, m_bus[0].cmd, m_bus[0].wdata, s_bus[0].rdata);
        parse_data(testv[1][i[1]], m_bus[1].req, m_bus[1].addr, m_bus[1].cmd, m_bus[1].wdata, s_bus[1].rdata);
        parse_data(testv[2][i[2]], m_bus[2].req, m_bus[2].addr, m_bus[2].cmd, m_bus[2].wdata, s_bus[2].rdata);
        parse_data(testv[3][i[3]], m_bus[3].req, m_bus[3].addr, m_bus[3].cmd, m_bus[3].wdata, s_bus[3].rdata);
    end

    // Sim finished when all vectors ends
    always @(posedge clk) begin
         if ((i[0] == P-1) && (i[1] == P-1) && (i[2] == P-1) && (i[3] == P-1)) begin   
            #20;
            $display("!!! Sim finished Sucessfull !!!");         
            $finish();
        end
    end

    initial begin
        $timeformat(-9,2,"ns");
        reset = 0;
        clk = 0;
        load_file;
        #30;
        reset = 1;
        #10000;                                                           // Max waiting time
        $display("TIMEOUT !!! Sim finished because of time ending");
        $finish();
    end

endmodule


module data_check #(parameter N = 32)
                    (
                    input [1:0] mr_n,
                    input int   i,
                    input       clk,
                    input       reset,
                    BUS.test    m_bus,
                    BUS.test    s_bus [3:0]
                    );
    
    logic [N-1:0]   slv_rdata;
    logic [1:0]     addr_prev;
    logic           read_flag;  
    int             prev_i;

    // use previous addr for rdata check
    assign slv_rdata = addr_prev[1] ?   (addr_prev[0] ? s_bus[3].rdata : s_bus[2].rdata) :
                                        (addr_prev[0] ? s_bus[1].rdata : s_bus[0].rdata);

    always @(negedge clk or negedge reset) begin : checker_block
        if (!reset) begin
            read_flag <= 0;
            prev_i <= 0;
            addr_prev <= 0;
        end else begin
            check_data_write(mr_n, i, 
                            {s_bus[3].req,   s_bus[2].req,   s_bus[1].req,   s_bus[0].req},
                            {s_bus[3].cmd,   s_bus[2].cmd,   s_bus[1].cmd,   s_bus[0].cmd},
                            {s_bus[3].addr,  s_bus[2].addr,  s_bus[1].addr,  s_bus[0].addr},
                            {s_bus[3].wdata, s_bus[2].wdata, s_bus[1].wdata, s_bus[0].wdata}
                            );        
            read_flag <= (m_bus.req && !m_bus.cmd && m_bus.ack);
            addr_prev <=  m_bus.addr[N-1:N-2];
            prev_i <= i;
            if(read_flag) begin
                check_data_r(mr_n, prev_i, m_bus.rdata, slv_rdata);
            end
        end
    end

    task automatic check_data_write(
                                    input [1:0]     master_n,
                                    input int       i,
                                    input           s_req[3:0],
                                    input           s_cmd[3:0],
                                    input [N-1:0]   s_addr[3:0],
                                    input [N-1:0]   s_wdata[3:0]
                                    );
        logic           check;     
        logic [1:0]     j = m_bus.addr[N-1:N-2];
          
        if(m_bus.req && m_bus.ack) begin
            $display("time=%0t Package %0d master %0d", $realtime, i, master_n); 
            if (m_bus.cmd) begin                                            
                check =    (m_bus.req == s_req[j])
                        && (m_bus.cmd == s_cmd[j]) 
                        && (m_bus.addr == s_addr[j]) 
                        && (m_bus.wdata == s_wdata[j]);
                $display("  Expected: cmd=%h, addr=%h, wdata=%h", m_bus.cmd, m_bus.addr, m_bus.wdata);
                $display("  Recieved: cmd=%h, addr=%h, wdata=%h", s_cmd[j], s_addr[j], s_wdata[j]);
            end else begin
                check =    (m_bus.req == s_req[j])
                        && (m_bus.cmd == s_cmd[j]) 
                        && (m_bus.addr == s_addr[j]);
                $display("  Expected: cmd=%h, addr=%h", m_bus.cmd, m_bus.addr);
                $display("  Recieved: cmd=%h, addr=%h", s_cmd[j], s_addr[j]);
            end 

            if (check) begin
                $display("  written RIGHT!");               
            end else begin
                $display("  written WRONG!");
                $finish;
            end
        end else if (!m_bus.req && m_bus.ack) begin
            $display("Unexpected Ack! time=%0t master %0d", $realtime, master_n);
            $finish;            
        end
    endtask

    task automatic check_data_r(
                                input [1:0]         master_n,
                                input int           i,
                                input [N-1:0]       master_rdata, 
                                input [N-1:0]       slave_rdata
                                );
        $display("time=%0t Package %0d master %0d read", $realtime, i, master_n);
        $display("  Expected: rdata=%h", slave_rdata);
        $display("  Recieved: rdata=%h", master_rdata);
        if(master_rdata == slave_rdata) begin
            $display("  read RIGHT!");
        end
        else begin
            $display("  read WRONG!");
            $finish;
        end
    endtask
endmodule


module data_change  #(parameter P = 8)
                    (
                    input  int   i,
                    input        clk,
                    input        reset,
                    input        m_req,
                    input        m_ack,
                    output int   next_i
                    );

    always_ff @(posedge clk or negedge reset) begin
        if(!reset) begin
            next_i <= 0;
        end else begin
            if(((m_req && m_ack) || (!m_req)) && (i<(P-1))) 
                next_i <= i+1;
        end        
    end
endmodule