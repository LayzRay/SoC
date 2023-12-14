#include <pulpino.h>
#include <uart.h>
#include <cipher.h>

int main()
{
    uint8_t recieved_data [16];// = { 0x3e, 0xe5, 0xc9, 0x9f, 0x9a, 0x41, 0xc3, 0x89, 0xac, 0x17, 0xb4, 0xfe, 0x99, 0xc7, 0x2a, 0xe4 };

    uart_set_cfg(0, 325);

    cipher_init();

    volatile uint32_t data_to_cipher [4]; 
    volatile uint32_t data_from_cipher [4];
    uint8_t data_tx [16];
    
    while (1)
    {

    for ( uint8_t i = 0; i < 16; i = i + 1 )
       recieved_data[i] = uart_getchar();

    for ( uint8_t i = 0; i < 4; i = i + 1 )
    {
        data_to_cipher[i] = (volatile uint32_t) recieved_data[i*4] << 24 |
                        (volatile uint32_t) recieved_data[i*4 + 1] << 16 |
                        (volatile uint32_t) recieved_data[i*4 + 2] << 8 |
                        (volatile uint32_t) recieved_data[i*4 + 3];
    }
    
    cipher_reset();

    cipher_write_data( data_to_cipher );
 
    cipher_set_req();

    if ( !cipher_is_busy() )
    {
        uart_send("Not busy!\n", 10);
        uart_wait_tx_done();
    }

    while( !cipher_is_valid() );
    
    cipher_read_data( data_from_cipher );

    cipher_set_ack();
    
    for ( uint8_t i = 0; i < 4; i = i + 1 )
    {
        data_tx[ 4 * i + 0 ] = (uint8_t) ( data_from_cipher[ i ] >> 24 );
        data_tx[ 4 * i + 1 ] = (uint8_t) ( ( data_from_cipher[ i ] << 8 ) >> 24 );       
        data_tx[ 4 * i + 2 ] = (uint8_t) ( ( data_from_cipher[ i ] << 16 ) >> 24 );          
        data_tx[ 4 * i + 3 ] = (uint8_t) ( ( data_from_cipher[ i ] << 24 ) >> 24 );                      
    }

    uart_send( data_tx, 16 ) ;
    uart_wait_tx_done();

    }

}
