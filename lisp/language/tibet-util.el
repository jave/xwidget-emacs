;;; tibet-util.el --- Support for inputting Tibetan characters

;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: multilingual, Tibetan

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

;; Author: Toru TOMABECHI, <Toru.Tomabechi@orient.unil.ch>

;; Created: Feb. 17. 1997

;; History:
;; 1997.03.13 Modification in treatment of text properties;
;;            Support for some special signs and punctuations.
;; 1999.10.25 Modification for a new composition way by K.Handa.

;;; Code:

;;;###autoload
(defun setup-tibetan-environment ()
  (interactive)
  (set-language-environment "Tibetan"))

;;;###autoload
(defun tibetan-char-p (ch)
  "Check if char CH is Tibetan character.
Returns non-nil if CH is Tibetan. Otherwise, returns nil."
  (memq (char-charset ch) '(tibetan tibetan-1-column)))

;;; Functions for Tibetan <-> Tibetan-transcription.

;;;###autoload
(defun tibetan-tibetan-to-transcription (str)
  "Transcribe Tibetan string STR and return the corresponding Roman string."
  (let (;; Accumulate transcriptions here in reverse order.
	(trans nil)
	(len (length str))
	(i 0)
	ch this-trans)
    (while (< i len)
      (let ((idx (string-match tibetan-precomposition-rule-alist str i)))
	(if (eq idx i)
	    ;; Ith character and the followings matches precomposable
	    ;; Tibetan sequence.
	    (setq i (match-end 0)
		  this-trans
		  (car (rassoc
			(cdr (assoc (match-string 0 str)
				    tibetan-precomposition-rule-alist))
			tibetan-precomposed-transcription-alist)))
	  (setq ch (substring str i (1+ i))
		i (1+ i)
		this-trans
		(car (or (rassoc ch tibetan-consonant-transcription-alist)
			 (rassoc ch tibetan-vowel-transcription-alist)
			 (rassoc ch tibetan-subjoined-transcription-alist)))))
	(setq trans (cons this-trans trans))))
    (apply 'concat (nreverse trans))))

;;;###autoload
(defun tibetan-transcription-to-tibetan (str)
  "Convert Tibetan Roman string STR to Tibetan character string.
The returned string has no composition information."
  (let (;; Case is significant.
	(case-fold-search nil)
	(idx 0)
	;; Accumulate Tibetan strings here in reverse order.
	(t-str-list nil)
	i subtrans)
    (while (setq i (string-match tibetan-regexp str idx))
      (if (< idx i)
	  ;; STR contains a pattern that doesn't match Tibetan
	  ;; transcription.  Include the pattern as is.
	  (setq t-str-list (cons (substring str idx i) t-str-list)))
      (setq subtrans (match-string 0 str)
	    idx (match-end 0))
      (let ((t-char (cdr (assoc subtrans
				tibetan-precomposed-transcription-alist))))
	(if t-char
	    ;; SUBTRANS corresponds to a transcription for
	    ;; precomposable Tibetan sequence.
	    (setq t-char (car (rassoc t-char
				      tibetan-precomposition-rule-alist)))
	  (setq t-char
		(cdr
		 (or (assoc subtrans tibetan-consonant-transcription-alist)
		     (assoc subtrans tibetan-vowel-transcription-alist)
		     (assoc subtrans tibetan-modifier-transcription-alist)
		     (assoc subtrans tibetan-subjoined-transcription-alist)))))
	(setq t-str-list (cons t-char t-str-list))))
    (if (< idx (length str))
	(setq t-str-list (cons (substring str idx) t-str-list)))
    (apply 'concat (nreverse t-str-list))))

;;;
;;; Functions for composing/decomposing Tibetan sequence.
;;;
;;; A Tibetan syllable is typically structured as follows:
;;;
;;;      [Prefix] C [C+] V [M] [Suffix [Post suffix]]
;;;
;;; where C's are all vertically stacked, V appears below or above
;;; consonant cluster and M is always put above the C[C+]V combination.
;;; (Sanskrit visarga, though it is a vowel modifier, is considered
;;;  to be a punctuation.)
;;;
;;; Here are examples of the words "bsgrubs" and "h'uM"
;;;
;;;            4$(7"70"714%qx!"U0"G###C"U14"70"714"G0"G1(B         4$(7"Hx!#Ax!"Ur'"_0"H"A"U"_1(B
;;;
;;;                             M
;;;             b s b s         h
;;;               g             '
;;;               r             u
;;;               u
;;;
;;; Consonants `'' ($(7"A(B), `w' ($(7">(B), `y' ($(7"B(B), `r' ($(7"C(B) take special
;;; forms when they are used as subjoined consonant.  Consonant `r'
;;; takes another special form when used as superjoined in such a case
;;; as "rka", while it does not change its form when conjoined with
;;; subjoined `'', `w' or `y' as in "rwa", "rya".

;; Append a proper composition rule and glyph to COMPONENTS to compose
;; CHAR with a composition that has COMPONENTS.

(defun tibetan-add-components (components char)
  (let ((last (last components))
	(stack-upper '(tc . bc))
	(stack-under '(bc . tc))
	rule)
    ;; Special treatment for 'a chung.
    ;; If 'a follows a consonant, turn it into the subjoined form.
    (if (and (= char ?$(7"A(B)
	     (aref (char-category-set (car last)) ?0))
	(setq char ?$(7#A(B))

    (cond
     ;; Compose upper vowel sign vertically over.
     ((aref (char-category-set char) ?2)
      (setq rule stack-upper))

     ;; Compose lower vowel sign vertically under.
     ((aref (char-category-set char) ?3)
      (setq rule stack-under))

     ;; Transform ra-mgo (superscribed r) if followed by a subjoined
     ;; consonant other than w, ', y, r.
     ((and (= (car last) ?$(7"C(B)
	   (not (memq char '(?$(7#>(B ?$(7#A(B ?$(7#B(B ?$(7#C(B))))
      (setcar last ?$(7#P(B)
      (setq rule stack-under))

     ;; Transform initial base consonant if followed by a subjoined
     ;; consonant but 'a.
     (t
      (let ((laststr (char-to-string (car last))))
	(if (and (/= char ?$(7#A(B)
		 (string-match "[$(7"!(B-$(7"="?"@"D(B-$(7"J(B]" laststr))
	    (setcar last (string-to-char
			  (cdr (assoc (char-to-string (car last))
				      tibetan-base-to-subjoined-alist)))))
	(setq rule stack-under))))

    (setcdr last (list rule char))))

;;;###autoload
(defun tibetan-compose-string (str)
  "Compose Tibetan string STR."
  (let ((idx 0))
    ;; `$(7"A(B' is included in the pattern for subjoined consonants
    ;; because we treat it specially in tibetan-add-components.
    (while (setq idx (string-match tibetan-composable-pattern str idx))
      (let ((from idx)
	    (to (match-end 0))
	    components)
	(if (eq (string-match tibetan-precomposition-rule-regexp str idx) idx)
	    (setq idx (match-end 0)
		  components
		  (list (string-to-char
			 (cdr
			  (assoc (match-string 0 str)
				 tibetan-precomposition-rule-alist)))))
	  (setq components (list (aref str idx))
		idx (1+ idx)))
	(while (< idx to)
	  (tibetan-add-components components (aref str idx))
	  (setq idx (1+ idx)))
	(compose-string str from to components))))
  str)

;;;###autoload
(defun tibetan-compose-region (beg end)
  "Compose Tibetan text the region BEG and END."
  (interactive "r")
  (let (str result chars)
    (save-excursion
      (save-restriction
	(narrow-to-region beg end)
	(goto-char (point-min))
	;; `$(7"A(B' is included in the pattern for subjoined consonants
	;; because we treat it specially in tibetan-add-components.
	(while (re-search-forward tibetan-composable-pattern nil t)
	  (let ((from (match-beginning 0))
		(to (match-end 0))
		components)
	    (goto-char from)
	    (if (looking-at tibetan-precomposition-rule-regexp)
		(progn
		  (setq components
			(list (string-to-char
			       (cdr
				(assoc (match-string 0)
				       tibetan-precomposition-rule-alist)))))
		  (goto-char (match-end 0)))
	      (setq components (list (char-after from)))
	      (forward-char 1))
	    (while (< (point) to)
	      (tibetan-add-components components (following-char))
	      (forward-char 1))
	    (compose-region from to components)))))))

;;;###autoload
(defalias 'tibetan-decompose-region 'decompose-region)
;;;###autoload
(defalias 'tibetan-decompose-string 'decompose-string)

;;;###autoload
(defun tibetan-composition-function (from to pattern &optional string)
  (if string
      (tibetan-compose-string string)
    (tibetan-compose-region from to))
  (- to from))

;;;
;;; This variable is used to avoid repeated decomposition.
;;;
(setq-default tibetan-decomposed nil)

;;;###autoload
(defun tibetan-decompose-buffer ()
  "Decomposes Tibetan characters in the buffer into their components.
See also the documentation of the function `tibetan-decompose-region'."
  (interactive)
  (make-local-variable 'tibetan-decomposed)
  (cond ((not tibetan-decomposed)
	 (tibetan-decompose-region (point-min) (point-max))
	 (setq tibetan-decomposed t))))

;;;###autoload
(defun tibetan-compose-buffer ()
  "Composes Tibetan character components in the buffer.
See also docstring of the function tibetan-compose-region."
  (interactive)
  (make-local-variable 'tibetan-decomposed)
  (tibetan-compose-region (point-min) (point-max))
  (setq tibetan-decomposed nil))

;;;###autoload
(defun tibetan-post-read-conversion (len)
  (save-excursion
    (save-restriction
      (let ((buffer-modified-p (buffer-modified-p)))
	(narrow-to-region (point) (+ (point) len))
	(tibetan-compose-region (point-min) (point-max))
	(set-buffer-modified-p buffer-modified-p)
	(make-local-variable 'tibetan-decomposed)
	(setq tibetan-decomposed nil)
	(- (point-max) (point-min))))))


;;;###autoload
(defun tibetan-pre-write-conversion (from to)
  (setq tibetan-decomposed-temp tibetan-decomposed)
  (let ((old-buf (current-buffer)))
    (set-buffer (generate-new-buffer " *temp*"))
    (if (stringp from)
	(insert from)
      (insert-buffer-substring old-buf from to))
    (if (not tibetan-decomposed-temp)
	(tibetan-decompose-region (point-min) (point-max)))
    ;; Should return nil as annotations.
    nil))

(provide 'tibet-util)

;;; language/tibet-util.el ends here.
