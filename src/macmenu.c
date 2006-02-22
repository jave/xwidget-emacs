/* Menu support for GNU Emacs on Mac OS.
   Copyright (C) 2000, 2001, 2002, 2003, 2004,
                 2005, 2006 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA.  */

/* Contributed by Andrew Choi (akochoi@mac.com).  */

#include <config.h>

#include <stdio.h>

#include "lisp.h"
#include "termhooks.h"
#include "keyboard.h"
#include "keymap.h"
#include "frame.h"
#include "window.h"
#include "blockinput.h"
#include "buffer.h"
#include "charset.h"
#include "coding.h"

#if !TARGET_API_MAC_CARBON
#include <MacTypes.h>
#include <Menus.h>
#include <QuickDraw.h>
#include <ToolUtils.h>
#include <Fonts.h>
#include <Controls.h>
#include <Windows.h>
#include <Events.h>
#if defined (__MRC__) || (__MSL__ >= 0x6000)
#include <ControlDefinitions.h>
#endif
#endif /* not TARGET_API_MAC_CARBON */

/* This may include sys/types.h, and that somehow loses
   if this is not done before the other system files.  */
#include "macterm.h"

/* Load sys/types.h if not already loaded.
   In some systems loading it twice is suicidal.  */
#ifndef makedev
#include <sys/types.h>
#endif

#include "dispextern.h"

#define POPUP_SUBMENU_ID 235
#define MIN_POPUP_SUBMENU_ID 512
#define MIN_MENU_ID 256
#define MIN_SUBMENU_ID 1

#define DIALOG_WINDOW_RESOURCE 130

#define HAVE_DIALOGS 1

#undef HAVE_MULTILINGUAL_MENU
#undef HAVE_DIALOGS /* TODO: Implement native dialogs.  */

/******************************************************************/
/* Definitions copied from lwlib.h */

typedef void * XtPointer;

enum button_type
{
  BUTTON_TYPE_NONE,
  BUTTON_TYPE_TOGGLE,
  BUTTON_TYPE_RADIO
};

/* This structure is based on the one in ../lwlib/lwlib.h, modified
   for Mac OS.  */
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

/* Assumed by other routines to zero area returned.  */
#define malloc_widget_value() (void *)memset (xmalloc (sizeof (widget_value)),\
                                              0, (sizeof (widget_value)))
#define free_widget_value(wv) xfree (wv)

/******************************************************************/

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif /* no TRUE */

Lisp_Object Vmenu_updating_frame;

Lisp_Object Qdebug_on_next_call;

extern Lisp_Object Qmenu_bar, Qmac_apple_event;

extern Lisp_Object QCtoggle, QCradio;

extern Lisp_Object Voverriding_local_map;
extern Lisp_Object Voverriding_local_map_menu_flag;

extern Lisp_Object Qoverriding_local_map, Qoverriding_terminal_local_map;

extern Lisp_Object Qmenu_bar_update_hook;

void set_frame_menubar P_ ((FRAME_PTR, int, int));

#if TARGET_API_MAC_CARBON
#define ENCODE_MENU_STRING(str) ENCODE_UTF_8 (str)
#else
#define ENCODE_MENU_STRING(str) ENCODE_SYSTEM (str)
#endif

static void push_menu_item P_ ((Lisp_Object, Lisp_Object, Lisp_Object,
				Lisp_Object, Lisp_Object, Lisp_Object,
				Lisp_Object, Lisp_Object));
#ifdef HAVE_DIALOGS
static Lisp_Object mac_dialog_show P_ ((FRAME_PTR, int, Lisp_Object,
					Lisp_Object, char **));
#endif
static Lisp_Object mac_menu_show P_ ((struct frame *, int, int, int, int,
				      Lisp_Object, char **));
static void keymap_panes P_ ((Lisp_Object *, int, int));
static void single_keymap_panes P_ ((Lisp_Object, Lisp_Object, Lisp_Object,
				     int, int));
static void list_of_panes P_ ((Lisp_Object));
static void list_of_items P_ ((Lisp_Object));

static int fill_menu P_ ((MenuHandle, widget_value *, int));
static void fill_menubar P_ ((widget_value *, int));
static void dispose_menus P_ ((int));


/* This holds a Lisp vector that holds the results of decoding
   the keymaps or alist-of-alists that specify a menu.

   It describes the panes and items within the panes.

   Each pane is described by 3 elements in the vector:
   t, the pane name, the pane's prefix key.
   Then follow the pane's items, with 5 elements per item:
   the item string, the enable flag, the item's value,
   the definition, and the equivalent keyboard key's description string.

   In some cases, multiple levels of menus may be described.
   A single vector slot containing nil indicates the start of a submenu.
   A single vector slot containing lambda indicates the end of a submenu.
   The submenu follows a menu item which is the way to reach the submenu.

   A single vector slot containing quote indicates that the
   following items should appear on the right of a dialog box.

   Using a Lisp vector to hold this information while we decode it
   takes care of protecting all the data from GC.  */

#define MENU_ITEMS_PANE_NAME 1
#define MENU_ITEMS_PANE_PREFIX 2
#define MENU_ITEMS_PANE_LENGTH 3

enum menu_item_idx
{
  MENU_ITEMS_ITEM_NAME = 0,
  MENU_ITEMS_ITEM_ENABLE,
  MENU_ITEMS_ITEM_VALUE,
  MENU_ITEMS_ITEM_EQUIV_KEY,
  MENU_ITEMS_ITEM_DEFINITION,
  MENU_ITEMS_ITEM_TYPE,
  MENU_ITEMS_ITEM_SELECTED,
  MENU_ITEMS_ITEM_HELP,
  MENU_ITEMS_ITEM_LENGTH
};

static Lisp_Object menu_items;

/* Number of slots currently allocated in menu_items.  */
static int menu_items_allocated;

/* This is the index in menu_items of the first empty slot.  */
static int menu_items_used;

/* The number of panes currently recorded in menu_items,
   excluding those within submenus.  */
static int menu_items_n_panes;

/* Current depth within submenus.  */
static int menu_items_submenu_depth;

/* This is set nonzero after the user activates the menu bar, and set
   to zero again after the menu bars are redisplayed by prepare_menu_bar.
   While it is nonzero, all calls to set_frame_menubar go deep.

   I don't understand why this is needed, but it does seem to be
   needed on Motif, according to Marcus Daniels <marcus@sysc.pdx.edu>.  */

int pending_menu_activation;

/* Initialize the menu_items structure if we haven't already done so.
   Also mark it as currently empty.  */

static void
init_menu_items ()
{
  if (NILP (menu_items))
    {
      menu_items_allocated = 60;
      menu_items = Fmake_vector (make_number (menu_items_allocated), Qnil);
    }

  menu_items_used = 0;
  menu_items_n_panes = 0;
  menu_items_submenu_depth = 0;
}

/* Call at the end of generating the data in menu_items.  */

static void
finish_menu_items ()
{
}

/* Call when finished using the data for the current menu
   in menu_items.  */

static void
discard_menu_items ()
{
  /* Free the structure if it is especially large.
     Otherwise, hold on to it, to save time.  */
  if (menu_items_allocated > 200)
    {
      menu_items = Qnil;
      menu_items_allocated = 0;
    }
}

/* Make the menu_items vector twice as large.  */

static void
grow_menu_items ()
{
  Lisp_Object old;
  int old_size = menu_items_allocated;
  old = menu_items;

  menu_items_allocated *= 2;
  menu_items = Fmake_vector (make_number (menu_items_allocated), Qnil);
  bcopy (XVECTOR (old)->contents, XVECTOR (menu_items)->contents,
	 old_size * sizeof (Lisp_Object));
}

/* Begin a submenu.  */

static void
push_submenu_start ()
{
  if (menu_items_used + 1 > menu_items_allocated)
    grow_menu_items ();

  XVECTOR (menu_items)->contents[menu_items_used++] = Qnil;
  menu_items_submenu_depth++;
}

/* End a submenu.  */

static void
push_submenu_end ()
{
  if (menu_items_used + 1 > menu_items_allocated)
    grow_menu_items ();

  XVECTOR (menu_items)->contents[menu_items_used++] = Qlambda;
  menu_items_submenu_depth--;
}

/* Indicate boundary between left and right.  */

static void
push_left_right_boundary ()
{
  if (menu_items_used + 1 > menu_items_allocated)
    grow_menu_items ();

  XVECTOR (menu_items)->contents[menu_items_used++] = Qquote;
}

/* Start a new menu pane in menu_items.
   NAME is the pane name.  PREFIX_VEC is a prefix key for this pane.  */

static void
push_menu_pane (name, prefix_vec)
     Lisp_Object name, prefix_vec;
{
  if (menu_items_used + MENU_ITEMS_PANE_LENGTH > menu_items_allocated)
    grow_menu_items ();

  if (menu_items_submenu_depth == 0)
    menu_items_n_panes++;
  XVECTOR (menu_items)->contents[menu_items_used++] = Qt;
  XVECTOR (menu_items)->contents[menu_items_used++] = name;
  XVECTOR (menu_items)->contents[menu_items_used++] = prefix_vec;
}

/* Push one menu item into the current pane.  NAME is the string to
   display.  ENABLE if non-nil means this item can be selected.  KEY
   is the key generated by choosing this item, or nil if this item
   doesn't really have a definition.  DEF is the definition of this
   item.  EQUIV is the textual description of the keyboard equivalent
   for this item (or nil if none).  TYPE is the type of this menu
   item, one of nil, `toggle' or `radio'. */

static void
push_menu_item (name, enable, key, def, equiv, type, selected, help)
     Lisp_Object name, enable, key, def, equiv, type, selected, help;
{
  if (menu_items_used + MENU_ITEMS_ITEM_LENGTH > menu_items_allocated)
    grow_menu_items ();

  XVECTOR (menu_items)->contents[menu_items_used++] = name;
  XVECTOR (menu_items)->contents[menu_items_used++] = enable;
  XVECTOR (menu_items)->contents[menu_items_used++] = key;
  XVECTOR (menu_items)->contents[menu_items_used++] = equiv;
  XVECTOR (menu_items)->contents[menu_items_used++] = def;
  XVECTOR (menu_items)->contents[menu_items_used++] = type;
  XVECTOR (menu_items)->contents[menu_items_used++] = selected;
  XVECTOR (menu_items)->contents[menu_items_used++] = help;
}

/* Look through KEYMAPS, a vector of keymaps that is NMAPS long,
   and generate menu panes for them in menu_items.
   If NOTREAL is nonzero,
   don't bother really computing whether an item is enabled.  */

static void
keymap_panes (keymaps, nmaps, notreal)
     Lisp_Object *keymaps;
     int nmaps;
     int notreal;
{
  int mapno;

  init_menu_items ();

  /* Loop over the given keymaps, making a pane for each map.
     But don't make a pane that is empty--ignore that map instead.
     P is the number of panes we have made so far.  */
  for (mapno = 0; mapno < nmaps; mapno++)
    single_keymap_panes (keymaps[mapno],
			 Fkeymap_prompt (keymaps[mapno]), Qnil, notreal, 10);

  finish_menu_items ();
}

/* Args passed between single_keymap_panes and single_menu_item.  */
struct skp
  {
     Lisp_Object pending_maps;
     int maxdepth, notreal;
  };

static void single_menu_item P_ ((Lisp_Object, Lisp_Object, Lisp_Object,
				  void *));

/* This is a recursive subroutine of keymap_panes.
   It handles one keymap, KEYMAP.
   The other arguments are passed along
   or point to local variables of the previous function.
   If NOTREAL is nonzero, only check for equivalent key bindings, don't
   evaluate expressions in menu items and don't make any menu.

   If we encounter submenus deeper than MAXDEPTH levels, ignore them.  */

static void
single_keymap_panes (keymap, pane_name, prefix, notreal, maxdepth)
     Lisp_Object keymap;
     Lisp_Object pane_name;
     Lisp_Object prefix;
     int notreal;
     int maxdepth;
{
  struct skp skp;
  struct gcpro gcpro1;

  skp.pending_maps = Qnil;
  skp.maxdepth = maxdepth;
  skp.notreal = notreal;

  if (maxdepth <= 0)
    return;

  push_menu_pane (pane_name, prefix);

  GCPRO1 (skp.pending_maps);
  map_keymap (keymap, single_menu_item, Qnil, &skp, 1);
  UNGCPRO;

  /* Process now any submenus which want to be panes at this level.  */
  while (CONSP (skp.pending_maps))
    {
      Lisp_Object elt, eltcdr, string;
      elt = XCAR (skp.pending_maps);
      eltcdr = XCDR (elt);
      string = XCAR (eltcdr);
      /* We no longer discard the @ from the beginning of the string here.
	 Instead, we do this in mac_menu_show.  */
      single_keymap_panes (Fcar (elt), string,
			   XCDR (eltcdr), notreal, maxdepth - 1);
      skp.pending_maps = XCDR (skp.pending_maps);
    }
}

/* This is a subroutine of single_keymap_panes that handles one
   keymap entry.
   KEY is a key in a keymap and ITEM is its binding.
   SKP->PENDING_MAPS_PTR is a list of keymaps waiting to be made into
   separate panes.
   If SKP->NOTREAL is nonzero, only check for equivalent key bindings, don't
   evaluate expressions in menu items and don't make any menu.
   If we encounter submenus deeper than SKP->MAXDEPTH levels, ignore them.  */

static void
single_menu_item (key, item, dummy, skp_v)
     Lisp_Object key, item, dummy;
     void *skp_v;
{
  Lisp_Object map, item_string, enabled;
  struct gcpro gcpro1, gcpro2;
  int res;
  struct skp *skp = skp_v;

  /* Parse the menu item and leave the result in item_properties.  */
  GCPRO2 (key, item);
  res = parse_menu_item (item, skp->notreal, 0);
  UNGCPRO;
  if (!res)
    return;			/* Not a menu item.  */

  map = XVECTOR (item_properties)->contents[ITEM_PROPERTY_MAP];

  if (skp->notreal)
    {
      /* We don't want to make a menu, just traverse the keymaps to
	 precompute equivalent key bindings.  */
      if (!NILP (map))
	single_keymap_panes (map, Qnil, key, 1, skp->maxdepth - 1);
      return;
    }

  enabled = XVECTOR (item_properties)->contents[ITEM_PROPERTY_ENABLE];
  item_string = XVECTOR (item_properties)->contents[ITEM_PROPERTY_NAME];

  if (!NILP (map) && SREF (item_string, 0) == '@')
    {
      if (!NILP (enabled))
	/* An enabled separate pane. Remember this to handle it later.  */
	skp->pending_maps = Fcons (Fcons (map, Fcons (item_string, key)),
				   skp->pending_maps);
      return;
    }

  push_menu_item (item_string, enabled, key,
		  XVECTOR (item_properties)->contents[ITEM_PROPERTY_DEF],
		  XVECTOR (item_properties)->contents[ITEM_PROPERTY_KEYEQ],
		  XVECTOR (item_properties)->contents[ITEM_PROPERTY_TYPE],
		  XVECTOR (item_properties)->contents[ITEM_PROPERTY_SELECTED],
		  XVECTOR (item_properties)->contents[ITEM_PROPERTY_HELP]);

  /* Display a submenu using the toolkit.  */
  if (! (NILP (map) || NILP (enabled)))
    {
      push_submenu_start ();
      single_keymap_panes (map, Qnil, key, 0, skp->maxdepth - 1);
      push_submenu_end ();
    }
}

/* Push all the panes and items of a menu described by the
   alist-of-alists MENU.
   This handles old-fashioned calls to x-popup-menu.  */

static void
list_of_panes (menu)
     Lisp_Object menu;
{
  Lisp_Object tail;

  init_menu_items ();

  for (tail = menu; CONSP (tail); tail = XCDR (tail))
    {
      Lisp_Object elt, pane_name, pane_data;
      elt = XCAR (tail);
      pane_name = Fcar (elt);
      CHECK_STRING (pane_name);
      push_menu_pane (ENCODE_MENU_STRING (pane_name), Qnil);
      pane_data = Fcdr (elt);
      CHECK_CONS (pane_data);
      list_of_items (pane_data);
    }

  finish_menu_items ();
}

/* Push the items in a single pane defined by the alist PANE.  */

static void
list_of_items (pane)
     Lisp_Object pane;
{
  Lisp_Object tail, item, item1;

  for (tail = pane; CONSP (tail); tail = XCDR (tail))
    {
      item = XCAR (tail);
      if (STRINGP (item))
	push_menu_item (ENCODE_MENU_STRING (item), Qnil, Qnil, Qt,
			Qnil, Qnil, Qnil, Qnil);
      else if (CONSP (item))
	{
	  item1 = XCAR (item);
	  CHECK_STRING (item1);
	  push_menu_item (ENCODE_MENU_STRING (item1), Qt, XCDR (item),
			  Qt, Qnil, Qnil, Qnil, Qnil);
	}
      else
	push_left_right_boundary ();

    }
}

static Lisp_Object
cleanup_popup_menu (arg)
     Lisp_Object arg;
{
  discard_menu_items ();
}

DEFUN ("x-popup-menu", Fx_popup_menu, Sx_popup_menu, 2, 2, 0,
       doc: /* Pop up a deck-of-cards menu and return user's selection.
POSITION is a position specification.  This is either a mouse button event
or a list ((XOFFSET YOFFSET) WINDOW)
where XOFFSET and YOFFSET are positions in pixels from the top left
corner of WINDOW.  (WINDOW may be a window or a frame object.)
This controls the position of the top left of the menu as a whole.
If POSITION is t, it means to use the current mouse position.

MENU is a specifier for a menu.  For the simplest case, MENU is a keymap.
The menu items come from key bindings that have a menu string as well as
a definition; actually, the "definition" in such a key binding looks like
\(STRING . REAL-DEFINITION).  To give the menu a title, put a string into
the keymap as a top-level element.

If REAL-DEFINITION is nil, that puts a nonselectable string in the menu.
Otherwise, REAL-DEFINITION should be a valid key binding definition.

You can also use a list of keymaps as MENU.
  Then each keymap makes a separate pane.

When MENU is a keymap or a list of keymaps, the return value is the
list of events corresponding to the user's choice. Note that
`x-popup-menu' does not actually execute the command bound to that
sequence of events.

Alternatively, you can specify a menu of multiple panes
  with a list of the form (TITLE PANE1 PANE2...),
where each pane is a list of form (TITLE ITEM1 ITEM2...).
Each ITEM is normally a cons cell (STRING . VALUE);
but a string can appear as an item--that makes a nonselectable line
in the menu.
With this form of menu, the return value is VALUE from the chosen item.

If POSITION is nil, don't display the menu at all, just precalculate the
cached information about equivalent key sequences.

If the user gets rid of the menu without making a valid choice, for
instance by clicking the mouse away from a valid choice or by typing
keyboard input, then this normally results in a quit and
`x-popup-menu' does not return.  But if POSITION is a mouse button
event (indicating that the user invoked the menu with the mouse) then
no quit occurs and `x-popup-menu' returns nil.  */)
     (position, menu)
     Lisp_Object position, menu;
{
  Lisp_Object keymap, tem;
  int xpos = 0, ypos = 0;
  Lisp_Object title;
  char *error_name = NULL;
  Lisp_Object selection;
  FRAME_PTR f = NULL;
  Lisp_Object x, y, window;
  int keymaps = 0;
  int for_click = 0;
  int specpdl_count = SPECPDL_INDEX ();
  struct gcpro gcpro1;

#ifdef HAVE_MENUS
  if (! NILP (position))
    {
      check_mac ();

      /* Decode the first argument: find the window and the coordinates.  */
      if (EQ (position, Qt)
	  || (CONSP (position) && (EQ (XCAR (position), Qmenu_bar)
				   || EQ (XCAR (position), Qtool_bar)
				   || EQ (XCAR (position), Qmac_apple_event))))
	{
	  /* Use the mouse's current position.  */
	  FRAME_PTR new_f = SELECTED_FRAME ();
	  Lisp_Object bar_window;
	  enum scroll_bar_part part;
	  unsigned long time;

	  if (mouse_position_hook)
	    (*mouse_position_hook) (&new_f, 1, &bar_window,
				    &part, &x, &y, &time);
	  if (new_f != 0)
	    XSETFRAME (window, new_f);
	  else
	    {
	      window = selected_window;
	      XSETFASTINT (x, 0);
	      XSETFASTINT (y, 0);
	    }
	}
      else
	{
	  tem = Fcar (position);
	  if (CONSP (tem))
	    {
	      window = Fcar (Fcdr (position));
	      x = XCAR (tem);
	      y = Fcar (XCDR (tem));
	    }
	  else
	    {
	      for_click = 1;
	      tem = Fcar (Fcdr (position));  /* EVENT_START (position) */
	      window = Fcar (tem);	     /* POSN_WINDOW (tem) */
	      tem = Fcar (Fcdr (Fcdr (tem))); /* POSN_WINDOW_POSN (tem) */
	      x = Fcar (tem);
	      y = Fcdr (tem);
	    }
	}

      CHECK_NUMBER (x);
      CHECK_NUMBER (y);

      /* Decode where to put the menu.  */

      if (FRAMEP (window))
	{
	  f = XFRAME (window);
	  xpos = 0;
	  ypos = 0;
	}
      else if (WINDOWP (window))
	{
	  CHECK_LIVE_WINDOW (window);
	  f = XFRAME (WINDOW_FRAME (XWINDOW (window)));

	  xpos = WINDOW_LEFT_EDGE_X (XWINDOW (window));
	  ypos = WINDOW_TOP_EDGE_Y (XWINDOW (window));
	}
      else
	/* ??? Not really clean; should be CHECK_WINDOW_OR_FRAME,
	   but I don't want to make one now.  */
	CHECK_WINDOW (window);

      xpos += XINT (x);
      ypos += XINT (y);

      XSETFRAME (Vmenu_updating_frame, f);
    }
  else
    Vmenu_updating_frame = Qnil;
#endif /* HAVE_MENUS */

  title = Qnil;
  GCPRO1 (title);

  /* Decode the menu items from what was specified.  */

  keymap = get_keymap (menu, 0, 0);
  if (CONSP (keymap))
    {
      /* We were given a keymap.  Extract menu info from the keymap.  */
      Lisp_Object prompt;

      /* Extract the detailed info to make one pane.  */
      keymap_panes (&menu, 1, NILP (position));

      /* Search for a string appearing directly as an element of the keymap.
	 That string is the title of the menu.  */
      prompt = Fkeymap_prompt (keymap);
      if (NILP (title) && !NILP (prompt))
	title = prompt;

      /* Make that be the pane title of the first pane.  */
      if (!NILP (prompt) && menu_items_n_panes >= 0)
	XVECTOR (menu_items)->contents[MENU_ITEMS_PANE_NAME] = prompt;

      keymaps = 1;
    }
  else if (CONSP (menu) && KEYMAPP (XCAR (menu)))
    {
      /* We were given a list of keymaps.  */
      int nmaps = XFASTINT (Flength (menu));
      Lisp_Object *maps
	= (Lisp_Object *) alloca (nmaps * sizeof (Lisp_Object));
      int i;

      title = Qnil;

      /* The first keymap that has a prompt string
	 supplies the menu title.  */
      for (tem = menu, i = 0; CONSP (tem); tem = XCDR (tem))
	{
	  Lisp_Object prompt;

	  maps[i++] = keymap = get_keymap (XCAR (tem), 1, 0);

	  prompt = Fkeymap_prompt (keymap);
	  if (NILP (title) && !NILP (prompt))
	    title = prompt;
	}

      /* Extract the detailed info to make one pane.  */
      keymap_panes (maps, nmaps, NILP (position));

      /* Make the title be the pane title of the first pane.  */
      if (!NILP (title) && menu_items_n_panes >= 0)
	XVECTOR (menu_items)->contents[MENU_ITEMS_PANE_NAME] = title;

      keymaps = 1;
    }
  else
    {
      /* We were given an old-fashioned menu.  */
      title = Fcar (menu);
      CHECK_STRING (title);

      list_of_panes (Fcdr (menu));

      keymaps = 0;
    }

  if (NILP (position))
    {
      discard_menu_items ();
      UNGCPRO;
      return Qnil;
    }

#ifdef HAVE_MENUS
  /* Display them in a menu.  */
  record_unwind_protect (cleanup_popup_menu, Qnil);
  BLOCK_INPUT;

  selection = mac_menu_show (f, xpos, ypos, for_click,
			     keymaps, title, &error_name);
  UNBLOCK_INPUT;
  unbind_to (specpdl_count, Qnil);

  UNGCPRO;
#endif /* HAVE_MENUS */

  if (error_name) error (error_name);
  return selection;
}

#ifdef HAVE_MENUS

DEFUN ("x-popup-dialog", Fx_popup_dialog, Sx_popup_dialog, 2, 3, 0,
       doc: /* Pop up a dialog box and return user's selection.
POSITION specifies which frame to use.
This is normally a mouse button event or a window or frame.
If POSITION is t, it means to use the frame the mouse is on.
The dialog box appears in the middle of the specified frame.

CONTENTS specifies the alternatives to display in the dialog box.
It is a list of the form (DIALOG ITEM1 ITEM2...).
Each ITEM is a cons cell (STRING . VALUE).
The return value is VALUE from the chosen item.

An ITEM may also be just a string--that makes a nonselectable item.
An ITEM may also be nil--that means to put all preceding items
on the left of the dialog box and all following items on the right.
\(By default, approximately half appear on each side.)

If HEADER is non-nil, the frame title for the box is "Information",
otherwise it is "Question".

If the user gets rid of the dialog box without making a valid choice,
for instance using the window manager, then this produces a quit and
`x-popup-dialog' does not return.  */)
     (position, contents, header)
     Lisp_Object position, contents, header;
{
  FRAME_PTR f = NULL;
  Lisp_Object window;

  check_mac ();

  /* Decode the first argument: find the window or frame to use.  */
  if (EQ (position, Qt)
      || (CONSP (position) && (EQ (XCAR (position), Qmenu_bar)
			       || EQ (XCAR (position), Qtool_bar)
			       || EQ (XCAR (position), Qmac_apple_event))))
    {
#if 0 /* Using the frame the mouse is on may not be right.  */
      /* Use the mouse's current position.  */
      FRAME_PTR new_f = SELECTED_FRAME ();
      Lisp_Object bar_window;
      enum scroll_bar_part part;
      unsigned long time;
      Lisp_Object x, y;

      (*mouse_position_hook) (&new_f, 1, &bar_window, &part, &x, &y, &time);

      if (new_f != 0)
	XSETFRAME (window, new_f);
      else
	window = selected_window;
#endif
      window = selected_window;
    }
  else if (CONSP (position))
    {
      Lisp_Object tem;
      tem = Fcar (position);
      if (CONSP (tem))
	window = Fcar (Fcdr (position));
      else
	{
	  tem = Fcar (Fcdr (position));  /* EVENT_START (position) */
	  window = Fcar (tem);	     /* POSN_WINDOW (tem) */
	}
    }
  else if (WINDOWP (position) || FRAMEP (position))
    window = position;
  else
    window = Qnil;

  /* Decode where to put the menu.  */

  if (FRAMEP (window))
    f = XFRAME (window);
  else if (WINDOWP (window))
    {
      CHECK_LIVE_WINDOW (window);
      f = XFRAME (WINDOW_FRAME (XWINDOW (window)));
    }
  else
    /* ??? Not really clean; should be CHECK_WINDOW_OR_FRAME,
       but I don't want to make one now.  */
    CHECK_WINDOW (window);

#ifndef HAVE_DIALOGS
  /* Display a menu with these alternatives
     in the middle of frame F.  */
  {
    Lisp_Object x, y, frame, newpos;
    XSETFRAME (frame, f);
    XSETINT (x, x_pixel_width (f) / 2);
    XSETINT (y, x_pixel_height (f) / 2);
    newpos = Fcons (Fcons (x, Fcons (y, Qnil)), Fcons (frame, Qnil));

    return Fx_popup_menu (newpos,
			  Fcons (Fcar (contents), Fcons (contents, Qnil)));
  }
#else /* HAVE_DIALOGS */
  {
    Lisp_Object title;
    char *error_name;
    Lisp_Object selection;
    int specpdl_count = SPECPDL_INDEX ();

    /* Decode the dialog items from what was specified.  */
    title = Fcar (contents);
    CHECK_STRING (title);

    list_of_panes (Fcons (contents, Qnil));

    /* Display them in a dialog box.  */
    record_unwind_protect (cleanup_popup_menu, Qnil);
    BLOCK_INPUT;
    selection = mac_dialog_show (f, 0, title, header, &error_name);
    UNBLOCK_INPUT;
    unbind_to (specpdl_count, Qnil);

    if (error_name) error (error_name);
    return selection;
  }
#endif /* HAVE_DIALOGS */
}

/* Activate the menu bar of frame F.
   This is called from keyboard.c when it gets the
   MENU_BAR_ACTIVATE_EVENT out of the Emacs event queue.

   To activate the menu bar, we use the button-press event location
   that was saved in saved_menu_event_location.

   But first we recompute the menu bar contents (the whole tree).

   The reason for saving the button event until here, instead of
   passing it to the toolkit right away, is that we can safely
   execute Lisp code.  */

void
x_activate_menubar (f)
     FRAME_PTR f;
{
  SInt32 menu_choice;
  extern Point saved_menu_event_location;

  set_frame_menubar (f, 0, 1);
  BLOCK_INPUT;

  menu_choice = MenuSelect (saved_menu_event_location);
  do_menu_choice (menu_choice);

  UNBLOCK_INPUT;
}

/* This callback is called from the menu bar pulldown menu
   when the user makes a selection.
   Figure out what the user chose
   and put the appropriate events into the keyboard buffer.  */

void
menubar_selection_callback (FRAME_PTR f, int client_data)
{
  Lisp_Object prefix, entry;
  Lisp_Object vector;
  Lisp_Object *subprefix_stack;
  int submenu_depth = 0;
  int i;

  if (!f)
    return;
  entry = Qnil;
  subprefix_stack = (Lisp_Object *) alloca (f->menu_bar_items_used * sizeof (Lisp_Object));
  vector = f->menu_bar_vector;
  prefix = Qnil;
  i = 0;
  while (i < f->menu_bar_items_used)
    {
      if (EQ (XVECTOR (vector)->contents[i], Qnil))
	{
	  subprefix_stack[submenu_depth++] = prefix;
	  prefix = entry;
	  i++;
	}
      else if (EQ (XVECTOR (vector)->contents[i], Qlambda))
	{
	  prefix = subprefix_stack[--submenu_depth];
	  i++;
	}
      else if (EQ (XVECTOR (vector)->contents[i], Qt))
	{
	  prefix = XVECTOR (vector)->contents[i + MENU_ITEMS_PANE_PREFIX];
	  i += MENU_ITEMS_PANE_LENGTH;
	}
      else
	{
	  entry = XVECTOR (vector)->contents[i + MENU_ITEMS_ITEM_VALUE];
	  /* The EMACS_INT cast avoids a warning.  There's no problem
	     as long as pointers have enough bits to hold small integers.  */
	  if ((int) (EMACS_INT) client_data == i)
	    {
	      int j;
	      struct input_event buf;
	      Lisp_Object frame;
	      EVENT_INIT (buf);

	      XSETFRAME (frame, f);
	      buf.kind = MENU_BAR_EVENT;
	      buf.frame_or_window = frame;
	      buf.arg = frame;
	      kbd_buffer_store_event (&buf);

	      for (j = 0; j < submenu_depth; j++)
		if (!NILP (subprefix_stack[j]))
		  {
		    buf.kind = MENU_BAR_EVENT;
		    buf.frame_or_window = frame;
		    buf.arg = subprefix_stack[j];
		    kbd_buffer_store_event (&buf);
		  }

	      if (!NILP (prefix))
		{
		  buf.kind = MENU_BAR_EVENT;
		  buf.frame_or_window = frame;
		  buf.arg = prefix;
		  kbd_buffer_store_event (&buf);
		}

	      buf.kind = MENU_BAR_EVENT;
	      buf.frame_or_window = frame;
	      buf.arg = entry;
	      kbd_buffer_store_event (&buf);

	      f->output_data.mac->menubar_active = 0;
	      return;
	    }
	  i += MENU_ITEMS_ITEM_LENGTH;
	}
    }
  f->output_data.mac->menubar_active = 0;
}

/* Allocate a widget_value, blocking input.  */

widget_value *
xmalloc_widget_value ()
{
  widget_value *value;

  BLOCK_INPUT;
  value = malloc_widget_value ();
  UNBLOCK_INPUT;

  return value;
}

/* This recursively calls free_widget_value on the tree of widgets.
   It must free all data that was malloc'ed for these widget_values.
   In Emacs, many slots are pointers into the data of Lisp_Strings, and
   must be left alone.  */

void
free_menubar_widget_value_tree (wv)
     widget_value *wv;
{
  if (! wv) return;

  wv->name = wv->value = wv->key = (char *) 0xDEADBEEF;

  if (wv->contents && (wv->contents != (widget_value*)1))
    {
      free_menubar_widget_value_tree (wv->contents);
      wv->contents = (widget_value *) 0xDEADBEEF;
    }
  if (wv->next)
    {
      free_menubar_widget_value_tree (wv->next);
      wv->next = (widget_value *) 0xDEADBEEF;
    }
  BLOCK_INPUT;
  free_widget_value (wv);
  UNBLOCK_INPUT;
}

/* Set up data in menu_items for a menu bar item
   whose event type is ITEM_KEY (with string ITEM_NAME)
   and whose contents come from the list of keymaps MAPS.  */

static int
parse_single_submenu (item_key, item_name, maps)
     Lisp_Object item_key, item_name, maps;
{
  Lisp_Object length;
  int len;
  Lisp_Object *mapvec;
  int i;
  int top_level_items = 0;

  length = Flength (maps);
  len = XINT (length);

  /* Convert the list MAPS into a vector MAPVEC.  */
  mapvec = (Lisp_Object *) alloca (len * sizeof (Lisp_Object));
  for (i = 0; i < len; i++)
    {
      mapvec[i] = Fcar (maps);
      maps = Fcdr (maps);
    }

  /* Loop over the given keymaps, making a pane for each map.
     But don't make a pane that is empty--ignore that map instead.  */
  for (i = 0; i < len; i++)
    {
      if (!KEYMAPP (mapvec[i]))
	{
	  /* Here we have a command at top level in the menu bar
	     as opposed to a submenu.  */
	  top_level_items = 1;
	  push_menu_pane (Qnil, Qnil);
	  push_menu_item (item_name, Qt, item_key, mapvec[i],
			  Qnil, Qnil, Qnil, Qnil);
	}
      else
	{
	  Lisp_Object prompt;
	  prompt = Fkeymap_prompt (mapvec[i]);
	  single_keymap_panes (mapvec[i],
			       !NILP (prompt) ? prompt : item_name,
			       item_key, 0, 10);
	}
    }

  return top_level_items;
}

/* Create a tree of widget_value objects
   representing the panes and items
   in menu_items starting at index START, up to index END.  */

static widget_value *
digest_single_submenu (start, end, top_level_items)
     int start, end, top_level_items;
{
  widget_value *wv, *prev_wv, *save_wv, *first_wv;
  int i;
  int submenu_depth = 0;
  widget_value **submenu_stack;

  submenu_stack
    = (widget_value **) alloca (menu_items_used * sizeof (widget_value *));
  wv = xmalloc_widget_value ();
  wv->name = "menu";
  wv->value = 0;
  wv->enabled = 1;
  wv->button_type = BUTTON_TYPE_NONE;
  wv->help = Qnil;
  first_wv = wv;
  save_wv = 0;
  prev_wv = 0;

  /* Loop over all panes and items made by the preceding call
     to parse_single_submenu and construct a tree of widget_value objects.
     Ignore the panes and items used by previous calls to
     digest_single_submenu, even though those are also in menu_items.  */
  i = start;
  while (i < end)
    {
      if (EQ (XVECTOR (menu_items)->contents[i], Qnil))
	{
	  submenu_stack[submenu_depth++] = save_wv;
	  save_wv = prev_wv;
	  prev_wv = 0;
	  i++;
	}
      else if (EQ (XVECTOR (menu_items)->contents[i], Qlambda))
	{
	  prev_wv = save_wv;
	  save_wv = submenu_stack[--submenu_depth];
	  i++;
	}
      else if (EQ (XVECTOR (menu_items)->contents[i], Qt)
	       && submenu_depth != 0)
	i += MENU_ITEMS_PANE_LENGTH;
      /* Ignore a nil in the item list.
	 It's meaningful only for dialog boxes.  */
      else if (EQ (XVECTOR (menu_items)->contents[i], Qquote))
	i += 1;
      else if (EQ (XVECTOR (menu_items)->contents[i], Qt))
	{
	  /* Create a new pane.  */
	  Lisp_Object pane_name, prefix;
	  char *pane_string;

	  pane_name = XVECTOR (menu_items)->contents[i + MENU_ITEMS_PANE_NAME];
	  prefix = XVECTOR (menu_items)->contents[i + MENU_ITEMS_PANE_PREFIX];

#ifndef HAVE_MULTILINGUAL_MENU
	  if (STRINGP (pane_name) && STRING_MULTIBYTE (pane_name))
	    {
	      pane_name = ENCODE_MENU_STRING (pane_name);
	      AREF (menu_items, i + MENU_ITEMS_PANE_NAME) = pane_name;
	    }
#endif
	  pane_string = (NILP (pane_name)
			 ? "" : (char *) SDATA (pane_name));
	  /* If there is just one top-level pane, put all its items directly
	     under the top-level menu.  */
	  if (menu_items_n_panes == 1)
	    pane_string = "";

	  /* If the pane has a meaningful name,
	     make the pane a top-level menu item
	     with its items as a submenu beneath it.  */
	  if (strcmp (pane_string, ""))
	    {
	      wv = xmalloc_widget_value ();
	      if (save_wv)
		save_wv->next = wv;
	      else
		first_wv->contents = wv;
	      wv->lname = pane_name;
              /* Set value to 1 so update_submenu_strings can handle '@'  */
	      wv->value = (char *)1;
	      wv->enabled = 1;
	      wv->button_type = BUTTON_TYPE_NONE;
	      wv->help = Qnil;
	    }
	  save_wv = wv;
	  prev_wv = 0;
	  i += MENU_ITEMS_PANE_LENGTH;
	}
      else
	{
	  /* Create a new item within current pane.  */
	  Lisp_Object item_name, enable, descrip, def, type, selected;
	  Lisp_Object help;

	  item_name = AREF (menu_items, i + MENU_ITEMS_ITEM_NAME);
	  enable = AREF (menu_items, i + MENU_ITEMS_ITEM_ENABLE);
	  descrip = AREF (menu_items, i + MENU_ITEMS_ITEM_EQUIV_KEY);
	  def = AREF (menu_items, i + MENU_ITEMS_ITEM_DEFINITION);
	  type = AREF (menu_items, i + MENU_ITEMS_ITEM_TYPE);
	  selected = AREF (menu_items, i + MENU_ITEMS_ITEM_SELECTED);
	  help = AREF (menu_items, i + MENU_ITEMS_ITEM_HELP);

#ifndef HAVE_MULTILINGUAL_MENU
          if (STRING_MULTIBYTE (item_name))
	    {
	      item_name = ENCODE_MENU_STRING (item_name);
	      AREF (menu_items, i + MENU_ITEMS_ITEM_NAME) = item_name;
	    }

          if (STRINGP (descrip) && STRING_MULTIBYTE (descrip))
	    {
	      descrip = ENCODE_MENU_STRING (descrip);
	      AREF (menu_items, i + MENU_ITEMS_ITEM_EQUIV_KEY) = descrip;
	    }
#endif /* not HAVE_MULTILINGUAL_MENU */

	  wv = xmalloc_widget_value ();
	  if (prev_wv)
	    prev_wv->next = wv;
	  else
	    save_wv->contents = wv;

	  wv->lname = item_name;
	  if (!NILP (descrip))
	    wv->lkey = descrip;
	  wv->value = 0;
	  /* The EMACS_INT cast avoids a warning.  There's no problem
	     as long as pointers have enough bits to hold small integers.  */
	  wv->call_data = (!NILP (def) ? (void *) (EMACS_INT) i : 0);
	  wv->enabled = !NILP (enable);

	  if (NILP (type))
	    wv->button_type = BUTTON_TYPE_NONE;
	  else if (EQ (type, QCradio))
	    wv->button_type = BUTTON_TYPE_RADIO;
	  else if (EQ (type, QCtoggle))
	    wv->button_type = BUTTON_TYPE_TOGGLE;
	  else
	    abort ();

	  wv->selected = !NILP (selected);
	  if (! STRINGP (help))
	    help = Qnil;

	  wv->help = help;

	  prev_wv = wv;

	  i += MENU_ITEMS_ITEM_LENGTH;
	}
    }

  /* If we have just one "menu item"
     that was originally a button, return it by itself.  */
  if (top_level_items && first_wv->contents && first_wv->contents->next == 0)
    {
      wv = first_wv->contents;
      free_widget_value (first_wv);
      return wv;
    }

  return first_wv;
}

/* Walk through the widget_value tree starting at FIRST_WV and update
   the char * pointers from the corresponding lisp values.
   We do this after building the whole tree, since GC may happen while the
   tree is constructed, and small strings are relocated.  So we must wait
   until no GC can happen before storing pointers into lisp values.  */
static void
update_submenu_strings (first_wv)
     widget_value *first_wv;
{
  widget_value *wv;

  for (wv = first_wv; wv; wv = wv->next)
    {
      if (STRINGP (wv->lname))
        {
          wv->name = SDATA (wv->lname);

          /* Ignore the @ that means "separate pane".
             This is a kludge, but this isn't worth more time.  */
          if (wv->value == (char *)1)
            {
              if (wv->name[0] == '@')
		wv->name++;
              wv->value = 0;
            }
        }

      if (STRINGP (wv->lkey))
        wv->key = SDATA (wv->lkey);

      if (wv->contents)
        update_submenu_strings (wv->contents);
    }
}


/* Event handler function that pops down a menu on C-g.  We can only pop
   down menus if CancelMenuTracking is present (OSX 10.3 or later).  */

#ifdef HAVE_CANCELMENUTRACKING
static pascal OSStatus
menu_quit_handler (nextHandler, theEvent, userData)
     EventHandlerCallRef nextHandler;
     EventRef theEvent;
     void* userData;
{
  UInt32 keyCode;
  UInt32 keyModifiers;
  extern int mac_quit_char_modifiers;
  extern int mac_quit_char_keycode;

  GetEventParameter (theEvent, kEventParamKeyCode,
                     typeUInt32, NULL, sizeof(UInt32), NULL, &keyCode);

  GetEventParameter (theEvent, kEventParamKeyModifiers,
                     typeUInt32, NULL, sizeof(UInt32),
                     NULL, &keyModifiers);

  if (keyCode == mac_quit_char_keycode
      && keyModifiers == mac_quit_char_modifiers)
    {
      MenuRef menu = userData != 0
        ? (MenuRef)userData : AcquireRootMenu ();

      CancelMenuTracking (menu, true, 0);
      if (!userData) ReleaseMenu (menu);
      return noErr;
    }

  return CallNextEventHandler (nextHandler, theEvent);
}
#endif /* HAVE_CANCELMENUTRACKING */

/* Add event handler for MENU_HANDLE so we can detect C-g.
   If MENU_HANDLE is NULL, install handler for all menus in the menu bar.
   If CancelMenuTracking isn't available, do nothing.  */

static void
install_menu_quit_handler (MenuHandle menu_handle)
{
#ifdef HAVE_CANCELMENUTRACKING
  EventTypeSpec typesList[] = { { kEventClassKeyboard, kEventRawKeyDown } };
  int i = MIN_MENU_ID;
  MenuHandle menu = menu_handle ? menu_handle : GetMenuHandle (i);

  while (menu != NULL)
    {
      InstallMenuEventHandler (menu, menu_quit_handler,
			       GetEventTypeCount (typesList),
                               typesList, menu_handle, NULL);
      if (menu_handle) break;
      menu = GetMenuHandle (++i);
    }

  i = menu_handle ? MIN_POPUP_SUBMENU_ID : MIN_SUBMENU_ID;
  menu = GetMenuHandle (i);
  while (menu != NULL)
    {
      InstallMenuEventHandler (menu, menu_quit_handler,
			       GetEventTypeCount (typesList),
                               typesList, menu_handle, NULL);
      menu = GetMenuHandle (++i);
    }
#endif /* HAVE_CANCELMENUTRACKING */
}

/* Set the contents of the menubar widgets of frame F.
   The argument FIRST_TIME is currently ignored;
   it is set the first time this is called, from initialize_frame_menubar.  */

void
set_frame_menubar (f, first_time, deep_p)
     FRAME_PTR f;
     int first_time;
     int deep_p;
{
  int menubar_widget = f->output_data.mac->menubar_widget;
  Lisp_Object items;
  widget_value *wv, *first_wv, *prev_wv = 0;
  int i, last_i = 0;
  int *submenu_start, *submenu_end;
  int *submenu_top_level_items, *submenu_n_panes;

  /* We must not change the menubar when actually in use.  */
  if (f->output_data.mac->menubar_active)
    return;

  XSETFRAME (Vmenu_updating_frame, f);

  if (! menubar_widget)
    deep_p = 1;
  else if (pending_menu_activation && !deep_p)
    deep_p = 1;

  if (deep_p)
    {
      /* Make a widget-value tree representing the entire menu trees.  */

      struct buffer *prev = current_buffer;
      Lisp_Object buffer;
      int specpdl_count = SPECPDL_INDEX ();
      int previous_menu_items_used = f->menu_bar_items_used;
      Lisp_Object *previous_items
	= (Lisp_Object *) alloca (previous_menu_items_used
				  * sizeof (Lisp_Object));

      /* If we are making a new widget, its contents are empty,
	 do always reinitialize them.  */
      if (! menubar_widget)
	previous_menu_items_used = 0;

      buffer = XWINDOW (FRAME_SELECTED_WINDOW (f))->buffer;
      specbind (Qinhibit_quit, Qt);
      /* Don't let the debugger step into this code
	 because it is not reentrant.  */
      specbind (Qdebug_on_next_call, Qnil);

      record_unwind_save_match_data ();
      if (NILP (Voverriding_local_map_menu_flag))
	{
	  specbind (Qoverriding_terminal_local_map, Qnil);
	  specbind (Qoverriding_local_map, Qnil);
	}

      set_buffer_internal_1 (XBUFFER (buffer));

      /* Run the Lucid hook.  */
      safe_run_hooks (Qactivate_menubar_hook);

      /* If it has changed current-menubar from previous value,
	 really recompute the menubar from the value.  */
      if (! NILP (Vlucid_menu_bar_dirty_flag))
	call0 (Qrecompute_lucid_menubar);
      safe_run_hooks (Qmenu_bar_update_hook);
      FRAME_MENU_BAR_ITEMS (f) = menu_bar_items (FRAME_MENU_BAR_ITEMS (f));

      items = FRAME_MENU_BAR_ITEMS (f);

      /* Save the frame's previous menu bar contents data.  */
      if (previous_menu_items_used)
	bcopy (XVECTOR (f->menu_bar_vector)->contents, previous_items,
	       previous_menu_items_used * sizeof (Lisp_Object));

      /* Fill in menu_items with the current menu bar contents.
	 This can evaluate Lisp code.  */
      menu_items = f->menu_bar_vector;
      menu_items_allocated = VECTORP (menu_items) ? ASIZE (menu_items) : 0;
      submenu_start = (int *) alloca (XVECTOR (items)->size * sizeof (int *));
      submenu_end = (int *) alloca (XVECTOR (items)->size * sizeof (int *));
      submenu_n_panes = (int *) alloca (XVECTOR (items)->size * sizeof (int));
      submenu_top_level_items
	= (int *) alloca (XVECTOR (items)->size * sizeof (int *));
      init_menu_items ();
      for (i = 0; i < XVECTOR (items)->size; i += 4)
	{
	  Lisp_Object key, string, maps;

	  last_i = i;

	  key = XVECTOR (items)->contents[i];
	  string = XVECTOR (items)->contents[i + 1];
	  maps = XVECTOR (items)->contents[i + 2];
	  if (NILP (string))
	    break;

	  submenu_start[i] = menu_items_used;

	  menu_items_n_panes = 0;
	  submenu_top_level_items[i]
	    = parse_single_submenu (key, string, maps);
	  submenu_n_panes[i] = menu_items_n_panes;

	  submenu_end[i] = menu_items_used;
	}

      finish_menu_items ();

      /* Convert menu_items into widget_value trees
	 to display the menu.  This cannot evaluate Lisp code.  */

      wv = xmalloc_widget_value ();
      wv->name = "menubar";
      wv->value = 0;
      wv->enabled = 1;
      wv->button_type = BUTTON_TYPE_NONE;
      wv->help = Qnil;
      first_wv = wv;

      for (i = 0; i < last_i; i += 4)
	{
	  menu_items_n_panes = submenu_n_panes[i];
	  wv = digest_single_submenu (submenu_start[i], submenu_end[i],
				      submenu_top_level_items[i]);
	  if (prev_wv)
	    prev_wv->next = wv;
	  else
	    first_wv->contents = wv;
	  /* Don't set wv->name here; GC during the loop might relocate it.  */
	  wv->enabled = 1;
	  wv->button_type = BUTTON_TYPE_NONE;
	  prev_wv = wv;
	}

      set_buffer_internal_1 (prev);
      unbind_to (specpdl_count, Qnil);

      /* If there has been no change in the Lisp-level contents
	 of the menu bar, skip redisplaying it.  Just exit.  */

      for (i = 0; i < previous_menu_items_used; i++)
	if (menu_items_used == i
	    || (!EQ (previous_items[i], XVECTOR (menu_items)->contents[i])))
	  break;
      if (i == menu_items_used && i == previous_menu_items_used && i != 0)
	{
	  free_menubar_widget_value_tree (first_wv);
	  discard_menu_items ();

	  return;
	}

      /* Now GC cannot happen during the lifetime of the widget_value,
	 so it's safe to store data from a Lisp_String.  */
      wv = first_wv->contents;
      for (i = 0; i < XVECTOR (items)->size; i += 4)
	{
	  Lisp_Object string;
	  string = XVECTOR (items)->contents[i + 1];
	  if (NILP (string))
	    break;
	  wv->name = (char *) SDATA (string);
          update_submenu_strings (wv->contents);
	  wv = wv->next;
	}

      f->menu_bar_vector = menu_items;
      f->menu_bar_items_used = menu_items_used;
      discard_menu_items ();
    }
  else
    {
      /* Make a widget-value tree containing
	 just the top level menu bar strings.  */

      wv = xmalloc_widget_value ();
      wv->name = "menubar";
      wv->value = 0;
      wv->enabled = 1;
      wv->button_type = BUTTON_TYPE_NONE;
      wv->help = Qnil;
      first_wv = wv;

      items = FRAME_MENU_BAR_ITEMS (f);
      for (i = 0; i < XVECTOR (items)->size; i += 4)
	{
	  Lisp_Object string;

	  string = XVECTOR (items)->contents[i + 1];
	  if (NILP (string))
	    break;

	  wv = xmalloc_widget_value ();
	  wv->name = (char *) SDATA (string);
	  wv->value = 0;
	  wv->enabled = 1;
	  wv->button_type = BUTTON_TYPE_NONE;
	  wv->help = Qnil;
	  /* This prevents lwlib from assuming this
	     menu item is really supposed to be empty.  */
	  /* The EMACS_INT cast avoids a warning.
	     This value just has to be different from small integers.  */
	  wv->call_data = (void *) (EMACS_INT) (-1);

	  if (prev_wv)
	    prev_wv->next = wv;
	  else
	    first_wv->contents = wv;
	  prev_wv = wv;
	}

      /* Forget what we thought we knew about what is in the
	 detailed contents of the menu bar menus.
	 Changing the top level always destroys the contents.  */
      f->menu_bar_items_used = 0;
    }

  /* Create or update the menu bar widget.  */

  BLOCK_INPUT;

  /* Non-null value to indicate menubar has already been "created".  */
  f->output_data.mac->menubar_widget = 1;

  fill_menubar (first_wv->contents, deep_p);

  /* Add event handler so we can detect C-g. */
  install_menu_quit_handler (NULL);
  free_menubar_widget_value_tree (first_wv);

  UNBLOCK_INPUT;
}

/* Get rid of the menu bar of frame F, and free its storage.
   This is used when deleting a frame, and when turning off the menu bar.  */

void
free_frame_menubar (f)
     FRAME_PTR f;
{
  f->output_data.mac->menubar_widget = 0;
}


static Lisp_Object
pop_down_menu (arg)
     Lisp_Object arg;
{
  struct Lisp_Save_Value *p = XSAVE_VALUE (arg);
  FRAME_PTR f = p->pointer;
  MenuHandle menu = GetMenuHandle (POPUP_SUBMENU_ID);

  BLOCK_INPUT;

  /* Must reset this manually because the button release event is not
     passed to Emacs event loop. */
  FRAME_MAC_DISPLAY_INFO (f)->grabbed = 0;

  /* delete all menus */
  dispose_menus (MIN_POPUP_SUBMENU_ID);
  DeleteMenu (POPUP_SUBMENU_ID);
  DisposeMenu (menu);

  UNBLOCK_INPUT;

  return Qnil;
}

/* Mac_menu_show actually displays a menu using the panes and items in
   menu_items and returns the value selected from it; we assume input
   is blocked by the caller.  */

/* F is the frame the menu is for.
   X and Y are the frame-relative specified position,
   relative to the inside upper left corner of the frame F.
   FOR_CLICK is nonzero if this menu was invoked for a mouse click.
   KEYMAPS is 1 if this menu was specified with keymaps;
    in that case, we return a list containing the chosen item's value
    and perhaps also the pane's prefix.
   TITLE is the specified menu title.
   ERROR is a place to store an error message string in case of failure.
   (We return nil on failure, but the value doesn't actually matter.)  */

static Lisp_Object
mac_menu_show (f, x, y, for_click, keymaps, title, error)
     FRAME_PTR f;
     int x;
     int y;
     int for_click;
     int keymaps;
     Lisp_Object title;
     char **error;
{
  int i;
  UInt32 refcon;
  int menu_item_choice;
  int menu_item_selection;
  MenuHandle menu;
  Point pos;
  widget_value *wv, *save_wv = 0, *first_wv = 0, *prev_wv = 0;
  widget_value **submenu_stack
    = (widget_value **) alloca (menu_items_used * sizeof (widget_value *));
  Lisp_Object *subprefix_stack
    = (Lisp_Object *) alloca (menu_items_used * sizeof (Lisp_Object));
  int submenu_depth = 0;

  int first_pane;
  int specpdl_count = SPECPDL_INDEX ();

  *error = NULL;

  if (menu_items_used <= MENU_ITEMS_PANE_LENGTH)
    {
      *error = "Empty menu";
      return Qnil;
    }

  /* Create a tree of widget_value objects
     representing the panes and their items.  */
  wv = xmalloc_widget_value ();
  wv->name = "menu";
  wv->value = 0;
  wv->enabled = 1;
  wv->button_type = BUTTON_TYPE_NONE;
  wv->help = Qnil;
  first_wv = wv;
  first_pane = 1;

  /* Loop over all panes and items, filling in the tree.  */
  i = 0;
  while (i < menu_items_used)
    {
      if (EQ (XVECTOR (menu_items)->contents[i], Qnil))
	{
	  submenu_stack[submenu_depth++] = save_wv;
	  save_wv = prev_wv;
	  prev_wv = 0;
	  first_pane = 1;
	  i++;
	}
      else if (EQ (XVECTOR (menu_items)->contents[i], Qlambda))
	{
	  prev_wv = save_wv;
	  save_wv = submenu_stack[--submenu_depth];
	  first_pane = 0;
	  i++;
	}
      else if (EQ (XVECTOR (menu_items)->contents[i], Qt)
	       && submenu_depth != 0)
	i += MENU_ITEMS_PANE_LENGTH;
      /* Ignore a nil in the item list.
	 It's meaningful only for dialog boxes.  */
      else if (EQ (XVECTOR (menu_items)->contents[i], Qquote))
	i += 1;
      else if (EQ (XVECTOR (menu_items)->contents[i], Qt))
	{
	  /* Create a new pane.  */
	  Lisp_Object pane_name, prefix;
	  char *pane_string;

	  pane_name = AREF (menu_items, i + MENU_ITEMS_PANE_NAME);
	  prefix = AREF (menu_items, i + MENU_ITEMS_PANE_PREFIX);

#ifndef HAVE_MULTILINGUAL_MENU
	  if (STRINGP (pane_name) && STRING_MULTIBYTE (pane_name))
	    {
	      pane_name = ENCODE_MENU_STRING (pane_name);
	      AREF (menu_items, i + MENU_ITEMS_PANE_NAME) = pane_name;
	    }
#endif
	  pane_string = (NILP (pane_name)
			 ? "" : (char *) SDATA (pane_name));
	  /* If there is just one top-level pane, put all its items directly
	     under the top-level menu.  */
	  if (menu_items_n_panes == 1)
	    pane_string = "";

	  /* If the pane has a meaningful name,
	     make the pane a top-level menu item
	     with its items as a submenu beneath it.  */
	  if (!keymaps && strcmp (pane_string, ""))
	    {
	      wv = xmalloc_widget_value ();
	      if (save_wv)
		save_wv->next = wv;
	      else
		first_wv->contents = wv;
	      wv->name = pane_string;
	      if (keymaps && !NILP (prefix))
		wv->name++;
	      wv->value = 0;
	      wv->enabled = 1;
	      wv->button_type = BUTTON_TYPE_NONE;
	      wv->help = Qnil;
	      save_wv = wv;
	      prev_wv = 0;
	    }
	  else if (first_pane)
	    {
	      save_wv = wv;
	      prev_wv = 0;
	    }
	  first_pane = 0;
	  i += MENU_ITEMS_PANE_LENGTH;
	}
      else
	{
	  /* Create a new item within current pane.  */
	  Lisp_Object item_name, enable, descrip, def, type, selected, help;
	  item_name = AREF (menu_items, i + MENU_ITEMS_ITEM_NAME);
	  enable = AREF (menu_items, i + MENU_ITEMS_ITEM_ENABLE);
	  descrip = AREF (menu_items, i + MENU_ITEMS_ITEM_EQUIV_KEY);
	  def = AREF (menu_items, i + MENU_ITEMS_ITEM_DEFINITION);
	  type = AREF (menu_items, i + MENU_ITEMS_ITEM_TYPE);
	  selected = AREF (menu_items, i + MENU_ITEMS_ITEM_SELECTED);
	  help = AREF (menu_items, i + MENU_ITEMS_ITEM_HELP);

#ifndef HAVE_MULTILINGUAL_MENU
          if (STRINGP (item_name) && STRING_MULTIBYTE (item_name))
	    {
	      item_name = ENCODE_MENU_STRING (item_name);
	      AREF (menu_items, i + MENU_ITEMS_ITEM_NAME) = item_name;
	    }

          if (STRINGP (descrip) && STRING_MULTIBYTE (descrip))
	    {
	      descrip = ENCODE_MENU_STRING (descrip);
	      AREF (menu_items, i + MENU_ITEMS_ITEM_EQUIV_KEY) = descrip;
	    }
#endif /* not HAVE_MULTILINGUAL_MENU */

	  wv = xmalloc_widget_value ();
	  if (prev_wv)
	    prev_wv->next = wv;
	  else
	    save_wv->contents = wv;
	  wv->name = (char *) SDATA (item_name);
	  if (!NILP (descrip))
	    wv->key = (char *) SDATA (descrip);
	  wv->value = 0;
	  /* Use the contents index as call_data, since we are
             restricted to 16-bits.  */
	  wv->call_data = !NILP (def) ? (void *) (EMACS_INT) i : 0;
	  wv->enabled = !NILP (enable);

	  if (NILP (type))
	    wv->button_type = BUTTON_TYPE_NONE;
	  else if (EQ (type, QCtoggle))
	    wv->button_type = BUTTON_TYPE_TOGGLE;
	  else if (EQ (type, QCradio))
	    wv->button_type = BUTTON_TYPE_RADIO;
	  else
	    abort ();

	  wv->selected = !NILP (selected);

          if (! STRINGP (help))
	    help = Qnil;

	  wv->help = help;

	  prev_wv = wv;

	  i += MENU_ITEMS_ITEM_LENGTH;
	}
    }

  /* Deal with the title, if it is non-nil.  */
  if (!NILP (title))
    {
      widget_value *wv_title = xmalloc_widget_value ();
      widget_value *wv_sep = xmalloc_widget_value ();

      /* Maybe replace this separator with a bitmap or owner-draw item
	 so that it looks better.  Having two separators looks odd.  */
      wv_sep->name = "--";
      wv_sep->next = first_wv->contents;
      wv_sep->help = Qnil;

#ifndef HAVE_MULTILINGUAL_MENU
      if (STRING_MULTIBYTE (title))
	title = ENCODE_MENU_STRING (title);
#endif

      wv_title->name = (char *) SDATA (title);
      wv_title->enabled = FALSE;
      wv_title->title = TRUE;
      wv_title->button_type = BUTTON_TYPE_NONE;
      wv_title->help = Qnil;
      wv_title->next = wv_sep;
      first_wv->contents = wv_title;
    }

  /* Actually create the menu.  */
  menu = NewMenu (POPUP_SUBMENU_ID, "\p");
  InsertMenu (menu, -1);
  fill_menu (menu, first_wv->contents, MIN_POPUP_SUBMENU_ID);

  /* Free the widget_value objects we used to specify the
     contents.  */
  free_menubar_widget_value_tree (first_wv);

  /* Adjust coordinates to be root-window-relative.  */
  pos.h = x;
  pos.v = y;

  SetPortWindowPort (FRAME_MAC_WINDOW (f));
  LocalToGlobal (&pos);

  /* No selection has been chosen yet.  */
  menu_item_choice = 0;
  menu_item_selection = 0;

  record_unwind_protect (pop_down_menu, make_save_value (f, 0));

  /* Add event handler so we can detect C-g. */
  install_menu_quit_handler (menu);

  /* Display the menu.  */
  menu_item_choice = PopUpMenuSelect (menu, pos.v, pos.h, 0);
  menu_item_selection = LoWord (menu_item_choice);

  /* Get the refcon to find the correct item */
  if (menu_item_selection)
    {
      MenuHandle sel_menu = GetMenuHandle (HiWord (menu_item_choice));
      if (sel_menu) {
	GetMenuItemRefCon (sel_menu, menu_item_selection, &refcon);
      }
    }
  else if (! for_click)
    /* Make "Cancel" equivalent to C-g unless this menu was popped up by
       a mouse press.  */
    Fsignal (Qquit, Qnil);

  /* Find the selected item, and its pane, to return
     the proper value.  */
  if (menu_item_selection != 0)
    {
      Lisp_Object prefix, entry;

      prefix = entry = Qnil;
      i = 0;
      while (i < menu_items_used)
	{
	  if (EQ (XVECTOR (menu_items)->contents[i], Qnil))
	    {
	      subprefix_stack[submenu_depth++] = prefix;
	      prefix = entry;
	      i++;
	    }
	  else if (EQ (XVECTOR (menu_items)->contents[i], Qlambda))
	    {
	      prefix = subprefix_stack[--submenu_depth];
	      i++;
	    }
	  else if (EQ (XVECTOR (menu_items)->contents[i], Qt))
	    {
	      prefix
		= XVECTOR (menu_items)->contents[i + MENU_ITEMS_PANE_PREFIX];
	      i += MENU_ITEMS_PANE_LENGTH;
	    }
	  /* Ignore a nil in the item list.
	     It's meaningful only for dialog boxes.  */
	  else if (EQ (XVECTOR (menu_items)->contents[i], Qquote))
	    i += 1;
	  else
	    {
	      entry
		= XVECTOR (menu_items)->contents[i + MENU_ITEMS_ITEM_VALUE];
	      if ((int) (EMACS_INT) refcon == i)
		{
		  if (keymaps != 0)
		    {
		      int j;

		      entry = Fcons (entry, Qnil);
		      if (!NILP (prefix))
			entry = Fcons (prefix, entry);
		      for (j = submenu_depth - 1; j >= 0; j--)
			if (!NILP (subprefix_stack[j]))
			  entry = Fcons (subprefix_stack[j], entry);
		    }
		  return entry;
		}
	      i += MENU_ITEMS_ITEM_LENGTH;
	    }
	}
    }
  else if (!for_click)
    /* Make "Cancel" equivalent to C-g.  */
    Fsignal (Qquit, Qnil);

  unbind_to (specpdl_count, Qnil);

  return Qnil;
}


#ifdef HAVE_DIALOGS
/* Construct native Mac OS menubar based on widget_value tree.  */

static int
mac_dialog (widget_value *wv)
{
  char *dialog_name;
  char *prompt;
  char **button_labels;
  UInt32 *ref_cons;
  int nb_buttons;
  int left_count;
  int i;
  int dialog_width;
  Rect rect;
  WindowPtr window_ptr;
  ControlHandle ch;
  int left;
  EventRecord event_record;
  SInt16 part_code;
  int control_part_code;
  Point mouse;

  dialog_name = wv->name;
  nb_buttons = dialog_name[1] - '0';
  left_count = nb_buttons - (dialog_name[4] - '0');
  button_labels = (char **) alloca (sizeof (char *) * nb_buttons);
  ref_cons = (UInt32 *) alloca (sizeof (UInt32) * nb_buttons);

  wv = wv->contents;
  prompt = (char *) alloca (strlen (wv->value) + 1);
  strcpy (prompt, wv->value);
  c2pstr (prompt);

  wv = wv->next;
  for (i = 0; i < nb_buttons; i++)
    {
      button_labels[i] = wv->value;
      button_labels[i] = (char *) alloca (strlen (wv->value) + 1);
      strcpy (button_labels[i], wv->value);
      c2pstr (button_labels[i]);
      ref_cons[i] = (UInt32) wv->call_data;
      wv = wv->next;
    }

  window_ptr = GetNewCWindow (DIALOG_WINDOW_RESOURCE, NULL, (WindowPtr) -1);

  SetPortWindowPort (window_ptr);

  TextFont (0);
  /* Left and right margins in the dialog are 13 pixels each.*/
  dialog_width = 14;
  /* Calculate width of dialog box: 8 pixels on each side of the text
     label in each button, 12 pixels between buttons.  */
  for (i = 0; i < nb_buttons; i++)
    dialog_width +=  StringWidth (button_labels[i]) + 16 + 12;

  if (left_count != 0 && nb_buttons - left_count != 0)
    dialog_width += 12;

  dialog_width = max (dialog_width, StringWidth (prompt) + 26);

  SizeWindow (window_ptr, dialog_width, 78, 0);
  ShowWindow (window_ptr);

  SetPortWindowPort (window_ptr);

  TextFont (0);

  MoveTo (13, 29);
  DrawString (prompt);

  left = 13;
  for (i = 0; i < nb_buttons; i++)
    {
      int button_width = StringWidth (button_labels[i]) + 16;
      SetRect (&rect, left, 45, left + button_width, 65);
      ch = NewControl (window_ptr, &rect, button_labels[i], 1, 0, 0, 0,
                       kControlPushButtonProc, ref_cons[i]);
      left += button_width + 12;
      if (i == left_count - 1)
        left += 12;
    }

  i = 0;
  while (!i)
    {
      if (WaitNextEvent (mDownMask, &event_record, 10, NULL))
        if (event_record.what == mouseDown)
          {
            part_code = FindWindow (event_record.where, &window_ptr);
            if (part_code == inContent)
              {
                mouse = event_record.where;
                GlobalToLocal (&mouse);
                control_part_code = FindControl (mouse, window_ptr, &ch);
                if (control_part_code == kControlButtonPart)
                  if (TrackControl (ch, mouse, NULL))
                    i = GetControlReference (ch);
              }
          }
    }

  DisposeWindow (window_ptr);

  return i;
}

static char * button_names [] = {
  "button1", "button2", "button3", "button4", "button5",
  "button6", "button7", "button8", "button9", "button10" };

static Lisp_Object
mac_dialog_show (f, keymaps, title, header, error_name)
     FRAME_PTR f;
     int keymaps;
     Lisp_Object title, header;
     char **error_name;
{
  int i, nb_buttons=0;
  char dialog_name[6];
  int menu_item_selection;

  widget_value *wv, *first_wv = 0, *prev_wv = 0;

  /* Number of elements seen so far, before boundary.  */
  int left_count = 0;
  /* 1 means we've seen the boundary between left-hand elts and right-hand.  */
  int boundary_seen = 0;

  *error_name = NULL;

  if (menu_items_n_panes > 1)
    {
      *error_name = "Multiple panes in dialog box";
      return Qnil;
    }

  /* Create a tree of widget_value objects
     representing the text label and buttons.  */
  {
    Lisp_Object pane_name, prefix;
    char *pane_string;
    pane_name = XVECTOR (menu_items)->contents[MENU_ITEMS_PANE_NAME];
    prefix = XVECTOR (menu_items)->contents[MENU_ITEMS_PANE_PREFIX];
    pane_string = (NILP (pane_name)
		   ? "" : (char *) SDATA (pane_name));
    prev_wv = xmalloc_widget_value ();
    prev_wv->value = pane_string;
    if (keymaps && !NILP (prefix))
      prev_wv->name++;
    prev_wv->enabled = 1;
    prev_wv->name = "message";
    prev_wv->help = Qnil;
    first_wv = prev_wv;

    /* Loop over all panes and items, filling in the tree.  */
    i = MENU_ITEMS_PANE_LENGTH;
    while (i < menu_items_used)
      {

	/* Create a new item within current pane.  */
	Lisp_Object item_name, enable, descrip;
	item_name = XVECTOR (menu_items)->contents[i + MENU_ITEMS_ITEM_NAME];
	enable = XVECTOR (menu_items)->contents[i + MENU_ITEMS_ITEM_ENABLE];
	descrip
	  = XVECTOR (menu_items)->contents[i + MENU_ITEMS_ITEM_EQUIV_KEY];

	if (NILP (item_name))
	  {
	    free_menubar_widget_value_tree (first_wv);
	    *error_name = "Submenu in dialog items";
	    return Qnil;
	  }
	if (EQ (item_name, Qquote))
	  {
	    /* This is the boundary between left-side elts
	       and right-side elts.  Stop incrementing right_count.  */
	    boundary_seen = 1;
	    i++;
	    continue;
	  }
	if (nb_buttons >= 9)
	  {
	    free_menubar_widget_value_tree (first_wv);
	    *error_name = "Too many dialog items";
	    return Qnil;
	  }

	wv = xmalloc_widget_value ();
	prev_wv->next = wv;
	wv->name = (char *) button_names[nb_buttons];
	if (!NILP (descrip))
	  wv->key = (char *) SDATA (descrip);
	wv->value = (char *) SDATA (item_name);
	wv->call_data = (void *) i;
	  /* menu item is identified by its index in menu_items table */
	wv->enabled = !NILP (enable);
	wv->help = Qnil;
	prev_wv = wv;

	if (! boundary_seen)
	  left_count++;

	nb_buttons++;
	i += MENU_ITEMS_ITEM_LENGTH;
      }

    /* If the boundary was not specified,
       by default put half on the left and half on the right.  */
    if (! boundary_seen)
      left_count = nb_buttons - nb_buttons / 2;

    wv = xmalloc_widget_value ();
    wv->name = dialog_name;
    wv->help = Qnil;

    /*  Frame title: 'Q' = Question, 'I' = Information.
        Can also have 'E' = Error if, one day, we want
        a popup for errors. */
    if (NILP(header))
      dialog_name[0] = 'Q';
    else
      dialog_name[0] = 'I';

    /* Dialog boxes use a really stupid name encoding
       which specifies how many buttons to use
       and how many buttons are on the right. */
    dialog_name[1] = '0' + nb_buttons;
    dialog_name[2] = 'B';
    dialog_name[3] = 'R';
    /* Number of buttons to put on the right.  */
    dialog_name[4] = '0' + nb_buttons - left_count;
    dialog_name[5] = 0;
    wv->contents = first_wv;
    first_wv = wv;
  }

  /* Actually create the dialog.  */
#ifdef HAVE_DIALOGS
  menu_item_selection = mac_dialog (first_wv);
#else
  menu_item_selection = 0;
#endif

  /* Free the widget_value objects we used to specify the contents.  */
  free_menubar_widget_value_tree (first_wv);

  /* Find the selected item, and its pane, to return
     the proper value.  */
  if (menu_item_selection != 0)
    {
      Lisp_Object prefix;

      prefix = Qnil;
      i = 0;
      while (i < menu_items_used)
	{
	  Lisp_Object entry;

	  if (EQ (XVECTOR (menu_items)->contents[i], Qt))
	    {
	      prefix
		= XVECTOR (menu_items)->contents[i + MENU_ITEMS_PANE_PREFIX];
	      i += MENU_ITEMS_PANE_LENGTH;
	    }
	  else if (EQ (XVECTOR (menu_items)->contents[i], Qquote))
	    {
	      /* This is the boundary between left-side elts and
		 right-side elts.  */
	      ++i;
	    }
	  else
	    {
	      entry
		= XVECTOR (menu_items)->contents[i + MENU_ITEMS_ITEM_VALUE];
	      if (menu_item_selection == i)
		{
		  if (keymaps != 0)
		    {
		      entry = Fcons (entry, Qnil);
		      if (!NILP (prefix))
			entry = Fcons (prefix, entry);
		    }
		  return entry;
		}
	      i += MENU_ITEMS_ITEM_LENGTH;
	    }
	}
    }
  else
    /* Make "Cancel" equivalent to C-g.  */
    Fsignal (Qquit, Qnil);

  return Qnil;
}
#endif  /* HAVE_DIALOGS  */


/* Is this item a separator? */
static int
name_is_separator (name)
     char *name;
{
  char *start = name;

  /* Check if name string consists of only dashes ('-').  */
  while (*name == '-') name++;
  /* Separators can also be of the form "--:TripleSuperMegaEtched"
     or "--deep-shadow".  We don't implement them yet, se we just treat
     them like normal separators.  */
  return (*name == '\0' || start + 2 == name);
}

static void
add_menu_item (menu, pos, wv)
     MenuHandle menu;
     int pos;
     widget_value *wv;
{
#if TARGET_API_MAC_CARBON
  CFStringRef item_name;
#else
  Str255 item_name;
#endif

  if (name_is_separator (wv->name))
    AppendMenu (menu, "\p-");
  else
    {
      AppendMenu (menu, "\pX");

#if TARGET_API_MAC_CARBON
      item_name = cfstring_create_with_utf8_cstring (wv->name);

      if (wv->key != NULL)
	{
	  CFStringRef name, key;

	  name = item_name;
	  key = cfstring_create_with_utf8_cstring (wv->key);
	  item_name = CFStringCreateWithFormat (NULL, NULL, CFSTR ("%@ %@"),
						name, key);
	  CFRelease (name);
	  CFRelease (key);
	}

      SetMenuItemTextWithCFString (menu, pos, item_name);
      CFRelease (item_name);

      if (wv->enabled)
        EnableMenuItem (menu, pos);
      else
        DisableMenuItem (menu, pos);
#else  /* ! TARGET_API_MAC_CARBON */
      item_name[sizeof (item_name) - 1] = '\0';
      strncpy (item_name, wv->name, sizeof (item_name) - 1);
      if (wv->key != NULL)
	{
	  int len = strlen (item_name);

	  strncpy (item_name + len, " ", sizeof (item_name) - 1 - len);
	  len = strlen (item_name);
	  strncpy (item_name + len, wv->key, sizeof (item_name) - 1 - len);
	}
      c2pstr (item_name);
      SetMenuItemText (menu, pos, item_name);

      if (wv->enabled)
        EnableItem (menu, pos);
      else
        DisableItem (menu, pos);
#endif  /* ! TARGET_API_MAC_CARBON */

      /* Draw radio buttons and tickboxes. */
      if (wv->selected && (wv->button_type == BUTTON_TYPE_TOGGLE ||
                           wv->button_type == BUTTON_TYPE_RADIO))
	SetItemMark (menu, pos, checkMark);
      else
	SetItemMark (menu, pos, noMark);

      SetMenuItemRefCon (menu, pos, (UInt32) wv->call_data);
    }
}

/* Construct native Mac OS menu based on widget_value tree.  */

static int
fill_menu (menu, wv, submenu_id)
     MenuHandle menu;
     widget_value *wv;
     int submenu_id;
{
  int pos;

  for (pos = 1; wv != NULL; wv = wv->next, pos++)
    {
      add_menu_item (menu, pos, wv);
      if (wv->contents)
	{
	  MenuHandle submenu = NewMenu (submenu_id, "\pX");

	  InsertMenu (submenu, -1);
	  SetMenuItemHierarchicalID (menu, pos, submenu_id);
	  submenu_id = fill_menu (submenu, wv->contents, submenu_id + 1);
	}
    }

  return submenu_id;
}

/* Construct native Mac OS menubar based on widget_value tree.  */

static void
fill_menubar (wv, deep_p)
     widget_value *wv;
     int deep_p;
{
  int id, submenu_id;
  MenuHandle menu;
  Str255 title;
#if !TARGET_API_MAC_CARBON
  int title_changed_p = 0;
#endif

  /* Clean up the menu bar when filled by the entire menu trees.  */
  if (deep_p)
    {
      dispose_menus (MIN_MENU_ID);
      dispose_menus (MIN_SUBMENU_ID);
#if !TARGET_API_MAC_CARBON
      title_changed_p = 1;
#endif
    }

  /* Fill menu bar titles and submenus.  Reuse the existing menu bar
     titles as much as possible to minimize redraw (if !deep_p).  */
  submenu_id = MIN_SUBMENU_ID;
  for (id = MIN_MENU_ID; wv != NULL; wv = wv->next, id++)
    {
      strncpy (title, wv->name, 255);
      title[255] = '\0';
      c2pstr (title);

      menu = GetMenuHandle (id);
      if (menu)
	{
#if TARGET_API_MAC_CARBON
	  Str255 old_title;

	  GetMenuTitle (menu, old_title);
	  if (!EqualString (title, old_title, false, false))
	    SetMenuTitle (menu, title);
#else  /* !TARGET_API_MAC_CARBON */
	  if (!EqualString (title, (*menu)->menuData, false, false))
	    {
	      DeleteMenu (id);
	      DisposeMenu (menu);
	      menu = NewMenu (id, title);
	      InsertMenu (menu, GetMenuHandle (id + 1) ? id + 1 : 0);
	      title_changed_p = 1;
	    }
#endif  /* !TARGET_API_MAC_CARBON */
	}
      else
	{
	  menu = NewMenu (id, title);
	  InsertMenu (menu, 0);
#if !TARGET_API_MAC_CARBON
	  title_changed_p = 1;
#endif
	}

      if (wv->contents)
        submenu_id = fill_menu (menu, wv->contents, submenu_id);
    }

  if (GetMenuHandle (id))
    {
      dispose_menus (id);
#if !TARGET_API_MAC_CARBON
      title_changed_p = 1;
#endif
    }

#if !TARGET_API_MAC_CARBON
  if (title_changed_p)
    InvalMenuBar ();
#endif
}

static void
dispose_menus (id)
     int id;
{
  MenuHandle menu;

  while ((menu = GetMenuHandle (id)) != NULL)
    {
      DeleteMenu (id);
      DisposeMenu (menu);
      id++;
    }
}

#endif /* HAVE_MENUS */

void
syms_of_macmenu ()
{
  staticpro (&menu_items);
  menu_items = Qnil;

  Qdebug_on_next_call = intern ("debug-on-next-call");
  staticpro (&Qdebug_on_next_call);

  DEFVAR_LISP ("menu-updating-frame", &Vmenu_updating_frame,
	       doc: /* Frame for which we are updating a menu.
The enable predicate for a menu command should check this variable.  */);
  Vmenu_updating_frame = Qnil;

  defsubr (&Sx_popup_menu);
#ifdef HAVE_MENUS
  defsubr (&Sx_popup_dialog);
#endif
}

/* arch-tag: 40b2c6c7-b8a9-4a49-b930-1b2707184cce
   (do not change this comment) */
