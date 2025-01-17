/**
 * keyboard.h 键盘相关
 */

#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "type.h"

#define KB_BUFSIZE	64
#define BREAK_MASK	0x80	/* Break Code 的最高位为 1 */
#define MAKE_MASK	0x7F	/* Make Code 最高位为 0 */


void keyboard_read();

typedef struct {
	u8	*p_head;		/* 队列头指针 */
	u8	*p_tail;		/* 队列尾指针 */
	int	count;			/* 缓冲区内待处理元素数 */
	u8	buf_queue[KB_BUFSIZE];	/* 缓冲区(队列), 存储 Scan Code */
} KB_INPUT;

#endif /* KEYBOARD_H */
