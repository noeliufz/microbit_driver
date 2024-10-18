#include <stdint.h>
extern int main_asm(void);
extern int read_temperature(void);
extern void uart_init(void);
extern void uart_send(int);
extern void delay(int);
extern void display_word(uint16_t[]);
extern void main_loop(void);

extern void init_leds(void);
int main()
{
    uart_init();

    uint16_t data[] ={
 0b00000,
 0b00000,
 0b00000,
 0b00000,
 0b00000,
 0b00000,
 0b11111,
 0b00100,
 0b00100,
 0b11111,
 0b00000,
 0b11111,
 0b10101,
 0b10101,
 0b00000,
 0b11111,
 0b10000,
 0b10000,
 0b00000,
 0b11111,
 0b10000,
 0b10000,
 0b00000,
 0b01110,
 0b10001,
 0b10001,
 0b01110,
 0b00000,
 0b00000,
 0b10111,
 0b00000,
 0b00000,
 0b00000,
 0b00000,
    };

    while (1)
    {
        display_word(&data[0]);
    }
    // int t = read_temperature();
    // uart_send(1);
    // uart_send(t);
    // delay(1600000);
}
