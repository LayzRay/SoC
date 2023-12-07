module inverted_testbench();

    logic [127:0] data_to_cipher ;//[11];
    logic [127:0] ciphered_data  ;//[11];
    logic clk, resetn, request, ack, valid, busy;
    logic [127:0] data_i, data_o;

    initial clk <= 0;

    always #5ns clk <= ~clk;

    integer i = 0;
    logic [128*11-1:0] print_str;


    Kuznechik_inverted DUT(
   // kuznechik_cipher DUT(
        .clk_i      (clk),
        .resetn_i   (resetn),
        .data_i     (data_i),
        .request_i  (request),
        .ack_i      (ack),
        .data_o     (data_o),
        .valid_o    (valid),
        .busy_o     (busy)
    );

    initial begin
        /*data_to_cipher[00] <= 128'h4e6576657220676f6e6e612067697665;
        data_to_cipher[01] <= 128'h20796f752075700a4e6576657220676f;
        data_to_cipher[02] <= 128'h6e6e61206c657420796f7520646f776e;
        data_to_cipher[03] <= 128'h0a4e6576657220676f6e6e612072756e;
        data_to_cipher[04] <= 128'h2061726f756e6420616e642064657365;
        data_to_cipher[05] <= 128'h727420796f750a4e6576657220676f6e;
        data_to_cipher[06] <= 128'h6e61206d616b6520796f75206372790a;
        data_to_cipher[07] <= 128'h4e6576657220676f6e6e612073617920;
        data_to_cipher[08] <= 128'h676f6f646279650a4e6576657220676f;
        data_to_cipher[09] <= 128'h6e6e612074656c6c2061206c69652061;
        data_to_cipher[10] <= 128'h6e64206875727420796f752020202020; */
        
        data_to_cipher <= 128'h7f679d90bebc24305a468d42b9d4edcd;
        $display("Testbench has been started.\nResetting");
        resetn <= 1'b0;
        ack <= 0;
        request <= 0;
        repeat(2) begin
            @(posedge clk);
        end
        resetn <= 1'b1;
        //for(i=0; i < 11; i++) begin
            $display("Trying to cipher %d chunk of data", 1);
            @(posedge clk);
            data_i <= data_to_cipher;//[i];
            while(busy) begin
                @(posedge clk);
            end
            request <= 1'b1;
            @(posedge clk);
            request <= 1'b0;
            while(~valid) begin
                @(posedge clk);
            end
            ciphered_data <= data_o;
            ack <= 1'b1;
            @(posedge clk);
            ack <= 1'b0;
        //end
        $display("Ciphering has been finished.");
        $display("============================");
        $display("===== Ciphered message =====");
        $display("============================");
        /*print_str = {ciphered_data[0],
                        ciphered_data[1],
                        ciphered_data[2],
                        ciphered_data[3],
                        ciphered_data[4],
                        ciphered_data[5],
                        ciphered_data[6],
                        ciphered_data[7],
                        ciphered_data[8],
                        ciphered_data[9],
                        ciphered_data[10]*/
                   // };
        //for ( i=0; i < 11; i++ ) 
            $display("%h", ciphered_data);
        $display("============================");
        $finish();
    end

endmodule
