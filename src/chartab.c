/* chartab.c -- char-table support
   Copyright (C) 2001, 2002
     National Institute of Advanced Industrial Science and Technology (AIST)
     Registration Number H13PRO009

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
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

#include <config.h>
#include "lisp.h"
#include "character.h"
#include "charset.h"
#include "ccl.h"

/* 64/16/32/128 */

/* Number of elements in Nth level char-table.  */
const int chartab_size[4] =
  { (1 << CHARTAB_SIZE_BITS_0),
    (1 << CHARTAB_SIZE_BITS_1),
    (1 << CHARTAB_SIZE_BITS_2),
    (1 << CHARTAB_SIZE_BITS_3) };

/* Number of characters each element of Nth level char-table
   covers.  */
const int chartab_chars[4] =
  { (1 << (CHARTAB_SIZE_BITS_1 + CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3)),
    (1 << (CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3)),
    (1 << CHARTAB_SIZE_BITS_3),
    1 };

/* Number of characters (in bits) each element of Nth level char-table
   covers.  */
const int chartab_bits[4] =
  { (CHARTAB_SIZE_BITS_1 + CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3),
    (CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3),
    CHARTAB_SIZE_BITS_3,
    0 };

#define CHARTAB_IDX(c, depth, min_char)		\
  (((c) - (min_char)) >> chartab_bits[(depth)])


DEFUN ("make-char-table", Fmake_char_table, Smake_char_table, 1, 2, 0,
       doc: /* Return a newly created char-table, with purpose PURPOSE.
Each element is initialized to INIT, which defaults to nil.

PURPOSE should be a symbol.  If it has a `char-table-extra-slots'
property, the property's value should be an integer between 0 and 10
that specifies how many extra slots the char-table has.  Otherwise,
the char-table has no extra slot.  */)
     (purpose, init)
     register Lisp_Object purpose, init;
{
  Lisp_Object vector;
  Lisp_Object n;
  int n_extras;
  int size;

  CHECK_SYMBOL (purpose);
  n = Fget (purpose, Qchar_table_extra_slots);
  if (NILP (n))
    n_extras = 0;
  else
    {
      CHECK_NATNUM (n);
      n_extras = XINT (n);
      if (n_extras > 10)
	args_out_of_range (n, Qnil);
    }

  size = VECSIZE (struct Lisp_Char_Table) - 1 + n_extras;
  vector = Fmake_vector (make_number (size), init);
  XCHAR_TABLE (vector)->parent = Qnil;
  XCHAR_TABLE (vector)->purpose = purpose;
  XSETCHAR_TABLE (vector, XCHAR_TABLE (vector));
  return vector;
}

static Lisp_Object
make_sub_char_table (depth, min_char, defalt)
     int depth, min_char;
     Lisp_Object defalt;
{
  Lisp_Object table;
  int size = VECSIZE (struct Lisp_Sub_Char_Table) - 1 + chartab_size[depth];

  table = Fmake_vector (make_number (size), defalt);
  XSUB_CHAR_TABLE (table)->depth = make_number (depth);
  XSUB_CHAR_TABLE (table)->min_char = make_number (min_char);
  XSETSUB_CHAR_TABLE (table, XSUB_CHAR_TABLE (table));

  return table;
}

static Lisp_Object
char_table_ascii (table)
     Lisp_Object table;
{
  Lisp_Object sub;

  sub = XCHAR_TABLE (table)->contents[0];
  if (! SUB_CHAR_TABLE_P (sub))
    return sub;
  sub = XSUB_CHAR_TABLE (sub)->contents[0];
  if (! SUB_CHAR_TABLE_P (sub))
    return sub;
  return XSUB_CHAR_TABLE (sub)->contents[0];
}

Lisp_Object
copy_sub_char_table (table)
     Lisp_Object table;
{
  Lisp_Object copy;
  int depth = XINT (XSUB_CHAR_TABLE (table)->depth);
  int min_char = XINT (XSUB_CHAR_TABLE (table)->min_char);
  Lisp_Object val;
  int i;

  copy = make_sub_char_table (depth, min_char, Qnil);
  /* Recursively copy any sub char-tables.  */
  for (i = 0; i < chartab_size[depth]; i++)
    {
      val = XSUB_CHAR_TABLE (table)->contents[i];
      if (SUB_CHAR_TABLE_P (val))
	XSUB_CHAR_TABLE (copy)->contents[i] = copy_sub_char_table (val);
      else
	XSUB_CHAR_TABLE (copy)->contents[i] = val;
    }

  return copy;
}


Lisp_Object
copy_char_table (table)
     Lisp_Object table;
{
  Lisp_Object copy;
  int size = XCHAR_TABLE (table)->size & PSEUDOVECTOR_SIZE_MASK;
  int i;

  copy = Fmake_vector (make_number (size), Qnil);
  XCHAR_TABLE (copy)->defalt = XCHAR_TABLE (table)->defalt;
  XCHAR_TABLE (copy)->parent = XCHAR_TABLE (table)->parent;
  XCHAR_TABLE (copy)->purpose = XCHAR_TABLE (table)->purpose;
  XCHAR_TABLE (copy)->ascii = XCHAR_TABLE (table)->ascii;
  for (i = 0; i < chartab_size[0]; i++)
    XCHAR_TABLE (copy)->contents[i]
      = (SUB_CHAR_TABLE_P (XCHAR_TABLE (table)->contents[i])
	 ? copy_sub_char_table (XCHAR_TABLE (table)->contents[i])
	 : XCHAR_TABLE (table)->contents[i]);
  if (SUB_CHAR_TABLE_P (XCHAR_TABLE (copy)->ascii))
    XCHAR_TABLE (copy)->ascii = char_table_ascii (copy);
  size -= VECSIZE (struct Lisp_Char_Table) - 1;
  for (i = 0; i < size; i++)
    XCHAR_TABLE (copy)->extras[i] = XCHAR_TABLE (table)->extras[i];

  XSETCHAR_TABLE (copy, XCHAR_TABLE (copy));
  return copy;
}

Lisp_Object
sub_char_table_ref (table, c)
     Lisp_Object table;
     int c;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT (tbl->depth);
  int min_char = XINT (tbl->min_char);
  Lisp_Object val;

  val = tbl->contents[CHARTAB_IDX (c, depth, min_char)];
  if (SUB_CHAR_TABLE_P (val))
    val = sub_char_table_ref (val, c);
  return val;
}

Lisp_Object
char_table_ref (table, c)
     Lisp_Object table;
     int c;
{
  struct Lisp_Char_Table *tbl = XCHAR_TABLE (table);
  Lisp_Object val;

  if (ASCII_CHAR_P (c))
    {
      val = tbl->ascii;
      if (SUB_CHAR_TABLE_P (val))
	val = XSUB_CHAR_TABLE (val)->contents[c];
    }
  else
    {
      val = tbl->contents[CHARTAB_IDX (c, 0, 0)];
      if (SUB_CHAR_TABLE_P (val))
	val = sub_char_table_ref (val, c);
    }
  if (NILP (val))
    {
      val = tbl->defalt;
      if (NILP (val) && CHAR_TABLE_P (tbl->parent))
	val = char_table_ref (tbl->parent, c);
    }
  return val;
}  

static Lisp_Object
sub_char_table_ref_and_range (table, c, from, to, defalt)
     Lisp_Object table;
     int c;
     int *from, *to;
     Lisp_Object defalt;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT (tbl->depth);
  int min_char = XINT (tbl->min_char);
  int max_char = min_char + chartab_chars[depth - 1] - 1;
  int index = CHARTAB_IDX (c, depth, min_char);
  Lisp_Object val;
  
  val = tbl->contents[index];
  *from = min_char + index * chartab_chars[depth];
  *to = *from + chartab_chars[depth] - 1;
  if (SUB_CHAR_TABLE_P (val))
    val = sub_char_table_ref_and_range (val, c, from, to, defalt);
  else if (NILP (val))
    val = defalt;

  while (*from > min_char
	 && *from == min_char + index * chartab_chars[depth])
    {
      Lisp_Object this_val;
      int this_from = *from - chartab_chars[depth];
      int this_to = *from - 1;

      index--;
      this_val = tbl->contents[index];
      if (SUB_CHAR_TABLE_P (this_val))
	this_val = sub_char_table_ref_and_range (this_val, this_to,
						 &this_from, &this_to,
						 defalt);
      else if (NILP (this_val))
	this_val = defalt;

      if (! EQ (this_val, val))
	break;
      *from = this_from;
    }
  index = CHARTAB_IDX (c, depth, min_char);
  while (*to < max_char
	 && *to == min_char + (index + 1) * chartab_chars[depth] - 1)
    {
      Lisp_Object this_val;
      int this_from = *to + 1;
      int this_to = this_from + chartab_chars[depth] - 1;

      index++;
      this_val = tbl->contents[index];
      if (SUB_CHAR_TABLE_P (this_val))
	this_val = sub_char_table_ref_and_range (this_val, this_from,
						 &this_from, &this_to,
						 defalt);
      else if (NILP (this_val))
	this_val = defalt;
      if (! EQ (this_val, val))
	break;
      *to = this_to;
    }

  return val;
}


/* Return the value for C in char-table TABLE.  Set *FROM and *TO to
   the range of characters (containing C) that have the same value as
   C.  It is not assured that the value of (*FROM - 1) and (*TO + 1)
   is different from that of C.  */

Lisp_Object
char_table_ref_and_range (table, c, from, to)
     Lisp_Object table;
     int c;
     int *from, *to;
{
  struct Lisp_Char_Table *tbl = XCHAR_TABLE (table);
  int index = CHARTAB_IDX (c, 0, 0);
  Lisp_Object val;

  val = tbl->contents[index];
  *from = index * chartab_chars[0];
  *to = *from + chartab_chars[0] - 1;
  if (SUB_CHAR_TABLE_P (val))
    val = sub_char_table_ref_and_range (val, c, from, to, tbl->defalt);
  else if (NILP (val))
    val = tbl->defalt;

  while (*from > 0 && *from == index * chartab_chars[0])
    {
      Lisp_Object this_val;
      int this_from = *from - chartab_chars[0];
      int this_to = *from - 1;

      index--;
      this_val = tbl->contents[index];
      if (SUB_CHAR_TABLE_P (this_val))
	this_val = sub_char_table_ref_and_range (this_val, this_to,
						 &this_from, &this_to,
						 tbl->defalt);
      else if (NILP (this_val))
	this_val = tbl->defalt;

      if (! EQ (this_val, val))
	break;
      *from = this_from;
    }
  while (*to < MAX_CHAR && *to == (index + 1) * chartab_chars[0] - 1)
    {
      Lisp_Object this_val;
      int this_from = *to + 1;
      int this_to = this_from + chartab_chars[0] - 1;

      index++;
      this_val = tbl->contents[index];
      if (SUB_CHAR_TABLE_P (this_val))
	this_val = sub_char_table_ref_and_range (this_val, this_from,
						 &this_from, &this_to,
						 tbl->defalt);
      else if (NILP (this_val))
	this_val = tbl->defalt;
      if (! EQ (this_val, val))
	break;
      *to = this_to;
    }

  return val;
}


#define ASET_RANGE(ARRAY, FROM, TO, LIMIT, VAL)				\
  do {									\
    int limit = (TO) < (LIMIT) ? (TO) : (LIMIT);			\
    for (; (FROM) < limit; (FROM)++) (ARRAY)->contents[(FROM)] = (VAL);	\
  } while (0)

#define GET_SUB_CHAR_TABLE(TABLE, SUBTABLE, IDX, DEPTH, MIN_CHAR)	  \
  do {									  \
    (SUBTABLE) = (TABLE)->contents[(IDX)];				  \
    if (!SUB_CHAR_TABLE_P (SUBTABLE))					  \
      (SUBTABLE) = make_sub_char_table ((DEPTH), (MIN_CHAR), (SUBTABLE)); \
  } while (0)


static void
sub_char_table_set (table, c, val)
     Lisp_Object table;
     int c;
     Lisp_Object val;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT ((tbl)->depth);
  int min_char = XINT ((tbl)->min_char);
  int i = CHARTAB_IDX (c, depth, min_char);
  Lisp_Object sub;
  
  if (depth == 3)
    tbl->contents[i] = val;
  else
    {
      sub = tbl->contents[i];
      if (! SUB_CHAR_TABLE_P (sub))
	{
	  sub = make_sub_char_table (depth + 1,
				     min_char + i * chartab_chars[depth], sub);
	  tbl->contents[i] = sub;
	}
      sub_char_table_set (sub, c, val);
    }
}

Lisp_Object
char_table_set (table, c, val)
     Lisp_Object table;
     int c;
     Lisp_Object val;
{
  struct Lisp_Char_Table *tbl = XCHAR_TABLE (table);

  if (ASCII_CHAR_P (c)
      && SUB_CHAR_TABLE_P (tbl->ascii))
    {
      XSUB_CHAR_TABLE (tbl->ascii)->contents[c] = val;
    }
  else
    {
      int i = CHARTAB_IDX (c, 0, 0);
      Lisp_Object sub;

      sub = tbl->contents[i];
      if (! SUB_CHAR_TABLE_P (sub))
	{
	  sub = make_sub_char_table (1, i * chartab_chars[0], sub);
	  tbl->contents[i] = sub;
	}
      sub_char_table_set (sub, c, val);
      if (ASCII_CHAR_P (c))
	tbl->ascii = char_table_ascii (table);
    }
  return val;
}

static void
sub_char_table_set_range (table, depth, min_char, from, to, val)
     Lisp_Object *table;
     int depth;
     int min_char;
     int from, to;
     Lisp_Object val;
{
  int max_char = min_char + chartab_chars[depth] - 1;

  if (depth == 3 || (from <= min_char && to >= max_char))
    *table = val;
  else
    {
      int i, j;

      depth++;
      if (! SUB_CHAR_TABLE_P (*table))
	*table = make_sub_char_table (depth, min_char, *table);
      if (from < min_char)
	from = min_char;
      if (to > max_char)
	to = max_char;
      i = CHARTAB_IDX (from, depth, min_char);
      j = CHARTAB_IDX (to, depth, min_char);
      min_char += chartab_chars[depth] * i;
      for (; i <= j; i++, min_char += chartab_chars[depth])
	sub_char_table_set_range (XSUB_CHAR_TABLE (*table)->contents + i,
				  depth, min_char, from, to, val);
    }
}


Lisp_Object
char_table_set_range (table, from, to, val)
     Lisp_Object table;
     int from, to;
     Lisp_Object val;
{
  struct Lisp_Char_Table *tbl = XCHAR_TABLE (table);
  Lisp_Object *contents = tbl->contents;
  int i, min_char;

  if (from == to)
    char_table_set (table, from, val);
  else
    {
      for (i = CHARTAB_IDX (from, 0, 0), min_char = i * chartab_chars[0];
	   min_char <= to;
	   i++, min_char += chartab_chars[0])
	sub_char_table_set_range (contents + i, 0, min_char, from, to, val);
      if (ASCII_CHAR_P (from))
	tbl->ascii = char_table_ascii (table);
    }
  return val;
}


DEFUN ("char-table-subtype", Fchar_table_subtype, Schar_table_subtype,
       1, 1, 0,
       doc: /*
Return the subtype of char-table CHAR-TABLE.  The value is a symbol.  */)
     (char_table)
     Lisp_Object char_table;
{
  CHECK_CHAR_TABLE (char_table);

  return XCHAR_TABLE (char_table)->purpose;
}

DEFUN ("char-table-parent", Fchar_table_parent, Schar_table_parent,
       1, 1, 0,
       doc: /* Return the parent char-table of CHAR-TABLE.
The value is either nil or another char-table.
If CHAR-TABLE holds nil for a given character,
then the actual applicable value is inherited from the parent char-table
\(or from its parents, if necessary).  */)
  (char_table)
     Lisp_Object char_table;
{
  CHECK_CHAR_TABLE (char_table);

  return XCHAR_TABLE (char_table)->parent;
}

DEFUN ("set-char-table-parent", Fset_char_table_parent, Sset_char_table_parent,
       2, 2, 0,
       doc: /* Set the parent char-table of CHAR-TABLE to PARENT.
PARENT must be either nil or another char-table.  */)
     (char_table, parent)
     Lisp_Object char_table, parent;
{
  Lisp_Object temp;

  CHECK_CHAR_TABLE (char_table);

  if (!NILP (parent))
    {
      CHECK_CHAR_TABLE (parent);

      for (temp = parent; !NILP (temp); temp = XCHAR_TABLE (temp)->parent)
	if (EQ (temp, char_table))
	  error ("Attempt to make a chartable be its own parent");
    }

  XCHAR_TABLE (char_table)->parent = parent;

  return parent;
}

DEFUN ("char-table-extra-slot", Fchar_table_extra_slot, Schar_table_extra_slot,
       2, 2, 0,
       doc: /* Return the value of CHAR-TABLE's extra-slot number N.  */)
     (char_table, n)
     Lisp_Object char_table, n;
{
  CHECK_CHAR_TABLE (char_table);
  CHECK_NUMBER (n);
  if (XINT (n) < 0
      || XINT (n) >= CHAR_TABLE_EXTRA_SLOTS (XCHAR_TABLE (char_table)))
    args_out_of_range (char_table, n);

  return XCHAR_TABLE (char_table)->extras[XINT (n)];
}

DEFUN ("set-char-table-extra-slot", Fset_char_table_extra_slot,
       Sset_char_table_extra_slot,
       3, 3, 0,
       doc: /* Set CHAR-TABLE's extra-slot number N to VALUE.  */)
     (char_table, n, value)
     Lisp_Object char_table, n, value;
{
  CHECK_CHAR_TABLE (char_table);
  CHECK_NUMBER (n);
  if (XINT (n) < 0
      || XINT (n) >= CHAR_TABLE_EXTRA_SLOTS (XCHAR_TABLE (char_table)))
    args_out_of_range (char_table, n);

  return XCHAR_TABLE (char_table)->extras[XINT (n)] = value;
}

DEFUN ("char-table-range", Fchar_table_range, Schar_table_range,
       2, 2, 0,
       doc: /* Return the value in CHAR-TABLE for a range of characters RANGE.
RANGE should be nil (for the default value),
a cons of character codes (for characters in the range), or a character code.  */)
     (char_table, range)
     Lisp_Object char_table, range;
{
  Lisp_Object val;
  CHECK_CHAR_TABLE (char_table);

  if (EQ (range, Qnil))
    val = XCHAR_TABLE (char_table)->defalt;
  else if (INTEGERP (range))
    val = CHAR_TABLE_REF (char_table, XINT (range));
  else if (CONSP (range))
    {
      int from, to;

      CHECK_CHARACTER (XCAR (range));
      CHECK_CHARACTER (XCDR (range));
      val = char_table_ref_and_range (char_table, XINT (XCAR (range)),
				      &from, &to);
      /* Not yet implemented. */
    }
  else
    error ("Invalid RANGE argument to `char-table-range'");
  return val;
}

DEFUN ("set-char-table-range", Fset_char_table_range, Sset_char_table_range,
       3, 3, 0,
       doc: /*
Set the value in CHAR-TABLE for characters specified by RANGE to VALUE.
RANGE should be t (for all characters), nil (for the default value),
a cons of character codes (for characters in the range), or a character code.  */)
     (char_table, range, value)
     Lisp_Object char_table, range, value;
{
  CHECK_CHAR_TABLE (char_table);
  if (EQ (range, Qt))
    {
      int i;

      XCHAR_TABLE (char_table)->ascii = Qnil;
      for (i = 0; i < chartab_size[0]; i++)
	XCHAR_TABLE (char_table)->contents[i] = Qnil;
      XCHAR_TABLE (char_table)->defalt = value;
    }
  else if (EQ (range, Qnil))
    XCHAR_TABLE (char_table)->defalt = value;
  else if (INTEGERP (range))
    char_table_set (char_table, XINT (range), value);
  else if (CONSP (range))
    {
      CHECK_CHARACTER (XCAR (range));
      CHECK_CHARACTER (XCDR (range));
      char_table_set_range (char_table,
			    XINT (XCAR (range)), XINT (XCDR (range)), value);
    }
  else
    error ("Invalid RANGE argument to `set-char-table-range'");

  return value;
}

DEFUN ("set-char-table-default", Fset_char_table_default,
       Sset_char_table_default, 3, 3, 0,
       doc: /*
This function is obsolete and has no effect.  */)
     (char_table, ch, value)
     Lisp_Object char_table, ch, value;
{
  return Qnil;
}

/* Look up the element in TABLE at index CH, and return it as an
   integer.  If the element is nil, return CH itself.  (Actually we do
   that for any non-integer.)  */

int
char_table_translate (table, ch)
     Lisp_Object table;
     int ch;
{
  Lisp_Object value;
  value = Faref (table, make_number (ch));
  if (! INTEGERP (value))	/* fixme: use CHARACTERP? */
    return ch;
  return XINT (value);
}

static Lisp_Object
optimize_sub_char_table (table)
     Lisp_Object table;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT (tbl->depth);
  Lisp_Object elt, this;
  int i;

  elt = XSUB_CHAR_TABLE (table)->contents[0];
  if (SUB_CHAR_TABLE_P (elt))
    elt = XSUB_CHAR_TABLE (table)->contents[0] = optimize_sub_char_table (elt);
  if (SUB_CHAR_TABLE_P (elt))
    return table;
  for (i = 1; i < chartab_size[depth]; i++)
    {
      this = XSUB_CHAR_TABLE (table)->contents[i];
      if (SUB_CHAR_TABLE_P (this))
	this = XSUB_CHAR_TABLE (table)->contents[i]
	  = optimize_sub_char_table (this);
      if (SUB_CHAR_TABLE_P (this)
	  || NILP (Fequal (this, elt)))
	break;
    }

  return (i < chartab_size[depth] ? table : elt);
}

DEFUN ("optimize-char-table", Foptimize_char_table, Soptimize_char_table,
       1, 1, 0,
       doc: /* Optimize CHAR-TABLE.  */)
     (char_table)
     Lisp_Object char_table;
{
  Lisp_Object elt;
  int i;

  CHECK_CHAR_TABLE (char_table);

  for (i = 0; i < chartab_size[0]; i++)
    {
      elt = XCHAR_TABLE (char_table)->contents[i];
      if (SUB_CHAR_TABLE_P (elt))
	XCHAR_TABLE (char_table)->contents[i] = optimize_sub_char_table (elt);
    }
  return Qnil;
}


static Lisp_Object
map_sub_char_table (c_function, function, table, arg, val, range)
     void (*c_function) P_ ((Lisp_Object, Lisp_Object, Lisp_Object));
     Lisp_Object function, table, arg, val, range;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT (tbl->depth);
  int i, c;

  for (i = 0, c = XINT (tbl->min_char); i < chartab_size[depth];
       i++, c += chartab_chars[depth])
    {
      Lisp_Object this;

      this = tbl->contents[i];
      if (SUB_CHAR_TABLE_P (this))
	val = map_sub_char_table (c_function, function, this, arg, val, range);
      else if (NILP (Fequal (val, this)))
	{
	  if (! NILP (val))
	    {
	      XCDR (range) = make_number (c - 1);
	      if (depth == 3
		  && EQ (XCAR (range), XCDR (range)))
		{
		  if (c_function)
		    (*c_function) (arg, XCAR (range), val);
		  else
		    call2 (function, XCAR (range), val);
		}
	      else
		{
		  if (c_function)
		    (*c_function) (arg, range, val);
		  else
		    call2 (function, range, val);
		}
	    }
	  val = this;
	  XCAR (range) = make_number (c);
	}
    }
  return val;
}


/* Map C_FUNCTION or FUNCTION over TABLE, calling it for each
   character or group of characters that share a value.

   ARG is passed to C_FUNCTION when that is called.

   DEPTH and INDICES are ignored.  They are removed in the new
   feature.  */

void
map_char_table (c_function, function, table, arg, depth, indices)
     void (*c_function) P_ ((Lisp_Object, Lisp_Object, Lisp_Object));
     Lisp_Object function, table, arg, *indices;
     int depth;
{
  Lisp_Object range, val;
  int c, i;

  range = Fcons (make_number (0), Qnil);
  val = char_table_ref (table, 0);

  for (i = 0, c = 0; i < chartab_size[0]; i++, c += chartab_chars[0])
    {
      Lisp_Object this;

      this = XCHAR_TABLE (table)->contents[i];
      if (SUB_CHAR_TABLE_P (this))
	val = map_sub_char_table (c_function, function, this, arg, val, range);
      else if (NILP (Fequal (val, this)))
	{
	  if (! NILP (val))
	    {
	      XCDR (range) = make_number (c - 1);
	      if (c_function)
		(*c_function) (arg, range, val);
	      else
		call2 (function, range, val);
	    }
	  val = this;
	  XCAR (range) = make_number (c);
	}
    }
}

DEFUN ("map-char-table", Fmap_char_table, Smap_char_table,
  2, 2, 0,
       doc: /*
Call FUNCTION for each character in CHAR-TABLE.
FUNCTION is called with two arguments--a key and a value.
The key is always a possible IDX argument to `aref'.  */)
     (function, char_table)
     Lisp_Object function, char_table;
{
  CHECK_CHAR_TABLE (char_table);

  map_char_table (NULL, function, char_table, char_table, 0, NULL);
  return Qnil;
}


static void
map_sub_char_table_for_charset (c_function, function, table, arg, range,
				charset, from, to)
     void (*c_function) P_ ((Lisp_Object, Lisp_Object));
     Lisp_Object function, table, arg, range;
     struct charset *charset;
     unsigned from, to;
{
  struct Lisp_Sub_Char_Table *tbl = XSUB_CHAR_TABLE (table);
  int depth = XINT (tbl->depth);
  int c, i;

  if (depth < 3)
    for (i = 0, c = XINT (tbl->min_char); i < chartab_size[depth];
	 i++, c += chartab_chars[depth])
      {
	Lisp_Object this;

	this = tbl->contents[i];
	if (SUB_CHAR_TABLE_P (this))
	  map_sub_char_table_for_charset (c_function, function, this, arg,
					  range, charset, from, to);
	else
	  {
	    if (! NILP (XCAR (range)))
	      {
		XSETCDR (range, make_number (c - 1));
		if (c_function)
		  (*c_function) (arg, range);
		else
		  call2 (function, range, arg);
	      }
	    XSETCAR (range, Qnil);
	  }
      }
  else
    for (i = 0, c = XINT (tbl->min_char); i < chartab_size[depth]; i++, c ++)
      {
	Lisp_Object this;
	unsigned code;

	this = tbl->contents[i];
	if (NILP (this)
	    || (charset
		&& (code = ENCODE_CHAR (charset, c),
		    (code < from || code > to))))
	  {
	    if (! NILP (XCAR (range)))
	      {
		XSETCDR (range, make_number (c - 1));
		if (c_function)
		  (*c_function) (range, arg);
		else
		  call2 (function, range, arg);
		XSETCAR (range, Qnil);
	      }
	  }
	else
	  {
	    if (NILP (XCAR (range)))
	      XSETCAR (range, make_number (c));
	  }
      }
}


void
map_char_table_for_charset (c_function, function, table, arg,
			    charset, from, to)
     void (*c_function) P_ ((Lisp_Object, Lisp_Object));
     Lisp_Object function, table, arg;
     struct charset *charset;
     unsigned from, to;
{
  Lisp_Object range;
  int c, i;

  if (NILP (char_table_ref (table, 0)))
    range = Fcons (Qnil, Qnil);
  else
    range = Fcons (make_number (0), make_number (0));

  for (i = 0, c = 0; i < chartab_size[0]; i++, c += chartab_chars[0])
    {
      Lisp_Object this;

      this = XCHAR_TABLE (table)->contents[i];
      if (SUB_CHAR_TABLE_P (this))
	map_sub_char_table_for_charset (c_function, function, this, arg,
					range, charset, from, to);
      else
	{
	  if (! NILP (XCAR (range)))
	    {
	      XSETCDR (range, make_number (c - 1));
	      if (c_function)
		(*c_function) (arg, range);
	      else
		call2 (function, range, arg);
	    }
	  XSETCAR (range, Qnil);
	}
    }
  if (! NILP (XCAR (range)))
    {
      XSETCDR (range, make_number (c - 1));
      if (c_function)
	(*c_function) (arg, range);
      else
	call2 (function, range, arg);
    }
}



#if 0
Lisp_Object
make_class_table (purpose)
     Lisp_Object purpose;
{
  Lisp_Object table;
  Lisp_Object args[4];
  
  args[0] = purpose;
  args[1] = Qnil;
  args[2] = QCextra_slots;
  args[3] = Fmake_vector (make_number (2), Qnil);
  ASET (args[3], 0, Fmakehash (Qequal));
  table = Fmake_char_table (4, args);
  return table;
}

Lisp_Object
modify_class_entry (c, val, table, set)
     int c;
     Lisp_Object val, table, set;
{
  Lisp_Object classes, hash, canon;
  int i, ival;

  hash = XCHAR_TABLE (table)->extras[0];
  classes = CHAR_TABLE_REF (table, c);

  if (! BOOL_VECTOR_P (classes))
    classes = (NILP (set)
	       ? Qnil
	       : Fmake_bool_vector (make_number ((ival / 8) * 8 + 8), Qnil));
  else if (ival < XBOOL_VECTOR (classes)->size)
    {
      Lisp_Object old;
      old = classes;
      classes = Fmake_bool_vector (make_number ((ival / 8) * 8 + 8), Qnil);
      for (i = 0; i < XBOOL_VECTOR (classes)->size; i++)
	Faset (classes, make_number (i), Faref (old, make_number (i)));
      Faset (classes, val, set);
    }
  else if (NILP (Faref (classes, val)) != NILP (set))
    {
      classes = Fcopy_sequence (classes);
      Faset (classes, val, set);
    }
  else
    classes = Qnil;

  if (!NILP (classes))
    {
      canon = Fgethash (classes, hash, Qnil);
      if (NILP (canon))
	{
	  canon = classes;
	  Fputhash (canon, canon, hash);
	}
      char_table_set (table, c, canon);
    }

  return val;
}
#endif


void
syms_of_chartab ()
{
  defsubr (&Smake_char_table);
  defsubr (&Schar_table_parent);
  defsubr (&Schar_table_subtype);
  defsubr (&Sset_char_table_parent);
  defsubr (&Schar_table_extra_slot);
  defsubr (&Sset_char_table_extra_slot);
  defsubr (&Schar_table_range);
  defsubr (&Sset_char_table_range);
  defsubr (&Sset_char_table_default);
  defsubr (&Soptimize_char_table);
  defsubr (&Smap_char_table);
}
