;;; korean.el --- Support for Korean

;; Copyright (C) 1995 Free Software Foundation, Inc.
;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.

;; Keywords: multilingual, Korean

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

;; For Korean, the character set KSC5601 is supported.

;;; Code:

(make-coding-system
 'euc-kr 2 ?K
 "Coding-system of Korean EUC (Extended Unix Code)."
 '((ascii t) korean-ksc5601 nil nil
   nil ascii-eol ascii-cntl))

(define-coding-system-alias 'euc-kr 'euc-korea)

(make-coding-system
 'iso-2022-kr 2 ?k
 "MIME ISO-2022-KR"
 '(ascii (nil korean-ksc5601) nil nil
	 nil ascii-eol ascii-cntl seven locking-shift nil nil nil nil nil
	 'designation-bol))

(register-input-method
 "Korean" '("hanterm" encoded-kbd-select-terminal euc-kr))
(register-input-method
 "Korean" '("quail-hangul" quail-use-package "quail/hangul"))
(register-input-method
 "Korean" '("quail-hangul3" quail-use-package "quail/hangul3"))
(register-input-method
 "Korean" '("quail-hanja" quail-use-package "quail/hanja"))
(register-input-method
 "Korean" '("quail-symbol-ksc" quail-use-package "quail/symbol-ksc"))
(register-input-method
 "Korean" '("quail-hanja-jis" quail-use-package "quail/hanja-jis"))

(defun setup-korean-environment ()
  (setq coding-category-iso-8-2 'euc-kr)

  (set-coding-priority
   '(coding-category-iso-7
     coding-category-iso-8-2
     coding-category-iso-8-1))

  (setq-default buffer-file-coding-system 'euc-kr)

  (setq default-input-method '("Korean" . "quail-hangul"))
  )

(set-language-info-alist
 "Korean" '((setup-function . setup-korean-environment)
	    (tutorial . "TUTORIAL.kr")
	    (charset . (korean-ksc5601))
	    (coding-system . (euc-kr iso-2022-kr))
	    (documentation . t)
	    (sample-text . "Hangul ($(CGQ1[(B)	$(C>H3gGO<<?d(B, $(C>H3gGO=J4O1n(B")))

;;; korean.el ends here
