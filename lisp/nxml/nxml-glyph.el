;;; nxml-glyph.el --- glyph-handling for nxml-mode

;; Copyright (C) 2003, 2007, 2008 Free Software Foundation, Inc.

;; Author: James Clark
;; Keywords: XML

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; The entry point to this file is `nxml-glyph-display-string'.
;; The current implementation is heuristic due to a lack of
;; Emacs primitives necessary to implement it properly.  The user
;; can tweak the heuristics using `nxml-glyph-set-hook'.

;;; Code:

(defconst nxml-ascii-glyph-set
  [(#x0020 . #x007E)])

(defconst nxml-latin1-glyph-set
  [(#x0020 . #x007E)
   (#x00A0 . #x00FF)])

;; These were generated by using nxml-insert-target-repertoire-glyph-set
;; on the TARGET[123] files in
;; http://www.cl.cam.ac.uk/~mgk25/download/ucs-fonts.tar.gz

(defconst nxml-misc-fixed-1-glyph-set
  [(#x0020 . #x007E)
   (#x00A0 . #x00FF)
   (#x0100 . #x017F)
   #x018F #x0192
   (#x0218 . #x021B)
   #x0259
   (#x02C6 . #x02C7)
   (#x02D8 . #x02DD)
   (#x0374 . #x0375)
   #x037A #x037E
   (#x0384 . #x038A)
   #x038C
   (#x038E . #x03A1)
   (#x03A3 . #x03CE)
   (#x0401 . #x040C)
   (#x040E . #x044F)
   (#x0451 . #x045C)
   (#x045E . #x045F)
   (#x0490 . #x0491)
   (#x05D0 . #x05EA)
   (#x1E02 . #x1E03)
   (#x1E0A . #x1E0B)
   (#x1E1E . #x1E1F)
   (#x1E40 . #x1E41)
   (#x1E56 . #x1E57)
   (#x1E60 . #x1E61)
   (#x1E6A . #x1E6B)
   (#x1E80 . #x1E85)
   (#x1EF2 . #x1EF3)
   (#x2010 . #x2022)
   #x2026 #x2030
   (#x2039 . #x203A)
   #x20AC #x2116 #x2122 #x2126
   (#x215B . #x215E)
   (#x2190 . #x2193)
   #x2260
   (#x2264 . #x2265)
   (#x23BA . #x23BD)
   (#x2409 . #x240D)
   #x2424 #x2500 #x2502 #x250C #x2510 #x2514 #x2518 #x251C #x2524 #x252C #x2534 #x253C #x2592 #x25C6 #x266A #xFFFD]
  "Glyph set for TARGET1 glyph repertoire of misc-fixed-* font.
This repertoire is supported for the bold and oblique fonts.")

(defconst nxml-misc-fixed-2-glyph-set
  [(#x0020 . #x007E)
   (#x00A0 . #x00FF)
   (#x0100 . #x017F)
   #x018F #x0192
   (#x01FA . #x01FF)
   (#x0218 . #x021B)
   #x0259
   (#x02C6 . #x02C7)
   #x02C9
   (#x02D8 . #x02DD)
   (#x0300 . #x0311)
   (#x0374 . #x0375)
   #x037A #x037E
   (#x0384 . #x038A)
   #x038C
   (#x038E . #x03A1)
   (#x03A3 . #x03CE)
   #x03D1
   (#x03D5 . #x03D6)
   #x03F1
   (#x0401 . #x040C)
   (#x040E . #x044F)
   (#x0451 . #x045C)
   (#x045E . #x045F)
   (#x0490 . #x0491)
   (#x05D0 . #x05EA)
   (#x1E02 . #x1E03)
   (#x1E0A . #x1E0B)
   (#x1E1E . #x1E1F)
   (#x1E40 . #x1E41)
   (#x1E56 . #x1E57)
   (#x1E60 . #x1E61)
   (#x1E6A . #x1E6B)
   (#x1E80 . #x1E85)
   (#x1EF2 . #x1EF3)
   (#x2010 . #x2022)
   #x2026 #x2030
   (#x2032 . #x2034)
   (#x2039 . #x203A)
   #x203C #x203E #x2044
   (#x2070 . #x2071)
   (#x2074 . #x208E)
   (#x20A3 . #x20A4)
   #x20A7 #x20AC
   (#x20D0 . #x20D7)
   #x2102 #x2105 #x2113
   (#x2115 . #x2116)
   #x211A #x211D #x2122 #x2124 #x2126 #x212E
   (#x215B . #x215E)
   (#x2190 . #x2195)
   (#x21A4 . #x21A8)
   (#x21D0 . #x21D5)
   (#x2200 . #x2209)
   (#x220B . #x220C)
   #x220F
   (#x2211 . #x2213)
   #x2215
   (#x2218 . #x221A)
   (#x221D . #x221F)
   #x2221
   (#x2224 . #x222B)
   #x222E #x223C #x2243 #x2245
   (#x2248 . #x2249)
   #x2259
   (#x225F . #x2262)
   (#x2264 . #x2265)
   (#x226A . #x226B)
   (#x2282 . #x228B)
   #x2295 #x2297
   (#x22A4 . #x22A7)
   (#x22C2 . #x22C3)
   #x22C5 #x2300 #x2302
   (#x2308 . #x230B)
   #x2310
   (#x2320 . #x2321)
   (#x2329 . #x232A)
   (#x23BA . #x23BD)
   (#x2409 . #x240D)
   #x2424 #x2500 #x2502 #x250C #x2510 #x2514 #x2518 #x251C #x2524 #x252C #x2534 #x253C
   (#x254C . #x2573)
   (#x2580 . #x25A1)
   (#x25AA . #x25AC)
   (#x25B2 . #x25B3)
   #x25BA #x25BC #x25C4 #x25C6
   (#x25CA . #x25CB)
   #x25CF
   (#x25D8 . #x25D9)
   #x25E6
   (#x263A . #x263C)
   #x2640 #x2642 #x2660 #x2663
   (#x2665 . #x2666)
   (#x266A . #x266B)
   (#xFB01 . #xFB02)
   #xFFFD]
  "Glyph set for TARGET2 glyph repertoire of the misc-fixed-* fonts.
This repertoire is supported for the following fonts:
5x7.bdf 5x8.bdf 6x9.bdf 6x10.bdf 6x12.bdf 7x13.bdf 7x14.bdf clR6x12.bdf")

(defconst nxml-misc-fixed-3-glyph-set
  [(#x0020 . #x007E)
   (#x00A0 . #x00FF)
   (#x0100 . #x01FF)
   (#x0200 . #x0220)
   (#x0222 . #x0233)
   (#x0250 . #x02AD)
   (#x02B0 . #x02EE)
   (#x0300 . #x034F)
   (#x0360 . #x036F)
   (#x0374 . #x0375)
   #x037A #x037E
   (#x0384 . #x038A)
   #x038C
   (#x038E . #x03A1)
   (#x03A3 . #x03CE)
   (#x03D0 . #x03F6)
   (#x0400 . #x0486)
   (#x0488 . #x04CE)
   (#x04D0 . #x04F5)
   (#x04F8 . #x04F9)
   (#x0500 . #x050F)
   (#x0531 . #x0556)
   (#x0559 . #x055F)
   (#x0561 . #x0587)
   (#x0589 . #x058A)
   (#x05B0 . #x05B9)
   (#x05BB . #x05C4)
   (#x05D0 . #x05EA)
   (#x05F0 . #x05F4)
   (#x10D0 . #x10F8)
   #x10FB
   (#x1E00 . #x1E9B)
   (#x1EA0 . #x1EF9)
   (#x1F00 . #x1F15)
   (#x1F18 . #x1F1D)
   (#x1F20 . #x1F45)
   (#x1F48 . #x1F4D)
   (#x1F50 . #x1F57)
   #x1F59 #x1F5B #x1F5D
   (#x1F5F . #x1F7D)
   (#x1F80 . #x1FB4)
   (#x1FB6 . #x1FC4)
   (#x1FC6 . #x1FD3)
   (#x1FD6 . #x1FDB)
   (#x1FDD . #x1FEF)
   (#x1FF2 . #x1FF4)
   (#x1FF6 . #x1FFE)
   (#x2000 . #x200A)
   (#x2010 . #x2027)
   (#x202F . #x2052)
   #x2057
   (#x205F . #x2063)
   (#x2070 . #x2071)
   (#x2074 . #x208E)
   (#x20A0 . #x20B1)
   (#x20D0 . #x20EA)
   (#x2100 . #x213A)
   (#x213D . #x214B)
   (#x2153 . #x2183)
   (#x2190 . #x21FF)
   (#x2200 . #x22FF)
   (#x2300 . #x23CE)
   (#x2400 . #x2426)
   (#x2440 . #x244A)
   (#x2500 . #x25FF)
   (#x2600 . #x2613)
   (#x2616 . #x2617)
   (#x2619 . #x267D)
   (#x2680 . #x2689)
   (#x27E6 . #x27EB)
   (#x27F5 . #x27FF)
   (#x2A00 . #x2A06)
   #x2A1D #x2A3F #x303F
   (#xFB00 . #xFB06)
   (#xFB13 . #xFB17)
   (#xFB1D . #xFB36)
   (#xFB38 . #xFB3C)
   #xFB3E
   (#xFB40 . #xFB41)
   (#xFB43 . #xFB44)
   (#xFB46 . #xFB4F)
   (#xFE20 . #xFE23)
   (#xFF61 . #xFF9F)
   #xFFFD]
  "Glyph set for TARGET3 glyph repertoire of the misc-fixed-* fonts.
This repertoire is supported for the following fonts:
6x13.bdf 8x13.bdf 9x15.bdf 9x18.bdf 10x20.bdf")

(defconst nxml-wgl4-glyph-set
  [(#x0020 . #x007E)
   (#x00A0 . #x017F)
   #x0192
   (#x01FA . #x01FF)
   (#x02C6 . #x02C7)
   #x02C9
   (#x02D8 . #x02DB)
   #x02DD
   (#x0384 . #x038A)
   #x038C
   (#x038E . #x03A1)
   (#x03A3 . #x03CE)
   (#x0401 . #x040C)
   (#x040E . #x044F)
   (#x0451 . #x045C)
   (#x045E . #x045F)
   (#x0490 . #x0491)
   (#x1E80 . #x1E85)
   (#x1EF2 . #x1EF3)
   (#x2013 . #x2015)
   (#x2017 . #x201E)
   (#x2020 . #x2022)
   #x2026 #x2030
   (#x2032 . #x2033)
   (#x2039 . #x203A)
   #x203C #x203E #x2044 #x207F
   (#x20A3 . #x20A4)
   #x20A7 #x20AC #x2105 #x2113 #x2116 #x2122 #x2126 #x212E
   (#x215B . #x215E)
   (#x2190 . #x2195)
   #x21A8 #x2202 #x2206 #x220F
   (#x2211 . #x2212)
   #x2215
   (#x2219 . #x221A)
   (#x221E . #x221F)
   #x2229 #x222B #x2248
   (#x2260 . #x2261)
   (#x2264 . #x2265)
   #x2302 #x2310
   (#x2320 . #x2321)
   #x2500 #x2502 #x250C #x2510 #x2514 #x2518 #x251C #x2524
   #x252C #x2534 #x253C
   (#x2550 . #x256C)
   #x2580 #x2584 #x2588 #x258C
   (#x2590 . #x2593)
   (#x25A0 . #x25A1)
   (#x25AA . #x25AC)
   #x25B2 #x25BA #x25BC #x25C4
   (#x25CA . #x25CB)
   #x25CF
   (#x25D8 . #x25D9)
   #x25E6
   (#x263A . #x263C)
   #x2640 #x2642 #x2660 #x2663
   (#x2665 . #x2666)
   (#x266A . #x266B)
   (#xFB01 . #xFB02)]
  "Glyph set corresponding to Windows Glyph List 4.")

(defvar nxml-glyph-set-hook nil
  "*Hook for determining the set of glyphs in a face.
The hook will receive a single argument FACE.  If it can determine
the set of glyphs representable by FACE, it must set the variable
`nxml-glyph-set' and return non-nil.  Otherwise, it must return nil.
The hook will be run until success.  The constants
`nxml-ascii-glyph-set', `nxml-latin1-glyph-set',
`nxml-misc-fixed-1-glyph-set', `nxml-misc-fixed-2-glyph-set',
`nxml-misc-fixed-3-glyph-set' and `nxml-wgl4-glyph-set' are
predefined for use by `nxml-glyph-set-hook'.")

(defvar nxml-glyph-set nil
  "Used by `nxml-glyph-set-hook' to return set of glyphs in a FACE.
This should dynamically bound by any function that runs
`nxml-glyph-set-hook'.  The value must be either nil representing an
empty set or a vector. Each member of the vector is either a single
integer or a cons (FIRST . LAST) representing the range of integers
from FIRST to LAST.  An integer represents a glyph with that Unicode
code-point.  The vector must be ordered.")

(defun nxml-x-set-glyph-set (face)
  (setq nxml-glyph-set
	(if (equal (face-attribute face :family) "misc-fixed")
	    nxml-misc-fixed-3-glyph-set
	  nxml-wgl4-glyph-set)))

(defun nxml-w32-set-glyph-set (face)
  (setq nxml-glyph-set nxml-wgl4-glyph-set))

(defun nxml-window-system-set-glyph-set (face)
  (setq nxml-glyph-set nxml-latin1-glyph-set))

(defun nxml-terminal-set-glyph-set (face)
  (setq nxml-glyph-set nxml-ascii-glyph-set))

(add-hook 'nxml-glyph-set-hook
	  (or (cdr (assq window-system
			 '((x . nxml-x-set-glyph-set)
			   (w32 . nxml-w32-set-glyph-set)
			   (nil . nxml-terminal-set-glyph-set))))
	      'nxml-window-system-set-glyph-set)
	  t)

;;;###autoload
(defun nxml-glyph-display-string (n face)
  "Return a string that can display a glyph for Unicode code-point N.
FACE gives the face that will be used for displaying the string.
Return nil if the face cannot display a glyph for N."
  (let ((nxml-glyph-set nil))
    (run-hook-with-args-until-success 'nxml-glyph-set-hook face)
    (and nxml-glyph-set
	 (nxml-glyph-set-contains-p n nxml-glyph-set)
	 (let ((ch (decode-char 'ucs n)))
	   (and ch (string ch))))))

(defun nxml-glyph-set-contains-p (n v)
  (let ((start 0)
	(end (length v))
	found mid mid-val mid-start-val mid-end-val)
    (while (> end start)
      (setq mid (+ start
		   (/ (- end start) 2)))
      (setq mid-val (aref v mid))
      (if (consp mid-val)
	  (setq mid-start-val (car mid-val)
		mid-end-val (cdr mid-val))
	(setq mid-start-val mid-val
	      mid-end-val mid-val))
      (cond ((and (<= mid-start-val n)
		  (<= n mid-end-val))
	     (setq found t)
	     (setq start end))
	    ((< n mid-start-val)
	     (setq end mid))
	    (t
	     (setq start
		   (if (eq start mid)
		       end
		     mid)))))
    found))

(provide 'nxml-glyph)

;; arch-tag: 50985104-27c6-4241-8625-b11aa5685633
;;; nxml-glyph.el ends here
