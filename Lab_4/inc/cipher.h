#include <pulpino.h>
#include <stdio.h>

__attribute__ ((packed)) struct CIPHER_APB
{
    volatile uint32_t CIPHER_REG_RST;   // 0x0
    volatile uint32_t CIPHER_REG_REQ;   // 0x4
    volatile uint32_t CIPHER_REG_ACK;   // 0x8

    volatile uint32_t CIPHER_REG_VALID; // 0xc
    volatile uint32_t CIPHER_REG_BUSY;  // 0x10
    
    volatile uint32_t CIPHER_REG_DATA_IN  [4];
    volatile uint32_t CIPHER_REG_DATA_OUT [4];

};

void cipher_init(void);
void cipher_reset(void);

void cipher_write_data(volatile uint32_t* data);
void cipher_read_data(volatile uint32_t* read_data);

void cipher_set_ack(void);
void cipher_set_req(void);

uint8_t cipher_is_valid(void);
uint8_t cipher_is_busy(void);
