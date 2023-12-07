module Kuznechik (

  input                     clk_i,     // Тактовый сигнал
                            resetn_i,  // Синхронный сигнал сброса с активным уровнем LOW
                            
                            request_i, // Сигнал запроса на начало шифрования
                            ack_i,     // Сигнал подтверждения приёма зашифрованных данных
                [ 127 : 0 ] data_i,    // Шифруемые данные
         
  output  logic             busy_o,    // Сигнал, сообщающий о невозможности приёма
                            valid_o,   // Сигнал готовности зашифрованных данных
          logic [ 127 : 0 ] data_o     // Зашифрованные данные

  );

  logic [ 127 : 0 ] key_mem   [ 0 : 9   ]; // 10 готовых раундовых ключей
  logic [ 7   : 0 ] S_box_mem [ 0 : 255 ]; // Готовая таблица из 256-ти элементов
  
  logic [ 7 : 0 ] L_mul_16_mem  [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_32_mem  [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_133_mem [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_148_mem [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_192_mem [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_194_mem [ 0 : 255 ];
  logic [ 7 : 0 ] L_mul_251_mem [ 0 : 255 ];
  
  logic [ 2 : 0 ] State;
  
  localparam IDLE      = 3'd0;
  localparam Key_phase = 3'd1;
  localparam S_phase   = 3'd2;
  localparam L_phase   = 3'd3;
  localparam Finish    = 3'd4;
  
  logic [ 127 : 0 ] Ciphertext, 
                    Ciphertext_S, 
                    Ciphertext_K;
  
  logic [ 3 : 0 ] Counter_keys;
  logic [ 4 : 0 ] Counter_L;
  
  initial 
    begin
      
      $readmemh( "keys.mem" , key_mem   );
      $readmemh( "S_box.mem", S_box_mem );
      
      $readmemh( "L_16.mem",  L_mul_16_mem  );
      $readmemh( "L_32.mem",  L_mul_32_mem  );
      $readmemh( "L_133.mem", L_mul_133_mem );
      $readmemh( "L_148.mem", L_mul_148_mem );
      $readmemh( "L_192.mem", L_mul_192_mem );
      $readmemh( "L_194.mem", L_mul_194_mem );
      $readmemh( "L_251.mem", L_mul_251_mem );
      
    end 
  
  assign Ciphertext_K = Ciphertext;
  
  generate;

    for ( genvar i = 0; i < 16; i++ )
      assign Ciphertext_S [ i * 8 + 7 : i * 8 ] = S_box_mem [ Ciphertext_K[ i * 8 + 7 : i * 8 ] ];       
      
  endgenerate
  
  always_ff @( posedge clk_i )
    begin
  
      if ( ~resetn_i ) begin
          
        State        <= IDLE;
        Counter_keys <= 4'd0;
        Counter_L    <= 5'd0;
        
        valid_o <= 1'd0;
        busy_o  <= 1'd0;
        
        data_o <= 128'dZ;
          
      end else
        case ( State )
          
          IDLE:
            if ( request_i ) begin
            
                Ciphertext <= data_i;
            
                busy_o <= 1'd1;
                State <= Key_phase;
            
            end else
              begin

                State        <= IDLE;
                Counter_keys <= 4'd0;
                Counter_L    <= 5'd0;
                
                valid_o <= 1'd0;
                busy_o  <= 1'd0;
                
                data_o <= 128'dZ;

              end
          
          Key_phase:
              
            if ( Counter_keys == 4'd9 ) begin
            
              Ciphertext   <= Ciphertext ^ key_mem[ Counter_keys ];
              Counter_keys <= 4'd0;
              State        <= Finish;
            
            end else begin
            
                Ciphertext   <= Ciphertext ^ key_mem[ Counter_keys ];
                Counter_keys <= Counter_keys + 4'd1;
                State        <= S_phase;
                
            end
          
          S_phase:
            begin
          
              Ciphertext <= Ciphertext_S;
              State      <= L_phase;
          
              /*
              Ciphertext[ 127 : 120 ] <= S_box_mem [ Ciphertext[ 127 : 120 ] ];
              Ciphertext[ 119 : 112 ] <= S_box_mem [ Ciphertext[ 119 : 112 ] ];
              Ciphertext[ 111 : 104 ] <= S_box_mem [ Ciphertext[ 111 : 104 ] ];
              Ciphertext[ 103 : 96 ] <= S_box_mem [ Ciphertext[ 103 : 96 ] ];
              Ciphertext[ 95 : 88 ] <= S_box_mem [ Ciphertext[ 95 : 88 ] ];
              Ciphertext[ 87 : 80 ] <= S_box_mem [ Ciphertext[ 87 : 80 ] ];
              Ciphertext[ 79 : 72 ] <= S_box_mem [ Ciphertext[ 79 : 72 ] ];
              Ciphertext[ 71 : 64 ] <= S_box_mem [ Ciphertext[ 71 : 64 ] ];
              Ciphertext[ 63 : 56 ] <= S_box_mem [ Ciphertext[ 63 : 56 ] ];
              Ciphertext[ 55 : 48 ] <= S_box_mem [ Ciphertext[ 55 : 48 ] ];
              Ciphertext[ 47 : 40 ] <= S_box_mem [ Ciphertext[ 47 : 40 ] ];
              Ciphertext[ 39 : 32 ] <= S_box_mem [ Ciphertext[ 39 : 32 ] ];
              Ciphertext[ 31 : 24 ] <= S_box_mem [ Ciphertext[ 31 : 24 ] ];
              Ciphertext[ 23 : 16 ] <= S_box_mem [ Ciphertext[ 23 : 16 ] ];
              Ciphertext[ 15 : 8 ] <= S_box_mem [ Ciphertext[ 15 : 8 ] ];
              Ciphertext[ 7 : 0 ] <= S_box_mem [ Ciphertext[ 7 : 0 ] ];   */             
          
            end
          
          L_phase:
            begin
          
              /*Ciphertext <= { 7'd0, L_mul_148_mem[ Ciphertext[ 127 : 120 ] ] ^
              L_mul_32_mem[ Ciphertext[ 119 : 112 ] ] ^               
              L_mul_133_mem[ Ciphertext[ 111 : 104 ] ] ^
              L_mul_16_mem[ Ciphertext[ 103 : 96 ] ] ^
              L_mul_194_mem[ Ciphertext[ 95 : 88 ] ] ^
              L_mul_192_mem[ Ciphertext[ 87 : 80 ] ] ^
              Ciphertext[ 79 : 72 ] ^
              L_mul_251_mem[ Ciphertext[ 71 : 64 ] ] ^
              Ciphertext[ 63 : 56 ] ^
              L_mul_192_mem[ Ciphertext[ 55 : 48 ] ] ^
              L_mul_194_mem[ Ciphertext[ 47 : 40 ] ] ^
              L_mul_16_mem[ Ciphertext[ 39 : 32 ] ] ^
              L_mul_133_mem[ Ciphertext[ 31 : 24 ] ] ^
              L_mul_32_mem[ Ciphertext[ 23 : 16 ] ] ^
              L_mul_148_mem[ Ciphertext[ 15 : 8 ] ] ^
              Ciphertext[ 7 : 0 ], Ciphertext[ 127 : 8 ] }; */
              
              Ciphertext <= {

                L_mul_148_mem[ Ciphertext[ 127 : 120 ] ] ^
                L_mul_32_mem [ Ciphertext[ 119 : 112 ] ] ^               
                L_mul_133_mem[ Ciphertext[ 111 : 104 ] ] ^
                L_mul_16_mem [ Ciphertext[ 103 : 96  ] ] ^
                L_mul_194_mem[ Ciphertext[ 95 : 88   ] ] ^
                L_mul_192_mem[ Ciphertext[ 87 : 80   ] ] ^
                Ciphertext   [ 79 : 72 ] ^
                L_mul_251_mem[ Ciphertext[ 71 : 64   ] ] ^
                Ciphertext   [ 63 : 56 ] ^
                L_mul_192_mem[ Ciphertext[ 55 : 48   ] ] ^
                L_mul_194_mem[ Ciphertext[ 47 : 40   ] ] ^
                L_mul_16_mem [ Ciphertext[ 39 : 32   ] ] ^
                L_mul_133_mem[ Ciphertext[ 31 : 24   ] ] ^
                L_mul_32_mem [ Ciphertext[ 23 : 16   ] ] ^
                L_mul_148_mem[ Ciphertext[ 15 : 8    ] ] ^
                Ciphertext   [ 7 : 0   ], 
                Ciphertext   [ 127 : 8 ] 
              
              };
              
              Counter_L <= Counter_L + 5'd1;
              
              if ( Counter_L == 5'd15 ) begin
              
                  Counter_L <= 5'd0;
                  State     <= Key_phase;
              
              end
          
            end
          
          Finish:
              
            if ( ~ack_i ) begin
            
                busy_o  <= 1'd0;
                valid_o <= 1'd1;
                data_o  <= Ciphertext;
            
            end else
    
                State <= IDLE;

          
          default: 
            begin
          
              busy_o       <= 1'd0;
              valid_o      <= 1'd0;
              Counter_keys <= 4'd0;
              Counter_L    <= 5'd0;
              
              data_o <= 128'dZ;
          
              State <= IDLE;
          
            end
          
          endcase
      
      end
  
endmodule
