;;; english.el --- support for English -*- no-byte-compile: t -*-

;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.
;;   Licensed to the Free Software Foundation.
;; Copyright (C) 2003
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H13PRO009

;; Keywords: multibyte character, character set, syntax, category

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; We need nothing special to support English on Emacs.  Selecting
;; English as a language environment is one of the ways to reset
;; various multilingual environment to the original settting.

;;; Code:

(set-language-info-alist
 "English" '((tutorial . "TUTORIAL")
	     (charset ascii)
	     (sample-text . "Hello!, Hi!, How are you?")
	     (documentation . "\
Nothing special is needed to handle English.")
	     ))

;; Mostly because we can now...
(define-coding-system 'ebcdic-us
  "US version of EBCDIC"
  :coding-type 'charset
  :charset-list '(ebcdic-us)
  :mnemonic ?*)

(define-coding-system 'ebcdic-uk
  "UK version of EBCDIC"
  :coding-type 'charset
  :charset-list '(ebcdic-uk)
  :mnemonic ?*)

(define-coding-system 'ibm1047
  "A version of EBCDIC used in OS/390 Unix"  ; says Groff
  :coding-type 'charset
  :charset-list '(ibm1047)
  :mnemonic ?*)
(define-coding-system-alias 'cp1047 'ibm1047)

;; Make "ASCII" an alias of "English" language environment.
(set-language-info-alist
 "ASCII" (cdr (assoc "English" language-info-alist)))

;;; arch-tag: e440bdb0-91b0-4fb4-ae38-425780f8f745
;;; english.el ends here
