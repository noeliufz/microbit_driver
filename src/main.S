.section .text
.syntax unified
.global main

main:
    /* 初始化 UART */
    bl uart_init
    
    /* 读取温度传感器值 */
    bl read_temperature

    /* 通过 UART 发送温度数据 */
    bl uart_send

    ldr r0, =16000000

    /* 延时 1 秒 */
    bl delay

    /* 重复循环 */
    b main

/* --------------------------------------- */

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


.type delay, %function
delay:
    subs r0, 1
    bmi delay_return
    b delay
delay_return:
    bx lr
.size delay, .-delay