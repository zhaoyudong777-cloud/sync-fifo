// 同步FIFO设计
// 功能：同步时钟先进先出缓存
// 方法：额外bit法判断空满
// 特性：可配置位宽/深度、almost标志、data_count、寄存器输出

module sync_fifo #(
    parameter DATA_WIDTH     = 8,
    parameter FIFO_DEPTH     = 16,
    parameter ALMOST_FULL_TH  = 2,
    parameter ALMOST_EMPTY_TH = 2
)(
    input                       clk,
    input                       rst_n,      // 异步复位，低有效
    input                       wr_en,      // 写使能
    input                       rd_en,      // 读使能
    input       [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out,   // 寄存器输出，晚一拍
    output                      full,
    output                      empty,
    output reg                  almost_full,
    output reg                  almost_empty,
    output reg  [$clog2(FIFO_DEPTH):0] data_count  // FIFO中数据个数
);

// 指针位宽 = 地址位宽 + 1（多出来的1位用于区分空和满）
localparam PTR_WIDTH = $clog2(FIFO_DEPTH) + 1;

reg [PTR_WIDTH-1:0] wr_ptr;
reg [PTR_WIDTH-1:0] rd_ptr;

reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];  // 存储体

// 实际地址 = 指针低(PTR_WIDTH-1)位，去掉最高位的额外bit
wire [PTR_WIDTH-2:0] wr_addr;
wire [PTR_WIDTH-2:0] rd_addr;

assign wr_addr = wr_ptr[PTR_WIDTH-2:0];
assign rd_addr = rd_ptr[PTR_WIDTH-2:0];

// ---------------------------------------------------------------
// 写指针：写使能+不满时加1
// ---------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        wr_ptr <= 'd0;
    else if (wr_en && !full)
        wr_ptr <= wr_ptr + 1'b1;
end

// ---------------------------------------------------------------
// 读指针：读使能+不空时加1
// ---------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rd_ptr <= 'd0;
    else if (rd_en && !empty)
        rd_ptr <= rd_ptr + 1'b1;
end

// ---------------------------------------------------------------
// 写操作
// ---------------------------------------------------------------
always @(posedge clk) begin
    if (wr_en && !full)
        mem[wr_addr] <= data_in;
end

// ---------------------------------------------------------------
// 读操作（寄存器输出）
// 注意：寄存器输出时序更稳定，但数据晚一个周期出来
// ---------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_out <= 'd0;
    else if (rd_en && !empty)
        data_out <= mem[rd_addr];
end

// ---------------------------------------------------------------
// 空满判断（额外bit法）
// 空：wr_ptr == rd_ptr（所有位都相等）
// 满：最高位不同，低位相同（写指针多跑了一圈）
// ---------------------------------------------------------------
assign empty = (wr_ptr == rd_ptr) ? 1'b1 : 1'b0;

assign full  = (wr_ptr[PTR_WIDTH-1] != rd_ptr[PTR_WIDTH-1] &&
                wr_ptr[PTR_WIDTH-2:0] == rd_ptr[PTR_WIDTH-2:0]) ? 1'b1 : 1'b0;

// ---------------------------------------------------------------
// data_count：数据个数计数器
// 只写+1，只读-1，同时读写不变
// ---------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_count <= 'd0;
    else begin
        case ({wr_en && !full, rd_en && !empty})
            2'b10:  data_count <= data_count + 1'b1;
            2'b01:  data_count <= data_count - 1'b1;
            default: data_count <= data_count;
        endcase
    end
end

// ---------------------------------------------------------------
// almost标志
// ---------------------------------------------------------------
always @(*) begin
    almost_full  = (data_count >= (FIFO_DEPTH - ALMOST_FULL_TH))  ? 1'b1 : 1'b0;
    almost_empty = (data_count <= ALMOST_EMPTY_TH) ? 1'b1 : 1'b0;
end

endmodule
