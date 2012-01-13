;;; iso-cvt.el --- translate ISO 8859-1 from/to various encodings -*- coding: iso-latin-1 -*-
;; This file was formerly called gm-lingo.el.

;; Copyright (C) 1993, 1994, 1995, 1996, 1997, 1998, 2000, 2001,
;;   2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012  Free Software Foundation, Inc.

;; Author: Michael Gschwind <mike@vlsivie.tuwien.ac.at>
;; Keywords: tex, iso, latin, i18n

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
;; This lisp code is a general framework for translating various
;; representations of the same data.
;; among other things it can be used to translate TeX, HTML, and compressed
;; files to ISO 8859-1.  It can also be used to translate different charsets
;; such as IBM PC, Macintosh or HP Roman8.
;; Note that many translations use the GNU recode tool to do the actual
;; conversion.  So you might want to install that tool to get the full
;; benefit of iso-cvt.el

; TO DO:
; Cover more cases for translation.  (There is an infinite number of ways to
; represent accented characters in TeX)

;; SEE ALSO:
; If you are interested in questions related to using the ISO 8859-1
; characters set (configuring emacs, Unix, etc. to use ISO), then you
; can get the ISO 8859-1 FAQ via anonymous ftp from
; ftp.vlsivie.tuwien.ac.at in /pub/8bit/FAQ-ISO-8859-1

;;; Code:

(defvar iso-spanish-trans-tab
  '(
    ("~n" "�")
    ("\([a-zA-Z]\)#" "\\1�")
    ("~N" "�")
    ("\\([-a-zA-Z\"`]\\)\"u" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"U" "\\1�")
    ("\\([-a-zA-Z]\\)'o" "\\1�")
    ("\\([-a-zA-Z]\\)'O" "\\�")
    ("\\([-a-zA-Z]\\)'e" "\\1�")
    ("\\([-a-zA-Z]\\)'E" "\\1�")
    ("\\([-a-zA-Z]\\)'a" "\\1�")
    ("\\([-a-zA-Z]\\)'A" "\\1A")
    ("\\([-a-zA-Z]\\)'i" "\\1�")
    ("\\([-a-zA-Z]\\)'I" "\\1�")
    )
  "Spanish translation table.")

(defun iso-translate-conventions (from to trans-tab)
  "Translate between FROM and TO using the translation table TRANS-TAB."
  (save-excursion
    (save-restriction
      (narrow-to-region from to)
      (goto-char from)
      (let ((work-tab trans-tab)
	    (buffer-read-only nil)
	    (case-fold-search nil))
	(while work-tab
	  (save-excursion
	    (let ((trans-this (car work-tab)))
	      (while (re-search-forward (car trans-this) nil t)
		(replace-match (car (cdr trans-this)) t nil)))
	    (setq work-tab (cdr work-tab)))))
      (point-max))))

;;;###autoload
(defun iso-spanish (from to &optional buffer)
  "Translate net conventions for Spanish to ISO 8859-1.
Translate the region between FROM and TO using the table
`iso-spanish-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
  (interactive "*r")
  (iso-translate-conventions from to iso-spanish-trans-tab))

(defvar iso-aggressive-german-trans-tab
  '(
    ("\"a" "�")
    ("\"A" "�")
    ("\"o" "�")
    ("\"O" "�")
    ("\"u" "�")
    ("\"U" "�")
    ("\"s" "�")
    ("\\\\3" "�")
    )
  "German translation table.
This table uses an aggressive translation approach
and may erroneously translate too much.")

(defvar iso-conservative-german-trans-tab
  '(
    ("\\([-a-zA-Z\"`]\\)\"a" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"A" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"o" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"O" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"u" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"U" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\"s" "\\1�")
    ("\\([-a-zA-Z\"`]\\)\\\\3" "\\1�")
    )
  "German translation table.
This table uses a conservative translation approach
and may translate too little.")

(defvar iso-german-trans-tab iso-aggressive-german-trans-tab
  "Currently active translation table for German.")

;;;###autoload
(defun iso-german (from to &optional buffer)
 "Translate net conventions for German to ISO 8859-1.
Translate the region FROM and TO using the table
`iso-german-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-german-trans-tab))

(defvar iso-iso2tex-trans-tab
  '(
    ("�" "{\\\\\"a}")
    ("�" "{\\\\`a}")
    ("�" "{\\\\'a}")
    ("�" "{\\\\~a}")
    ("�" "{\\\\^a}")
    ("�" "{\\\\\"e}")
    ("�" "{\\\\`e}")
    ("�" "{\\\\'e}")
    ("�" "{\\\\^e}")
    ("�" "{\\\\\"\\\\i}")
    ("�" "{\\\\`\\\\i}")
    ("�" "{\\\\'\\\\i}")
    ("�" "{\\\\^\\\\i}")
    ("�" "{\\\\\"o}")
    ("�" "{\\\\`o}")
    ("�" "{\\\\'o}")
    ("�" "{\\\\~o}")
    ("�" "{\\\\^o}")
    ("�" "{\\\\\"u}")
    ("�" "{\\\\`u}")
    ("�" "{\\\\'u}")
    ("�" "{\\\\^u}")
    ("�" "{\\\\\"A}")
    ("�" "{\\\\`A}")
    ("�" "{\\\\'A}")
    ("�" "{\\\\~A}")
    ("�" "{\\\\^A}")
    ("�" "{\\\\\"E}")
    ("�" "{\\\\`E}")
    ("�" "{\\\\'E}")
    ("�" "{\\\\^E}")
    ("�" "{\\\\\"I}")
    ("�" "{\\\\`I}")
    ("�" "{\\\\'I}")
    ("�" "{\\\\^I}")
    ("�" "{\\\\\"O}")
    ("�" "{\\\\`O}")
    ("�" "{\\\\'O}")
    ("�" "{\\\\~O}")
    ("�" "{\\\\^O}")
    ("�" "{\\\\\"U}")
    ("�" "{\\\\`U}")
    ("�" "{\\\\'U}")
    ("�" "{\\\\^U}")
    ("�" "{\\\\~n}")
    ("�" "{\\\\~N}")
    ("�" "{\\\\c c}")
    ("�" "{\\\\c C}")
    ("�" "{\\\\ss}")
    ("\306" "{\\\\AE}")
    ("\346" "{\\\\ae}")
    ("\305" "{\\\\AA}")
    ("\345" "{\\\\aa}")
    ("\251" "{\\\\copyright}")
    ("�" "{\\\\pounds}")
    ("�" "{\\\\P}")
    ("�" "{\\\\S}")
    ("�" "{?`}")
    ("�" "{!`}")
    )
  "Translation table for translating ISO 8859-1 characters to TeX sequences.")

;;;###autoload
(defun iso-iso2tex (from to &optional buffer)
 "Translate ISO 8859-1 characters to TeX sequences.
Translate the region between FROM and TO using the table
`iso-iso2tex-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2tex-trans-tab))

(defvar iso-tex2iso-trans-tab
  '(
    ("{\\\\\"a}" "�")
    ("{\\\\`a}" "�")
    ("{\\\\'a}" "�")
    ("{\\\\~a}" "�")
    ("{\\\\^a}" "�")
    ("{\\\\\"e}" "�")
    ("{\\\\`e}" "�")
    ("{\\\\'e}" "�")
    ("{\\\\^e}" "�")
    ("{\\\\\"\\\\i}" "�")
    ("{\\\\`\\\\i}" "�")
    ("{\\\\'\\\\i}" "�")
    ("{\\\\^\\\\i}" "�")
    ("{\\\\\"i}" "�")
    ("{\\\\`i}" "�")
    ("{\\\\'i}" "�")
    ("{\\\\^i}" "�")
    ("{\\\\\"o}" "�")
    ("{\\\\`o}" "�")
    ("{\\\\'o}" "�")
    ("{\\\\~o}" "�")
    ("{\\\\^o}" "�")
    ("{\\\\\"u}" "�")
    ("{\\\\`u}" "�")
    ("{\\\\'u}" "�")
    ("{\\\\^u}" "�")
    ("{\\\\\"A}" "�")
    ("{\\\\`A}" "�")
    ("{\\\\'A}" "�")
    ("{\\\\~A}" "�")
    ("{\\\\^A}" "�")
    ("{\\\\\"E}" "�")
    ("{\\\\`E}" "�")
    ("{\\\\'E}" "�")
    ("{\\\\^E}" "�")
    ("{\\\\\"I}" "�")
    ("{\\\\`I}" "�")
    ("{\\\\'I}" "�")
    ("{\\\\^I}" "�")
    ("{\\\\\"O}" "�")
    ("{\\\\`O}" "�")
    ("{\\\\'O}" "�")
    ("{\\\\~O}" "�")
    ("{\\\\^O}" "�")
    ("{\\\\\"U}" "�")
    ("{\\\\`U}" "�")
    ("{\\\\'U}" "�")
    ("{\\\\^U}" "�")
    ("{\\\\~n}" "�")
    ("{\\\\~N}" "�")
    ("{\\\\c c}" "�")
    ("{\\\\c C}" "�")
    ("\\\\\"a" "�")
    ("\\\\`a" "�")
    ("\\\\'a" "�")
    ("\\\\~a" "�")
    ("\\\\^a" "�")
    ("\\\\\"e" "�")
    ("\\\\`e" "�")
    ("\\\\'e" "�")
    ("\\\\^e" "�")
    ;; Discard spaces and/or one EOF after macro \i.
    ;; Converting it back will use braces.
    ("\\\\\"\\\\i *\n\n" "�\n\n")
    ("\\\\\"\\\\i *\n?" "�")
    ("\\\\`\\\\i *\n\n" "�\n\n")
    ("\\\\`\\\\i *\n?" "�")
    ("\\\\'\\\\i *\n\n" "�\n\n")
    ("\\\\'\\\\i *\n?" "�")
    ("\\\\^\\\\i *\n\n" "�\n\n")
    ("\\\\^\\\\i *\n?" "�")
    ("\\\\\"i" "�")
    ("\\\\`i" "�")
    ("\\\\'i" "�")
    ("\\\\^i" "�")
    ("\\\\\"o" "�")
    ("\\\\`o" "�")
    ("\\\\'o" "�")
    ("\\\\~o" "�")
    ("\\\\^o" "�")
    ("\\\\\"u" "�")
    ("\\\\`u" "�")
    ("\\\\'u" "�")
    ("\\\\^u" "�")
    ("\\\\\"A" "�")
    ("\\\\`A" "�")
    ("\\\\'A" "�")
    ("\\\\~A" "�")
    ("\\\\^A" "�")
    ("\\\\\"E" "�")
    ("\\\\`E" "�")
    ("\\\\'E" "�")
    ("\\\\^E" "�")
    ("\\\\\"I" "�")
    ("\\\\`I" "�")
    ("\\\\'I" "�")
    ("\\\\^I" "�")
    ("\\\\\"O" "�")
    ("\\\\`O" "�")
    ("\\\\'O" "�")
    ("\\\\~O" "�")
    ("\\\\^O" "�")
    ("\\\\\"U" "�")
    ("\\\\`U" "�")
    ("\\\\'U" "�")
    ("\\\\^U" "�")
    ("\\\\~n" "�")
    ("\\\\~N" "�")
    ("\\\\\"{a}" "�")
    ("\\\\`{a}" "�")
    ("\\\\'{a}" "�")
    ("\\\\~{a}" "�")
    ("\\\\^{a}" "�")
    ("\\\\\"{e}" "�")
    ("\\\\`{e}" "�")
    ("\\\\'{e}" "�")
    ("\\\\^{e}" "�")
    ("\\\\\"{\\\\i}" "�")
    ("\\\\`{\\\\i}" "�")
    ("\\\\'{\\\\i}" "�")
    ("\\\\^{\\\\i}" "�")
    ("\\\\\"{i}" "�")
    ("\\\\`{i}" "�")
    ("\\\\'{i}" "�")
    ("\\\\^{i}" "�")
    ("\\\\\"{o}" "�")
    ("\\\\`{o}" "�")
    ("\\\\'{o}" "�")
    ("\\\\~{o}" "�")
    ("\\\\^{o}" "�")
    ("\\\\\"{u}" "�")
    ("\\\\`{u}" "�")
    ("\\\\'{u}" "�")
    ("\\\\^{u}" "�")
    ("\\\\\"{A}" "�")
    ("\\\\`{A}" "�")
    ("\\\\'{A}" "�")
    ("\\\\~{A}" "�")
    ("\\\\^{A}" "�")
    ("\\\\\"{E}" "�")
    ("\\\\`{E}" "�")
    ("\\\\'{E}" "�")
    ("\\\\^{E}" "�")
    ("\\\\\"{I}" "�")
    ("\\\\`{I}" "�")
    ("\\\\'{I}" "�")
    ("\\\\^{I}" "�")
    ("\\\\\"{O}" "�")
    ("\\\\`{O}" "�")
    ("\\\\'{O}" "�")
    ("\\\\~{O}" "�")
    ("\\\\^{O}" "�")
    ("\\\\\"{U}" "�")
    ("\\\\`{U}" "�")
    ("\\\\'{U}" "�")
    ("\\\\^{U}" "�")
    ("\\\\~{n}" "�")
    ("\\\\~{N}" "�")
    ("\\\\c{c}" "�")
    ("\\\\c{C}" "�")
    ("{\\\\ss}" "�")
    ("{\\\\AE}" "\306")
    ("{\\\\ae}" "\346")
    ("{\\\\AA}" "\305")
    ("{\\\\aa}" "\345")
    ("{\\\\copyright}" "\251")
    ("\\\\copyright{}" "\251")
    ("{\\\\pounds}" "�" )
    ("{\\\\P}" "�" )
    ("{\\\\S}" "�" )
    ("\\\\pounds{}" "�" )
    ("\\\\P{}" "�" )
    ("\\\\S{}" "�" )
    ("{\\?`}" "�")
    ("{!`}" "�")
    ("\\?`" "�")
    ("!`" "�")
    )
  "Translation table for translating TeX sequences to ISO 8859-1 characters.
This table is not exhaustive (and due to TeX's power can never be).
It only contains commonly used sequences.")

;;;###autoload
(defun iso-tex2iso (from to &optional buffer)
 "Translate TeX sequences to ISO 8859-1 characters.
Translate the region between FROM and TO using the table
`iso-tex2iso-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-tex2iso-trans-tab))

(defvar iso-gtex2iso-trans-tab
  '(
    ("{\\\\\"a}" "�")
    ("{\\\\`a}" "�")
    ("{\\\\'a}" "�")
    ("{\\\\~a}" "�")
    ("{\\\\^a}" "�")
    ("{\\\\\"e}" "�")
    ("{\\\\`e}" "�")
    ("{\\\\'e}" "�")
    ("{\\\\^e}" "�")
    ("{\\\\\"\\\\i}" "�")
    ("{\\\\`\\\\i}" "�")
    ("{\\\\'\\\\i}" "�")
    ("{\\\\^\\\\i}" "�")
    ("{\\\\\"i}" "�")
    ("{\\\\`i}" "�")
    ("{\\\\'i}" "�")
    ("{\\\\^i}" "�")
    ("{\\\\\"o}" "�")
    ("{\\\\`o}" "�")
    ("{\\\\'o}" "�")
    ("{\\\\~o}" "�")
    ("{\\\\^o}" "�")
    ("{\\\\\"u}" "�")
    ("{\\\\`u}" "�")
    ("{\\\\'u}" "�")
    ("{\\\\^u}" "�")
    ("{\\\\\"A}" "�")
    ("{\\\\`A}" "�")
    ("{\\\\'A}" "�")
    ("{\\\\~A}" "�")
    ("{\\\\^A}" "�")
    ("{\\\\\"E}" "�")
    ("{\\\\`E}" "�")
    ("{\\\\'E}" "�")
    ("{\\\\^E}" "�")
    ("{\\\\\"I}" "�")
    ("{\\\\`I}" "�")
    ("{\\\\'I}" "�")
    ("{\\\\^I}" "�")
    ("{\\\\\"O}" "�")
    ("{\\\\`O}" "�")
    ("{\\\\'O}" "�")
    ("{\\\\~O}" "�")
    ("{\\\\^O}" "�")
    ("{\\\\\"U}" "�")
    ("{\\\\`U}" "�")
    ("{\\\\'U}" "�")
    ("{\\\\^U}" "�")
    ("{\\\\~n}" "�")
    ("{\\\\~N}" "�")
    ("{\\\\c c}" "�")
    ("{\\\\c C}" "�")
    ("\\\\\"a" "�")
    ("\\\\`a" "�")
    ("\\\\'a" "�")
    ("\\\\~a" "�")
    ("\\\\^a" "�")
    ("\\\\\"e" "�")
    ("\\\\`e" "�")
    ("\\\\'e" "�")
    ("\\\\^e" "�")
    ("\\\\\"\\\\i" "�")
    ("\\\\`\\\\i" "�")
    ("\\\\'\\\\i" "�")
    ("\\\\^\\\\i" "�")
    ("\\\\\"i" "�")
    ("\\\\`i" "�")
    ("\\\\'i" "�")
    ("\\\\^i" "�")
    ("\\\\\"o" "�")
    ("\\\\`o" "�")
    ("\\\\'o" "�")
    ("\\\\~o" "�")
    ("\\\\^o" "�")
    ("\\\\\"u" "�")
    ("\\\\`u" "�")
    ("\\\\'u" "�")
    ("\\\\^u" "�")
    ("\\\\\"A" "�")
    ("\\\\`A" "�")
    ("\\\\'A" "�")
    ("\\\\~A" "�")
    ("\\\\^A" "�")
    ("\\\\\"E" "�")
    ("\\\\`E" "�")
    ("\\\\'E" "�")
    ("\\\\^E" "�")
    ("\\\\\"I" "�")
    ("\\\\`I" "�")
    ("\\\\'I" "�")
    ("\\\\^I" "�")
    ("\\\\\"O" "�")
    ("\\\\`O" "�")
    ("\\\\'O" "�")
    ("\\\\~O" "�")
    ("\\\\^O" "�")
    ("\\\\\"U" "�")
    ("\\\\`U" "�")
    ("\\\\'U" "�")
    ("\\\\^U" "�")
    ("\\\\~n" "�")
    ("\\\\~N" "�")
    ("\\\\\"{a}" "�")
    ("\\\\`{a}" "�")
    ("\\\\'{a}" "�")
    ("\\\\~{a}" "�")
    ("\\\\^{a}" "�")
    ("\\\\\"{e}" "�")
    ("\\\\`{e}" "�")
    ("\\\\'{e}" "�")
    ("\\\\^{e}" "�")
    ("\\\\\"{\\\\i}" "�")
    ("\\\\`{\\\\i}" "�")
    ("\\\\'{\\\\i}" "�")
    ("\\\\^{\\\\i}" "�")
    ("\\\\\"{i}" "�")
    ("\\\\`{i}" "�")
    ("\\\\'{i}" "�")
    ("\\\\^{i}" "�")
    ("\\\\\"{o}" "�")
    ("\\\\`{o}" "�")
    ("\\\\'{o}" "�")
    ("\\\\~{o}" "�")
    ("\\\\^{o}" "�")
    ("\\\\\"{u}" "�")
    ("\\\\`{u}" "�")
    ("\\\\'{u}" "�")
    ("\\\\^{u}" "�")
    ("\\\\\"{A}" "�")
    ("\\\\`{A}" "�")
    ("\\\\'{A}" "�")
    ("\\\\~{A}" "�")
    ("\\\\^{A}" "�")
    ("\\\\\"{E}" "�")
    ("\\\\`{E}" "�")
    ("\\\\'{E}" "�")
    ("\\\\^{E}" "�")
    ("\\\\\"{I}" "�")
    ("\\\\`{I}" "�")
    ("\\\\'{I}" "�")
    ("\\\\^{I}" "�")
    ("\\\\\"{O}" "�")
    ("\\\\`{O}" "�")
    ("\\\\'{O}" "�")
    ("\\\\~{O}" "�")
    ("\\\\^{O}" "�")
    ("\\\\\"{U}" "�")
    ("\\\\`{U}" "�")
    ("\\\\'{U}" "�")
    ("\\\\^{U}" "�")
    ("\\\\~{n}" "�")
    ("\\\\~{N}" "�")
    ("\\\\c{c}" "�")
    ("\\\\c{C}" "�")
    ("{\\\\ss}" "�")
    ("{\\\\AE}" "\306")
    ("{\\\\ae}" "\346")
    ("{\\\\AA}" "\305")
    ("{\\\\aa}" "\345")
    ("{\\\\copyright}" "\251")
    ("\\\\copyright{}" "\251")
    ("{\\\\pounds}" "�" )
    ("{\\\\P}" "�" )
    ("{\\\\S}" "�" )
    ("\\\\pounds{}" "�" )
    ("\\\\P{}" "�" )
    ("\\\\S{}" "�" )
    ("?`" "�")
    ("!`" "�")
    ("{?`}" "�")
    ("{!`}" "�")
    ("\"a" "�")
    ("\"A" "�")
    ("\"o" "�")
    ("\"O" "�")
    ("\"u" "�")
    ("\"U" "�")
    ("\"s" "�")
    ("\\\\3" "�")
    )
  "Translation table for translating German TeX sequences to ISO 8859-1.
This table is not exhaustive (and due to TeX's power can never be).
It only contains commonly used sequences.")

(defvar iso-iso2gtex-trans-tab
  '(
    ("�" "\"a")
    ("�" "{\\\\`a}")
    ("�" "{\\\\'a}")
    ("�" "{\\\\~a}")
    ("�" "{\\\\^a}")
    ("�" "{\\\\\"e}")
    ("�" "{\\\\`e}")
    ("�" "{\\\\'e}")
    ("�" "{\\\\^e}")
    ("�" "{\\\\\"\\\\i}")
    ("�" "{\\\\`\\\\i}")
    ("�" "{\\\\'\\\\i}")
    ("�" "{\\\\^\\\\i}")
    ("�" "\"o")
    ("�" "{\\\\`o}")
    ("�" "{\\\\'o}")
    ("�" "{\\\\~o}")
    ("�" "{\\\\^o}")
    ("�" "\"u")
    ("�" "{\\\\`u}")
    ("�" "{\\\\'u}")
    ("�" "{\\\\^u}")
    ("�" "\"A")
    ("�" "{\\\\`A}")
    ("�" "{\\\\'A}")
    ("�" "{\\\\~A}")
    ("�" "{\\\\^A}")
    ("�" "{\\\\\"E}")
    ("�" "{\\\\`E}")
    ("�" "{\\\\'E}")
    ("�" "{\\\\^E}")
    ("�" "{\\\\\"I}")
    ("�" "{\\\\`I}")
    ("�" "{\\\\'I}")
    ("�" "{\\\\^I}")
    ("�" "\"O")
    ("�" "{\\\\`O}")
    ("�" "{\\\\'O}")
    ("�" "{\\\\~O}")
    ("�" "{\\\\^O}")
    ("�" "\"U")
    ("�" "{\\\\`U}")
    ("�" "{\\\\'U}")
    ("�" "{\\\\^U}")
    ("�" "{\\\\~n}")
    ("�" "{\\\\~N}")
    ("�" "{\\\\c c}")
    ("�" "{\\\\c C}")
    ("�" "\"s")
    ("\306" "{\\\\AE}")
    ("\346" "{\\\\ae}")
    ("\305" "{\\\\AA}")
    ("\345" "{\\\\aa}")
    ("\251" "{\\\\copyright}")
    ("�" "{\\\\pounds}")
    ("�" "{\\\\P}")
    ("�" "{\\\\S}")
    ("�" "{?`}")
    ("�" "{!`}")
    )
  "Translation table for translating ISO 8859-1 characters to German TeX.")

;;;###autoload
(defun iso-gtex2iso (from to &optional buffer)
 "Translate German TeX sequences to ISO 8859-1 characters.
Translate the region between FROM and TO using the table
`iso-gtex2iso-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-gtex2iso-trans-tab))

;;;###autoload
(defun iso-iso2gtex (from to &optional buffer)
 "Translate ISO 8859-1 characters to German TeX sequences.
Translate the region between FROM and TO using the table
`iso-iso2gtex-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2gtex-trans-tab))

(defvar iso-iso2duden-trans-tab
  '(("�" "ae")
    ("�" "Ae")
    ("�" "oe")
    ("�" "Oe")
    ("�" "ue")
    ("�" "Ue")
    ("�" "ss"))
    "Translation table for translating ISO 8859-1 characters to Duden sequences.")

;;;###autoload
(defun iso-iso2duden (from to &optional buffer)
 "Translate ISO 8859-1 characters to Duden sequences.
Translate the region between FROM and TO using the table
`iso-iso2duden-trans-tab'.
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2duden-trans-tab))

(defvar iso-iso2sgml-trans-tab
  '(("�" "&Agrave;")
    ("�" "&Aacute;")
    ("�" "&Acirc;")
    ("�" "&Atilde;")
    ("�" "&Auml;")
    ("�" "&Aring;")
    ("�" "&AElig;")
    ("�" "&Ccedil;")
    ("�" "&Egrave;")
    ("�" "&Eacute;")
    ("�" "&Ecirc;")
    ("�" "&Euml;")
    ("�" "&Igrave;")
    ("�" "&Iacute;")
    ("�" "&Icirc;")
    ("�" "&Iuml;")
    ("�" "&ETH;")
    ("�" "&Ntilde;")
    ("�" "&Ograve;")
    ("�" "&Oacute;")
    ("�" "&Ocirc;")
    ("�" "&Otilde;")
    ("�" "&Ouml;")
    ("�" "&Oslash;")
    ("�" "&Ugrave;")
    ("�" "&Uacute;")
    ("�" "&Ucirc;")
    ("�" "&Uuml;")
    ("�" "&Yacute;")
    ("�" "&THORN;")
    ("�" "&szlig;")
    ("�" "&agrave;")
    ("�" "&aacute;")
    ("�" "&acirc;")
    ("�" "&atilde;")
    ("�" "&auml;")
    ("�" "&aring;")
    ("�" "&aelig;")
    ("�" "&ccedil;")
    ("�" "&egrave;")
    ("�" "&eacute;")
    ("�" "&ecirc;")
    ("�" "&euml;")
    ("�" "&igrave;")
    ("�" "&iacute;")
    ("�" "&icirc;")
    ("�" "&iuml;")
    ("�" "&eth;")
    ("�" "&ntilde;")
    ("�" "&ograve;")
    ("�" "&oacute;")
    ("�" "&ocirc;")
    ("�" "&otilde;")
    ("�" "&ouml;")
    ("�" "&oslash;")
    ("�" "&ugrave;")
    ("�" "&uacute;")
    ("�" "&ucirc;")
    ("�" "&uuml;")
    ("�" "&yacute;")
    ("�" "&thorn;")
    ("�" "&yuml;")))

(defvar iso-sgml2iso-trans-tab
  '(("&Agrave;" "�")
    ("&Aacute;" "�")
    ("&Acirc;" "�")
    ("&Atilde;" "�")
    ("&Auml;" "�")
    ("&Aring;" "�")
    ("&AElig;" "�")
    ("&Ccedil;" "�")
    ("&Egrave;" "�")
    ("&Eacute;" "�")
    ("&Ecirc;" "�")
    ("&Euml;" "�")
    ("&Igrave;" "�")
    ("&Iacute;" "�")
    ("&Icirc;" "�")
    ("&Iuml;" "�")
    ("&ETH;" "�")
    ("&Ntilde;" "�")
    ("&Ograve;" "�")
    ("&Oacute;" "�")
    ("&Ocirc;" "�")
    ("&Otilde;" "�")
    ("&Ouml;" "�")
    ("&Oslash;" "�")
    ("&Ugrave;" "�")
    ("&Uacute;" "�")
    ("&Ucirc;" "�")
    ("&Uuml;" "�")
    ("&Yacute;" "�")
    ("&THORN;" "�")
    ("&szlig;" "�")
    ("&agrave;" "�")
    ("&aacute;" "�")
    ("&acirc;" "�")
    ("&atilde;" "�")
    ("&auml;" "�")
    ("&aring;" "�")
    ("&aelig;" "�")
    ("&ccedil;" "�")
    ("&egrave;" "�")
    ("&eacute;" "�")
    ("&ecirc;" "�")
    ("&euml;" "�")
    ("&igrave;" "�")
    ("&iacute;" "�")
    ("&icirc;" "�")
    ("&iuml;" "�")
    ("&eth;" "�")
    ("&ntilde;" "�")
    ("&nbsp;" "�")
    ("&ograve;" "�")
    ("&oacute;" "�")
    ("&ocirc;" "�")
    ("&otilde;" "�")
    ("&ouml;" "�")
    ("&oslash;" "�")
    ("&ugrave;" "�")
    ("&uacute;" "�")
    ("&ucirc;" "�")
    ("&uuml;" "�")
    ("&yacute;" "�")
    ("&thorn;" "�")
    ("&yuml;" "�")))

;;;###autoload
(defun iso-iso2sgml (from to &optional buffer)
 "Translate ISO 8859-1 characters in the region to SGML entities.
Use entities from \"ISO 8879:1986//ENTITIES Added Latin 1//EN\".
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-iso2sgml-trans-tab))

;;;###autoload
(defun iso-sgml2iso (from to &optional buffer)
 "Translate SGML entities in the region to ISO 8859-1 characters.
Use entities from \"ISO 8879:1986//ENTITIES Added Latin 1//EN\".
Optional arg BUFFER is ignored (for use in `format-alist')."
 (interactive "*r")
 (iso-translate-conventions from to iso-sgml2iso-trans-tab))

;;;###autoload
(defun iso-cvt-read-only (&rest ignore)
  "Warn that format is read-only."
  (interactive)
  (error "This format is read-only; specify another format for writing"))

;;;###autoload
(defun iso-cvt-write-only (&rest ignore)
  "Warn that format is write-only."
  (interactive)
  (error "This format is write-only"))

;;;###autoload
(defun iso-cvt-define-menu ()
  "Add submenus to the File menu, to convert to and from various formats."
  (interactive)

  (let ((load-as-menu-map (make-sparse-keymap "Load As..."))
	(insert-as-menu-map (make-sparse-keymap "Insert As..."))
	(write-as-menu-map (make-sparse-keymap "Write As..."))
	(translate-to-menu-map (make-sparse-keymap "Translate to..."))
	(translate-from-menu-map (make-sparse-keymap "Translate from..."))
	(menu menu-bar-file-menu))

    (define-key menu [load-as-separator] '("--"))

    (define-key menu [load-as] '("Load As..." . iso-cvt-load-as))
    (fset 'iso-cvt-load-as load-as-menu-map)

    ;;(define-key menu [insert-as] '("Insert As..." . iso-cvt-insert-as))
    (fset 'iso-cvt-insert-as insert-as-menu-map)

    (define-key menu [write-as] '("Write As..." . iso-cvt-write-as))
    (fset 'iso-cvt-write-as write-as-menu-map)

    (define-key menu [translate-separator] '("--"))

    (define-key menu [translate-to] '("Translate to..." . iso-cvt-translate-to))
    (fset 'iso-cvt-translate-to translate-to-menu-map)

    (define-key menu [translate-from] '("Translate from..." . iso-cvt-translate-from))
    (fset 'iso-cvt-translate-from translate-from-menu-map)

    (dolist (file-type (reverse format-alist))
      (let ((name (car file-type))
	    (str-name (cadr file-type)))
	(if (stringp str-name)
	    (progn
	      (define-key load-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive ,(format "FFind file (as %s): " name))
			 (format-find-file file ',name))))
	      (define-key insert-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive (format "FInsert file (as %s): " ,name))
			 (format-insert-file file ',name))))
	      (define-key write-as-menu-map (vector name)
		(cons str-name
		      `(lambda (file)
			 (interactive (format "FWrite file (as %s): " ,name))
			 (format-write-file file ',name))))
	      (define-key translate-to-menu-map (vector name)
		(cons str-name
		      `(lambda ()
			 (interactive)
			 (format-encode-buffer ',name))))
	      (define-key translate-from-menu-map (vector name)
		(cons str-name
		      `(lambda ()
			 (interactive)
			 (format-decode-buffer ',name))))))))))

(provide 'iso-cvt)

;; arch-tag: 64ae843f-ed0e-43e1-ba50-ffd581b90840
;;; iso-cvt.el ends here
