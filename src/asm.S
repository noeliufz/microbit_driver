.section .text
.syntax unified
.global main_asm, uart_init, read_temperature, uart_send, delay, main_loop, display_word
@ SYST Constants
.set SYST_CSR, 0xE000E010
.set SYST_RVR, 0xE000E014

.type display_word, %function
display_word:
  push {r0}
  @ enable systicker
  ldr r0, =SYST_CSR
  ldr r1, [r0]
  ldr r2, =0b111
  orr r1, r2
  str r1, [r0]
  @ set reload value
  ldr r0, =SYST_RVR
  ldr r1, [r0]
  ldr r2, =16000000
  str r2, [r0]
  bl init_leds
  pop {r0}

.type main_loop, %function
main_loop:
    bl word_loop
    b main_loop

/* --------------------------------------- */

.type uart_init, %function
/* 初始化 UART */
uart_init:
    /* 配置波特率为 115200 */
    ldr r0, =0x40002524  /* UART BAUDRATE 寄存器地址 (nRF52 特定) */
    ldr r1, =0x01D60000  /* 设置波特率为 115200 */
    str r1, [r0]         /* 写入波特率值 */

    /* 使能 UART，启用 TX 和 RX */
    ldr r0, =0x40002500  /* UART ENABLE 寄存器 */
    ldr r1, =4           /* 使能 UART (4: 启用 TX 和 RX) */
    str r1, [r0]

    /* 配置 TXD 引脚为 P0.06 */
    ldr r0, =0x4000250C   /* UART PSEL.TXD 寄存器地址 */
    ldr r1, =0x06         /* 设置 TXD 引脚为 P0.06 */
    str r1, [r0]

    /* 启动 TX 发送任务 */
    ldr r0, =0x40002008  /* TASKS_STARTTX */
    ldr r1, =1
    str r1, [r0]         /* 启动发送任务 */

    bx lr

.type read_temperature, %function
/* 读取温度传感器值 */
read_temperature:
    ldr r0, =0x4000C000  /* TEMP 寄存器基地址 */
    ldr r1, =1
    str r1, [r0, #0x000] /* 启动温度传感器任务 */

wait_temp:
    ldr r1, [r0, #0x100] /* 读取任务完成寄存器 */
    cmp r1, #1           /* 检查是否任务完成 */
    bne wait_temp        /* 如果未完成，继续等待 */

    ldr r0, [r0, #0x508] /* 读取温度值 */
    bx lr

/* 通过 UART 发送温度数据 */
uart_send:
    /* 使用 r0 中的温度值发送数据 */
    ldr r1, =0x4000251C  /* UART TXD 寄存器地址 */
    str r0, [r1]         /* 将温度数据写入 UART 数据寄存器 */

wait_tx:
    ldr r2, =0x4000211C  /* UART TXDRDY 事件寄存器地址 */
    ldr r3, [r2]         /* 读取 TXDRDY 状态 */
    cmp r3, #1           /* 检查是否发送完成 */
    
    bne wait_tx          /* 如果未完成，继续等待 */

    /* 清除 TXDRDY 标志 */
    ldr r1, =1           /* 将1写入 TXDRDY 来清除标志 */
    str r1, [r2]         /* 清除 TXDRDY 标志 */

    bx lr



    .equ SAADC_BASE, 0x40007000       @ SAADC 基地址
    .equ SAADC_TASKS_START, 0x000     @ 启动 SAADC 任务
    .equ SAADC_TASKS_SAMPLE, 0x004    @ 触发 SAADC 采样
    .equ SAADC_EVENTS_END, 0x100      @ SAADC 转换结束事件
    .equ SAADC_RESULT, 0x500          @ SAADC 结果寄存器
    .equ SAADC_ENABLE, 0x500          @ SAADC 使能寄存器
    .equ SAADC_CH0_PSELP, 0x510       @ SAADC 通道 0 正极引脚选择
    
    .equ GPIO_BASE, 0x50000000        @ GPIO 基地址
    .equ GPIO_DIRSET, 0x518           @ GPIO 设置为输出
    .equ GPIO_DIR, 0x514           @ GPIO 设置为输入

    .global get_light_level
    .type get_light_level, %function


get_light_level:
    // Set up the ADC and configure the GPIO pin connected to the light sensor
    LDR R0, =0x50000000 // GPIO base address for micro:bit
    MOV R1, #0x01       // Select COL1 (connected to ADC) as input
    STR R1, [R0, #0x700] // Configure pin as input
    
    LDR R0, =0x40007000  // SAADC 基地址
    LDR R1, =1
    STR R1, [R0, #0x500] // TASKS_START: 启动 SAAD
    // 启动 SAADC
    LDR R1, =1
    STR R1, [R0, #0x000] // TASKS_START: 启动 SAADC

    // 启动采样
    STR R1, [R0, #0x004] // TASKS_SAMPLE: 启动采样

wait_adc:
    LDR R2, [R0, #0x10C] // 读取 EVENTS_RESULTDONE: 检查转换是否完成
    TST R2, #1           // 检查最低位是否为 1
    BEQ wait_adc          // 如果没有完成，继续等待

    // 读取转换结果
    LDR R3, [R0, #0x62C] // 读取结果的指针地址（如果配置了）
    
    // 继续处理结果...

.type word_loop, %function
word_loop:
  @ store the registers
  push {r0, r1, r2, r3, lr}
  @ load the "HELLO" display columns
  @ ldr r3, =hello_col
  mov r3, r0
  @ load the pointer to start the display with
  @ it will increment by system time ticker
  ldr r2, =word_pointer
  ldr r2, [r2]

  @ start scanning for each row
  ldr r0, =0b00001
  ldr r1, [r3, r2]
  bl word_scanning

  add r2, #2
  ldr r0, =0b00010
  ldr r1, [r3,r2]
  bl word_scanning
  
  add r2, #2
  ldr r0, =0b00100
  ldr r1, [r3,r2]
  bl word_scanning
  
  add r2, #2
  ldr r0, =0b01000
  ldr r1, [r3,r2]
  bl word_scanning

  add r2, #2
  ldr r0, =0b10000
  ldr r1, [r3,r2]
  bl word_scanning

  @ restore registers
  pop {r0, r1, r2, r3, lr}
  @ go back to main loop
  b main_loop

.type word_scanning, %function
@ args:
@   r0: coloumn state
@   r1: row state
word_scanning:
  push {r3}
  push {r2}
  push {lr}
  push {r1}
  @ use r0 to write column pins
  bl write_column_pins
  pop {r0}
  @ use r1 in parameters to write row pins
  bl write_row_pins

  ldr r0, =100
  bl delay

  @ off the leds for a certain time
  ldr r0, =0b00000
  bl write_column_pins
  ldr r0, =0b00000
  bl write_row_pins
  ldr r0, =100
  bl delay
  
  @ restore registers
  pop {lr}
  pop {r2}
  pop {r3}
  bx lr


.global SysTick_Handler
.type SysTick_Handler, %function
SysTick_Handler:
  @ update word loop pointer in systick handler
  @ store the registers
  push {r0, r1}
  @ load the word pointer
  ldr r0, =word_pointer
  ldr r1, [r0]
  @ add 2 
  add r1, #2
  @ store back the word pointer
  str r1, [r0]
  @ if it touches the end of the word, change back to the beginning
  cmp r1, #60
  beq restart
  @ restore registers
  pop {r0, r1}
  bx lr
restart:
  @ set the pointer to 0 to restart
  ldr r1, =0 
  str r1, [r0]
  pop {r0, r1}
  bx lr
.size SysTick_Handler, .-SysTick_Handler

.global memcpy
.type memcpy, %function

memcpy:
    cmp r2, #0             @ 如果长度为0，直接返回
    beq end_memcpy

copy_loop:
    ldrb r3, [r1], #1      @ 从源地址加载一个字节
    strb r3, [r0], #1      @ 存储到目标地址
    subs r2, r2, #1        @ 长度减1
    bne copy_loop          @ 如果还有字节，继续循环

end_memcpy:
    bx lr                  @ 返回
.type delay, %function
delay:
    subs r0, 1
    bmi delay_return
    b delay
delay_return:
    bx lr
.size delay, .-delay

word_pointer:
  @ pointer for word display loop
  @ point to the start byte to start display leds
  .word 0 
