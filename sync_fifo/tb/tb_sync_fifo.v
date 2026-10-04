// 同步FIFO Testbench
// 功能：自校验测试
// 场景：复位检查 → 写5读5 → 写满 → 读空

module tb_sync_fifo;

parameter DATA_WIDTH     = 8;
parameter FIFO_DEPTH     = 16;
parameter ALMOST_FULL_TH  = 2;
parameter ALMOST_EMPTY_TH = 2;

reg                     clk;
reg                     rst_n;
reg                     wr_en;
reg                     rd_en;
reg   [DATA_WIDTH-1:0]  data_in;
wire  [DATA_WIDTH-1:0]  data_out;
wire                    full;
wire                    empty;
wire                    almost_full;
wire                    almost_empty;
wire  [$clog2(FIFO_DEPTH):0] data_count;

integer error_cnt;
integer i;
reg [DATA_WIDTH-1:0] expected;

// 例化DUT
sync_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .ALMOST_FULL_TH(ALMOST_FULL_TH),
    .ALMOST_EMPTY_TH(ALMOST_EMPTY_TH)
) u_sync_fifo (
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
    .data_in(data_in), .data_out(data_out),
    .full(full), .empty(empty),
    .almost_full(almost_full), .almost_empty(almost_empty),
    .data_count(data_count)
);

// 时钟 100MHz
always #5 clk = ~clk;

initial begin
    clk = 0; rst_n = 0; wr_en = 0; rd_en = 0;
    data_in = 0; error_cnt = 0; expected = 0;

    // 释放复位
    #100;
    @(posedge clk);
    rst_n <= 1;
    $display("=== 同步FIFO测试开始 ===");
    $display("  深度=%0d, almost_full阈值=%0d, almost_empty阈值=%0d",
             FIFO_DEPTH, ALMOST_FULL_TH, ALMOST_EMPTY_TH);

    // 复位检查
    @(negedge clk);
    if (empty !== 1 || full !== 0 || data_count !== 0) begin
        $display("FAIL: 复位状态不对");
        error_cnt = error_cnt + 1;
    end else
        $display("PASS: 复位状态正确");

    // ---------- 第一轮：写5个，读5个 ----------
    $display("\n--- 第一轮：写5读5 ---");
    for (i = 1; i <= 5; i = i + 1) begin
        @(posedge clk);
        wr_en <= 1; data_in <= i;
    end
    @(posedge clk);
    wr_en <= 0; data_in <= 0;

    @(negedge clk);
    $display("写完5个，data_count=%0d", data_count);

    #50;

    // 读数据（寄存器输出晚一拍，第一个数据等一拍再检查）
    expected = 1;
    @(posedge clk);
    rd_en <= 1;
    @(posedge clk);  // 等一拍

    for (i = 1; i <= 5; i = i + 1) begin
        @(negedge clk);
        if (data_out !== expected) begin
            $display("FAIL: 第%0d个读错，期望%0d，实际%0d", i, expected, data_out);
            error_cnt = error_cnt + 1;
        end else
            $display("OK:   第%0d个=%0d", i, data_out);
        expected = expected + 1;
        @(posedge clk);
    end
    rd_en <= 0;

    @(negedge clk);
    $display("读空后，empty=%b, data_count=%0d", empty, data_count);

    #100;

    // ---------- 第二轮：写满 ----------
    $display("\n--- 第二轮：写满测试 ---");
    for (i = 1; i <= FIFO_DEPTH + 4; i = i + 1) begin
        @(posedge clk);
        wr_en <= 1; data_in <= i;
    end
    @(posedge clk);
    wr_en <= 0; data_in <= 0;

    @(negedge clk);
    if (full !== 1) begin
        $display("FAIL: 写满后full没拉高");
        error_cnt = error_cnt + 1;
    end
    if (data_count !== FIFO_DEPTH) begin
        $display("FAIL: 写满后data_count=%0d，期望%0d", data_count, FIFO_DEPTH);
        error_cnt = error_cnt + 1;
    end
    if (almost_full !== 1) begin
        $display("FAIL: 写满后almost_full没拉高");
        error_cnt = error_cnt + 1;
    end
    $display("写满，data_count=%0d, full=%b, almost_full=%b",
             data_count, full, almost_full);

    #50;

    // ---------- 第三轮：读空 ----------
    $display("\n--- 第三轮：读空测试 ---");
    expected = 1;

    @(posedge clk);
    rd_en <= 1;
    @(posedge clk);  // 等一拍

    for (i = 1; i <= FIFO_DEPTH; i = i + 1) begin
        @(negedge clk);
        if (data_out !== expected) begin
            $display("FAIL: 第%0d个读错，期望%0d，实际%0d", i, expected, data_out);
            error_cnt = error_cnt + 1;
        end
        expected = expected + 1;
        @(posedge clk);
    end

    // 多读4个，测试空保护
    repeat(4) begin
        @(negedge clk);
        if (empty !== 1) begin
            $display("FAIL: 空的时候empty不对");
            error_cnt = error_cnt + 1;
        end
        @(posedge clk);
    end

    rd_en <= 0;

    // ---------- 汇总 ----------
    $display("\n=== 测试结束 ===");
    if (error_cnt == 0)
        $display("全部通过！");
    else
        $display("失败，共%0d个错误", error_cnt);

    #100;
    $finish;
end

// 波形
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_sync_fifo);
end

endmodule