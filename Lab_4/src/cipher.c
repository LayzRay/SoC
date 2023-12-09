#include <cipher.h>

volatile struct CIPHER_APB* cipher; 

void cipher_init()
{
    CGREG |= ( 1 << CGCIPHER );
    cipher = (volatile struct CIPHER_APB*)(CIPHER_BASE_ADDR);
    cipher -> CIPHER_REG_RST = 0x1;
    cipher_reset();
}

void cipher_reset()
{
    cipher -> CIPHER_REG_RST = 0x0;
    cipher -> CIPHER_REG_RST = 0x1;
}

void cipher_write_data( volatile uint32_t* data )
{
    for ( uint8_t i = 0; i < 4; i = i + 1 )
        cipher -> CIPHER_REG_DATA_IN[ 3 - i ] = *( data + i ); 
}

void cipher_read_data( volatile uint32_t* read_data )
{
    for ( uint8_t i = 0; i < 4; i = i + 1 )
    *( read_data + i ) = cipher -> CIPHER_REG_DATA_OUT[ 3 - i ];
}

void cipher_set_req()
{
    cipher -> CIPHER_REG_ACK = 0x0;
    cipher -> CIPHER_REG_REQ = 0x1;
}

void cipher_set_ack()
{
    cipher -> CIPHER_REG_ACK = 0x1;
    cipher -> CIPHER_REG_REQ = 0x0;
}

uint8_t cipher_is_valid()
{
    if ( cipher -> CIPHER_REG_VALID )
        return 1;
    else 
        return 0;
}

uint8_t cipher_is_busy()
{
    if ( cipher -> CIPHER_REG_BUSY )
        return 1;
    else 
        return 0;
}
