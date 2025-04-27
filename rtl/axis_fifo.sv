/* Copyright (c) 2025 MAVERIC NU. All rights reserved. */

//-------------------------------
// Engineer     : Olzhas Nurman
//-------------------------------

//-----------------------------------------------------------------------
// This is a module that implements AXI Stream FIFO module.
// This design is not fully correct, I need to make small modifications.
//-----------------------------------------------------------------------

module axis_fifo
#(
    parameter FIFO_DEPTH = 1024,
    parameter DATA_WIDTH = 8
)
(
    // Common clock and reset.
    input  logic                    i_clk,
    input  logic                    i_rstn,
    
    // Slave interface.
    input  logic [DATA_WIDTH - 1:0] s_axis_fifo_tdata,
    input  logic                    s_axis_fifo_tuser,
    input  logic                    s_axis_fifo_tlast,
    input  logic                    s_axis_fifo_tvalid,
    output logic                    s_axis_fifo_tready,

    // Master interface. 
    input  logic                    m_axis_fifo_tready,
    output logic [DATA_WIDTH - 1:0] m_axis_fifo_tdata,
    output logic                    m_axis_fifo_tuser,
    output logic                    m_axis_fifo_tlast,
    output logic                    m_axis_fifo_tvalid
);
    //------------------------------------
    // Internal nets.
    //------------------------------------
    localparam COUNT_W = $clog2(FIFO_DEPTH);

    logic [COUNT_W - 1:0] s_write_index;
    logic [COUNT_W - 1:0] s_read_index;

    logic s_fifo_empty;
    logic s_fifo_full;

    logic s_fifo_read_after_empty;

    //-----------------------------
    // Memory space.
    //-----------------------------
    logic [DATA_WIDTH - 1:0] s_fifo_mem_tdata [FIFO_DEPTH - 1:0];
    logic s_fifo_mem_tuser [FIFO_DEPTH - 1:0];
    logic s_fifo_mem_tlast [FIFO_DEPTH - 1:0];
 
    // FIFO write.
    always_ff @(posedge i_clk) begin
        if (~ i_rstn) s_write_index <= '0;
        else if (s_axis_fifo_tvalid & s_axis_fifo_tready) begin
            s_fifo_mem_tdata[s_write_index] <= s_axis_fifo_tdata;
            s_fifo_mem_tuser[s_write_index] <= s_axis_fifo_tuser;
            s_fifo_mem_tlast[s_write_index] <= s_axis_fifo_tlast;
            s_write_index <= s_write_index + {{(COUNT_W - 1) {1'b0}} , 1'b1};
        end
    end

    // FIFO read.
    always_ff @(posedge i_clk) begin
        if (~ i_rstn) begin 
            s_read_index       <= '0;
            m_axis_fifo_tdata  <= '0;
            m_axis_fifo_tuser  <= '0;
            m_axis_fifo_tlast  <= '0;
            m_axis_fifo_tvalid <= '0;

            s_fifo_read_after_empty <= 1'b1;
        end
        else if (~ s_fifo_empty & m_axis_fifo_tready) begin
            s_read_index <= s_read_index + {{(COUNT_W - 1) {1'b0}} , 1'b1};
            
            //----------------------------------------------------
            // Syncronization Stages: 2
            //----------------------------------------------------
            m_axis_fifo_tdata  <= s_fifo_mem_tdata[s_read_index];
            m_axis_fifo_tuser  <= s_fifo_mem_tuser[s_read_index];
            m_axis_fifo_tlast  <= s_fifo_mem_tlast[s_read_index];

            s_fifo_read_after_empty <= 1'b0;
        end
        else if (s_fifo_empty) begin
            s_fifo_read_after_empty <= 1'b1;
        end

        // If reading for the first time after FIFO being empty wait for 2 cycles to assert valid.
        // Else assert with one cycle delay 
        // This is because tdata, tuser, tlast values are updated with the same variable delay.
        if (s_fifo_read_after_empty)
            m_axis_fifo_tvalid <= (~ s_fifo_empty) & m_axis_fifo_tready;
        else
            m_axis_fifo_tvalid <= (~ s_fifo_empty); 
    end

    assign s_fifo_empty    = (s_write_index == s_read_index);
    assign s_fifo_full     = ((s_write_index + {{(COUNT_W - 1) {1'b0}} , 1'b1}) == s_read_index);

    assign s_axis_fifo_tready = ~ s_fifo_full;

endmodule
