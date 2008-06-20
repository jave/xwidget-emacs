/* Definitions and headers for communication on the Microsoft W32 API.
   Copyright (C) 1995, 2001, 2002, 2003, 2004, 2005,
                 2006, 2007, 2008  Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */

#ifndef EMACS_W32GUI_H
#define EMACS_W32GUI_H
#include <windows.h>

#include "w32bdf.h"

/* Emulate XCharStruct.  */
typedef struct _XCharStruct
{
  short rbearing;
  short lbearing;
  short width;
  short ascent;
  short descent;
} XCharStruct;

/* Emulate widget_value from ../lwlib/lwlib.h, modified for Windows.  */
typedef void * XtPointer;
typedef char Boolean;
enum button_type
{
  BUTTON_TYPE_NONE,
  BUTTON_TYPE_TOGGLE,
  BUTTON_TYPE_RADIO
};
typedef struct _widget_value
{
  /* name of widget */
  Lisp_Object   lname;
  char*		name;
  /* value (meaning depend on widget type) */
  char*		value;
  /* keyboard equivalent. no implications for XtTranslations */
  Lisp_Object   lkey;
  char*		key;
  /* Help string or nil if none.
     GC finds this string through the frame's menu_bar_vector
     or through menu_items.  */
  Lisp_Object	help;
  /* true if enabled */
  Boolean	enabled;
  /* true if selected */
  Boolean	selected;
  /* The type of a button.  */
  enum button_type button_type;
  /* true if menu title */
  Boolean       title;
#if 0
  /* true if was edited (maintained by get_value) */
  Boolean	edited;
  /* true if has changed (maintained by lw library) */
  change_type	change;
  /* true if this widget itself has changed,
     but not counting the other widgets found in the `next' field.  */
  change_type   this_one_change;
#endif
  /* Contents of the sub-widgets, also selected slot for checkbox */
  struct _widget_value*	contents;
  /* data passed to callback */
  XtPointer	call_data;
  /* next one in the list */
  struct _widget_value*	next;
#if 0
  /* slot for the toolkit dependent part.  Always initialize to NULL. */
  void* toolkit_data;
  /* tell us if we should free the toolkit data slot when freeing the
     widget_value itself. */
  Boolean free_toolkit_data;

  /* we resource the widget_value structures; this points to the next
     one on the free list if this one has been deallocated.
   */
  struct _widget_value *free_list;
#endif
} widget_value;
/* Local memory management for menus.  */
#define local_heap (GetProcessHeap ())
#define local_alloc(n) (HeapAlloc (local_heap, HEAP_ZERO_MEMORY, (n)))
#define local_free(p) (HeapFree (local_heap, 0, ((LPVOID) (p))))

#define malloc_widget_value() ((widget_value *) local_alloc (sizeof (widget_value)))
#define free_widget_value(wv) (local_free ((wv)))


enum w32_char_font_type
{
  UNKNOWN_FONT = 0 /* FONT_TYPE_UNKNOWN */,
  ANSI_FONT,
  UNICODE_FONT,
  BDF_1D_FONT,
  BDF_2D_FONT
};

typedef struct W32FontStruct {
  enum w32_char_font_type font_type;
  TEXTMETRIC tm;
  HFONT hfont;
  bdffont *bdf;
  int double_byte_p;
  XCharStruct max_bounds;
  XCharStruct scratch;
  /* Only store info for ascii chars, if not fixed pitch.  */
  XCharStruct * per_char;
} W32FontStruct;

typedef struct W32FontStruct XFontStruct;

/* Emulate X GC's by keeping color and font info in a structure.  */
typedef struct _XGCValues
{
  COLORREF foreground;
  COLORREF background;
  struct font *font;
} XGCValues;

#define GCForeground 0x01
#define GCBackground 0x02
#define GCFont 0x03

typedef HBITMAP Pixmap;
typedef HBITMAP Bitmap;

typedef char * XrmDatabase;

typedef XGCValues * GC;
typedef COLORREF Color;
typedef DWORD Time;
typedef HWND Window;
typedef HDC Display;  /* HDC so it doesn't conflict with xpm lib.  */
typedef HCURSOR Cursor;

#define No_Cursor (0)

#define XChar2b wchar_t

/* Dealing with bits of wchar_t as if they were an XChar2b.  */
#define STORE_XCHAR2B(chp, byte1, byte2) \
  ((*chp) = ((XChar2b)((((byte1) & 0x00ff) << 8) | ((byte2) & 0x00ff))))

#define XCHAR2B_BYTE1(chp) \
 (((*chp) & 0xff00) >> 8)

#define XCHAR2B_BYTE2(chp) \
 ((*chp) & 0x00ff)


/* Windows equivalent of XImage.  */
typedef struct _XImage
{
  unsigned char * data;
  BITMAPINFO info;
  /* Optional RGBQUAD array for palette follows (see BITMAPINFO docs).  */
} XImage;

#define FACE_DEFAULT (~0)

extern HINSTANCE hinst;
extern HINSTANCE hprevinst;
extern LPSTR lpCmdLine;
extern int nCmdShow;

/* Bit Gravity */

#define ForgetGravity		0
#define NorthWestGravity	1
#define NorthGravity		2
#define NorthEastGravity	3
#define WestGravity		4
#define CenterGravity		5
#define EastGravity		6
#define SouthWestGravity	7
#define SouthGravity		8
#define SouthEastGravity	9
#define StaticGravity		10

#define NoValue		0x0000
#define XValue  	0x0001
#define YValue		0x0002
#define WidthValue  	0x0004
#define HeightValue  	0x0008
#define AllValues 	0x000F
#define XNegative 	0x0010
#define YNegative 	0x0020

#define USPosition	(1L << 0) /* user specified x, y */
#define USSize		(1L << 1) /* user specified width, height */

#define PPosition	(1L << 2) /* program specified position */
#define PSize		(1L << 3) /* program specified size */
#define PMinSize	(1L << 4) /* program specified minimum size */
#define PMaxSize	(1L << 5) /* program specified maximum size */
#define PResizeInc	(1L << 6) /* program specified resize increments */
#define PAspect		(1L << 7) /* program specified min and max aspect ratios */
#define PBaseSize	(1L << 8) /* program specified base for incrementing */
#define PWinGravity	(1L << 9) /* program specified window gravity */

extern int XParseGeometry ();


typedef struct {
    int x, y;
    unsigned width, height;
} XRectangle;

#define NativeRectangle RECT

#define CONVERT_TO_XRECT(xr,nr)			\
  ((xr).x = (nr).left,				\
   (xr).y = (nr).top,				\
   (xr).width = ((nr).right - (nr).left),	\
   (xr).height = ((nr).bottom - (nr).top))

#define CONVERT_FROM_XRECT(xr,nr)		\
  ((nr).left = (xr).x,				\
   (nr).top = (xr).y,				\
   (nr).right = ((xr).x + (xr).width),		\
   (nr).bottom = ((xr).y + (xr).height))

#define STORE_NATIVE_RECT(nr,x,y,width,height)	\
  ((nr).left = (x),				\
   (nr).top = (y),				\
   (nr).right = ((nr).left + (width)),		\
   (nr).bottom = ((nr).top + (height)))


#endif /* EMACS_W32GUI_H */

/* arch-tag: 9172e5fb-45a5-4684-afd9-ca0e81324604
   (do not change this comment) */
