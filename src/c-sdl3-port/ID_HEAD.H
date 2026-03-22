// ID_HEAD.H

#ifndef __ID_HEAD_H__
#define __ID_HEAD_H__

#include <stdint.h>

#define	EXTENSION	"WLF"
#define WOLF

#define	TEXTGR	0
#define	CGAGR	1
#define	EGAGR	2
#define	VGAGR	3

#define GRMODE	VGAGR

#include "VERSION.H"

#include <stdbool.h>
typedef	int	boolean;
typedef	uint8_t					byte;
typedef	uint16_t				word;
typedef	uint32_t				longword;
typedef	byte *					Ptr;

typedef	struct
		{
			int	x,y;
		} Point;

typedef	struct
		{
			Point	ul,lr;
		} Rect;


void	Quit (char *error);		// defined in user program

#endif /* __ID_HEAD_H__ */
