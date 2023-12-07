module kuznechik_cipher_apb_wrapper(

    // Clock and reset
    input  logic            pclk_i,
    input  logic            presetn_i,

    // Address
    input  logic     [31:0] paddr_i,

    // Control-status
    input  logic            psel_i,
    input  logic            penable_i,
    input  logic            pwrite_i,

    // Write
    input  logic [3:0][7:0] pwdata_i,
    input  logic      [3:0] pstrb_i,

    // Slave
    output logic            pready_o,
    output logic     [31:0] prdata_o,
    output logic            pslverr_o

);
    
    import kuznechik_cipher_apb_wrapper_pkg::*;
    localparam ADDR_LEN = 6;
    

    // Регистры устройства
    logic [7:0] reg_rst, reg_req_ack, reg_valid, reg_busy;
    logic [31:0] reg_data_in[0:3], reg_data_out[0:3];
    assign reg_valid[7:1] = 7'b0;
    assign reg_busy[7:1] = 7'b0;
    
    
    // Подключаем модуль, осуществляющий шифрование
    logic [127:0] kuz_data_in, kuz_data_out;
    generate
        for (genvar i=0; i<4; i++) begin
            assign kuz_data_in[i*32+31:i*32] = reg_data_in[i];
            assign reg_data_out[i] = kuz_data_out[i*32+31:i*32];
        end
    endgenerate
    
    logic kuz_resetn, kuz_req, kuz_ack, kuz_busy, kuz_valid;
    Kuznechik cipher(
        .clk_i      (pclk_i),
        .resetn_i   (kuz_resetn),
        .request_i  (kuz_req),
        .ack_i      (kuz_ack),
        .data_i     (kuz_data_in),
        .busy_o     (kuz_busy),
        .valid_o    (kuz_valid),
        .data_o     (kuz_data_out)
    );
    
    // Выставляем сигнал сброса для модуля шифрования и состояния регистров VALID и BUSY
    assign kuz_resetn = presetn_i && reg_rst[0];
    assign reg_valid[0] = kuz_valid;
    assign reg_busy[0] = kuz_busy;


    // Сигнал о необходимости выполнить операцию чтения / записи в текущем такте
    logic req;
    assign req = psel_i && !penable_i;
    
    // Выставляем сигнал завершения операции на шину
    always_ff @(posedge pclk_i)
        pready_o <= req;


    // Проверяем, есть ли обращение к регистрам входных/выходных данных и находим относительный адрес (внутри регистра)
    logic is_addr_reg_in, is_addr_reg_out;
    logic [ADDR_LEN-3:0] addr_reg_in, addr_reg_out;
    assign is_addr_reg_in = (paddr_i[ADDR_LEN:0]>=DATA_IN) && (paddr_i[ADDR_LEN:0]<DATA_IN+16);
    assign is_addr_reg_out = (paddr_i[ADDR_LEN:0]>=DATA_OUT) && (paddr_i[ADDR_LEN:0]<DATA_OUT+16);
    assign addr_reg_in = (paddr_i[ADDR_LEN:0] - DATA_IN) >> 2;
    assign addr_reg_out = (paddr_i[ADDR_LEN:0] - DATA_OUT) >> 2;


    // Реализуем операцию чтения
    always_ff @(posedge pclk_i) begin
        if (!presetn_i) begin
            prdata_o <= '0;
        end else if (req && !pwrite_i) begin
            if (paddr_i[ADDR_LEN:2] == '0) begin
                prdata_o <= {reg_busy, reg_valid, reg_req_ack, reg_rst};
            end else if (is_addr_reg_in) begin
                prdata_o <= reg_data_in[addr_reg_in];
            end else if (is_addr_reg_out) begin
                prdata_o <= reg_data_out[addr_reg_out];
            end
        end
    end
    
    
    // Реализуем операцию записи
    logic is_addr_reg_rst, is_addr_reg_req_ack;
    assign is_addr_reg_rst = (paddr_i[ADDR_LEN:2] == '0) && pstrb_i[0];
    assign is_addr_reg_req_ack = (paddr_i[ADDR_LEN:2] == '0) && pstrb_i[1];
    
    // Запись в регистр сброса
    always_ff @(posedge pclk_i) begin
        if (!presetn_i) begin
            reg_rst <= '1;
        end else if (req && pwrite_i && is_addr_reg_rst) begin
            reg_rst <= pwdata_i[RST];
        end
    end

    // Запись в регистр запроса/подтверждения
    always_ff @(posedge pclk_i) begin
        if (presetn_i && req && pwrite_i && is_addr_reg_req_ack) begin
            reg_req_ack <= pwdata_i[REQ_ACK];
            if (pwdata_i[REQ_ACK][0]) begin
                if (kuz_valid) begin
                    kuz_ack <= 1'b1;
                end else begin
                    kuz_req <= 1'b1;
                end
            end
        end else begin // сброс или отсутствие операции записи к этому регистру
            reg_req_ack <= '0;
            kuz_req <= 1'b0;
            kuz_ack <= 1'b0;
        end
    end
    
    // Запись в регистр входных данных
    generate
        for (genvar i=0; i<4; i++)
            always_ff @(posedge pclk_i) begin
                if (presetn_i && req && pwrite_i && is_addr_reg_in) begin
                    if (pstrb_i[i])
                        reg_data_in[addr_reg_in][8*i+7:8*i] <= pwdata_i[i]; 
                end
             end
    endgenerate
    

    // Выставление сигнала ошибки
    logic err, err_apb, err_no_reg, err_misaligned, err_wr2ro_reg, err_fsm;
    assign err_apb = 1'b0;
    assign err_no_reg = !(paddr_i[ADDR_LEN-1:2]=='0) && !is_addr_reg_in && !is_addr_reg_out;
    assign err_misaligned = paddr_i[1:0] != 2'b0;
    assign err_wr2ro_reg = pwrite_i && ((paddr_i[ADDR_LEN:2]=='0) && (pstrb_i[VALID] || pstrb_i[BUSY]) || is_addr_reg_out);
    assign err_fsm = (pwrite_i && is_addr_reg_req_ack && pwdata_i[REQ_ACK][0]) && (!kuz_valid && kuz_busy);
    assign err = err_apb || err_no_reg || err_misaligned || err_wr2ro_reg || err_fsm;

    always @(posedge pclk_i) begin
        if (req) begin
            pslverr_o <= err;
        end else begin
            pslverr_o <= 1'b0;
        end
    end
    
    
endmodule


/*`define FIRST_BYTE 7:0
`define SECOND_BYTE 15:8
`define THIRD_BYTE 23:16
`define FOURTH_BYTE 31:24
`define Condition_W psel_i && penable_i && pwrite_i
`define Condition_R psel_i && penable_i && ~pwrite_i

module kuznechik_cipher_apb_wrapper(

    // Clock
    input  logic            pclk_i,

    // Reset
    input  logic            presetn_i,

    // Address
    input  logic     [31:0] paddr_i,

    // Control-status
    input  logic            psel_i,
    input  logic            penable_i,
    input  logic            pwrite_i,

    // Write
    input  logic [3:0][7:0] pwdata_i,
    input  logic      [3:0] pstrb_i,

    // Slave
    output logic            pready_o,
    output logic     [31:0] prdata_o,
    output logic            pslverr_o

);

    ////////////////////
    // Design package //
    ////////////////////

    import kuznechik_cipher_apb_wrapper_pkg::*;

    //////////////////////////
    // Cipher instantiation //
    //////////////////////////

    logic [ 3:0 ] [ 31:0 ] data_in_reg, data_out_reg;
    logic [ 3:0 ] [ 7:0 ] control_in_reg;

    // Instantiation
    Kuznechik cipher(
        .clk_i      (  pclk_i  ),
        .resetn_i   (  presetn_i & control_in_reg[ RST ][ 0 ] ),
        .request_i  (  control_in_reg[ REQ_ACK ][ 0 ]  ),
        .ack_i      (  control_in_reg[ REQ_ACK ][ 1 ]  ),
        .data_i     (  data_in_reg  ),
        .busy_o     (  control_in_reg[ BUSY ][ 0 ]  ),
        .valid_o    (  control_in_reg[ VALID ][ 0 ]  ),
        .data_o     (  data_out_reg  )
    );
    
    logic counter;
    
    always_ff @( posedge pclk_i )
        counter <= `Condition_W && counter ? counter + 1 : 1'b0;
    
    always_comb
    
        if ( !presetn_i ) begin
        
            pready_o <= 1'b1;
            prdata_o <= 32'dZ;
            pslverr_o <= 1'b0;
            
            data_in_reg <= 128'd0;
            //data_out_reg <= 128'd0;
            
            control_in_reg <= 32'd0;
            
            //counter <= 1'd0;
        
        end else begin
            
            pready_o <= `Condition_W && ~counter ? 1'b0 : 1'b1;
            
            pslverr_o <= 1'b0;
            
            case ( paddr_i )
                    
                32'h0000_0000: begin
                
                    prdata_o <= `Condition_R ? control_in_reg : 32'dZ; 
                    
                    case ( pstrb_i )

                        4'b0000: control_in_reg <= control_in_reg;
                           
                        4'b0001: control_in_reg[ RST ][ 0 ] <= `Condition_W ? pwdata_i[ RST ][ 0 ] : control_in_reg[ RST ][ 0 ];

                        4'b0010: control_in_reg[ REQ_ACK ][ 1:0 ] <= `Condition_W ? pwdata_i[ REQ_ACK ][ 1:0 ] : control_in_reg[ REQ_ACK ][ 1:0 ];
                        
                        4'b0011: begin
                            
                                control_in_reg[ RST ][ 0 ] <= `Condition_W  ? pwdata_i[ RST ][ 0 ] : control_in_reg[ RST ][ 0 ];
                                control_in_reg[ REQ_ACK ][ 1:0 ] <= `Condition_W  ? pwdata_i[ REQ_ACK ][ 1:0 ] : control_in_reg[ REQ_ACK ][ 1:0 ];
                                if( control_in_reg[ BUSY ][ 0 ] )  pslverr_o <= 1'b1;           
                           end
                        
                        default: pslverr_o <= 1'b1;
                        
                    endcase
                        
                end
                            
                32'h0000_0004: begin
                
                    prdata_o <= `Condition_R ? data_in_reg[ 0 ] : 32'dZ;
                    
                    case ( pstrb_i )

                        4'b0000: data_in_reg[ 0 ] <= data_in_reg[ 0 ];
                        
                        4'b0001: data_in_reg[ 0 ][ `FIRST_BYTE   ] <= `Condition_W ? pwdata_i[ 0 ] : data_in_reg[ 0 ][ `FIRST_BYTE   ];
                        4'b0010: data_in_reg[ 0 ][ `SECOND_BYTE  ] <= `Condition_W ? pwdata_i[ 1 ] : data_in_reg[ 0 ][ `SECOND_BYTE  ];
                        4'b0100: data_in_reg[ 0 ][ `THIRD_BYTE ] <= `Condition_W ? pwdata_i[ 2 ] : data_in_reg[ 0 ][ `THIRD_BYTE ];
                        4'b1000: data_in_reg[ 0 ][ `FOURTH_BYTE ] <= `Condition_W ? pwdata_i[ 3 ] : data_in_reg[ 0 ][ `FOURTH_BYTE ];
                        
                        *//*
                        4'b0011: data_in_reg[ 0 ][ 15:0  ] <= pwdata_i[ 1:0 ];
                        4'b0110: data_in_reg[ 0 ][ 23:8  ] <= pwdata_i[ 2:1 ];
                        4'b1100: data_in_reg[ 0 ][ 31:16 ] <= pwdata_i[ 3:2 ];
                         
                        4'b0101: data_in_reg[ 0 ] <= { data_in_reg[ 0 ][ `FOURTH_BYTE ], pwdata_i[ 2 ], data_in_reg[ 0 ][ `SECOND_BYTE ], pwdata_i[ 0 ] };
                        4'b1010: data_in_reg[ 0 ] <= { pwdata_i[ 3 ], data_in_reg[ 0 ][ `THIRD_BYTE ], pwdata_i[ 1 ], data_in_reg[ 0 ][ `FIRST_BYTE ] };
                         
                        4'b1001: data_in_reg[ 0 ] <= { pwdata_i[ 3 ], data_in_reg[ 0 ][ `THIRD_BYTE ], data_in_reg[ 0 ][ `SECOND_BYTE ], pwdata_i[ 0 ] };
                         
                        4'b0111: data_in_reg[ 0 ][ 23:0 ] <= pwdata_i[ 2:0 ];
                        4'b1110: data_in_reg[ 0 ][ 31:8 ] <= pwdata_i[ 3:1 ];
                         
                        4'b1011: data_in_reg[ 0 ] <= { pwdata_i[ 3 ], data_in_reg[ 0 ][ `THIRD_BYTE ], pwdata_i[ 1:0 ] };
                        4'b1101: data_in_reg[ 0 ] <= { pwdata_i[ 3:2 ], data_in_reg[ 0 ][ `SECOND_BYTE ], pwdata_i[ 0 ] };
                        *//*
                        
                        4'b1111: data_in_reg[ 0 ] <= `Condition_W ? pwdata_i : data_in_reg[ 0 ];
                        
                        endcase
                    
                end

            32'h0000_0008: begin
            
                prdata_o <= `Condition_R ? data_in_reg[ 1 ] : 32'dZ;
                    
                case ( pstrb_i )
                
                    4'b0000: data_in_reg[ 1 ] <= data_in_reg[ 0 ]; 
                    4'b0001: data_in_reg[ 1 ][ `FIRST_BYTE   ] <= `Condition_W ? pwdata_i[ 0 ] : data_in_reg[ 1 ][ `FIRST_BYTE   ];
                    4'b0010: data_in_reg[ 1 ][ `SECOND_BYTE  ] <= `Condition_W ? pwdata_i[ 1 ] : data_in_reg[ 1 ][ `SECOND_BYTE  ];
                    4'b0100: data_in_reg[ 1 ][ `THIRD_BYTE   ] <= `Condition_W ? pwdata_i[ 2 ] : data_in_reg[ 1 ][ `THIRD_BYTE   ];
                    4'b1000: data_in_reg[ 1 ][ `FOURTH_BYTE  ] <= `Condition_W ? pwdata_i[ 3 ] : data_in_reg[ 1 ][ `FOURTH_BYTE  ];
                    4'b1111: data_in_reg[ 1 ]                  <= `Condition_W ? pwdata_i      : data_in_reg[ 1 ];
                
                endcase
            
            end
            
            32'h0000_000C: begin
            
                prdata_o <= `Condition_R ? data_in_reg[ 2 ] : 32'dZ;
                    
                case ( pstrb_i )
                
                    4'b0000: data_in_reg[ 2 ] <= data_in_reg[ 0 ]; 
                    4'b0001: data_in_reg[ 2 ][ `FIRST_BYTE   ] <= `Condition_W ? pwdata_i[ 0 ] : data_in_reg[ 2 ][ `FIRST_BYTE   ];
                    4'b0010: data_in_reg[ 2 ][ `SECOND_BYTE  ] <= `Condition_W ? pwdata_i[ 1 ] : data_in_reg[ 2 ][ `SECOND_BYTE  ];
                    4'b0100: data_in_reg[ 2 ][ `THIRD_BYTE   ] <= `Condition_W ? pwdata_i[ 2 ] : data_in_reg[ 2 ][ `THIRD_BYTE   ];
                    4'b1000: data_in_reg[ 2 ][ `FOURTH_BYTE  ] <= `Condition_W ? pwdata_i[ 3 ] : data_in_reg[ 2 ][ `FOURTH_BYTE  ];
                    4'b1111: data_in_reg[ 2 ]                  <= `Condition_W ? pwdata_i      : data_in_reg[ 2 ];
                
                endcase
            
            end
            
            32'h0000_0010: begin
            
                prdata_o <= `Condition_R ? data_in_reg[ 3 ] : 32'dZ;
                    
                case ( pstrb_i )
                
                    4'b0000: data_in_reg[ 3 ] <= data_in_reg[ 0 ]; 
                    4'b0001: data_in_reg[ 3 ][ `FIRST_BYTE   ] <= `Condition_W ? pwdata_i[ 0 ] : data_in_reg[ 3 ][ `FIRST_BYTE   ];
                    4'b0010: data_in_reg[ 3 ][ `SECOND_BYTE  ] <= `Condition_W ? pwdata_i[ 1 ] : data_in_reg[ 3 ][ `SECOND_BYTE  ];
                    4'b0100: data_in_reg[ 3 ][ `THIRD_BYTE   ] <= `Condition_W ? pwdata_i[ 2 ] : data_in_reg[ 3 ][ `THIRD_BYTE   ];
                    4'b1000: data_in_reg[ 3 ][ `FOURTH_BYTE  ] <= `Condition_W ? pwdata_i[ 3 ] : data_in_reg[ 3 ][ `FOURTH_BYTE  ];
                    4'b1111: data_in_reg[ 3 ]                  <= `Condition_W ? pwdata_i      : data_in_reg[ 3 ];
                
                endcase
            
            end
            
            32'h0000_0014: begin
            
                prdata_o <= `Condition_R ? data_out_reg[ 0 ] : 32'dZ;
                pslverr_o <= `Condition_W ? 1'b1 : 1'b0;
                
            end
            32'h0000_0018: begin
            
                prdata_o <= `Condition_R ? data_out_reg[ 1 ] : 32'dZ;
                pslverr_o <= `Condition_W ? 1'b1 : 1'b0;
                
            end
            32'h0000_001C: begin
            
                prdata_o <= `Condition_R ? data_out_reg[ 2 ] : 32'dZ;
                pslverr_o <= `Condition_W ? 1'b1 : 1'b0;
                
            end
            32'h0000_0020: begin
            
                prdata_o <= `Condition_R ? data_out_reg[ 3 ] : 32'dZ;
                pslverr_o <= `Condition_W ? 1'b1 : 1'b0;
                
            end

            default: pslverr_o <= 1'b1;

        endcase
        
        end
   
endmodule*/