`ifndef vars
`define vars
    `timescale 1ns/1ps

    parameter Nr = 32;                  // Bus size

    interface BUS;                      // req, addr, cmd, wdata, ack, rdata
        logic           req;
        logic [Nr-1:0]  addr;           // [N-1 : N-2] - addr of slave
        logic           cmd;            // 0 - read, 1 – write
        logic [Nr-1:0]  wdata;
        logic           ack;
        logic [Nr-1:0]  rdata;

        modport slv  (input ack, rdata, output req, addr, cmd, wdata);
        modport mstr (input req, addr, cmd, wdata, output ack, rdata);
        modport test (input req, addr, cmd, wdata, ack, rdata);
    endinterface
`endif


