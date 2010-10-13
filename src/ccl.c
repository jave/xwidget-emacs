/* CCL (Code Conversion Language) interpreter.
   Copyright (C) 2001, 2002, 2003, 2004, 2005,
                 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.
   Copyright (C) 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
     2005, 2006, 2007, 2008, 2009, 2010
     National Institute of Advanced Industrial Science and Technology (AIST)
     Registration Number H14PRO021
   Copyright (C) 2003
     National Institute of Advanced Industrial Science and Technology (AIST)
     Registration Number H13PRO009

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

#include <config.h>

#include <stdio.h>
#include <setjmp.h>

#include "lisp.h"
#include "character.h"
#include "charset.h"
#include "ccl.h"
#include "coding.h"

Lisp_Object Qccl, Qcclp;

/* This contains all code conversion map available to CCL.  */
Lisp_Object Vcode_conversion_map_vector;

/* Alist of fontname patterns vs corresponding CCL program.  */
Lisp_Object Vfont_ccl_encoder_alist;

/* This symbol is a property which associates with ccl program vector.
   Ex: (get 'ccl-big5-encoder 'ccl-program) returns ccl program vector.  */
Lisp_Object Qccl_program;

/* These symbols are properties which associate with code conversion
   map and their ID respectively.  */
Lisp_Object Qcode_conversion_map;
Lisp_Object Qcode_conversion_map_id;

/* Symbols of ccl program have this property, a value of the property
   is an index for Vccl_protram_table. */
Lisp_Object Qccl_program_idx;

/* Table of registered CCL programs.  Each element is a vector of
   NAME, CCL_PROG, RESOLVEDP, and UPDATEDP, where NAME (symbol) is the
   name of the program, CCL_PROG (vector) is the compiled code of the
   program, RESOLVEDP (t or nil) is the flag to tell if symbols in
   CCL_PROG is already resolved to index numbers or not, UPDATEDP (t
   or nil) is the flat to tell if the CCL program is updated after it
   was once used.  */
Lisp_Object Vccl_program_table;

/* Vector of registered hash tables for translation.  */
Lisp_Object Vtranslation_hash_table_vector;

/* Return a hash table of id number ID.  */
#define GET_HASH_TABLE(id) \
  (XHASH_TABLE (XCDR(XVECTOR(Vtranslation_hash_table_vector)->contents[(id)])))

extern int charset_unicode;

/* CCL (Code Conversion Language) is a simple language which has
   operations on one input buffer, one output buffer, and 7 registers.
   The syntax of CCL is described in `ccl.el'.  Emacs Lisp function
   `ccl-compile' compiles a CCL program and produces a CCL code which
   is a vector of integers.  The structure of this vector is as
   follows: The 1st element: buffer-magnification, a factor for the
   size of output buffer compared with the size of input buffer.  The
   2nd element: address of CCL code to be executed when encountered
   with end of input stream.  The 3rd and the remaining elements: CCL
   codes.  */

/* Header of CCL compiled code */
#define CCL_HEADER_BUF_MAG	0
#define CCL_HEADER_EOF		1
#define CCL_HEADER_MAIN		2

/* CCL code is a sequence of 28-bit non-negative integers (i.e. the
   MSB is always 0), each contains CCL command and/or arguments in the
   following format:

	|----------------- integer (28-bit) ------------------|
	|------- 17-bit ------|- 3-bit --|- 3-bit --|- 5-bit -|
	|--constant argument--|-register-|-register-|-command-|
	   ccccccccccccccccc      RRR        rrr       XXXXX
  or
	|------- relative address -------|-register-|-command-|
	       cccccccccccccccccccc          rrr       XXXXX
  or
	|------------- constant or other args ----------------|
                     cccccccccccccccccccccccccccc

   where, `cc...c' is a non-negative integer indicating constant value
   (the left most `c' is always 0) or an absolute jump address, `RRR'
   and `rrr' are CCL register number, `XXXXX' is one of the following
   CCL commands.  */

/* CCL commands

   Each comment fields shows one or more lines for command syntax and
   the following lines for semantics of the command.  In semantics, IC
   stands for Instruction Counter.  */

#define CCL_SetRegister		0x00 /* Set register a register value:
					1:00000000000000000RRRrrrXXXXX
					------------------------------
					reg[rrr] = reg[RRR];
					*/

#define CCL_SetShortConst	0x01 /* Set register a short constant value:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					------------------------------
					reg[rrr] = CCCCCCCCCCCCCCCCCCC;
					*/

#define CCL_SetConst		0x02 /* Set register a constant value:
					1:00000000000000000000rrrXXXXX
					2:CONSTANT
					------------------------------
					reg[rrr] = CONSTANT;
					IC++;
					*/

#define CCL_SetArray		0x03 /* Set register an element of array:
					1:CCCCCCCCCCCCCCCCCRRRrrrXXXXX
					2:ELEMENT[0]
					3:ELEMENT[1]
					...
					------------------------------
					if (0 <= reg[RRR] < CC..C)
					  reg[rrr] = ELEMENT[reg[RRR]];
					IC += CC..C;
					*/

#define CCL_Jump		0x04 /* Jump:
					1:A--D--D--R--E--S--S-000XXXXX
					------------------------------
					IC += ADDRESS;
					*/

/* Note: If CC..C is greater than 0, the second code is omitted.  */

#define CCL_JumpCond		0x05 /* Jump conditional:
					1:A--D--D--R--E--S--S-rrrXXXXX
					------------------------------
					if (!reg[rrr])
					  IC += ADDRESS;
					*/


#define CCL_WriteRegisterJump	0x06 /* Write register and jump:
					1:A--D--D--R--E--S--S-rrrXXXXX
					------------------------------
					write (reg[rrr]);
					IC += ADDRESS;
					*/

#define CCL_WriteRegisterReadJump 0x07 /* Write register, read, and jump:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:A--D--D--R--E--S--S-rrrYYYYY
					-----------------------------
					write (reg[rrr]);
					IC++;
					read (reg[rrr]);
					IC += ADDRESS;
					*/
/* Note: If read is suspended, the resumed execution starts from the
   second code (YYYYY == CCL_ReadJump).  */

#define CCL_WriteConstJump	0x08 /* Write constant and jump:
					1:A--D--D--R--E--S--S-000XXXXX
					2:CONST
					------------------------------
					write (CONST);
					IC += ADDRESS;
					*/

#define CCL_WriteConstReadJump	0x09 /* Write constant, read, and jump:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:CONST
					3:A--D--D--R--E--S--S-rrrYYYYY
					-----------------------------
					write (CONST);
					IC += 2;
					read (reg[rrr]);
					IC += ADDRESS;
					*/
/* Note: If read is suspended, the resumed execution starts from the
   second code (YYYYY == CCL_ReadJump).  */

#define CCL_WriteStringJump	0x0A /* Write string and jump:
					1:A--D--D--R--E--S--S-000XXXXX
					2:LENGTH
					3:000MSTRIN[0]STRIN[1]STRIN[2]
					...
					------------------------------
					if (M)
					  write_multibyte_string (STRING, LENGTH);
					else
					  write_string (STRING, LENGTH);
					IC += ADDRESS;
					*/

#define CCL_WriteArrayReadJump	0x0B /* Write an array element, read, and jump:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:LENGTH
					3:ELEMENET[0]
					4:ELEMENET[1]
					...
					N:A--D--D--R--E--S--S-rrrYYYYY
					------------------------------
					if (0 <= reg[rrr] < LENGTH)
					  write (ELEMENT[reg[rrr]]);
					IC += LENGTH + 2; (... pointing at N+1)
					read (reg[rrr]);
					IC += ADDRESS;
					*/
/* Note: If read is suspended, the resumed execution starts from the
   Nth code (YYYYY == CCL_ReadJump).  */

#define CCL_ReadJump		0x0C /* Read and jump:
					1:A--D--D--R--E--S--S-rrrYYYYY
					-----------------------------
					read (reg[rrr]);
					IC += ADDRESS;
					*/

#define CCL_Branch		0x0D /* Jump by branch table:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					2:A--D--D--R--E-S-S[0]000XXXXX
					3:A--D--D--R--E-S-S[1]000XXXXX
					...
					------------------------------
					if (0 <= reg[rrr] < CC..C)
					  IC += ADDRESS[reg[rrr]];
					else
					  IC += ADDRESS[CC..C];
					*/

#define CCL_ReadRegister	0x0E /* Read bytes into registers:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					2:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					...
					------------------------------
					while (CCC--)
					  read (reg[rrr]);
					*/

#define CCL_WriteExprConst	0x0F  /* write result of expression:
					1:00000OPERATION000RRR000XXXXX
					2:CONSTANT
					------------------------------
					write (reg[RRR] OPERATION CONSTANT);
					IC++;
					*/

/* Note: If the Nth read is suspended, the resumed execution starts
   from the Nth code.  */

#define CCL_ReadBranch		0x10 /* Read one byte into a register,
					and jump by branch table:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					2:A--D--D--R--E-S-S[0]000XXXXX
					3:A--D--D--R--E-S-S[1]000XXXXX
					...
					------------------------------
					read (read[rrr]);
					if (0 <= reg[rrr] < CC..C)
					  IC += ADDRESS[reg[rrr]];
					else
					  IC += ADDRESS[CC..C];
					*/

#define CCL_WriteRegister	0x11 /* Write registers:
					1:CCCCCCCCCCCCCCCCCCCrrrXXXXX
					2:CCCCCCCCCCCCCCCCCCCrrrXXXXX
					...
					------------------------------
					while (CCC--)
					  write (reg[rrr]);
					...
					*/

/* Note: If the Nth write is suspended, the resumed execution
   starts from the Nth code.  */

#define CCL_WriteExprRegister	0x12 /* Write result of expression
					1:00000OPERATIONRrrRRR000XXXXX
					------------------------------
					write (reg[RRR] OPERATION reg[Rrr]);
					*/

#define CCL_Call		0x13 /* Call the CCL program whose ID is
					CC..C or cc..c.
					1:CCCCCCCCCCCCCCCCCCCCFFFXXXXX
					[2:00000000cccccccccccccccccccc]
					------------------------------
					if (FFF)
					  call (cc..c)
					  IC++;
					else
					  call (CC..C)
					*/

#define CCL_WriteConstString	0x14 /* Write a constant or a string:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					[2:000MSTRIN[0]STRIN[1]STRIN[2]]
					[...]
					-----------------------------
					if (!rrr)
					  write (CC..C)
					else
					  if (M)
					    write_multibyte_string (STRING, CC..C);
					  else
					    write_string (STRING, CC..C);
					  IC += (CC..C + 2) / 3;
					*/

#define CCL_WriteArray		0x15 /* Write an element of array:
					1:CCCCCCCCCCCCCCCCCCCCrrrXXXXX
					2:ELEMENT[0]
					3:ELEMENT[1]
					...
					------------------------------
					if (0 <= reg[rrr] < CC..C)
					  write (ELEMENT[reg[rrr]]);
					IC += CC..C;
					*/

#define CCL_End			0x16 /* Terminate:
					1:00000000000000000000000XXXXX
					------------------------------
					terminate ();
					*/

/* The following two codes execute an assignment arithmetic/logical
   operation.  The form of the operation is like REG OP= OPERAND.  */

#define CCL_ExprSelfConst	0x17 /* REG OP= constant:
					1:00000OPERATION000000rrrXXXXX
					2:CONSTANT
					------------------------------
					reg[rrr] OPERATION= CONSTANT;
					*/

#define CCL_ExprSelfReg		0x18 /* REG1 OP= REG2:
					1:00000OPERATION000RRRrrrXXXXX
					------------------------------
					reg[rrr] OPERATION= reg[RRR];
					*/

/* The following codes execute an arithmetic/logical operation.  The
   form of the operation is like REG_X = REG_Y OP OPERAND2.  */

#define CCL_SetExprConst	0x19 /* REG_X = REG_Y OP constant:
					1:00000OPERATION000RRRrrrXXXXX
					2:CONSTANT
					------------------------------
					reg[rrr] = reg[RRR] OPERATION CONSTANT;
					IC++;
					*/

#define CCL_SetExprReg		0x1A /* REG1 = REG2 OP REG3:
					1:00000OPERATIONRrrRRRrrrXXXXX
					------------------------------
					reg[rrr] = reg[RRR] OPERATION reg[Rrr];
					*/

#define CCL_JumpCondExprConst	0x1B /* Jump conditional according to
					an operation on constant:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:OPERATION
					3:CONSTANT
					-----------------------------
					reg[7] = reg[rrr] OPERATION CONSTANT;
					if (!(reg[7]))
					  IC += ADDRESS;
					else
					  IC += 2
					*/

#define CCL_JumpCondExprReg	0x1C /* Jump conditional according to
					an operation on register:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:OPERATION
					3:RRR
					-----------------------------
					reg[7] = reg[rrr] OPERATION reg[RRR];
					if (!reg[7])
					  IC += ADDRESS;
					else
					  IC += 2;
					*/

#define CCL_ReadJumpCondExprConst 0x1D /* Read and jump conditional according
					  to an operation on constant:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:OPERATION
					3:CONSTANT
					-----------------------------
					read (reg[rrr]);
					reg[7] = reg[rrr] OPERATION CONSTANT;
					if (!reg[7])
					  IC += ADDRESS;
					else
					  IC += 2;
					*/

#define CCL_ReadJumpCondExprReg	0x1E /* Read and jump conditional according
					to an operation on register:
					1:A--D--D--R--E--S--S-rrrXXXXX
					2:OPERATION
					3:RRR
					-----------------------------
					read (reg[rrr]);
					reg[7] = reg[rrr] OPERATION reg[RRR];
					if (!reg[7])
					  IC += ADDRESS;
					else
					  IC += 2;
					*/

#define CCL_Extension		0x1F /* Extended CCL code
					1:ExtendedCOMMNDRrrRRRrrrXXXXX
					2:ARGUEMENT
					3:...
					------------------------------
					extended_command (rrr,RRR,Rrr,ARGS)
				      */

/*
   Here after, Extended CCL Instructions.
   Bit length of extended command is 14.
   Therefore, the instruction code range is 0..16384(0x3fff).
 */

/* Read a multibyte character.
   A code point is stored into reg[rrr].  A charset ID is stored into
   reg[RRR].  */

#define CCL_ReadMultibyteChar2	0x00 /* Read Multibyte Character
					1:ExtendedCOMMNDRrrRRRrrrXXXXX  */

/* Write a multibyte character.
   Write a character whose code point is reg[rrr] and the charset ID
   is reg[RRR].  */

#define CCL_WriteMultibyteChar2	0x01 /* Write Multibyte Character
					1:ExtendedCOMMNDRrrRRRrrrXXXXX  */

/* Translate a character whose code point is reg[rrr] and the charset
   ID is reg[RRR] by a translation table whose ID is reg[Rrr].

   A translated character is set in reg[rrr] (code point) and reg[RRR]
   (charset ID).  */

#define CCL_TranslateCharacter	0x02 /* Translate a multibyte character
					1:ExtendedCOMMNDRrrRRRrrrXXXXX  */

/* Translate a character whose code point is reg[rrr] and the charset
   ID is reg[RRR] by a translation table whose ID is ARGUMENT.

   A translated character is set in reg[rrr] (code point) and reg[RRR]
   (charset ID).  */

#define CCL_TranslateCharacterConstTbl 0x03 /* Translate a multibyte character
					       1:ExtendedCOMMNDRrrRRRrrrXXXXX
					       2:ARGUMENT(Translation Table ID)
					    */

/* Iterate looking up MAPs for reg[rrr] starting from the Nth (N =
   reg[RRR]) MAP until some value is found.

   Each MAP is a Lisp vector whose element is number, nil, t, or
   lambda.
   If the element is nil, ignore the map and proceed to the next map.
   If the element is t or lambda, finish without changing reg[rrr].
   If the element is a number, set reg[rrr] to the number and finish.

   Detail of the map structure is descibed in the comment for
   CCL_MapMultiple below.  */

#define CCL_IterateMultipleMap	0x10 /* Iterate multiple maps
					1:ExtendedCOMMNDXXXRRRrrrXXXXX
					2:NUMBER of MAPs
					3:MAP-ID1
					4:MAP-ID2
					...
				     */

/* Map the code in reg[rrr] by MAPs starting from the Nth (N =
   reg[RRR]) map.

   MAPs are supplied in the succeeding CCL codes as follows:

   When CCL program gives this nested structure of map to this command:
	((MAP-ID11
	  MAP-ID12
	  (MAP-ID121 MAP-ID122 MAP-ID123)
	  MAP-ID13)
	 (MAP-ID21
	  (MAP-ID211 (MAP-ID2111) MAP-ID212)
	  MAP-ID22)),
   the compiled CCL codes has this sequence:
	CCL_MapMultiple (CCL code of this command)
	16 (total number of MAPs and SEPARATORs)
	-7 (1st SEPARATOR)
	MAP-ID11
	MAP-ID12
	-3 (2nd SEPARATOR)
	MAP-ID121
	MAP-ID122
	MAP-ID123
	MAP-ID13
	-7 (3rd SEPARATOR)
	MAP-ID21
	-4 (4th SEPARATOR)
	MAP-ID211
	-1 (5th SEPARATOR)
	MAP_ID2111
	MAP-ID212
	MAP-ID22

   A value of each SEPARATOR follows this rule:
	MAP-SET := SEPARATOR [(MAP-ID | MAP-SET)]+
	SEPARATOR := -(number of MAP-IDs and SEPARATORs in the MAP-SET)

   (*)....Nest level of MAP-SET must not be over than MAX_MAP_SET_LEVEL.

   When some map fails to map (i.e. it doesn't have a value for
   reg[rrr]), the mapping is treated as identity.

   The mapping is iterated for all maps in each map set (set of maps
   separated by SEPARATOR) except in the case that lambda is
   encountered.  More precisely, the mapping proceeds as below:

   At first, VAL0 is set to reg[rrr], and it is translated by the
   first map to VAL1.  Then, VAL1 is translated by the next map to
   VAL2.  This mapping is iterated until the last map is used.  The
   result of the mapping is the last value of VAL?.  When the mapping
   process reached to the end of the map set, it moves to the next
   map set.  If the next does not exit, the mapping process terminates,
   and regard the last value as a result.

   But, when VALm is mapped to VALn and VALn is not a number, the
   mapping proceed as below:

   If VALn is nil, the lastest map is ignored and the mapping of VALm
   proceed to the next map.

   In VALn is t, VALm is reverted to reg[rrr] and the mapping of VALm
   proceed to the next map.

   If VALn is lambda, move to the next map set like reaching to the
   end of the current map set.

   If VALn is a symbol, call the CCL program refered by it.
   Then, use reg[rrr] as a mapped value except for -1, -2 and -3.
   Such special values are regarded as nil, t, and lambda respectively.

   Each map is a Lisp vector of the following format (a) or (b):
	(a)......[STARTPOINT VAL1 VAL2 ...]
	(b)......[t VAL STARTPOINT ENDPOINT],
   where
	STARTPOINT is an offset to be used for indexing a map,
	ENDPOINT is a maximum index number of a map,
	VAL and VALn is a number, nil, t, or lambda.

   Valid index range of a map of type (a) is:
	STARTPOINT <= index < STARTPOINT + map_size - 1
   Valid index range of a map of type (b) is:
	STARTPOINT <= index < ENDPOINT	*/

#define CCL_MapMultiple 0x11	/* Mapping by multiple code conversion maps
					 1:ExtendedCOMMNDXXXRRRrrrXXXXX
					 2:N-2
					 3:SEPARATOR_1 (< 0)
					 4:MAP-ID_1
					 5:MAP-ID_2
					 ...
					 M:SEPARATOR_x (< 0)
					 M+1:MAP-ID_y
					 ...
					 N:SEPARATOR_z (< 0)
				      */

#define MAX_MAP_SET_LEVEL 30

typedef struct
{
  int rest_length;
  int orig_val;
} tr_stack;

static tr_stack mapping_stack[MAX_MAP_SET_LEVEL];
static tr_stack *mapping_stack_pointer;

/* If this variable is non-zero, it indicates the stack_idx
   of immediately called by CCL_MapMultiple. */
static int stack_idx_of_map_multiple;

#define PUSH_MAPPING_STACK(restlen, orig)		\
do							\
  {							\
    mapping_stack_pointer->rest_length = (restlen);	\
    mapping_stack_pointer->orig_val = (orig);		\
    mapping_stack_pointer++;				\
  }							\
while (0)

#define POP_MAPPING_STACK(restlen, orig)		\
do							\
  {							\
    mapping_stack_pointer--;				\
    (restlen) = mapping_stack_pointer->rest_length;	\
    (orig) = mapping_stack_pointer->orig_val;		\
  }							\
while (0)

#define CCL_CALL_FOR_MAP_INSTRUCTION(symbol, ret_ic)		\
do								\
  {								\
    struct ccl_program called_ccl;				\
    if (stack_idx >= 256					\
	|| (setup_ccl_program (&called_ccl, (symbol)) != 0))	\
      {								\
	if (stack_idx > 0)					\
	  {							\
	    ccl_prog = ccl_prog_stack_struct[0].ccl_prog;	\
	    ic = ccl_prog_stack_struct[0].ic;			\
	    eof_ic = ccl_prog_stack_struct[0].eof_ic;		\
	  }							\
	CCL_INVALID_CMD;					\
      }								\
    ccl_prog_stack_struct[stack_idx].ccl_prog = ccl_prog;	\
    ccl_prog_stack_struct[stack_idx].ic = (ret_ic);		\
    ccl_prog_stack_struct[stack_idx].eof_ic = eof_ic;		\
    stack_idx++;						\
    ccl_prog = called_ccl.prog;					\
    ic = CCL_HEADER_MAIN;					\
    eof_ic = XFASTINT (ccl_prog[CCL_HEADER_EOF]);		\
    goto ccl_repeat;						\
  }								\
while (0)

#define CCL_MapSingle		0x12 /* Map by single code conversion map
					1:ExtendedCOMMNDXXXRRRrrrXXXXX
					2:MAP-ID
					------------------------------
					Map reg[rrr] by MAP-ID.
					If some valid mapping is found,
					  set reg[rrr] to the result,
					else
					  set reg[RRR] to -1.
				     */

#define CCL_LookupIntConstTbl 0x13 /* Lookup multibyte character by
				      integer key.  Afterwards R7 set
				      to 1 if lookup succeeded.
				      1:ExtendedCOMMNDRrrRRRXXXXXXXX
				      2:ARGUMENT(Hash table ID) */

#define CCL_LookupCharConstTbl 0x14 /* Lookup integer by multibyte
				       character key.  Afterwards R7 set
				       to 1 if lookup succeeded.
				       1:ExtendedCOMMNDRrrRRRrrrXXXXX
				       2:ARGUMENT(Hash table ID) */

/* CCL arithmetic/logical operators. */
#define CCL_PLUS	0x00	/* X = Y + Z */
#define CCL_MINUS	0x01	/* X = Y - Z */
#define CCL_MUL		0x02	/* X = Y * Z */
#define CCL_DIV		0x03	/* X = Y / Z */
#define CCL_MOD		0x04	/* X = Y % Z */
#define CCL_AND		0x05	/* X = Y & Z */
#define CCL_OR		0x06	/* X = Y | Z */
#define CCL_XOR		0x07	/* X = Y ^ Z */
#define CCL_LSH		0x08	/* X = Y << Z */
#define CCL_RSH		0x09	/* X = Y >> Z */
#define CCL_LSH8	0x0A	/* X = (Y << 8) | Z */
#define CCL_RSH8	0x0B	/* X = Y >> 8, r[7] = Y & 0xFF  */
#define CCL_DIVMOD	0x0C	/* X = Y / Z, r[7] = Y % Z */
#define CCL_LS		0x10	/* X = (X < Y) */
#define CCL_GT		0x11	/* X = (X > Y) */
#define CCL_EQ		0x12	/* X = (X == Y) */
#define CCL_LE		0x13	/* X = (X <= Y) */
#define CCL_GE		0x14	/* X = (X >= Y) */
#define CCL_NE		0x15	/* X = (X != Y) */

#define CCL_DECODE_SJIS 0x16	/* X = HIGHER_BYTE (DE-SJIS (Y, Z))
				   r[7] = LOWER_BYTE (DE-SJIS (Y, Z)) */
#define CCL_ENCODE_SJIS 0x17	/* X = HIGHER_BYTE (SJIS (Y, Z))
				   r[7] = LOWER_BYTE (SJIS (Y, Z) */

/* Terminate CCL program successfully.  */
#define CCL_SUCCESS			\
do					\
  {					\
    ccl->status = CCL_STAT_SUCCESS;	\
    goto ccl_finish;			\
  }					\
while(0)

/* Suspend CCL program because of reading from empty input buffer or
   writing to full output buffer.  When this program is resumed, the
   same I/O command is executed.  */
#define CCL_SUSPEND(stat)	\
do				\
  {				\
    ic--;			\
    ccl->status = stat;		\
    goto ccl_finish;		\
  }				\
while (0)

/* Terminate CCL program because of invalid command.  Should not occur
   in the normal case.  */
#ifndef CCL_DEBUG

#define CCL_INVALID_CMD		     	\
do					\
  {				     	\
    ccl->status = CCL_STAT_INVALID_CMD;	\
    goto ccl_error_handler;	     	\
  }					\
while(0)

#else

#define CCL_INVALID_CMD		     	\
do					\
  {				     	\
    ccl_debug_hook (this_ic);		\
    ccl->status = CCL_STAT_INVALID_CMD;	\
    goto ccl_error_handler;	     	\
  }					\
while(0)

#endif

/* Encode one character CH to multibyte form and write to the current
   output buffer.  If CH is less than 256, CH is written as is.  */
#define CCL_WRITE_CHAR(ch)			\
  do {						\
    if (! dst)					\
      CCL_INVALID_CMD;				\
    else if (dst < dst_end)			\
      *dst++ = (ch);				\
    else					\
      CCL_SUSPEND (CCL_STAT_SUSPEND_BY_DST);	\
  } while (0)

/* Write a string at ccl_prog[IC] of length LEN to the current output
   buffer.  */
#define CCL_WRITE_STRING(len)					\
  do {								\
    int i;							\
    if (!dst)							\
      CCL_INVALID_CMD;						\
    else if (dst + len <= dst_end)				\
      {								\
	if (XFASTINT (ccl_prog[ic]) & 0x1000000)		\
	  for (i = 0; i < len; i++)				\
	    *dst++ = XFASTINT (ccl_prog[ic + i]) & 0xFFFFFF;	\
	else							\
	  for (i = 0; i < len; i++)				\
	    *dst++ = ((XFASTINT (ccl_prog[ic + (i / 3)]))	\
		      >> ((2 - (i % 3)) * 8)) & 0xFF;		\
      }								\
    else							\
      CCL_SUSPEND (CCL_STAT_SUSPEND_BY_DST);			\
  } while (0)

/* Read one byte from the current input buffer into Rth register.  */
#define CCL_READ_CHAR(r)			\
  do {						\
    if (! src)					\
      CCL_INVALID_CMD;				\
    else if (src < src_end)			\
      r = *src++;				\
    else if (ccl->last_block)			\
      {						\
	r = -1;					\
	ic = ccl->eof_ic;			\
	goto ccl_repeat;			\
      }						\
    else					\
      CCL_SUSPEND (CCL_STAT_SUSPEND_BY_SRC);	\
    } while (0)

/* Decode CODE by a charset whose id is ID.  If ID is 0, return CODE
   as is for backward compatibility.  Assume that we can use the
   variable `charset'.  */

#define CCL_DECODE_CHAR(id, code)	\
  ((id) == 0 ? (code)			\
   : (charset = CHARSET_FROM_ID ((id)), DECODE_CHAR (charset, (code))))

/* Encode character C by some of charsets in CHARSET_LIST.  Set ID to
   the id of the used charset, ENCODED to the resulf of encoding.
   Assume that we can use the variable `charset'.  */

#define CCL_ENCODE_CHAR(c, charset_list, id, encoded)		\
  do {								\
    unsigned code;						\
								\
    charset = char_charset ((c), (charset_list), &code);	\
    if (! charset && ! NILP (charset_list))			\
      charset = char_charset ((c), Qnil, &code);	  	\
    if (charset)						\
      {								\
	(id) = CHARSET_ID (charset);				\
	(encoded) = code;					\
      }								\
   } while (0)

/* Execute CCL code on characters at SOURCE (length SRC_SIZE).  The
   resulting text goes to a place pointed by DESTINATION, the length
   of which should not exceed DST_SIZE.  As a side effect, how many
   characters are consumed and produced are recorded in CCL->consumed
   and CCL->produced, and the contents of CCL registers are updated.
   If SOURCE or DESTINATION is NULL, only operations on registers are
   permitted.  */

#ifdef CCL_DEBUG
#define CCL_DEBUG_BACKTRACE_LEN 256
int ccl_backtrace_table[CCL_DEBUG_BACKTRACE_LEN];
int ccl_backtrace_idx;

int
ccl_debug_hook (int ic)
{
  return ic;
}

#endif

struct ccl_prog_stack
  {
    Lisp_Object *ccl_prog;	/* Pointer to an array of CCL code.  */
    int ic;			/* Instruction Counter.  */
    int eof_ic;			/* Instruction Counter to jump on EOF.  */
  };

/* For the moment, we only support depth 256 of stack.  */
static struct ccl_prog_stack ccl_prog_stack_struct[256];

void
ccl_driver (ccl, source, destination, src_size, dst_size, charset_list)
     struct ccl_program *ccl;
     int *source, *destination;
     int src_size, dst_size;
     Lisp_Object charset_list;
{
  register int *reg = ccl->reg;
  register int ic = ccl->ic;
  register int code = 0, field1, field2;
  register Lisp_Object *ccl_prog = ccl->prog;
  int *src = source, *src_end = src + src_size;
  int *dst = destination, *dst_end = dst + dst_size;
  int jump_address;
  int i = 0, j, op;
  int stack_idx = ccl->stack_idx;
  /* Instruction counter of the current CCL code. */
  int this_ic = 0;
  struct charset *charset;
  int eof_ic = ccl->eof_ic;
  int eof_hit = 0;

  if (ccl->buf_magnification == 0) /* We can't read/produce any bytes.  */
    dst = NULL;

  /* Set mapping stack pointer. */
  mapping_stack_pointer = mapping_stack;

#ifdef CCL_DEBUG
  ccl_backtrace_idx = 0;
#endif

  for (;;)
    {
    ccl_repeat:
#ifdef CCL_DEBUG
      ccl_backtrace_table[ccl_backtrace_idx++] = ic;
      if (ccl_backtrace_idx >= CCL_DEBUG_BACKTRACE_LEN)
	ccl_backtrace_idx = 0;
      ccl_backtrace_table[ccl_backtrace_idx] = 0;
#endif

      if (!NILP (Vquit_flag) && NILP (Vinhibit_quit))
	{
	  /* We can't just signal Qquit, instead break the loop as if
             the whole data is processed.  Don't reset Vquit_flag, it
             must be handled later at a safer place.  */
	  if (src)
	    src = source + src_size;
	  ccl->status = CCL_STAT_QUIT;
	  break;
	}

      this_ic = ic;
      code = XINT (ccl_prog[ic]); ic++;
      field1 = code >> 8;
      field2 = (code & 0xFF) >> 5;

#define rrr field2
#define RRR (field1 & 7)
#define Rrr ((field1 >> 3) & 7)
#define ADDR field1
#define EXCMD (field1 >> 6)

      switch (code & 0x1F)
	{
	case CCL_SetRegister:	/* 00000000000000000RRRrrrXXXXX */
	  reg[rrr] = reg[RRR];
	  break;

	case CCL_SetShortConst:	/* CCCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  reg[rrr] = field1;
	  break;

	case CCL_SetConst:	/* 00000000000000000000rrrXXXXX */
	  reg[rrr] = XINT (ccl_prog[ic]);
	  ic++;
	  break;

	case CCL_SetArray:	/* CCCCCCCCCCCCCCCCCCCCRRRrrrXXXXX */
	  i = reg[RRR];
	  j = field1 >> 3;
	  if ((unsigned int) i < j)
	    reg[rrr] = XINT (ccl_prog[ic + i]);
	  ic += j;
	  break;

	case CCL_Jump:		/* A--D--D--R--E--S--S-000XXXXX */
	  ic += ADDR;
	  break;

	case CCL_JumpCond:	/* A--D--D--R--E--S--S-rrrXXXXX */
	  if (!reg[rrr])
	    ic += ADDR;
	  break;

	case CCL_WriteRegisterJump: /* A--D--D--R--E--S--S-rrrXXXXX */
	  i = reg[rrr];
	  CCL_WRITE_CHAR (i);
	  ic += ADDR;
	  break;

	case CCL_WriteRegisterReadJump: /* A--D--D--R--E--S--S-rrrXXXXX */
	  i = reg[rrr];
	  CCL_WRITE_CHAR (i);
	  ic++;
	  CCL_READ_CHAR (reg[rrr]);
	  ic += ADDR - 1;
	  break;

	case CCL_WriteConstJump: /* A--D--D--R--E--S--S-000XXXXX */
	  i = XINT (ccl_prog[ic]);
	  CCL_WRITE_CHAR (i);
	  ic += ADDR;
	  break;

	case CCL_WriteConstReadJump: /* A--D--D--R--E--S--S-rrrXXXXX */
	  i = XINT (ccl_prog[ic]);
	  CCL_WRITE_CHAR (i);
	  ic++;
	  CCL_READ_CHAR (reg[rrr]);
	  ic += ADDR - 1;
	  break;

	case CCL_WriteStringJump: /* A--D--D--R--E--S--S-000XXXXX */
	  j = XINT (ccl_prog[ic]);
	  ic++;
	  CCL_WRITE_STRING (j);
	  ic += ADDR - 1;
	  break;

	case CCL_WriteArrayReadJump: /* A--D--D--R--E--S--S-rrrXXXXX */
	  i = reg[rrr];
	  j = XINT (ccl_prog[ic]);
	  if ((unsigned int) i < j)
	    {
	      i = XINT (ccl_prog[ic + 1 + i]);
	      CCL_WRITE_CHAR (i);
	    }
	  ic += j + 2;
	  CCL_READ_CHAR (reg[rrr]);
	  ic += ADDR - (j + 2);
	  break;

	case CCL_ReadJump:	/* A--D--D--R--E--S--S-rrrYYYYY */
	  CCL_READ_CHAR (reg[rrr]);
	  ic += ADDR;
	  break;

	case CCL_ReadBranch:	/* CCCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  CCL_READ_CHAR (reg[rrr]);
	  /* fall through ... */
	case CCL_Branch:	/* CCCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  if ((unsigned int) reg[rrr] < field1)
	    ic += XINT (ccl_prog[ic + reg[rrr]]);
	  else
	    ic += XINT (ccl_prog[ic + field1]);
	  break;

	case CCL_ReadRegister:	/* CCCCCCCCCCCCCCCCCCCCrrXXXXX */
	  while (1)
	    {
	      CCL_READ_CHAR (reg[rrr]);
	      if (!field1) break;
	      code = XINT (ccl_prog[ic]); ic++;
	      field1 = code >> 8;
	      field2 = (code & 0xFF) >> 5;
	    }
	  break;

	case CCL_WriteExprConst:  /* 1:00000OPERATION000RRR000XXXXX */
	  rrr = 7;
	  i = reg[RRR];
	  j = XINT (ccl_prog[ic]);
	  op = field1 >> 6;
	  jump_address = ic + 1;
	  goto ccl_set_expr;

	case CCL_WriteRegister:	/* CCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  while (1)
	    {
	      i = reg[rrr];
	      CCL_WRITE_CHAR (i);
	      if (!field1) break;
	      code = XINT (ccl_prog[ic]); ic++;
	      field1 = code >> 8;
	      field2 = (code & 0xFF) >> 5;
	    }
	  break;

	case CCL_WriteExprRegister: /* 1:00000OPERATIONRrrRRR000XXXXX */
	  rrr = 7;
	  i = reg[RRR];
	  j = reg[Rrr];
	  op = field1 >> 6;
	  jump_address = ic;
	  goto ccl_set_expr;

	case CCL_Call:		/* 1:CCCCCCCCCCCCCCCCCCCCFFFXXXXX */
	  {
	    Lisp_Object slot;
	    int prog_id;

	    /* If FFF is nonzero, the CCL program ID is in the
               following code.  */
	    if (rrr)
	      {
		prog_id = XINT (ccl_prog[ic]);
		ic++;
	      }
	    else
	      prog_id = field1;

	    if (stack_idx >= 256
		|| prog_id < 0
		|| prog_id >= ASIZE (Vccl_program_table)
		|| (slot = AREF (Vccl_program_table, prog_id), !VECTORP (slot))
		|| !VECTORP (AREF (slot, 1)))
	      {
		if (stack_idx > 0)
		  {
		    ccl_prog = ccl_prog_stack_struct[0].ccl_prog;
		    ic = ccl_prog_stack_struct[0].ic;
		    eof_ic = ccl_prog_stack_struct[0].eof_ic;
		  }
		CCL_INVALID_CMD;
	      }

	    ccl_prog_stack_struct[stack_idx].ccl_prog = ccl_prog;
	    ccl_prog_stack_struct[stack_idx].ic = ic;
	    ccl_prog_stack_struct[stack_idx].eof_ic = eof_ic;
	    stack_idx++;
	    ccl_prog = XVECTOR (AREF (slot, 1))->contents;
	    ic = CCL_HEADER_MAIN;
	    eof_ic = XFASTINT (ccl_prog[CCL_HEADER_EOF]);
	  }
	  break;

	case CCL_WriteConstString: /* CCCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  if (!rrr)
	    CCL_WRITE_CHAR (field1);
	  else
	    {
	      CCL_WRITE_STRING (field1);
	      ic += (field1 + 2) / 3;
	    }
	  break;

	case CCL_WriteArray:	/* CCCCCCCCCCCCCCCCCCCCrrrXXXXX */
	  i = reg[rrr];
	  if ((unsigned int) i < field1)
	    {
	      j = XINT (ccl_prog[ic + i]);
	      CCL_WRITE_CHAR (j);
	    }
	  ic += field1;
	  break;

	case CCL_End:		/* 0000000000000000000000XXXXX */
	  if (stack_idx > 0)
	    {
	      stack_idx--;
	      ccl_prog = ccl_prog_stack_struct[stack_idx].ccl_prog;
	      ic = ccl_prog_stack_struct[stack_idx].ic;
	      eof_ic = ccl_prog_stack_struct[stack_idx].eof_ic;
	      if (eof_hit)
		ic = eof_ic;
	      break;
	    }
	  if (src)
	    src = src_end;
	  /* ccl->ic should points to this command code again to
             suppress further processing.  */
	  ic--;
	  CCL_SUCCESS;

	case CCL_ExprSelfConst: /* 00000OPERATION000000rrrXXXXX */
	  i = XINT (ccl_prog[ic]);
	  ic++;
	  op = field1 >> 6;
	  goto ccl_expr_self;

	case CCL_ExprSelfReg:	/* 00000OPERATION000RRRrrrXXXXX */
	  i = reg[RRR];
	  op = field1 >> 6;

	ccl_expr_self:
	  switch (op)
	    {
	    case CCL_PLUS: reg[rrr] += i; break;
	    case CCL_MINUS: reg[rrr] -= i; break;
	    case CCL_MUL: reg[rrr] *= i; break;
	    case CCL_DIV: reg[rrr] /= i; break;
	    case CCL_MOD: reg[rrr] %= i; break;
	    case CCL_AND: reg[rrr] &= i; break;
	    case CCL_OR: reg[rrr] |= i; break;
	    case CCL_XOR: reg[rrr] ^= i; break;
	    case CCL_LSH: reg[rrr] <<= i; break;
	    case CCL_RSH: reg[rrr] >>= i; break;
	    case CCL_LSH8: reg[rrr] <<= 8; reg[rrr] |= i; break;
	    case CCL_RSH8: reg[7] = reg[rrr] & 0xFF; reg[rrr] >>= 8; break;
	    case CCL_DIVMOD: reg[7] = reg[rrr] % i; reg[rrr] /= i; break;
	    case CCL_LS: reg[rrr] = reg[rrr] < i; break;
	    case CCL_GT: reg[rrr] = reg[rrr] > i; break;
	    case CCL_EQ: reg[rrr] = reg[rrr] == i; break;
	    case CCL_LE: reg[rrr] = reg[rrr] <= i; break;
	    case CCL_GE: reg[rrr] = reg[rrr] >= i; break;
	    case CCL_NE: reg[rrr] = reg[rrr] != i; break;
	    default: CCL_INVALID_CMD;
	    }
	  break;

	case CCL_SetExprConst:	/* 00000OPERATION000RRRrrrXXXXX */
	  i = reg[RRR];
	  j = XINT (ccl_prog[ic]);
	  op = field1 >> 6;
	  jump_address = ++ic;
	  goto ccl_set_expr;

	case CCL_SetExprReg:	/* 00000OPERATIONRrrRRRrrrXXXXX */
	  i = reg[RRR];
	  j = reg[Rrr];
	  op = field1 >> 6;
	  jump_address = ic;
	  goto ccl_set_expr;

	case CCL_ReadJumpCondExprConst: /* A--D--D--R--E--S--S-rrrXXXXX */
	  CCL_READ_CHAR (reg[rrr]);
	case CCL_JumpCondExprConst: /* A--D--D--R--E--S--S-rrrXXXXX */
	  i = reg[rrr];
	  op = XINT (ccl_prog[ic]);
	  jump_address = ic++ + ADDR;
	  j = XINT (ccl_prog[ic]);
	  ic++;
	  rrr = 7;
	  goto ccl_set_expr;

	case CCL_ReadJumpCondExprReg: /* A--D--D--R--E--S--S-rrrXXXXX */
	  CCL_READ_CHAR (reg[rrr]);
	case CCL_JumpCondExprReg:
	  i = reg[rrr];
	  op = XINT (ccl_prog[ic]);
	  jump_address = ic++ + ADDR;
	  j = reg[XINT (ccl_prog[ic])];
	  ic++;
	  rrr = 7;

	ccl_set_expr:
	  switch (op)
	    {
	    case CCL_PLUS: reg[rrr] = i + j; break;
	    case CCL_MINUS: reg[rrr] = i - j; break;
	    case CCL_MUL: reg[rrr] = i * j; break;
	    case CCL_DIV: reg[rrr] = i / j; break;
	    case CCL_MOD: reg[rrr] = i % j; break;
	    case CCL_AND: reg[rrr] = i & j; break;
	    case CCL_OR: reg[rrr] = i | j; break;
	    case CCL_XOR: reg[rrr] = i ^ j; break;
	    case CCL_LSH: reg[rrr] = i << j; break;
	    case CCL_RSH: reg[rrr] = i >> j; break;
	    case CCL_LSH8: reg[rrr] = (i << 8) | j; break;
	    case CCL_RSH8: reg[rrr] = i >> 8; reg[7] = i & 0xFF; break;
	    case CCL_DIVMOD: reg[rrr] = i / j; reg[7] = i % j; break;
	    case CCL_LS: reg[rrr] = i < j; break;
	    case CCL_GT: reg[rrr] = i > j; break;
	    case CCL_EQ: reg[rrr] = i == j; break;
	    case CCL_LE: reg[rrr] = i <= j; break;
	    case CCL_GE: reg[rrr] = i >= j; break;
	    case CCL_NE: reg[rrr] = i != j; break;
	    case CCL_DECODE_SJIS:
	      {
		i = (i << 8) | j;
		SJIS_TO_JIS (i);
		reg[rrr] = i >> 8;
		reg[7] = i & 0xFF;
		break;
	      }
	    case CCL_ENCODE_SJIS:
	      {
		i = (i << 8) | j;
		JIS_TO_SJIS (i);
		reg[rrr] = i >> 8;
		reg[7] = i & 0xFF;
		break;
	      }
	    default: CCL_INVALID_CMD;
	    }
	  code &= 0x1F;
	  if (code == CCL_WriteExprConst || code == CCL_WriteExprRegister)
	    {
	      i = reg[rrr];
	      CCL_WRITE_CHAR (i);
	      ic = jump_address;
	    }
	  else if (!reg[rrr])
	    ic = jump_address;
	  break;

	case CCL_Extension:
	  switch (EXCMD)
	    {
	    case CCL_ReadMultibyteChar2:
	      if (!src)
		CCL_INVALID_CMD;
	      CCL_READ_CHAR (i);
	      CCL_ENCODE_CHAR (i, charset_list, reg[RRR], reg[rrr]);
	      break;

	    case CCL_WriteMultibyteChar2:
	      if (! dst)
		CCL_INVALID_CMD;
	      i = CCL_DECODE_CHAR (reg[RRR], reg[rrr]);
	      CCL_WRITE_CHAR (i);
	      break;

	    case CCL_TranslateCharacter:
	      i = CCL_DECODE_CHAR (reg[RRR], reg[rrr]);
	      op = translate_char (GET_TRANSLATION_TABLE (reg[Rrr]), i);
	      CCL_ENCODE_CHAR (op, charset_list, reg[RRR], reg[rrr]);
	      break;

	    case CCL_TranslateCharacterConstTbl:
	      op = XINT (ccl_prog[ic]); /* table */
	      ic++;
	      i = CCL_DECODE_CHAR (reg[RRR], reg[rrr]);
	      op = translate_char (GET_TRANSLATION_TABLE (op), i);
	      CCL_ENCODE_CHAR (op, charset_list, reg[RRR], reg[rrr]);
	      break;

	    case CCL_LookupIntConstTbl:
	      op = XINT (ccl_prog[ic]); /* table */
	      ic++;
	      {
		struct Lisp_Hash_Table *h = GET_HASH_TABLE (op);

		op = hash_lookup (h, make_number (reg[RRR]), NULL);
		if (op >= 0)
		  {
		    Lisp_Object opl;
		    opl = HASH_VALUE (h, op);
		    if (! CHARACTERP (opl))
		      CCL_INVALID_CMD;
		    reg[RRR] = charset_unicode;
		    reg[rrr] = op;
		    reg[7] = 1; /* r7 true for success */
		  }
		else
		  reg[7] = 0;
	      }
	      break;

	    case CCL_LookupCharConstTbl:
	      op = XINT (ccl_prog[ic]); /* table */
	      ic++;
	      i = CCL_DECODE_CHAR (reg[RRR], reg[rrr]);
	      {
		struct Lisp_Hash_Table *h = GET_HASH_TABLE (op);

		op = hash_lookup (h, make_number (i), NULL);
		if (op >= 0)
		  {
		    Lisp_Object opl;
		    opl = HASH_VALUE (h, op);
		    if (!INTEGERP (opl))
		      CCL_INVALID_CMD;
		    reg[RRR] = XINT (opl);
		    reg[7] = 1; /* r7 true for success */
		  }
		else
		  reg[7] = 0;
	      }
	      break;

	    case CCL_IterateMultipleMap:
	      {
		Lisp_Object map, content, attrib, value;
		int point, size, fin_ic;

		j = XINT (ccl_prog[ic++]); /* number of maps. */
		fin_ic = ic + j;
		op = reg[rrr];
		if ((j > reg[RRR]) && (j >= 0))
		  {
		    ic += reg[RRR];
		    i = reg[RRR];
		  }
		else
		  {
		    reg[RRR] = -1;
		    ic = fin_ic;
		    break;
		  }

		for (;i < j;i++)
		  {

		    size = ASIZE (Vcode_conversion_map_vector);
		    point = XINT (ccl_prog[ic++]);
		    if (point >= size) continue;
		    map = AREF (Vcode_conversion_map_vector, point);

		    /* Check map validity.  */
		    if (!CONSP (map)) continue;
		    map = XCDR (map);
		    if (!VECTORP (map)) continue;
		    size = ASIZE (map);
		    if (size <= 1) continue;

		    content = AREF (map, 0);

		    /* check map type,
		       [STARTPOINT VAL1 VAL2 ...] or
		       [t ELEMENT STARTPOINT ENDPOINT]  */
		    if (NUMBERP (content))
		      {
			point = XUINT (content);
			point = op - point + 1;
			if (!((point >= 1) && (point < size))) continue;
			content = AREF (map, point);
		      }
		    else if (EQ (content, Qt))
		      {
			if (size != 4) continue;
			if ((op >= XUINT (AREF (map, 2)))
			    && (op < XUINT (AREF (map, 3))))
			  content = AREF (map, 1);
			else
			  continue;
		      }
		    else
		      continue;

		    if (NILP (content))
		      continue;
		    else if (NUMBERP (content))
		      {
			reg[RRR] = i;
			reg[rrr] = XINT(content);
			break;
		      }
		    else if (EQ (content, Qt) || EQ (content, Qlambda))
		      {
			reg[RRR] = i;
			break;
		      }
		    else if (CONSP (content))
		      {
			attrib = XCAR (content);
			value = XCDR (content);
			if (!NUMBERP (attrib) || !NUMBERP (value))
			  continue;
			reg[RRR] = i;
			reg[rrr] = XUINT (value);
			break;
		      }
		    else if (SYMBOLP (content))
		      CCL_CALL_FOR_MAP_INSTRUCTION (content, fin_ic);
		    else
		      CCL_INVALID_CMD;
		  }
		if (i == j)
		  reg[RRR] = -1;
		ic = fin_ic;
	      }
	      break;

	    case CCL_MapMultiple:
	      {
		Lisp_Object map, content, attrib, value;
		int point, size, map_vector_size;
		int map_set_rest_length, fin_ic;
		int current_ic = this_ic;

		/* inhibit recursive call on MapMultiple. */
		if (stack_idx_of_map_multiple > 0)
		  {
		    if (stack_idx_of_map_multiple <= stack_idx)
		      {
			stack_idx_of_map_multiple = 0;
			mapping_stack_pointer = mapping_stack;
			CCL_INVALID_CMD;
		      }
		  }
		else
		  mapping_stack_pointer = mapping_stack;
		stack_idx_of_map_multiple = 0;

		map_set_rest_length =
		  XINT (ccl_prog[ic++]); /* number of maps and separators. */
		fin_ic = ic + map_set_rest_length;
		op = reg[rrr];

		if ((map_set_rest_length > reg[RRR]) && (reg[RRR] >= 0))
		  {
		    ic += reg[RRR];
		    i = reg[RRR];
		    map_set_rest_length -= i;
		  }
		else
		  {
		    ic = fin_ic;
		    reg[RRR] = -1;
		    mapping_stack_pointer = mapping_stack;
		    break;
		  }

		if (mapping_stack_pointer <= (mapping_stack + 1))
		  {
		    /* Set up initial state. */
		    mapping_stack_pointer = mapping_stack;
		    PUSH_MAPPING_STACK (0, op);
		    reg[RRR] = -1;
		  }
		else
		  {
		    /* Recover after calling other ccl program. */
		    int orig_op;

		    POP_MAPPING_STACK (map_set_rest_length, orig_op);
		    POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
		    switch (op)
		      {
		      case -1:
			/* Regard it as Qnil. */
			op = orig_op;
			i++;
			ic++;
			map_set_rest_length--;
			break;
		      case -2:
			/* Regard it as Qt. */
			op = reg[rrr];
			i++;
			ic++;
			map_set_rest_length--;
			break;
		      case -3:
			/* Regard it as Qlambda. */
			op = orig_op;
			i += map_set_rest_length;
			ic += map_set_rest_length;
			map_set_rest_length = 0;
			break;
		      default:
			/* Regard it as normal mapping. */
			i += map_set_rest_length;
			ic += map_set_rest_length;
			POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
			break;
		      }
		  }
		map_vector_size = ASIZE (Vcode_conversion_map_vector);

		do {
		  for (;map_set_rest_length > 0;i++, ic++, map_set_rest_length--)
		    {
		      point = XINT(ccl_prog[ic]);
		      if (point < 0)
			{
			  /* +1 is for including separator. */
			  point = -point + 1;
			  if (mapping_stack_pointer
			      >= &mapping_stack[MAX_MAP_SET_LEVEL])
			    CCL_INVALID_CMD;
			  PUSH_MAPPING_STACK (map_set_rest_length - point,
					      reg[rrr]);
			  map_set_rest_length = point;
			  reg[rrr] = op;
			  continue;
			}

		      if (point >= map_vector_size) continue;
		      map = AREF (Vcode_conversion_map_vector, point);

		      /* Check map validity.  */
		      if (!CONSP (map)) continue;
		      map = XCDR (map);
		      if (!VECTORP (map)) continue;
		      size = ASIZE (map);
		      if (size <= 1) continue;

		      content = AREF (map, 0);

		      /* check map type,
			 [STARTPOINT VAL1 VAL2 ...] or
			 [t ELEMENT STARTPOINT ENDPOINT]  */
		      if (NUMBERP (content))
			{
			  point = XUINT (content);
			  point = op - point + 1;
			  if (!((point >= 1) && (point < size))) continue;
			  content = AREF (map, point);
			}
		      else if (EQ (content, Qt))
			{
			  if (size != 4) continue;
			  if ((op >= XUINT (AREF (map, 2))) &&
			      (op < XUINT (AREF (map, 3))))
			    content = AREF (map, 1);
			  else
			    continue;
			}
		      else
			continue;

		      if (NILP (content))
			continue;

		      reg[RRR] = i;
		      if (NUMBERP (content))
			{
			  op = XINT (content);
			  i += map_set_rest_length - 1;
			  ic += map_set_rest_length - 1;
			  POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
			  map_set_rest_length++;
			}
		      else if (CONSP (content))
			{
			  attrib = XCAR (content);
			  value = XCDR (content);
			  if (!NUMBERP (attrib) || !NUMBERP (value))
			    continue;
			  op = XUINT (value);
			  i += map_set_rest_length - 1;
			  ic += map_set_rest_length - 1;
			  POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
			  map_set_rest_length++;
			}
		      else if (EQ (content, Qt))
			{
			  op = reg[rrr];
			}
		      else if (EQ (content, Qlambda))
			{
			  i += map_set_rest_length;
			  ic += map_set_rest_length;
			  break;
			}
		      else if (SYMBOLP (content))
			{
			  if (mapping_stack_pointer
			      >= &mapping_stack[MAX_MAP_SET_LEVEL])
			    CCL_INVALID_CMD;
			  PUSH_MAPPING_STACK (map_set_rest_length, reg[rrr]);
			  PUSH_MAPPING_STACK (map_set_rest_length, op);
			  stack_idx_of_map_multiple = stack_idx + 1;
			  CCL_CALL_FOR_MAP_INSTRUCTION (content, current_ic);
			}
		      else
			CCL_INVALID_CMD;
		    }
		  if (mapping_stack_pointer <= (mapping_stack + 1))
		    break;
		  POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
		  i += map_set_rest_length;
		  ic += map_set_rest_length;
		  POP_MAPPING_STACK (map_set_rest_length, reg[rrr]);
		} while (1);

		ic = fin_ic;
	      }
	      reg[rrr] = op;
	      break;

	    case CCL_MapSingle:
	      {
		Lisp_Object map, attrib, value, content;
		int size, point;
		j = XINT (ccl_prog[ic++]); /* map_id */
		op = reg[rrr];
		if (j >= ASIZE (Vcode_conversion_map_vector))
		  {
		    reg[RRR] = -1;
		    break;
		  }
		map = AREF (Vcode_conversion_map_vector, j);
		if (!CONSP (map))
		  {
		    reg[RRR] = -1;
		    break;
		  }
		map = XCDR (map);
		if (!VECTORP (map))
		  {
		    reg[RRR] = -1;
		    break;
		  }
		size = ASIZE (map);
		point = XUINT (AREF (map, 0));
		point = op - point + 1;
		reg[RRR] = 0;
		if ((size <= 1) ||
		    (!((point >= 1) && (point < size))))
		  reg[RRR] = -1;
		else
		  {
		    reg[RRR] = 0;
		    content = AREF (map, point);
		    if (NILP (content))
		      reg[RRR] = -1;
		    else if (NUMBERP (content))
		      reg[rrr] = XINT (content);
		    else if (EQ (content, Qt));
		    else if (CONSP (content))
		      {
			attrib = XCAR (content);
			value = XCDR (content);
			if (!NUMBERP (attrib) || !NUMBERP (value))
			  continue;
			reg[rrr] = XUINT(value);
			break;
		      }
		    else if (SYMBOLP (content))
		      CCL_CALL_FOR_MAP_INSTRUCTION (content, ic);
		    else
		      reg[RRR] = -1;
		  }
	      }
	      break;

	    default:
	      CCL_INVALID_CMD;
	    }
	  break;

	default:
	  CCL_INVALID_CMD;
	}
    }

 ccl_error_handler:
  /* The suppress_error member is set when e.g. a CCL-based coding
     system is used for terminal output.  */
  if (!ccl->suppress_error && destination)
    {
      /* We can insert an error message only if DESTINATION is
         specified and we still have a room to store the message
         there.  */
      char msg[256];
      int msglen;

      if (!dst)
	dst = destination;

      switch (ccl->status)
	{
	case CCL_STAT_INVALID_CMD:
	  sprintf(msg, "\nCCL: Invalid command %x (ccl_code = %x) at %d.",
		  code & 0x1F, code, this_ic);
#ifdef CCL_DEBUG
	  {
	    int i = ccl_backtrace_idx - 1;
	    int j;

	    msglen = strlen (msg);
	    if (dst + msglen <= (dst_bytes ? dst_end : src))
	      {
		bcopy (msg, dst, msglen);
		dst += msglen;
	      }

	    for (j = 0; j < CCL_DEBUG_BACKTRACE_LEN; j++, i--)
	      {
		if (i < 0) i = CCL_DEBUG_BACKTRACE_LEN - 1;
		if (ccl_backtrace_table[i] == 0)
		  break;
		sprintf(msg, " %d", ccl_backtrace_table[i]);
		msglen = strlen (msg);
		if (dst + msglen > (dst_bytes ? dst_end : src))
		  break;
		bcopy (msg, dst, msglen);
		dst += msglen;
	      }
	    goto ccl_finish;
	  }
#endif
	  break;

	case CCL_STAT_QUIT:
	  if (! ccl->quit_silently)
	    sprintf(msg, "\nCCL: Quited.");
	  break;

	default:
	  sprintf(msg, "\nCCL: Unknown error type (%d)", ccl->status);
	}

      msglen = strlen (msg);
      if (dst + msglen <= dst_end)
	{
	  for (i = 0; i < msglen; i++)
	    *dst++ = msg[i];
	}

      if (ccl->status == CCL_STAT_INVALID_CMD)
	{
#if 0 /* If the remaining bytes contain 0x80..0x9F, copying them
	 results in an invalid multibyte sequence.  */

	  /* Copy the remaining source data.  */
	  int i = src_end - src;
	  if (dst_bytes && (dst_end - dst) < i)
	    i = dst_end - dst;
	  bcopy (src, dst, i);
	  src += i;
	  dst += i;
#else
	  /* Signal that we've consumed everything.  */
	  src = src_end;
#endif
	}
    }

 ccl_finish:
  ccl->ic = ic;
  ccl->stack_idx = stack_idx;
  ccl->prog = ccl_prog;
  ccl->consumed = src - source;
  if (dst != NULL)
    ccl->produced = dst - destination;
  else
    ccl->produced = 0;
}

/* Resolve symbols in the specified CCL code (Lisp vector).  This
   function converts symbols of code conversion maps and character
   translation tables embeded in the CCL code into their ID numbers.

   The return value is a vector (CCL itself or a new vector in which
   all symbols are resolved), Qt if resolving of some symbol failed,
   or nil if CCL contains invalid data.  */

static Lisp_Object
resolve_symbol_ccl_program (ccl)
     Lisp_Object ccl;
{
  int i, veclen, unresolved = 0;
  Lisp_Object result, contents, val;

  result = ccl;
  veclen = ASIZE (result);

  for (i = 0; i < veclen; i++)
    {
      contents = AREF (result, i);
      if (INTEGERP (contents))
	continue;
      else if (CONSP (contents)
	       && SYMBOLP (XCAR (contents))
	       && SYMBOLP (XCDR (contents)))
	{
	  /* This is the new style for embedding symbols.  The form is
	     (SYMBOL . PROPERTY).  (get SYMBOL PROPERTY) should give
	     an index number.  */

	  if (EQ (result, ccl))
	    result =  Fcopy_sequence (ccl);

	  val = Fget (XCAR (contents), XCDR (contents));
	  if (NATNUMP (val))
	    ASET (result, i, val);
	  else
	    unresolved = 1;
	  continue;
	}
      else if (SYMBOLP (contents))
	{
	  /* This is the old style for embedding symbols.  This style
             may lead to a bug if, for instance, a translation table
             and a code conversion map have the same name.  */
	  if (EQ (result, ccl))
	    result = Fcopy_sequence (ccl);

	  val = Fget (contents, Qtranslation_table_id);
	  if (NATNUMP (val))
	    ASET (result, i, val);
	  else
	    {
	      val = Fget (contents, Qcode_conversion_map_id);
	      if (NATNUMP (val))
		ASET (result, i, val);
	      else
		{
		  val = Fget (contents, Qccl_program_idx);
		  if (NATNUMP (val))
		    ASET (result, i, val);
		  else
		    unresolved = 1;
		}
	    }
	  continue;
	}
      return Qnil;
    }

  return (unresolved ? Qt : result);
}

/* Return the compiled code (vector) of CCL program CCL_PROG.
   CCL_PROG is a name (symbol) of the program or already compiled
   code.  If necessary, resolve symbols in the compiled code to index
   numbers.  If we failed to get the compiled code or to resolve
   symbols, return Qnil.  */

static Lisp_Object
ccl_get_compiled_code (ccl_prog, idx)
     Lisp_Object ccl_prog;
     int *idx;
{
  Lisp_Object val, slot;

  if (VECTORP (ccl_prog))
    {
      val = resolve_symbol_ccl_program (ccl_prog);
      *idx = -1;
      return (VECTORP (val) ? val : Qnil);
    }
  if (!SYMBOLP (ccl_prog))
    return Qnil;

  val = Fget (ccl_prog, Qccl_program_idx);
  if (! NATNUMP (val)
      || XINT (val) >= ASIZE (Vccl_program_table))
    return Qnil;
  slot = AREF (Vccl_program_table, XINT (val));
  if (! VECTORP (slot)
      || ASIZE (slot) != 4
      || ! VECTORP (AREF (slot, 1)))
    return Qnil;
  *idx = XINT (val);
  if (NILP (AREF (slot, 2)))
    {
      val = resolve_symbol_ccl_program (AREF (slot, 1));
      if (! VECTORP (val))
	return Qnil;
      ASET (slot, 1, val);
      ASET (slot, 2, Qt);
    }
  return AREF (slot, 1);
}

/* Setup fields of the structure pointed by CCL appropriately for the
   execution of CCL program CCL_PROG.  CCL_PROG is the name (symbol)
   of the CCL program or the already compiled code (vector).
   Return 0 if we succeed this setup, else return -1.

   If CCL_PROG is nil, we just reset the structure pointed by CCL.  */
int
setup_ccl_program (ccl, ccl_prog)
     struct ccl_program *ccl;
     Lisp_Object ccl_prog;
{
  int i;

  if (! NILP (ccl_prog))
    {
      struct Lisp_Vector *vp;

      ccl_prog = ccl_get_compiled_code (ccl_prog, &ccl->idx);
      if (! VECTORP (ccl_prog))
	return -1;
      vp = XVECTOR (ccl_prog);
      ccl->size = vp->size;
      ccl->prog = vp->contents;
      ccl->eof_ic = XINT (vp->contents[CCL_HEADER_EOF]);
      ccl->buf_magnification = XINT (vp->contents[CCL_HEADER_BUF_MAG]);
      if (ccl->idx >= 0)
	{
	  Lisp_Object slot;

	  slot = AREF (Vccl_program_table, ccl->idx);
	  ASET (slot, 3, Qnil);
	}
    }
  ccl->ic = CCL_HEADER_MAIN;
  for (i = 0; i < 8; i++)
    ccl->reg[i] = 0;
  ccl->last_block = 0;
  ccl->private_state = 0;
  ccl->status = 0;
  ccl->stack_idx = 0;
  ccl->suppress_error = 0;
  ccl->eight_bit_control = 0;
  ccl->quit_silently = 0;
  return 0;
}


/* Check if CCL is updated or not.  If not, re-setup members of CCL.  */

int
check_ccl_update (ccl)
     struct ccl_program *ccl;
{
  Lisp_Object slot, ccl_prog;

  if (ccl->idx < 0)
    return 0;
  slot = AREF (Vccl_program_table, ccl->idx);
  if (NILP (AREF (slot, 3)))
    return 0;
  ccl_prog = ccl_get_compiled_code (AREF (slot, 0), &ccl->idx);
  if (! VECTORP (ccl_prog))
    return -1;
  ccl->size = ASIZE (ccl_prog);
  ccl->prog = XVECTOR (ccl_prog)->contents;
  ccl->eof_ic = XINT (AREF (ccl_prog, CCL_HEADER_EOF));
  ccl->buf_magnification = XINT (AREF (ccl_prog, CCL_HEADER_BUF_MAG));
  ASET (slot, 3, Qnil);
  return 0;
}


DEFUN ("ccl-program-p", Fccl_program_p, Sccl_program_p, 1, 1, 0,
       doc: /* Return t if OBJECT is a CCL program name or a compiled CCL program code.
See the documentation of `define-ccl-program' for the detail of CCL program.  */)
     (object)
     Lisp_Object object;
{
  Lisp_Object val;

  if (VECTORP (object))
    {
      val = resolve_symbol_ccl_program (object);
      return (VECTORP (val) ? Qt : Qnil);
    }
  if (!SYMBOLP (object))
    return Qnil;

  val = Fget (object, Qccl_program_idx);
  return ((! NATNUMP (val)
	   || XINT (val) >= ASIZE (Vccl_program_table))
	  ? Qnil : Qt);
}

DEFUN ("ccl-execute", Fccl_execute, Sccl_execute, 2, 2, 0,
       doc: /* Execute CCL-PROGRAM with registers initialized by REGISTERS.

CCL-PROGRAM is a CCL program name (symbol)
or compiled code generated by `ccl-compile' (for backward compatibility.
In the latter case, the execution overhead is bigger than in the former).
No I/O commands should appear in CCL-PROGRAM.

REGISTERS is a vector of [R0 R1 ... R7] where RN is an initial value
for the Nth register.

As side effect, each element of REGISTERS holds the value of
the corresponding register after the execution.

See the documentation of `define-ccl-program' for a definition of CCL
programs.  */)
     (ccl_prog, reg)
     Lisp_Object ccl_prog, reg;
{
  struct ccl_program ccl;
  int i;

  if (setup_ccl_program (&ccl, ccl_prog) < 0)
    error ("Invalid CCL program");

  CHECK_VECTOR (reg);
  if (ASIZE (reg) != 8)
    error ("Length of vector REGISTERS is not 8");

  for (i = 0; i < 8; i++)
    ccl.reg[i] = (INTEGERP (AREF (reg, i))
		  ? XINT (AREF (reg, i))
		  : 0);

  ccl_driver (&ccl, NULL, NULL, 0, 0, Qnil);
  QUIT;
  if (ccl.status != CCL_STAT_SUCCESS)
    error ("Error in CCL program at %dth code", ccl.ic);

  for (i = 0; i < 8; i++)
    ASET (reg, i, make_number (ccl.reg[i]));
  return Qnil;
}

DEFUN ("ccl-execute-on-string", Fccl_execute_on_string, Sccl_execute_on_string,
       3, 5, 0,
       doc: /* Execute CCL-PROGRAM with initial STATUS on STRING.

CCL-PROGRAM is a symbol registered by `register-ccl-program',
or a compiled code generated by `ccl-compile' (for backward compatibility,
in this case, the execution is slower).

Read buffer is set to STRING, and write buffer is allocated automatically.

STATUS is a vector of [R0 R1 ... R7 IC], where
 R0..R7 are initial values of corresponding registers,
 IC is the instruction counter specifying from where to start the program.
If R0..R7 are nil, they are initialized to 0.
If IC is nil, it is initialized to head of the CCL program.

If optional 4th arg CONTINUE is non-nil, keep IC on read operation
when read buffer is exhausted, else, IC is always set to the end of
CCL-PROGRAM on exit.

It returns the contents of write buffer as a string,
 and as side effect, STATUS is updated.
If the optional 5th arg UNIBYTE-P is non-nil, the returned string
is a unibyte string.  By default it is a multibyte string.

See the documentation of `define-ccl-program' for the detail of CCL program.
usage: (ccl-execute-on-string CCL-PROGRAM STATUS STRING &optional CONTINUE UNIBYTE-P)  */)
     (ccl_prog, status, str, contin, unibyte_p)
     Lisp_Object ccl_prog, status, str, contin, unibyte_p;
{
  Lisp_Object val;
  struct ccl_program ccl;
  int i;
  int outbufsize;
  unsigned char *outbuf, *outp;
  int str_chars, str_bytes;
#define CCL_EXECUTE_BUF_SIZE 1024
  int source[CCL_EXECUTE_BUF_SIZE], destination[CCL_EXECUTE_BUF_SIZE];
  int consumed_chars, consumed_bytes, produced_chars;

  if (setup_ccl_program (&ccl, ccl_prog) < 0)
    error ("Invalid CCL program");

  CHECK_VECTOR (status);
  if (ASIZE (status) != 9)
    error ("Length of vector STATUS is not 9");
  CHECK_STRING (str);

  str_chars = SCHARS (str);
  str_bytes = SBYTES (str);

  for (i = 0; i < 8; i++)
    {
      if (NILP (AREF (status, i)))
	ASET (status, i, make_number (0));
      if (INTEGERP (AREF (status, i)))
	ccl.reg[i] = XINT (AREF (status, i));
    }
  if (INTEGERP (AREF (status, i)))
    {
      i = XFASTINT (AREF (status, 8));
      if (ccl.ic < i && i < ccl.size)
	ccl.ic = i;
    }

  outbufsize = (ccl.buf_magnification
		? str_bytes * ccl.buf_magnification + 256
		: str_bytes + 256);
  outp = outbuf = (unsigned char *) xmalloc (outbufsize);

  consumed_chars = consumed_bytes = 0;
  produced_chars = 0;
  while (1)
    {
      const unsigned char *p = SDATA (str) + consumed_bytes;
      const unsigned char *endp = SDATA (str) + str_bytes;
      int i = 0;
      int *src, src_size;

      if (endp - p == str_chars - consumed_chars)
	while (i < CCL_EXECUTE_BUF_SIZE && p < endp)
	  source[i++] = *p++;
      else
	while (i < CCL_EXECUTE_BUF_SIZE && p < endp)
	  source[i++] = STRING_CHAR_ADVANCE (p);
      consumed_chars += i;
      consumed_bytes = p - SDATA (str);

      if (consumed_bytes == str_bytes)
	ccl.last_block = NILP (contin);
      src = source;
      src_size = i;
      while (1)
	{
	  ccl_driver (&ccl, src, destination, src_size, CCL_EXECUTE_BUF_SIZE,
		      Qnil);
	  produced_chars += ccl.produced;
	  if (NILP (unibyte_p))
	    {
	      if (outp - outbuf + MAX_MULTIBYTE_LENGTH * ccl.produced
		  > outbufsize)
		{
		  int offset = outp - outbuf;
		  outbufsize += MAX_MULTIBYTE_LENGTH * ccl.produced;
		  outbuf = (unsigned char *) xrealloc (outbuf, outbufsize);
		  outp = outbuf + offset;
		}
	      for (i = 0; i < ccl.produced; i++)
		CHAR_STRING_ADVANCE (destination[i], outp);
	    }
	  else
	    {
	      if (outp - outbuf + ccl.produced > outbufsize)
		{
		  int offset = outp - outbuf;
		  outbufsize += ccl.produced;
		  outbuf = (unsigned char *) xrealloc (outbuf, outbufsize);
		  outp = outbuf + offset;
		}
	      for (i = 0; i < ccl.produced; i++)
		*outp++ = destination[i];
	    }
	  src += ccl.consumed;
	  src_size -= ccl.consumed;
	  if (ccl.status != CCL_STAT_SUSPEND_BY_DST)
	    break;
	}

      if (ccl.status != CCL_STAT_SUSPEND_BY_SRC
	  || str_chars == consumed_chars)
	break;
    }

  if (ccl.status == CCL_STAT_INVALID_CMD)
    error ("Error in CCL program at %dth code", ccl.ic);
  if (ccl.status == CCL_STAT_QUIT)
    error ("CCL program interrupted at %dth code", ccl.ic);

  for (i = 0; i < 8; i++)
    ASET (status, i, make_number (ccl.reg[i]));
  ASET (status, 8, make_number (ccl.ic));

  if (NILP (unibyte_p))
    val = make_multibyte_string ((char *) outbuf, produced_chars,
				 outp - outbuf);
  else
    val = make_unibyte_string ((char *) outbuf, produced_chars);
  xfree (outbuf);

  return val;
}

DEFUN ("register-ccl-program", Fregister_ccl_program, Sregister_ccl_program,
       2, 2, 0,
       doc: /* Register CCL program CCL-PROG as NAME in `ccl-program-table'.
CCL-PROG should be a compiled CCL program (vector), or nil.
If it is nil, just reserve NAME as a CCL program name.
Return index number of the registered CCL program.  */)
     (name, ccl_prog)
     Lisp_Object name, ccl_prog;
{
  int len = ASIZE (Vccl_program_table);
  int idx;
  Lisp_Object resolved;

  CHECK_SYMBOL (name);
  resolved = Qnil;
  if (!NILP (ccl_prog))
    {
      CHECK_VECTOR (ccl_prog);
      resolved = resolve_symbol_ccl_program (ccl_prog);
      if (NILP (resolved))
	error ("Error in CCL program");
      if (VECTORP (resolved))
	{
	  ccl_prog = resolved;
	  resolved = Qt;
	}
      else
	resolved = Qnil;
    }

  for (idx = 0; idx < len; idx++)
    {
      Lisp_Object slot;

      slot = AREF (Vccl_program_table, idx);
      if (!VECTORP (slot))
	/* This is the first unused slot.  Register NAME here.  */
	break;

      if (EQ (name, AREF (slot, 0)))
	{
	  /* Update this slot.  */
	  ASET (slot, 1, ccl_prog);
	  ASET (slot, 2, resolved);
	  ASET (slot, 3, Qt);
	  return make_number (idx);
	}
    }

  if (idx == len)
    /* Extend the table.  */
    Vccl_program_table = larger_vector (Vccl_program_table, len * 2, Qnil);

  {
    Lisp_Object elt;

    elt = Fmake_vector (make_number (4), Qnil);
    ASET (elt, 0, name);
    ASET (elt, 1, ccl_prog);
    ASET (elt, 2, resolved);
    ASET (elt, 3, Qt);
    ASET (Vccl_program_table, idx, elt);
  }

  Fput (name, Qccl_program_idx, make_number (idx));
  return make_number (idx);
}

/* Register code conversion map.
   A code conversion map consists of numbers, Qt, Qnil, and Qlambda.
   The first element is the start code point.
   The other elements are mapped numbers.
   Symbol t means to map to an original number before mapping.
   Symbol nil means that the corresponding element is empty.
   Symbol lambda means to terminate mapping here.
*/

DEFUN ("register-code-conversion-map", Fregister_code_conversion_map,
       Sregister_code_conversion_map,
       2, 2, 0,
       doc: /* Register SYMBOL as code conversion map MAP.
Return index number of the registered map.  */)
     (symbol, map)
     Lisp_Object symbol, map;
{
  int len = ASIZE (Vcode_conversion_map_vector);
  int i;
  Lisp_Object index;

  CHECK_SYMBOL (symbol);
  CHECK_VECTOR (map);

  for (i = 0; i < len; i++)
    {
      Lisp_Object slot = AREF (Vcode_conversion_map_vector, i);

      if (!CONSP (slot))
	break;

      if (EQ (symbol, XCAR (slot)))
	{
	  index = make_number (i);
	  XSETCDR (slot, map);
	  Fput (symbol, Qcode_conversion_map, map);
	  Fput (symbol, Qcode_conversion_map_id, index);
	  return index;
	}
    }

  if (i == len)
    Vcode_conversion_map_vector = larger_vector (Vcode_conversion_map_vector,
						 len * 2, Qnil);

  index = make_number (i);
  Fput (symbol, Qcode_conversion_map, map);
  Fput (symbol, Qcode_conversion_map_id, index);
  ASET (Vcode_conversion_map_vector, i, Fcons (symbol, map));
  return index;
}


void
syms_of_ccl ()
{
  staticpro (&Vccl_program_table);
  Vccl_program_table = Fmake_vector (make_number (32), Qnil);

  Qccl = intern_c_string ("ccl");
  staticpro (&Qccl);

  Qcclp = intern_c_string ("cclp");
  staticpro (&Qcclp);

  Qccl_program = intern_c_string ("ccl-program");
  staticpro (&Qccl_program);

  Qccl_program_idx = intern_c_string ("ccl-program-idx");
  staticpro (&Qccl_program_idx);

  Qcode_conversion_map = intern_c_string ("code-conversion-map");
  staticpro (&Qcode_conversion_map);

  Qcode_conversion_map_id = intern_c_string ("code-conversion-map-id");
  staticpro (&Qcode_conversion_map_id);

  DEFVAR_LISP ("code-conversion-map-vector", &Vcode_conversion_map_vector,
	       doc: /* Vector of code conversion maps.  */);
  Vcode_conversion_map_vector = Fmake_vector (make_number (16), Qnil);

  DEFVAR_LISP ("font-ccl-encoder-alist", &Vfont_ccl_encoder_alist,
	       doc: /* Alist of fontname patterns vs corresponding CCL program.
Each element looks like (REGEXP . CCL-CODE),
 where CCL-CODE is a compiled CCL program.
When a font whose name matches REGEXP is used for displaying a character,
 CCL-CODE is executed to calculate the code point in the font
 from the charset number and position code(s) of the character which are set
 in CCL registers R0, R1, and R2 before the execution.
The code point in the font is set in CCL registers R1 and R2
 when the execution terminated.
 If the font is single-byte font, the register R2 is not used.  */);
  Vfont_ccl_encoder_alist = Qnil;

  DEFVAR_LISP ("translation-hash-table-vector", &Vtranslation_hash_table_vector,
    doc: /* Vector containing all translation hash tables ever defined.
Comprises pairs (SYMBOL . TABLE) where SYMBOL and TABLE were set up by calls
to `define-translation-hash-table'.  The vector is indexed by the table id
used by CCL.  */);
    Vtranslation_hash_table_vector = Qnil;

  defsubr (&Sccl_program_p);
  defsubr (&Sccl_execute);
  defsubr (&Sccl_execute_on_string);
  defsubr (&Sregister_ccl_program);
  defsubr (&Sregister_code_conversion_map);
}

/* arch-tag: bb9a37be-68ce-4576-8d3d-15d750e4a860
   (do not change this comment) */
