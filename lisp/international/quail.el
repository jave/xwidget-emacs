;;; quail.el --- provides simple input method for multilingual text

;; Copyright (C) 1995, 2000 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.
;; Copyright (C) 2001 Free Software Foundation, Inc.

;; Author: Kenichi HANDA <handa@etl.go.jp>
;;	   Naoto TAKAHASHI <ntakahas@etl.go.jp>
;; Maintainer: Kenichi HANDA <handa@etl.go.jp>
;; Keywords: mule, multilingual, input method

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

;; In Quail minor mode, you can input multilingual text easily.  By
;; defining a translation table (named Quail map) which maps ASCII key
;; string to multilingual character or string, you can input any text
;; from ASCII keyboard.
;;
;; We use words "translation" and "conversion" differently.  The
;; former is done by Quail package itself, the latter is the further
;; process of converting a translated text to some more desirable
;; text.  For instance, Quail package for Japanese (`quail-jp')
;; translates Roman text (transliteration of Japanese in Latin
;; alphabets) to Hiragana text, which is then converted to
;; Kanji-and-Kana mixed text or Katakana text by commands specified in
;; CONVERSION-KEYS argument of the Quail package.

;;; Code:

(require 'help-mode)

(defgroup quail nil
  "Quail: multilingual input method."
  :group 'leim)

;; Buffer local variables

(defvar quail-current-package nil
  "The current Quail package, which depends on the current input method.
See the documentation of `quail-package-alist' for the format.")
(make-variable-buffer-local 'quail-current-package)
(put 'quail-current-package 'permanent-local t)

;; Quail uses the following two buffers to assist users.
;; A buffer to show available key sequence or translation list.
(defvar quail-guidance-buf nil)
;; A buffer to show completion list of the current key sequence.
(defvar quail-completion-buf nil)

;; Each buffer in which Quail is activated should use different
;; guidance buffers.
(make-variable-buffer-local 'quail-guidance-buf)
(put 'quail-guidance-buf 'permanent-local t)

;; A main window showing Quail guidance buffer.
(defvar quail-guidance-win nil)
(make-variable-buffer-local 'quail-guidance-win)

(defvar quail-overlay nil
  "Overlay which covers the current translation region of Quail.")
(make-variable-buffer-local 'quail-overlay)

(defvar quail-conv-overlay nil
  "Overlay which covers the text to be converted in Quail mode.")
(make-variable-buffer-local 'quail-conv-overlay)

(defvar quail-current-key nil
  "Current key for translation in Quail mode.")
(make-variable-buffer-local 'quail-current-key)

(defvar quail-current-str nil
  "Currently selected translation of the current key.")
(make-variable-buffer-local 'quail-current-str)

(defvar quail-current-translations nil
  "Cons of indices and vector of possible translations of the current key.
Indices is a list of (CURRENT START END BLOCK BLOCKS), where
CURRENT is an index of the current translation,
START and END are indices of the start and end of the current block,
BLOCK is the current block index,
BLOCKS is a number of  blocks of translation.")
(make-variable-buffer-local 'quail-current-translations)

(defvar quail-current-data nil
  "Any Lisp object holding information of current translation status.
When a key sequence is mapped to TRANS and TRANS is a cons
of actual translation and some Lisp object to be referred
for translating the longer key sequence, this variable is set
to that Lisp object.")
(make-variable-buffer-local 'quail-current-data)

;; Quail package handlers.

(defvar quail-package-alist nil
  "List of Quail packages.
A Quail package is a list of these elements:
  NAME, TITLE, QUAIL-MAP, GUIDANCE, DOCSTRING, TRANSLATION-KEYS,
  FORGET-LAST-SELECTION, DETERMINISTIC, KBD-TRANSLATE, SHOW-LAYOUT,
  DECODE-MAP, MAXIMUM-SHORTEST, OVERLAY-PLIST, UPDATE-TRANSLATION-FUNCTION,
  CONVERSION-KEYS, SIMPLE.

QUAIL-MAP is a data structure to map key strings to translations.  For
the format, see the documentation of `quail-map-p'.

DECODE-MAP is an alist of translations and corresponding keys.

See the documentation of `quail-define-package' for the other elements.")

;; Return various slots in the current quail-package.

(defsubst quail-name ()
  "Return the name of the current Quail package."
  (nth 0 quail-current-package))
;;;###autoload
(defun quail-title ()
  "Return the title of the current Quail package."
  (let ((title (nth 1 quail-current-package)))
    ;; TITLE may be a string or a list.  If it is a list, each element
    ;; is a string or the form (VAR STR1 STR2), and the interpretation
    ;; of the list is the same as that of mode-line-format.
    (if (stringp title)
	title
      (condition-case nil
	  (mapconcat
	   (lambda (x) 
	     (cond ((stringp x) x)
		   ((and (listp x) (symbolp (car x)) (= (length x) 3))
		    (if (symbol-value (car x))
			(nth 1 x) (nth 2 x)))
		   (t "")))
	   title "")
	(error "")))))
(defsubst quail-map ()
  "Return the translation map of the current Quail package."
  (nth 2 quail-current-package))
(defsubst quail-guidance ()
  "Return an object used for `guidance' feature of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 3 quail-current-package))
(defsubst quail-docstring ()
  "Return the documentation string of the current Quail package."
  (nth 4 quail-current-package))
(defsubst quail-translation-keymap ()
  "Return translation keymap in the current Quail package.
Translation keymap is a keymap used while translation region is active."
  (nth 5 quail-current-package))
(defsubst quail-forget-last-selection ()
  "Return `forget-last-selection' flag of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 6 quail-current-package))
(defsubst quail-deterministic ()
  "Return `deterministic' flag of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 7 quail-current-package))
(defsubst quail-kbd-translate ()
  "Return `kbd-translate' flag of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 8 quail-current-package))
(defsubst quail-show-layout ()
  "Return `show-layout' flag of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 9 quail-current-package))
(defsubst quail-decode-map ()
  "Return decode map of the current Quail package.
It is an alist of translations and corresponding keys."
  (nth 10 quail-current-package))
(defsubst quail-maximum-shortest ()
  "Return `maximum-shortest' flag of the current Quail package.
See also the documentation of `quail-define-package'."
  (nth 11 quail-current-package))
(defsubst quail-overlay-plist ()
  "Return property list of an overly used in the current Quail package."
  (nth 12 quail-current-package))
(defsubst quail-update-translation-function ()
  "Return a function for updating translation in the current Quail package."
  (nth 13 quail-current-package))
(defsubst quail-conversion-keymap ()
  "Return conversion keymap in the current Quail package.
Conversion keymap is a keymap used while conversion region is active
 but translation region is not active."
  (nth 14 quail-current-package))
(defsubst quail-simple ()
  "Return t if the current Quail package is simple."
  (nth 15 quail-current-package))

(defsubst quail-package (name)
  "Return Quail package named NAME."
  (assoc name quail-package-alist))

(defun quail-add-package (package)
  "Add Quail package PACKAGE to `quail-package-alist'."
  (let ((pac (quail-package (car package))))
    (if pac
	(setcdr pac (cdr package))
      (setq quail-package-alist (cons package quail-package-alist)))))

(defun quail-select-package (name)
  "Select Quail package named NAME as the current Quail package."
  (let ((package (quail-package name)))
    (if (null package)
	(error "No Quail package `%s'" name))
    (setq quail-current-package package)
    (setq-default quail-current-package package)
    name))

;;;###autoload
(defun quail-use-package (package-name &rest libraries)
  "Start using Quail package PACKAGE-NAME.
The remaining arguments are libraries to be loaded before using the package.

This activates input method defined by PACKAGE-NAME by running
`quail-activate', which see."
  (let ((package (quail-package package-name)))
    (if (null package)
	;; Perhaps we have not yet loaded necessary libraries.
	(while libraries
	  (if (not (load (car libraries) t))
	      (progn
		(with-output-to-temp-buffer "*Help*"
		  (princ "Quail package \"")
		  (princ package-name)
		  (princ "\" can't be activated\n  because library \"")
		  (princ (car libraries))
		  (princ "\" is not in `load-path'.

The most common case is that you have not yet installed appropriate
libraries in LEIM (Libraries of Emacs Input Method) which is
distributed separately from Emacs.

LEIM is available from the same ftp directory as Emacs."))
		(error "Can't use the Quail package `%s'" package-name))
	    (setq libraries (cdr libraries))))))
  (quail-select-package package-name)
  (setq current-input-method-title (quail-title))
  (quail-activate)
  ;; Hide all '... loaded' message.
  (message nil))

(defvar quail-translation-keymap
  (let ((map (make-keymap))
	(i 0))
    (while (< i ?\ )
      (define-key map (char-to-string i) 'quail-other-command)
      (setq i (1+ i)))
    (while (< i 127)
      (define-key map (char-to-string i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (define-key map "\177" 'quail-delete-last-char)
    (define-key map "\C-f" 'quail-next-translation)
    (define-key map "\C-b" 'quail-prev-translation)
    (define-key map "\C-n" 'quail-next-translation-block)
    (define-key map "\C-p" 'quail-prev-translation-block)
    (define-key map [right] 'quail-next-translation)
    (define-key map [left] 'quail-prev-translation)
    (define-key map [down] 'quail-next-translation-block)
    (define-key map [up] 'quail-prev-translation-block)
    (define-key map "\C-i" 'quail-completion)
    (define-key map "\C-@" 'quail-select-current)
    ;; Following simple.el, Enter key on numeric keypad selects the
    ;; current translation just like `C-SPC', and `mouse-2' chooses
    ;; any completion visible in the *Quail Completions* buffer.
    (define-key map [kp-enter] 'quail-select-current)
    (define-key map [mouse-2] 'quail-mouse-choose-completion)
    (define-key map [down-mouse-2] nil)
    (define-key map "\C-h" 'quail-translation-help)
    (define-key map [?\C- ] 'quail-select-current)
    (define-key map [tab] 'quail-completion)
    (define-key map [delete] 'quail-delete-last-char)
    (define-key map [backspace] 'quail-delete-last-char)
    map)
  "Keymap used processing translation in complex Quail modes.
Only a few especially complex input methods use this map;
most use `quail-simple-translation-keymap' instead.
This map is activated while translation region is active.")

(defvar quail-translation-docstring
  "When you type keys, the echo area shows the possible characters
which correspond to that key sequence, each preceded by a digit.  You
can select one of the characters shown by typing the corresponding
digit.  Alternatively, you can use C-f and C-b to move through the
line to select the character you want, then type a letter to begin
entering another Chinese character or type a space or punctuation
character.

If there are more than ten possible characters for the given spelling,
the echo area shows ten characters at a time; you can use C-n to move
to the next group of ten, and C-p to move back to the previous group
of ten.")

;; Categorize each Quail commands to make the output of quail-help
;; concise.  This is done by putting `quail-help' property.  The value
;; is:
;;	hide -- never show this command
;;	non-deterministic -- show only for non-deterministic input method
(let ((l '((quail-other-command . hide)
	   (quail-self-insert-command . hide)
	   (quail-delete-last-char . hide)
	   (quail-next-translation . non-deterministic)
	   (quail-prev-translation . non-deterministic)
	   (quail-next-translation-block . non-deterministic)
	   (quail-prev-translation-block . non-deterministic))))
  (while l
    (put (car (car l)) 'quail-help (cdr (car l)))
    (setq l (cdr l))))

(defvar quail-simple-translation-keymap
  (let ((map (make-keymap))
	(i 0))
    (while (< i ?\ )
      (define-key map (char-to-string i) 'quail-other-command)
      (setq i (1+ i)))
    (while (< i 127)
      (define-key map (char-to-string i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (define-key map "\177" 'quail-delete-last-char)
    (define-key map [delete] 'quail-delete-last-char)
    (define-key map [backspace] 'quail-delete-last-char)
    ;;(let ((meta-map (make-sparse-keymap)))
    ;;(define-key map (char-to-string meta-prefix-char) meta-map)
    ;;(define-key map [escape] meta-map))
    map)
  "Keymap used while processing translation in simple Quail modes.
A few especially complex input methods use `quail-translation-keymap' instead.
This map is activated while translation region is active.")

(defvar quail-conversion-keymap
  (let ((map (make-keymap))
	(i ?\ ))
    (while (< i 127)
      (define-key map (char-to-string i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) 'quail-self-insert-command)
      (setq i (1+ i)))
    (define-key map "\C-b" 'quail-conversion-backward-char)
    (define-key map "\C-f" 'quail-conversion-forward-char)
    (define-key map "\C-a" 'quail-conversion-beginning-of-region)
    (define-key map "\C-e" 'quail-conversion-end-of-region)
    (define-key map "\C-d" 'quail-conversion-delete-char)
    (define-key map "\C-k" 'quail-conversion-delete-tail)
    (define-key map "\C-h" 'quail-translation-help)
    (define-key map "\177" 'quail-conversion-backward-delete-char)
    (define-key map [delete] 'quail-conversion-backward-delete-char)
    (define-key map [backspace] 'quail-conversion-backward-delete-char)
    map)
  "Keymap used for processing conversion in Quail mode.
This map is activated while conversion region is active but translation
region is not active.")

;; Just a dummy definition.
(defun quail-other-command ()
  (interactive)
  )

;;;###autoload
(defun quail-define-package (name language title
				  &optional guidance docstring translation-keys
				  forget-last-selection deterministic
				  kbd-translate show-layout create-decode-map
				  maximum-shortest overlay-plist
				  update-translation-function
				  conversion-keys simple)
  "Define NAME as a new Quail package for input LANGUAGE.
TITLE is a string to be displayed at mode-line to indicate this package.
Optional arguments are GUIDANCE, DOCSTRING, TRANSLATION-KEYS,
 FORGET-LAST-SELECTION, DETERMINISTIC, KBD-TRANSLATE, SHOW-LAYOUT,
 CREATE-DECODE-MAP, MAXIMUM-SHORTEST, OVERLAY-PLIST,
 UPDATE-TRANSLATION-FUNCTION, CONVERSION-KEYS and SIMPLE.

GUIDANCE specifies how a guidance string is shown in echo area.
If it is t, list of all possible translations for the current key is shown
 with the currently selected translation being highlighted.
If it is an alist, the element has the form (CHAR . STRING).  Each character
 in the current key is searched in the list and the corresponding string is
 shown.
If it is nil, the current key is shown.

DOCSTRING is the documentation string of this package.  The command
`describe-input-method' shows this string while replacing the form
\\=\\<VAR> in the string by the value of VAR.  That value should be a
string.  For instance, the form \\=\\<quail-translation-docstring> is
replaced by a description about how to select a translation from a
list of candidates.

TRANSLATION-KEYS specifies additional key bindings used while translation
region is active.  It is an alist of single key character vs. corresponding
command to be called.

FORGET-LAST-SELECTION non-nil means a selected translation is not kept
for the future to translate the same key.  If this flag is nil, a
translation selected for a key is remembered so that it can be the
first candidate when the same key is entered later.

DETERMINISTIC non-nil means the first candidate of translation is
selected automatically without allowing users to select another
translation for a key.  In this case, unselected translations are of
no use for an interactive use of Quail but can be used by some other
programs.  If this flag is non-nil, FORGET-LAST-SELECTION is also set
to t.

KBD-TRANSLATE non-nil means input characters are translated from a
user's keyboard layout to the standard keyboard layout.  See the
documentation of `quail-keyboard-layout' and
`quail-keyboard-layout-standard' for more detail.

SHOW-LAYOUT non-nil means the `quail-help' command should show
the user's keyboard layout visually with translated characters.
If KBD-TRANSLATE is set, it is desirable to set also this flag unless
this package defines no translations for single character keys.

CREATE-DECODE-MAP non-nil means decode map is also created.  A decode
map is an alist of translations and corresponding original keys.
Although this map is not used by Quail itself, it can be used by some
other programs.  For instance, Vietnamese supporting needs this map to
convert Vietnamese text to VIQR format which uses only ASCII
characters to represent Vietnamese characters.

MAXIMUM-SHORTEST non-nil means break key sequence to get maximum
length of the shortest sequence.  When we don't have a translation of
key \"..ABCD\" but have translations of \"..AB\" and \"CD..\", break
the key at \"..AB\" and start translation of \"CD..\".  Hangul
packages, for instance, use this facility.  If this flag is nil, we
break the key just at \"..ABC\" and start translation of \"D..\".

OVERLAY-PLIST if non-nil is a property list put on an overlay which
covers Quail translation region.

UPDATE-TRANSLATION-FUNCTION if non-nil is a function to call to update
the current translation region according to a new translation data.  By
default, a translated text or a user's key sequence (if no translation
for it) is inserted.

CONVERSION-KEYS specifies additional key bindings used while
conversion region is active.  It is an alist of single key character
vs. corresponding command to be called.

If SIMPLE is non-nil, then we do not alter the meanings of
commands such as C-f, C-b, C-n, C-p and TAB; they are treated as
non-Quail commands."
  (let (translation-keymap conversion-keymap)
    (if deterministic (setq forget-last-selection t))
    (if translation-keys
	(progn
	  (setq translation-keymap (copy-keymap
				    (if simple quail-simple-translation-keymap
				      quail-translation-keymap)))
	  (while translation-keys
	    (define-key translation-keymap
	      (car (car translation-keys)) (cdr (car translation-keys)))
	    (setq translation-keys (cdr translation-keys))))
      (setq translation-keymap
	    (if simple quail-simple-translation-keymap
	      quail-translation-keymap)))
    (when conversion-keys
      (setq conversion-keymap (copy-keymap quail-conversion-keymap))
      (while conversion-keys
	(define-key conversion-keymap
	  (car (car conversion-keys)) (cdr (car conversion-keys)))
	(setq conversion-keys (cdr conversion-keys))))
    (quail-add-package
     (list name title (list nil) guidance (or docstring "")
	   translation-keymap
	   forget-last-selection deterministic kbd-translate show-layout
	   (if create-decode-map (list 'decode-map) nil)
	   maximum-shortest overlay-plist update-translation-function
	   conversion-keymap simple))

    ;; Update input-method-alist.
    (let ((slot (assoc name input-method-alist))
	  (val (list language 'quail-use-package title docstring)))
      (if slot (setcdr slot val)
	(setq input-method-alist (cons (cons name val) input-method-alist)))))

  (quail-select-package name))

;; Quail minor mode handlers.

;; Setup overlays used in Quail mode.
(defun quail-setup-overlays (conversion-mode)
  (let ((pos (point)))
    (if (overlayp quail-overlay)
	(move-overlay quail-overlay pos pos)
      (setq quail-overlay (make-overlay pos pos nil nil t))
      (if input-method-highlight-flag
	  (overlay-put quail-overlay 'face 'underline))
      (let ((l (quail-overlay-plist)))
	(while l
	  (overlay-put quail-overlay (car l) (car (cdr l)))
	  (setq l (cdr (cdr l))))))
    (if conversion-mode
	(if (overlayp quail-conv-overlay)
	    (if (not (overlay-start quail-conv-overlay))
		(move-overlay quail-conv-overlay pos pos))
	  (setq quail-conv-overlay (make-overlay pos pos nil nil t))
	  (if input-method-highlight-flag
	      (overlay-put quail-conv-overlay 'face 'underline))))))

;; Delete overlays used in Quail mode.
(defun quail-delete-overlays ()
  (if (and (overlayp quail-overlay) (overlay-start quail-overlay))
      (delete-overlay quail-overlay))
  (if (and (overlayp quail-conv-overlay) (overlay-start quail-conv-overlay))
      (delete-overlay quail-conv-overlay)))

;; Kill Quail guidance buffer.  Set in kill-buffer-hook.
(defun quail-kill-guidance-buf ()
  (if (buffer-live-p quail-guidance-buf)
      (kill-buffer quail-guidance-buf)))

(defun quail-inactivate ()
  "Inactivate Quail input method.

This function runs the normal hook `quail-inactivate-hook'."
  (interactive)
  (quail-activate -1))

(defun quail-activate (&optional arg)
  "Activate Quail input method.
With arg, activate Quail input method if and only if arg is positive.

This function runs `quail-activate-hook' if it activates the input
method, `quail-inactivate-hook' if it deactivates it.

While this input method is active, the variable
`input-method-function' is bound to the function `quail-input-method'."
  (if (and arg
	  (< (prefix-numeric-value arg) 0))
      ;; Let's inactivate Quail input method.
      (unwind-protect
	  (progn
	    (quail-hide-guidance-buf)
	    (quail-delete-overlays)
	    (setq describe-current-input-method-function nil)
	    (run-hooks 'quail-inactivate-hook))
	(kill-local-variable 'input-method-function))
    ;; Let's activate Quail input method.
    (if (null quail-current-package)
	;; Quail package is not yet selected.  Select one now.
	(let (name)
	  (if quail-package-alist
	      (setq name (car (car quail-package-alist)))
	    (error "No Quail package loaded"))
	  (quail-select-package name)))
    (setq inactivate-current-input-method-function 'quail-inactivate)
    (setq describe-current-input-method-function 'quail-help)
    (quail-delete-overlays)
    (quail-show-guidance-buf)
    ;; If we are in minibuffer, turn off the current input method
    ;; before exiting.
    (if (eq (selected-window) (minibuffer-window))
	(add-hook 'minibuffer-exit-hook 'quail-exit-from-minibuffer))
    (add-hook 'kill-buffer-hook 'quail-kill-guidance-buf nil t)
    (run-hooks 'quail-activate-hook)
    (make-local-variable 'input-method-function)
    (setq input-method-function 'quail-input-method)))

(defun quail-exit-from-minibuffer ()
  (inactivate-input-method)
  (if (<= (minibuffer-depth) 1)
      (remove-hook 'minibuffer-exit-hook 'quail-exit-from-minibuffer)))

;; Keyboard layout translation handlers.

;; Some Quail packages provide localized keyboard simulation which
;; requires a particular keyboard layout.  In this case, what we need
;; is locations of keys the user entered, not character codes
;; generated by those keys.  However, for the moment, there's no
;; common way to get such information.  So, we ask a user to give
;; information of his own keyboard layout, then translate it to the
;; standard layout which we defined so that all Quail packages depend
;; just on it.

(defconst quail-keyboard-layout-standard
  "\
                              \
  1!2@3#4$5%6^7&8*9(0)-_=+`~  \
  qQwWeErRtTyYuUiIoOpP[{]}    \
  aAsSdDfFgGhHjJkKlL;:'\"\\|    \
  zZxXcCvVbBnNmM,<.>/?        \
                              "
  "Standard keyboard layout of printable characters Quail assumes.
See the documentation of `quail-keyboard-layout' for this format.
This layout is almost the same as that of VT100,
 but the location of key \\ (backslash) is just right of key ' (single-quote),
 not right of RETURN key.")

(defvar quail-keyboard-layout quail-keyboard-layout-standard
  "A string which represents physical key layout of a particular keyboard.
We assume there are six rows and each row has 15 keys (columns),
	the first row is above the `1' - `0' row,
	the first column of the second row is left of key `1',
	the first column of the third row is left of key `q',
	the first column of the fourth row is left of key `a',
	the first column of the fifth row is left of key `z',
	the sixth row is below the `z' - `/' row.
Nth (N is even) and (N+1)th characters in the string are non-shifted
and shifted characters respectively at the same location.
The location of Nth character is row (N / 30) and column ((N mod 30) / 2).
The command `quail-set-keyboard-layout' usually sets this variable.")

(defconst quail-keyboard-layout-len 180)

;; Here we provide several examples of famous keyboard layouts.

(defvar quail-keyboard-layout-alist
  (list
   (cons "standard" quail-keyboard-layout-standard)
   '("sun-type3" . "\
                              \
  1!2@3#4$5%6^7&8*9(0)-_=+\\|`~\
  qQwWeErRtTyYuUiIoOpP[{]}    \
  aAsSdDfFgGhHjJkKlL;:'\"      \
  zZxXcCvVbBnNmM,<.>/?        \
                              ")
   '("atari-german" . "\
                              \
  1!2\"3\2474$5%6&7/8(9)0=\337?'`#^  \
  qQwWeErRtTzZuUiIoOpP\374\334+*    \
  aAsSdDfFgGhHjJkKlL\366\326\344\304~|    \
<>yYxXcCvVbBnNmM,;.:-_        \
                              ")

   '("pc102-de" . "\
                              \
^\2601!2\"3\2474$5%6&7/8(9)0=\337?\264`#'  \
  qQwWeErRtTzZuUiIoOpP\374\334+*    \
  aAsSdDfFgGhHjJkKlL\366\326\344\304      \
<>yYxXcCvVbBnNmM,;.:-_        \
                              ")

   '("jp106" . "\
                              \
  1!2\"3#4$5%6&7'8(9)0~-=^~\\|  \
  qQwWeErRtTyYuUiIoOpP@`[{    \
  aAsSdDfFgGhHjJkKlL;+:*]}    \
  zZxXcCvVbBnNmM,<.>/?\\_      \
                              ")
   )
  "Alist of keyboard names and corresponding layout strings.
See the documentation of `quail-keyboard-layout' for the format of
the layout string.")

;; A non-standard keyboard layout may miss some key locations of the
;; standard layout while having additional key locations not in the
;; standard layout.  This alist maps those additional key locations to
;; the missing locations.  The value is updated automatically by
;; quail-set-keyboard-layout.
(defvar quail-keyboard-layout-substitution nil)

(defun quail-update-keyboard-layout (kbd-type)
  (let ((layout (assoc kbd-type quail-keyboard-layout-alist)))
    (if (null layout)
	;; Here, we had better ask a user to define his own keyboard
	;; layout interactively.
	(error "Unknown keyboard type `%s'" kbd-type))
    (setq quail-keyboard-layout (cdr layout))
    (let ((i quail-keyboard-layout-len)
	  subst-list missing-list)
      ;; Sum up additional key locations not in the standard layout in
      ;; subst-list, and missing key locations in missing-list.
      (while (> i 0)
	(setq i (1- i))
	(if (= (aref quail-keyboard-layout i) ? )
	    (if (/= (aref quail-keyboard-layout-standard i) ? )
		(setq missing-list (cons i missing-list)))
	  (if (= (aref quail-keyboard-layout-standard i) ? )
	      (setq subst-list (cons (cons i nil) subst-list)))))
      (setq quail-keyboard-layout-substitution subst-list)
      ;; If there are additional key locations, map them to missing
      ;; key locations.
      (while missing-list
	(while (and subst-list (cdr (car subst-list)))
	  (setq subst-list (cdr subst-list)))
	(if subst-list
	    (setcdr (car subst-list) (car missing-list)))
	(setq missing-list (cdr missing-list))))))

(defcustom quail-keyboard-layout-type "standard"
  "Type of keyboard layout used in Quail base input method.
Available types are listed in the variable `quail-keyboard-layout-alist'."
  :group 'quail
  :type 'string
  :set #'(lambda (symbol value)
	   (quail-update-keyboard-layout value)
	   (set symbol value)))

;;;###autoload
(defun quail-set-keyboard-layout (kbd-type)
  "Set the current keyboard layout to the same as keyboard KBD-TYPE.

Since some Quail packages depends on a physical layout of keys (not
characters generated by them), those are created by assuming the
standard layout defined in `quail-keyboard-layout-standard'.  This
function tells Quail system the layout of your keyboard so that what
you type is correctly handled."
  (interactive
   (let* ((completion-ignore-case t)
	  (type (completing-read "Keyboard type: "
				 quail-keyboard-layout-alist)))
     (list type)))
  (quail-update-keyboard-layout kbd-type)
  (setq quail-keyboard-layout-type kbd-type))

(defun quail-keyboard-translate (char)
  "Translate CHAR to the one in the standard keyboard layout."
  (if (eq quail-keyboard-layout quail-keyboard-layout-standard)
      ;; All Quail packages are designed based on
      ;; `quail-keyboard-layout-standard'.
      char
    (let ((i 0))
      ;; Find the key location on the current keyboard layout.
      (while (and (< i quail-keyboard-layout-len)
		  (/= char (aref quail-keyboard-layout i)))
	(setq i (1+ i)))
      (if (= i quail-keyboard-layout-len)
	  ;; CHAR is not in quail-keyboard-layout, which means that a
	  ;; user typed a key which generated a character code to be
	  ;; handled out of Quail.  Just return CHAR and make
	  ;; quail-execute-non-quail-command handle it correctly.
	  char
	(let ((ch (aref quail-keyboard-layout-standard i)))
	  (if (= ch ?\ )
	      ;; This location not available in the standard keyboard
	      ;; layout.  Check if the location is used to substitute
	      ;; for the other location of the standard layout.
	      (if (setq i (cdr (assq i quail-keyboard-layout-substitution)))
		  (aref quail-keyboard-layout-standard i)
		;; Just return CHAR as well as above.
		char)
	    ch))))))

(defun quail-keyseq-translate (keyseq)
  (apply 'string
	 (mapcar (function (lambda (x) (quail-keyboard-translate x)))
		 keyseq)))

(defun quail-insert-kbd-layout (kbd-layout)
"Insert the visual keyboard layout table according to KBD-LAYOUT.
The format of KBD-LAYOUT is the same as `quail-keyboard-layout'."
  (let (done-list layout i ch)
    ;; At first, convert KBD-LAYOUT to the same size vector that
    ;; contains translated character or string.
    (setq layout (string-to-vector kbd-layout)
	  i 0)
    (while (< i quail-keyboard-layout-len)
      (setq ch (aref kbd-layout i))
      (if (quail-kbd-translate)
	  (setq ch (quail-keyboard-translate ch)))
      (let* ((map (cdr (assq ch (cdr (quail-map)))))
	     (translation (and map (quail-get-translation
				    (car map) (char-to-string ch) 1))))
	(if translation
	    (progn
	      (if (consp translation)
		  (setq translation (aref (cdr translation) 0)))
	      (setq done-list (cons translation done-list)))
	  (setq translation ch))
	(aset layout i translation))
      (setq i (1+ i)))

    (let ((pos (point))
	  (bar "|")
	  lower upper row)
      ;; Make table without horizontal lines.  Each column for a key
      ;; has the form "| LU |" where L is for lower key and and U is
      ;; for a upper key.  If width of L (U) is greater than 1,
      ;; preceding (following) space is not inserted.
      (put-text-property 0 1 'face 'bold bar)
      (setq i 0)
      (while (< i quail-keyboard-layout-len)
	(when (= (% i 30) 0)
	  (setq row (/ i 30))
	  (if (> row 1)
	      (insert-char 32 (+ row (/ (- row 2) 2)))))
	(setq lower (aref layout i)
	      upper (aref layout (1+ i)))
	(if (and (integerp lower) (>= lower 128) (< lower 256))
	    (setq lower (unibyte-char-to-multibyte lower)))
	(if (and (integerp upper) (>= upper 128) (< upper 256))
	    (setq upper (unibyte-char-to-multibyte upper)))
	(insert bar)
	(if (= (if (stringp lower) (string-width lower) (char-width lower)) 1)
	    (insert " "))
	(insert lower upper)
	(if (= (if (stringp upper) (string-width upper) (char-width upper)) 1)
	    (insert " "))
	(setq i (+ i 2))
	(if (= (% i 30) 0)
	    (insert bar "\n")))
      ;; Insert horizontal lines while deleting blank key columns at the
      ;; beginning and end of each line.
      (save-restriction
	(narrow-to-region pos (point))
	(goto-char pos)
	;;(while (looking-at "[| ]*$")
	;;(forward-line 1)
	;;(delete-region pos (point)))
	(let ((from1 100) (to1 0) from2 to2)
	  (while (not (eobp))
	    (if (looking-at "[| ]*$")
		;; The entire row is blank.
		(delete-region (point) (match-end 0))
	      ;; Delete blank key columns at the head.
	      (if (looking-at " *\\(|    \\)+")
		  (subst-char-in-region (point) (match-end 0) ?| ? ))
	      ;; Delete blank key columns at the tail.
	      (if (re-search-forward "\\(    |\\)+$" (line-end-position) t)
		  (delete-region (match-beginning 0) (point)))
	      (beginning-of-line))
	    ;; Calculate the start and end columns of a horizontal line.
	    (if (eolp)
		(setq from2 from1 to2 to1)
	      (skip-chars-forward " ")
	      (setq from2 (current-column))
	      (end-of-line)
	      (setq to2 (current-column))
	      (if (< from2 from1)
		  (setq from1 from2))
	      (if (> to2 to1)
		  (setq to1 to2))
	      (beginning-of-line))
	    ;; If the previous or the current line has at least one key
	    ;; column, insert a horizontal line.
	    (when (> to1 0)
	      (insert-char 32 from1)
	      (setq pos (point))
	      (insert "+")
	      (insert-char ?- (- (- to1 from1) 2))
	      (insert "+")
	      (put-text-property pos (point) 'face 'bold)
	      (insert "\n"))
	    (setq from1 from2 to1 to2)
	    (forward-line 1)))
	;; Insert "space bar" box.
	(forward-line -1)
	(setq pos (point))
	(insert
"		    +-----------------------------+
		    |          space bar          |
		    +-----------------------------+
")
	(put-text-property pos (point) 'face 'bold)
	(insert ?\n)))

    done-list))

;;;###autoload
(defun quail-show-keyboard-layout (&optional keyboard-type)
  "Show the physical layout of the keyboard type KEYBOARD-TYPE.

The variable `quail-keyboard-layout-type' holds the currently selected
keyboard type."
  (interactive
   (list (completing-read "Keyboard type (default, current choise): "
			  quail-keyboard-layout-alist
			  nil t)))
  (or (and keyboard-type (> (length keyboard-type) 0))
      (setq keyboard-type quail-keyboard-layout-type))
  (let ((layout (assoc keyboard-type quail-keyboard-layout-alist)))
    (or layout
	(error "Unknown keyboard type: %s" keyboard-type))
    (with-output-to-temp-buffer "*Help*"
      (with-current-buffer standard-output
	(insert "Keyboard layout (keyboard type: "
		keyboard-type
		")\n")
	(quail-insert-kbd-layout (cdr layout))))))

;; Quail map

(defsubst quail-map-p (object)
  "Return t if OBJECT is a Quail map.

A Quail map holds information how a particular key should be translated.
Its format is (TRANSLATION . ALIST).
TRANSLATION is either a character, or a cons (INDEX . VECTOR).
In the latter case, each element of VECTOR is a candidate for the translation,
and INDEX points the currently selected translation.

ALIST is normally a list of elements that look like (CHAR . DEFN),
where DEFN is another Quail map for a longer key (CHAR added to the
current key).  It may also be a symbol of a function which returns an
alist of the above format.

Just after a Quail package is read, TRANSLATION may be a string or a
vector.  Then each element of the string or vector is a candidate for
the translation.  These objects are transformed to cons cells in the
format \(INDEX . VECTOR), as described above."
  (and (consp object)
       (let ((translation (car object)))
	 (or (integerp translation) (null translation)
	     (vectorp translation) (stringp translation)
	     (symbolp translation)
	     (and (consp translation) (not (vectorp (cdr translation))))))
       (let ((alist (cdr object)))
	 (or (and (listp alist) (consp (car alist)))
	     (symbolp alist)))))

;;;###autoload
(defmacro quail-define-rules (&rest rules)
  "Define translation rules of the current Quail package.
Each argument is a list of KEY and TRANSLATION.
KEY is a string meaning a sequence of keystrokes to be translated.
TRANSLATION is a character, a string, a vector, a Quail map, or a function.
If it is a character, it is the sole translation of KEY.
If it is a string, each character is a candidate for the translation.
If it is a vector, each element (string or character) is a candidate
  for the translation.
In these cases, a key specific Quail map is generated and assigned to KEY.

If TRANSLATION is a Quail map or a function symbol which returns a Quail map,
 it is used to handle KEY.

The first argument may be an alist of annotations for the following
rules.  Each element has the form (ANNOTATION . VALUE), where
ANNOTATION is a symbol indicating the annotation type.  Currently
the following annotation types are supported.

  append -- the value non-nil means that the following rules should
	be appended to the rules of the current Quail package.

  face -- the value is a face to use for displaying TRANSLATIONs in
	candidate list.

  advice -- the value is a function to call after one of RULES is
	selected.  The function is called with one argument, the
	selected TRANSLATION string, after the TRANSLATION is
	inserted.

  no-decode-map --- the value non-nil means that decoding map is not
	generated for the following translations."
  (let ((l rules)
	append no-decode-map props)
    ;; If the first argument is an alist of annotations, handle them.
    (if (consp (car (car l)))
	(let ((annotations (car l)))
	  (setq append (assq 'append annotations))
	  (if append
	      (setq annotations (delete append annotations)
		    append (cdr append)))
	  (setq no-decode-map (assq 'no-decode-map annotations))
	  (if no-decode-map
	      (setq annotations (delete no-decode-map annotations)
		    no-decode-map (cdr no-decode-map)))
	  ;; Convert the remaining annoations to property list PROPS.
	  (while annotations
	    (setq props
		  (cons (car (car annotations))
			(cons (cdr (car annotations))
			      props))
		  annotations (cdr annotations)))
	  (setq l (cdr l))))
    ;; Process the remaining arguments one by one.
    (if append
	;; There's no way to add new rules at compiling time.
	`(let ((tail ',l)
	       (map (quail-map))
	       (decode-map (and (quail-decode-map) (not ,no-decode-map)))
	       (properties ',props)
	       key trans)
	   (while tail
	     (setq key (car (car tail)) trans (car (cdr (car tail)))
		   tail (cdr tail))
	     (quail-defrule-internal key trans map t decode-map properties)))
      ;; We can build up quail map and decode map at compiling time.
      (let ((map (list nil))
	    (decode-map (if (not no-decode-map) (list 'decode-map)))
	    key trans)
	(while l
	  (setq key (car (car l)) trans (car (cdr (car l))) l (cdr l))
	  (quail-defrule-internal key trans map t decode-map props))
	`(if (not (quail-decode-map))
	     (quail-install-map ',map)
	   (quail-install-map ',map)
	   (quail-install-decode-map ',decode-map))))))

;;;###autoload
(defun quail-install-map (map &optional name)
  "Install the Quail map MAP in the current Quail package.

Optional 2nd arg NAME, if non-nil, is a name of Quail package for
which to install MAP.

The installed map can be referred by the function `quail-map'."
  (if (null quail-current-package)
      (error "No current Quail package"))
  (if (null (quail-map-p map))
      (error "Invalid Quail map `%s'" map))
  (setcar (cdr (cdr quail-current-package)) map))

;;;###autoload
(defun quail-install-decode-map (decode-map &optional name)
  "Install the Quail decode map DECODE-MAP in the current Quail package.

Optional 2nd arg NAME, if non-nil, is a name of Quail package for
which to install MAP.

The installed decode map can be referred by the function `quail-decode-map'."
  (if (null quail-current-package)
      (error "No current Quail package"))
  (if (not (and (consp decode-map) (eq (car decode-map) 'decode-map)))
      (error "Invalid Quail decode map `%s'" decode-map))
  (setcar (nthcdr 10 quail-current-package) decode-map))

;;;###autoload
(defun quail-defrule (key translation &optional name append)
  "Add one translation rule, KEY to TRANSLATION, in the current Quail package.
KEY is a string meaning a sequence of keystrokes to be translated.
TRANSLATION is a character, a string, a vector, a Quail map,
 a function, or a cons.
It it is a character, it is the sole translation of KEY.
If it is a string, each character is a candidate for the translation.
If it is a vector, each element (string or character) is a candidate
 for the translation.
If it is a cons, the car is one of the above and the cdr is a function
 to call when translating KEY (the return value is assigned to the
 variable `quail-current-data').  If the cdr part is not a function,
 the value itself is assigned to `quail-current-data'.
In these cases, a key specific Quail map is generated and assigned to KEY.

If TRANSLATION is a Quail map or a function symbol which returns a Quail map,
 it is used to handle KEY.

Optional 3rd argument NAME, if specified, says which Quail package
to define this translation rule in.  The default is to define it in the
current Quail package.

Optional 4th argument APPEND, if non-nil, appends TRANSLATION
to the current translations for KEY instead of replacing them."
  (if name
      (let ((package (quail-package name)))
	(if (null package)
	    (error "No Quail package `%s'" name))
	(setq quail-current-package package)))
  (quail-defrule-internal key translation (quail-map) append))

;;;###autoload
(defun quail-defrule-internal (key trans map &optional append decode-map props)
  "Define KEY as TRANS in a Quail map MAP.

If Optional 4th arg APPEND is non-nil, TRANS is appended to the
current translations for KEY instead of replacing them.

Optional 5th arg DECODE-MAP is a Quail decode map.

Optional 6th arg PROPS is a property list annotating TRANS.  See the
function `quail-define-rules' for the detail."
  (if (null (stringp key))
      "Invalid Quail key `%s'" key)
  (if (not (or (numberp trans) (stringp trans) (vectorp trans)
	       (consp trans)
	       (symbolp trans)
	       (quail-map-p trans)))
      (error "Invalid Quail translation `%s'" trans))
  (if (null (quail-map-p map))
      (error "Invalid Quail map `%s'" map))
  (let ((len (length key))
	(idx 0)
	ch entry)
    ;; Make a map for registering TRANS if necessary.
    (while (< idx len)
      (if (null (consp map))
	  ;; We come here, for example, when we try to define a rule
	  ;; for "ABC" but a rule for "AB" is already defined as a
	  ;; symbol.
	  (error "Quail key %s is too long" key))
      (setq ch (aref key idx)
	    entry (assq ch (cdr map)))
      (if (null entry)
	  (progn
	    (setq entry (cons ch (list nil)))
	    (setcdr map (cons entry (cdr map)))))
      (setq map (cdr entry))
      (setq idx (1+ idx)))
    (if (symbolp trans)
	(if (cdr map)
	    ;; We come here, for example, when we try to define a rule
	    ;; for "AB" as a symbol but a rule for "ABC" is already
	    ;; defined.
	    (error "Quail key %s is too short" key)
	  (setcdr entry trans))
      (if (quail-map-p trans)
	  (if (not (listp (cdr map)))
	      ;; We come here, for example, when we try to define a rule
	      ;; for "AB" as a symbol but a rule for "ABC" is already
	      ;; defined.
	      (error "Quail key %s is too short" key)
	    (if (not (listp (cdr trans)))
		(if (cdr map)
		    ;; We come here, for example, when we try to
		    ;; define a rule for "AB" as a symbol but a rule
		    ;; for "ABC" is already defined.
		    (error "Quail key %s is too short" key)
		  (setcdr entry trans))
	      (setcdr entry (append trans (cdr map)))))
	;; If PROPS is non-nil or DECODE-MAP is non-nil, convert TRANS
	;; to a vector of strings, add PROPS to each string and record
	;; this rule in DECODE-MAP.
	(when (and (or props decode-map)
		   (not (consp trans)) (not (symbolp trans)))
	  (if (integerp trans)
	      (setq trans (vector trans))
	    (if (stringp trans)
		(setq trans (string-to-vector trans))))
	  (let ((len (length trans))
		elt)
	    (while (> len 0)
	      (setq len (1- len))
	      (setq elt (aref trans len))
	      (if (integerp elt)
		  (setq elt (char-to-string elt)))
	      (aset trans len elt)
	      (if props
		  (add-text-properties 0 (length elt) props elt))
	      (if decode-map
		  (setcdr decode-map
			  (cons (cons elt key) (cdr decode-map)))))))
	(if (and (car map) append)
	    (let ((prev (quail-get-translation (car map) key len)))
	      (if (integerp prev)
		  (setq prev (vector prev))
		(setq prev (cdr prev)))
	      (if (integerp trans)
		  (setq trans (vector trans))
		(if (stringp trans)
		    (setq trans (string-to-vector trans))))
	      (setq trans
		    (cons (list 0 0 0 0 nil)
			  (vconcat prev trans)))))
	(setcar map trans)))))

(defun quail-get-translation (def key len)
  "Return the translation specified as DEF for KEY of length LEN.
The translation is either a character or a cons of the form (INDEX . VECTOR),
where VECTOR is a vector of candidates (character or string) for
the translation, and INDEX points into VECTOR to specify the currently
selected translation."
  (if (and def (symbolp def))
      (if (functionp def)
	  ;; DEF is a symbol of a function which returns valid translation.
	  (setq def (funcall def key len))
	(setq def nil)))
  (if (and (consp def) (not (vectorp (cdr def))))
      (setq def (car def)))

  (cond
   ((or (integerp def) (consp def))
    def)

   ((null def)
    ;; No translation.
    nil)

   ((stringp def)
    ;; If the length is 1, we don't need vector but a single candidate
    ;; as the translation.
    (if (= (length def) 1)
	(aref def 0)
      ;; Each character in DEF is a candidate of translation.  Reform
      ;; it as (INDICES . VECTOR).
      (cons (list 0 0 0 0 nil) (string-to-vector def))))

   ((vectorp def)
    ;; If the length is 1, and the length of element string is 1, we
    ;; don't need vector but a single candidate as the translation.
    (if (and (= (length def) 1)
	     (= (length (aref def 0)) 1))
	(aref (aref def 0) 0)
      ;; Each element (string or character) in DEF is a candidate of
      ;; translation.  Reform it as (INDICES . VECTOR).
      (cons (list 0 0 0 0 nil) def)))

   (t
    (error "Invalid object in Quail map: %s" def))))

(defun quail-lookup-key (key &optional len)
  "Lookup KEY of length LEN in the current Quail map and return the definition.
The returned value is a Quail map specific to KEY."
  (or len
      (setq len (length key)))
  (let ((idx 0)
	(map (quail-map))
	(kbd-translate (quail-kbd-translate))
	slot ch translation def)
    (while (and map (< idx len))
      (setq ch (if kbd-translate (quail-keyboard-translate (aref key idx))
		 (aref key idx)))
      (setq idx (1+ idx))
      (if (and (cdr map) (symbolp (cdr map)))
	  (setcdr map (funcall (cdr map) key idx)))
      (setq slot (assq ch (cdr map)))
      (if (and (cdr slot) (symbolp (cdr slot)))
	  (setcdr slot (funcall (cdr slot) key idx)))
      (setq map (cdr slot)))
    (setq def (car map))
    (setq quail-current-translations nil)
    (if (and map (setq translation (quail-get-translation def key len)))
	(progn
	  (if (and (consp def) (not (vectorp (cdr def))))
	      (progn
		(if (not (equal (car def) translation))
		    ;; We must reflect TRANSLATION to car part of DEF.
		    (setcar def translation))
		(setq quail-current-data
		      (if (functionp (cdr def))
			  (funcall (cdr def))
			(cdr def))))
	    (if (not (equal def translation))
		;; We must reflect TRANSLATION to car part of MAP.
		(setcar map translation)))
	  (if (and (consp translation) (vectorp (cdr translation)))
	      (progn
		(setq quail-current-translations translation)
		(if (quail-forget-last-selection)
		    (setcar (car quail-current-translations) 0))))))
    ;; We may have to reform cdr part of MAP.
    (if (and (cdr map) (functionp (cdr map)))
	(setcdr map (funcall (cdr map) key len)))
    map))

(put 'quail-error 'error-conditions '(quail-error error))
(defun quail-error (&rest args)
  (signal 'quail-error (apply 'format args)))


(defun quail-input-string-to-events (str)
  "Convert input string STR to a list of events.
Do so while interleaving with the following special events:
\(compose-last-chars LEN COMPONENTS)
\(quail-advice INPUT-STRING)"
  (let* ((events (string-to-list str))
	 (len (length str))
	 (idx len)
	 composition from to)
    (while (and (> idx 0)
		(setq composition (find-composition idx 0 str t)))
      (setq from (car composition) to (nth 1 composition))
      (setcdr (nthcdr (1- to) events)
	      (cons (list 'compose-last-chars (- to from)
			  (and (not (nth 3 composition)) (nth 2 composition)))
		    (nthcdr to events)))
      (setq idx (1- from)))
    (if (or (get-text-property 0 'advice str)
	    (next-single-property-change 0 'advice str))
	(setq events
	      (nconc events (list (list 'quail-advice str)))))
    events))

(defvar quail-translating nil)
(defvar quail-converting nil)
(defvar quail-conversion-str nil)

(defun quail-input-method (key)
  (if (or buffer-read-only
	  overriding-terminal-local-map
	  overriding-local-map)
      (list key)
    (quail-setup-overlays (quail-conversion-keymap))
    (let ((modified-p (buffer-modified-p))
	  (buffer-undo-list t))
      (or (and quail-guidance-win
	       (window-live-p quail-guidance-win)
	       (eq (window-buffer quail-guidance-win) quail-guidance-buf)
	       (not input-method-use-echo-area))
	  (quail-show-guidance-buf))
      (unwind-protect
	  (let ((input-string (if (quail-conversion-keymap)
				  (quail-start-conversion key)
				(quail-start-translation key))))
	    (when (and (stringp input-string)
		       (> (length input-string) 0))
	      (if input-method-exit-on-first-char
		  (list (aref input-string 0))
		(quail-input-string-to-events input-string))))
	(quail-delete-overlays)
	(if (buffer-live-p quail-guidance-buf)
	    (with-current-buffer quail-guidance-buf
	      (erase-buffer)))
	(quail-hide-guidance-buf)
	(set-buffer-modified-p modified-p)
	;; Run this hook only when the current input method doesn't require
	;; conversion.  When conversion is required, the conversion function
	;; should run this hook at a proper timing.
	(unless (quail-conversion-keymap)
	  (run-hooks 'input-method-after-insert-chunk-hook))))))

(defun quail-overlay-region-events (overlay)
  (let ((start (overlay-start overlay))
	(end (overlay-end overlay)))
    (if (< start end)
	(prog1
	    (string-to-list (buffer-substring start end))
	  (delete-region start end)))))

(defsubst quail-delete-region ()
  "Delete the text in the current translation region of Quail."
  (if (overlay-start quail-overlay)
      (delete-region (overlay-start quail-overlay)
		     (overlay-end quail-overlay))))

(defun quail-start-translation (key)
  "Start translation of the typed character KEY by the current Quail package.
Return the input string."
  ;; Check the possibility of translating KEY.
  ;; If KEY is nil, we can anyway start translation.
  (if (or (and (integerp key)
	       (assq (if (quail-kbd-translate)
			 (quail-keyboard-translate key) key)
		     (cdr (quail-map))))
	  (null key))
      ;; OK, we can start translation.
      (let* ((echo-keystrokes 0)
	     (help-char nil)
	     (overriding-terminal-local-map (quail-translation-keymap))
	     (generated-events nil)
	     (input-method-function nil)
	     (modified-p (buffer-modified-p)))
	(setq quail-current-key ""
	      quail-current-str ""
	      quail-translating t)
	(if key
	    (setq unread-command-events (cons key unread-command-events)))
	(while quail-translating
	  (set-buffer-modified-p modified-p)
	  (let* ((keyseq (read-key-sequence
			  (and input-method-use-echo-area
			       (concat input-method-previous-message
				       quail-current-str))
			  nil nil t))
		 (cmd (lookup-key (quail-translation-keymap) keyseq)))
	    (if (if key
		    (and (commandp cmd) (not (eq cmd 'quail-other-command)))
		  (eq cmd 'quail-self-insert-command))
		(let ((last-command-event (aref keyseq (1- (length keyseq))))
		      (last-command this-command)
		      (this-command cmd))
		  (setq key t)
		  (condition-case err
		      (call-interactively cmd)
		    (quail-error (message "%s" (cdr err)) (beep))))
	      ;; KEYSEQ is not defined in the translation keymap.
	      ;; Let's return the event(s) to the caller.
	      (setq unread-command-events
		    (string-to-list (this-single-command-raw-keys)))
	      (setq quail-translating nil))))
	(quail-delete-region)
	quail-current-str)

    ;; Since KEY doesn't start any translation, just return it.
    ;; But translate KEY if necessary.
    (if (quail-kbd-translate)
	(setq key (quail-keyboard-translate key)))
    (char-to-string key)))

(defun quail-start-conversion (key)
  "Start conversion of the typed character KEY by the current Quail package.
Return the input string."
  ;; Check the possibility of translating KEY.
  ;; If KEY is nil, we can anyway start translation.
  (if (or (and (integerp key)
	       (assq (if (quail-kbd-translate)
			 (quail-keyboard-translate key) key)
		     (cdr (quail-map))))
	  (null key))
      ;; Ok, we can start translation and conversion.
      (let* ((echo-keystrokes 0)
	     (help-char nil)
	     (overriding-terminal-local-map (quail-conversion-keymap))
	     (generated-events nil)
	     (input-method-function nil)
	     (modified-p (buffer-modified-p)))
	(setq quail-current-key ""
	      quail-current-str ""
	      quail-translating t
	      quail-converting t
	      quail-conversion-str "")
	(if key
	    (setq unread-command-events (cons key unread-command-events)))
	(while quail-converting
	  (set-buffer-modified-p modified-p)
	  (or quail-translating
	      (progn
		(setq quail-current-key ""
		      quail-current-str ""
		      quail-translating t)
		(quail-setup-overlays nil)))
	  ;; Hide '... loaded' message.
	  (message nil)
	  (let* ((keyseq (read-key-sequence
			  (and input-method-use-echo-area
			       (concat input-method-previous-message
				       quail-conversion-str
				       quail-current-str))
			  nil nil t))
		 (cmd (lookup-key (quail-conversion-keymap) keyseq)))
	    (if (if key (commandp cmd) (eq cmd 'quail-self-insert-command))
		(let ((last-command-event (aref keyseq (1- (length keyseq))))
		      (last-command this-command)
		      (this-command cmd))
		  (setq key t)
		  (condition-case err
		      (call-interactively cmd)
		    (quail-error (message "%s" (cdr err)) (beep)))
		  (or quail-translating
		      (progn
			(if quail-current-str
			    (setq quail-conversion-str
				  (concat quail-conversion-str
					  (if (stringp quail-current-str)
					      quail-current-str
					    (char-to-string quail-current-str)))))
			(if (or input-method-exit-on-first-char
				(= (length quail-conversion-str) 0))
			    (setq quail-converting nil)))))
	      ;; KEYSEQ is not defined in the conversion keymap.
	      ;; Let's return the event(s) to the caller.
	      (setq unread-command-events
		    (string-to-list (this-single-command-raw-keys)))
	      (setq quail-converting nil))))
	(setq quail-translating nil)
	(if (overlay-start quail-conv-overlay)
	    (delete-region (overlay-start quail-conv-overlay)
			   (overlay-end quail-conv-overlay)))
	(if (> (length quail-conversion-str) 0)
	    quail-conversion-str))

    ;; Since KEY doesn't start any translation, just return it.
    ;; But translate KEY if necessary.
    (if (quail-kbd-translate)
	(setq key (quail-keyboard-translate key)))
    (char-to-string key)))

(defun quail-terminate-translation ()
  "Terminate the translation of the current key."
  (setq quail-translating nil)
  (if (buffer-live-p quail-guidance-buf)
      (with-current-buffer quail-guidance-buf
	(erase-buffer))))

(defun quail-select-current ()
  "Accept the currently selected translation."
  (interactive)
  (quail-terminate-translation))

(defun quail-update-translation (control-flag)
"Update the current translation status according to CONTROL-FLAG.
If CONTROL-FLAG is integer value, it is the number of keys in the
head `quail-current-key' which can be translated.  The remaining keys
are put back to `unread-command-events' to be handled again.  If
CONTROL-FLAG is t, terminate the translation for the whole keys in
`quail-current-key'.  If CONTROL-FLAG is nil, proceed the translation
with more keys."
  (let ((func (quail-update-translation-function)))
    (if func
	(setq control-flag (funcall func control-flag))
      (cond ((numberp control-flag)
	     (let ((len (length quail-current-key)))
	       (if (= control-flag 0)
		   (setq quail-current-str
			 (if (quail-kbd-translate)
			     (quail-keyseq-translate quail-current-key)
			   quail-current-key)))
	       (or input-method-exit-on-first-char
		   (while (> len control-flag)
		     (setq len (1- len))
		     (setq unread-command-events
			   (cons (aref quail-current-key len)
				 unread-command-events))))))
	    ((null control-flag)
	     (unless quail-current-str
	       (setq quail-current-str
		     (if (quail-kbd-translate)
			 (quail-keyseq-translate quail-current-key)
		       quail-current-key))
	       (if (and input-method-exit-on-first-char
			(quail-simple))
		   (setq control-flag t)))))))
  (or input-method-use-echo-area
      (progn
	(quail-delete-region)
	(insert quail-current-str)))
  (let (quail-current-str)
    (quail-update-guidance))
  (or (stringp quail-current-str)
      (setq quail-current-str (char-to-string quail-current-str)))
  (if control-flag
      (quail-terminate-translation)))

(defun quail-self-insert-command ()
  "Translate the typed key by the current Quail map, and insert."
  (interactive "*")
  (setq quail-current-key
	(concat quail-current-key (char-to-string last-command-event)))
  (or (catch 'quail-tag
	(quail-update-translation (quail-translate-key))
	t)
      ;; If someone throws for `quail-tag' by value nil, we exit from
      ;; translation mode.
      (setq quail-translating nil)))

(defun quail-map-definition (map)
"Return the actual definition part of Quail map MAP."
  (let ((def (car map)))
    (if (and (consp def) (not (vectorp (cdr def))))
	(setq def (car def)))
    (if (eq def t)
	(setq def nil))
    def))

(defun quail-get-current-str (len def)
  "Return string to be shown as current translation of key sequence.
LEN is the length of the sequence.  DEF is a definition part of the
Quail map for the sequence."
  (or (and (consp def) (aref (cdr def) (car (car def))))
      def
      (and (> len 1)
	   (let ((str (quail-get-current-str
		       (1- len)
		       (quail-map-definition (quail-lookup-key
					      quail-current-key (1- len))))))
	     (if str
		 (concat (if (stringp str) str (char-to-string str))
			 (substring quail-current-key (1- len) len)))))))

(defvar quail-guidance-translations-starting-column 20)

(defun quail-update-current-translations (&optional relative-index)
  "Update `quail-current-translations'.
Make RELATIVE-INDEX the current translation."
  (let* ((indices (car quail-current-translations))
	 (cur (car indices))
	 (start (nth 1 indices))
	 (end (nth 2 indices)))
    ;; Validate the index number of current translation.
    (if (< cur 0)
	(setcar indices (setq cur 0))
      (if (>= cur (length (cdr quail-current-translations)))
	  (setcar indices
		  (setq cur (1- (length (cdr quail-current-translations)))))))

    (if (or (null end)			; We have not yet calculated END.
	    (< cur start)		; We moved to the previous block.
	    (>= cur end))		; We moved to the next block.
	(let ((len (length (cdr quail-current-translations)))
	      (maxcol (- (window-width quail-guidance-win)
			 quail-guidance-translations-starting-column))
	      (block (nth 3 indices))
	      col idx width trans num-items blocks)
	  (if (< cur start)
	      ;; We must calculate from the head.
	      (setq start 0 block 0)
	    (if end			; i.e. (>= cur end)
		(setq start end)))
	  (setq idx start col 0 end start num-items 0)
	  ;; Loop until we hit the tail, or reach the block of CUR.
	  (while (and (< idx len) (>= cur end))
	    (if (= num-items 0)
		(setq start idx col 0 block (1+ block)))
	    (setq trans (aref (cdr quail-current-translations) idx))
	    (setq width (if (integerp trans) (char-width trans)
			  (string-width trans)))
	    (setq col (+ col width 3) num-items (1+ num-items))
	    (if (and (> num-items 0)
		     (or (>= col maxcol) (> num-items 10)))
		(setq end idx num-items 0)
	      (setq idx (1+ idx))))
	  (setcar (nthcdr 3 indices) block)
	  (if (>= idx len)
	      (progn
		;; We hit the tail before reaching MAXCOL.
		(setq end idx)
		(setcar (nthcdr 4 indices) block)))
	  (setcar (cdr indices) start)
	  (setcar (nthcdr 2 indices) end)))
    (if relative-index
	(if (>= (+ start relative-index) end)
	    (setcar indices (1- end))
	  (setcar indices (+ start relative-index))))
    (setq quail-current-str
	  (aref (cdr quail-current-translations) (car indices)))
    (or (stringp quail-current-str)
	(setq quail-current-str (char-to-string quail-current-str)))))

(defun quail-translate-key ()
  "Translate the current key sequence according to the current Quail map.
Return t if we can terminate the translation.
Return nil if the current key sequence may be followed by more keys.
Return number if we can't find any translation for the current key
sequence.  The number is the count of valid keys in the current
sequence counting from the head."
  (let* ((len (length quail-current-key))
	 (map (quail-lookup-key quail-current-key len))
	 def ch)
    (if map
	(let ((def (quail-map-definition map)))
	  (setq quail-current-str (quail-get-current-str len def))
	  ;; Return t only if we can terminate the current translation.
	  (and
	   ;; No alternative translations.
	   (or (null (consp def)) (= (length (cdr def)) 1))
	   ;; No translation for the longer key.
	   (null (cdr map))
	   ;; No shorter breaking point.
	   (or (null (quail-maximum-shortest))
	       (< len 3)
	       (null (quail-lookup-key quail-current-key (1- len)))
	       (null (quail-lookup-key
		      (substring quail-current-key -2 -1) 1)))))

      ;; There's no translation for the current key sequence.  Before
      ;; giving up, we must check two possibilities.
      (cond ((and
	      (quail-maximum-shortest)
	      (>= len 3)
	      (setq def (quail-map-definition
			 (quail-lookup-key quail-current-key (- len 2))))
	      (quail-lookup-key (substring quail-current-key -2) 2))
	     ;; Now the sequence is "...ABCD", which can be split into
	     ;; "...AB" and "CD..." to get valid translation.
	     ;; At first, get translation of "...AB".
	     (setq quail-current-str (quail-get-current-str (- len 2) def))
	     ;; Then, return the length of "...AB".
	     (- len 2))

	    ((and (> len 0)
		  (quail-lookup-key (substring quail-current-key 0 -1))
		  quail-current-translations
		  (not (quail-deterministic))
		  (setq ch (aref quail-current-key (1- len)))
		  (>= ch ?0) (<= ch ?9))
	     ;; A numeric key is entered to select a desirable translation.
	     (setq quail-current-key (substring quail-current-key 0 -1))
	     ;; We treat key 1,2..,9,0 as specifying 0,1,..8,9.
	     (setq ch (if (= ch ?0) 9 (- ch ?1)))
	     (quail-update-current-translations ch)
	     ;; And, we can terminate the current translation.
	     t)

	    (t
	     ;; No way to handle the last character in this context.
	     (1- len))))))

(defun quail-next-translation ()
  "Select next translation in the current batch of candidates."
  (interactive)
  (if quail-current-translations
      (let ((indices (car quail-current-translations)))
	(if (= (1+ (car indices)) (length (cdr quail-current-translations)))
	    ;; We are already at the tail.
	    (beep)
	  (setcar indices (1+ (car indices)))
	  (quail-update-current-translations)
	  (quail-update-translation nil)))
    (setq unread-command-events
	  (cons last-command-event unread-command-events))
    (quail-terminate-translation)))

(defun quail-prev-translation ()
  "Select previous translation in the current batch of candidates."
  (interactive)
  (if quail-current-translations
      (let ((indices (car quail-current-translations)))
	(if (= (car indices) 0)
	    ;; We are already at the head.
	    (beep)
	  (setcar indices (1- (car indices)))
	  (quail-update-current-translations)
	  (quail-update-translation nil)))
    (setq unread-command-events
	  (cons last-command-event unread-command-events))
    (quail-terminate-translation)))

(defun quail-next-translation-block ()
  "Select from the next block of translations."
  (interactive)
  (if quail-current-translations
      (let* ((indices (car quail-current-translations))
	     (offset (- (car indices) (nth 1 indices))))
	(if (>= (nth 2 indices) (length (cdr quail-current-translations)))
	    ;; We are already at the last block.
	    (beep)
	  (setcar indices (+ (nth 2 indices) offset))
	  (quail-update-current-translations)
	  (quail-update-translation nil)))
    (setq unread-command-events
	  (cons last-command-event unread-command-events))
    (quail-terminate-translation)))

(defun quail-prev-translation-block ()
  "Select the previous batch of 10 translation candidates."
  (interactive)
  (if quail-current-translations
      (let* ((indices (car quail-current-translations))
	     (offset (- (car indices) (nth 1 indices))))
	(if (= (nth 1 indices) 0)
	    ;; We are already at the first block.
	    (beep)
	  (setcar indices (1- (nth 1 indices)))
	  (quail-update-current-translations)
	  (if (< (+ (nth 1 indices) offset) (nth 2 indices))
	      (progn
		(setcar indices (+ (nth 1 indices) offset))
		(quail-update-current-translations)))
	  (quail-update-translation nil)))
    (setq unread-command-events
	  (cons last-command-event unread-command-events))
    (quail-terminate-translation)))

(defun quail-abort-translation ()
  "Abort translation and delete the current Quail key sequence."
  (interactive)
  (quail-delete-region)
  (setq quail-current-str nil)
  (quail-terminate-translation))

(defun quail-delete-last-char ()
  "Delete the last input character from the current Quail key sequence."
  (interactive)
  (if (= (length quail-current-key) 1)
      (quail-abort-translation)
    (setq quail-current-key (substring quail-current-key 0 -1))
    (quail-delete-region)
    (quail-update-translation (quail-translate-key))))

;; For conversion mode.

(defsubst quail-point-in-conversion-region ()
  "Return non-nil value if the point is in conversion region of Quail mode."
  (let (start pos)
    (and (setq start (overlay-start quail-conv-overlay))
	 (>= (setq pos (point)) start)
	 (<= pos (overlay-end quail-conv-overlay)))))

(defun quail-conversion-backward-char ()
  (interactive)
  (if (<= (point) (overlay-start quail-conv-overlay))
      (quail-error "Beginning of conversion region"))
  (setq quail-translating nil)
  (forward-char -1))

(defun quail-conversion-forward-char ()
  (interactive)
  (if (>= (point) (overlay-end quail-conv-overlay))
      (quail-error "End of conversion region"))
  (setq quail-translating nil)
  (forward-char 1))

(defun quail-conversion-beginning-of-region ()
  (interactive)
  (setq quail-translating nil)
  (goto-char (overlay-start quail-conv-overlay)))

(defun quail-conversion-end-of-region ()
  (interactive)
  (setq quail-translating nil)
  (goto-char (overlay-end quail-conv-overlay)))

(defun quail-conversion-delete-char ()
  (interactive)
  (setq quail-translating nil)
  (if (>= (point) (overlay-end quail-conv-overlay))
      (quail-error "End of conversion region"))
  (delete-char 1)
  (let ((start (overlay-start quail-conv-overlay))
	(end (overlay-end quail-conv-overlay)))
    (setq quail-conversion-str (buffer-substring start end))
    (if (= start end)
	(setq quail-converting nil))))

(defun quail-conversion-delete-tail ()
  (interactive)
  (if (>= (point) (overlay-end quail-conv-overlay))
      (quail-error "End of conversion region"))
  (delete-region (point) (overlay-end quail-conv-overlay))
  (let ((start (overlay-start quail-conv-overlay))
	(end (overlay-end quail-conv-overlay)))
    (setq quail-conversion-str (buffer-substring start end))
    (if (= start end)
	(setq quail-converting nil))))

(defun quail-conversion-backward-delete-char ()
  (interactive)
  (if (> (length quail-current-key) 0)
      (quail-delete-last-char)
    (if (<= (point) (overlay-start quail-conv-overlay))
	(quail-error "Beginning of conversion region"))
    (delete-char -1)
    (let ((start (overlay-start quail-conv-overlay))
	  (end (overlay-end quail-conv-overlay)))
      (setq quail-conversion-str (buffer-substring start end))
      (if (= start end)
	  (setq quail-converting nil)))))

(defun quail-do-conversion (func &rest args)
  "Call FUNC to convert text in the current conversion region of Quail.
Remaining args are for FUNC."
  (delete-overlay quail-overlay)
  (apply func args))

(defun quail-no-conversion ()
  "Do no conversion of the current conversion region of Quail."
  (interactive)
  (setq quail-converting nil))

;; Guidance, Completion, and Help buffer handlers.

(defun quail-make-guidance-frame (buf)
  "Make a new one-line frame for Quail guidance buffer."
  (let* ((fparam (frame-parameters))
	 (top (cdr (assq 'top fparam)))
	 (border (cdr (assq 'border-width fparam)))
	 (internal-border (cdr (assq 'internal-border-width fparam)))
	 (newtop (- top
		    (frame-char-height) (* internal-border 2) (* border 2))))
    (if (< newtop 0)
	(setq newtop (+ top (frame-pixel-height))))
    (let* ((frame (make-frame (append '((user-position . t) (height . 1)
					(minibuffer) (menu-bar-lines . 0))
				      (cons (cons 'top newtop) fparam))))
	   (win (frame-first-window frame)))
      (set-window-buffer win buf)
      ;;(set-window-dedicated-p win t)
      )))

(defun quail-setup-completion-buf ()
  "Setup Quail completion buffer."
  (unless (buffer-live-p quail-completion-buf)
    (let ((default-enable-multibyte-characters enable-multibyte-characters))
      (setq quail-completion-buf (get-buffer-create "*Quail Completions*")))
    (with-current-buffer quail-completion-buf
      (setq quail-overlay (make-overlay 1 1))
      (overlay-put quail-overlay 'face 'highlight))))

(defun quail-require-guidance-buf ()
  "Return t iff the current Quail package requires showing guidance buffer."
  (and input-method-verbose-flag
       (if (eq input-method-verbose-flag 'default)
	   (not (and (eq (selected-window) (minibuffer-window))
		     (quail-simple)))
	 (if (eq input-method-verbose-flag 'complex-only)
	     (not (quail-simple))
	   t))))

(defun quail-show-guidance-buf ()
  "Display a guidance buffer for Quail input method in some window.
Create the buffer if it does not exist yet.
The buffer is normally displayed at the echo area,
but if the current buffer is a minibuffer, it is shown in
the bottom-most ordinary window of the same frame,
or in a newly created frame (if the selected frame has no other windows)."
  (when (quail-require-guidance-buf)
    ;; At first, setup a guidance buffer.
    (let ((default-enable-multibyte-characters enable-multibyte-characters))
      (or (buffer-live-p quail-guidance-buf)
	  (setq quail-guidance-buf (generate-new-buffer " *Quail-guidance*"))))
    (let ((name (quail-name))
	  (title (quail-title)))
      (with-current-buffer quail-guidance-buf
	;; To show the title of Quail package.
	(setq current-input-method name
	      current-input-method-title title)
	(erase-buffer)
	(or (overlayp quail-overlay)
	    (progn
	      (setq quail-overlay (make-overlay 1 1))
	      (overlay-put quail-overlay 'face 'highlight)))
	(delete-overlay quail-overlay)
	(set-buffer-modified-p nil)))
    (bury-buffer quail-guidance-buf)

    ;; Assign the buffer " *Minibuf-N*" to all windows which are now
    ;; displaying quail-guidance-buf.
    (let ((win-list (get-buffer-window-list quail-guidance-buf t t)))
      (while win-list
	(set-window-buffer (car win-list)
			   (format " *Minibuf-%d*" (minibuffer-depth)))
	(setq win-list (cdr win-list))))

    ;; Then, display it in an appropriate window.
    (let ((win (minibuffer-window)))
      (if (or (eq (selected-window) win)
	      input-method-use-echo-area)
	  ;; Since we are in minibuffer, we can't use it for guidance.
	  (if (eq win (frame-root-window))
	      ;; Create a frame.  It is sure that we are using some
	      ;; window system.
	      (quail-make-guidance-frame quail-guidance-buf)
	    ;; Find the bottom window and split it if necessary.
	    (setq win (window-at
		       0 (1- (- (frame-height) (window-height win)))))
	    (let ((height (window-height win))
		  (window-min-height 2))
	      ;; If WIN is tall enough, split it vertically and use
	      ;; the lower one.
	      (when (>= height 4)
		;; Here, `split-window' returns a lower window
		;; which is what we wanted.
		(setq win (split-window win (- height 2))))
	      (set-window-buffer win quail-guidance-buf)
	      (with-current-buffer quail-guidance-buf
		(fit-window-to-buffer win nil (window-height win)))))
	(set-window-buffer win quail-guidance-buf)
	(set-minibuffer-window win))
      (setq quail-guidance-win win)))

  ;; And, create a buffer for completion.
  (quail-setup-completion-buf)
  (bury-buffer quail-completion-buf))

(defun quail-hide-guidance-buf ()
  "Hide the Quail guidance buffer."
  (if (buffer-live-p quail-guidance-buf)
      (let ((win-list (get-buffer-window-list quail-guidance-buf t t))
	    win)
	(while win-list
	  (setq win (car win-list) win-list (cdr win-list))
	  (if (window-minibuffer-p win)
	      ;; We are using echo area for the guidance buffer.
	      ;; Vacate it to the deepest minibuffer.
	      (set-window-buffer win
				 (format " *Minibuf-%d*" (minibuffer-depth)))
	    (if (eq win (frame-root-window (window-frame win)))
		(progn
		  ;; We are using a separate frame for guidance buffer.
		  ;;(set-window-dedicated-p win nil)
		  (delete-frame (window-frame win)))
	      ;;(set-window-dedicated-p win nil)
	      (delete-window win))))
	(setq quail-guidance-win nil))))

(defun quail-update-guidance ()
  "Update the Quail guidance buffer and completion buffer (if displayed now)."
  ;; Update guidance buffer.
  (if (quail-require-guidance-buf)
      (let ((guidance (quail-guidance)))
	(unless (and (eq (selected-frame) (window-frame (minibuffer-window)))
		     (eq (selected-frame) (window-frame quail-guidance-win)))
	  ;; The guidance window is not shown in this frame, show it.
	  (quail-show-guidance-buf))
	(cond ((or (eq guidance t)
		   (consp guidance))
	       ;; Show the current possible translations.
	       (quail-show-translations))
	      ((null guidance)
	       ;; Show the current input keys.
	       (let ((key quail-current-key))
		 (if (quail-kbd-translate)
		     (setq key (quail-keyseq-translate key)))
		 (with-current-buffer quail-guidance-buf
		   (erase-buffer)
		   (insert key)))))
	;; Make sure the height of the guidance window is OK --
	;; sometimes, if the minibuffer window expands due to user
	;; input (for instance if the newly inserted character is in a
	;; different font), it will cause the guidance window to be
	;; only partially visible.  We force a redisplay first because
	;; this automatic expansion doesn't happen until then, and we
	;; want to see the window sizes after the expansion.
	(sit-for 0)
	(fit-window-to-buffer quail-guidance-win nil
			      (window-height quail-guidance-win))))

  ;; Update completion buffer if displayed now.  We highlight the
  ;; selected candidate string in *Completion* buffer if any.
  (let ((win (get-buffer-window quail-completion-buf))
	key str pos)
    (if win
	(save-excursion
	  (setq str (if (stringp quail-current-str)
			quail-current-str
		      (if (numberp quail-current-str)
			  (char-to-string quail-current-str)))
		key quail-current-key)
	  (set-buffer quail-completion-buf)
	  (goto-char (point-min))
	  (if (null (search-forward (concat " " key ":") nil t))
	      (delete-overlay quail-overlay)
	    (setq pos (point))
	    (if (and str (search-forward (concat "." str) nil t))
		  (move-overlay quail-overlay (1+ (match-beginning 0)) (point))
		(move-overlay quail-overlay (match-beginning 0) (point)))
	    ;; Now POS points end of KEY and (point) points end of STR.
	    (if (pos-visible-in-window-p (point) win)
		;; STR is already visible.
		nil
	      ;; We want to make both KEY and STR visible, but if the
	      ;; window is too short, make at least STR visible.
	      (setq pos (progn (point) (goto-char pos)))
	      (beginning-of-line)
	      (set-window-start win (point))
	      (if (not (pos-visible-in-window-p pos win))
		  (set-window-start win pos))
	      ))))))

(defun quail-show-translations ()
  "Show the current possible translations."
  (let* ((key quail-current-key)
	 (map (quail-lookup-key quail-current-key))
	 (current-translations quail-current-translations))
    (if quail-current-translations
	(quail-update-current-translations))
    (with-current-buffer quail-guidance-buf
      (erase-buffer)

      ;; Show the current key.
      (let ((guidance (quail-guidance)))
	(if (listp guidance)
	    ;; We must show the specified PROMPTKEY instead of the
	    ;; actual typed keys.
	    (let ((i 0)
		  (len (length key))
		  prompt-key)
	      (while (< i len)
		(setq prompt-key (cdr (assoc (aref key i) guidance)))
		(insert (or prompt-key (aref key i)))
		(setq i (1+ i))))
	  (insert key)))

      ;; Show followable keys.
      (if (and (> (length key) 0) (cdr map))
	  (let ((keys (mapcar (function (lambda (x) (car x)))
			      (cdr map))))
	    (setq keys (sort keys '<))
	    (insert "[")
	    (while keys
	      (insert (car keys))
	      (setq keys (cdr keys)))
	    (insert "]")))

      ;; Show list of translations.
      (if (and current-translations
	       (not (quail-deterministic)))
	  (let* ((indices (car current-translations))
		 (cur (car indices))
		 (start (nth 1 indices))
		 (end (nth 2 indices))
		 (idx start))
	    (indent-to (- quail-guidance-translations-starting-column 7))
	    (insert (format "(%02d/"(nth 3 indices))
		    (if (nth 4 indices)
			(format "%02d)" (nth 4 indices))
		      "??)"))
	    (while (< idx end)
	      (insert (format " %d." (if (= (- idx start) 9) 0
				       (1+ (- idx start)))))
	      (let ((pos (point)))
		(insert (aref (cdr current-translations) idx))
		(if (= idx cur)
		    (move-overlay quail-overlay pos (point))))
	      (setq idx (1+ idx)))))
      )))

(defvar quail-completion-max-depth 5
  "The maximum depth of Quail completion list.")

(defun quail-completion ()
  "List all completions for the current key.
All possible translations of the current key and whole possible longer keys
are shown (at most to the depth specified `quail-completion-max-depth')."
  (interactive)
  (quail-setup-completion-buf)
  (let ((win (get-buffer-window quail-completion-buf 'visible))
	(key quail-current-key)
	(map (quail-lookup-key quail-current-key))
	(require-update nil))
    (with-current-buffer quail-completion-buf
      (if (and win
	       (equal key quail-current-key)
	       (eq last-command 'quail-completion))
	  ;; The window for Quail completion buffer has already been
	  ;; shown.  We just scroll it appropriately.
	  (if (pos-visible-in-window-p (point-max) win)
	      (set-window-start win (point-min))
	    (let ((other-window-scroll-buffer quail-completion-buf))
	      (scroll-other-window)))
	(setq quail-current-key key)
	(erase-buffer)
	(insert "Possible completion and corresponding translations are:\n")
	(quail-completion-1 key map 1)
	(goto-char (point-min))
	(display-buffer (current-buffer))
	(setq require-update t)))
    (if require-update
	(quail-update-guidance)))
  (setq this-command 'quail-completion))

(defun quail-completion-1 (key map indent)
"List all completions of KEY in MAP with indentation INDENT."
  (let ((len (length key)))
    (indent-to indent)
    (insert key ":")
    (if (and (symbolp map) (fboundp map))
	(setq map (funcall map key len)))
    (if (car map)
	(quail-completion-list-translations map key (+ indent len 1))
      (insert " -\n"))
    (setq indent (+ indent 2))
    (if (and (cdr map) (< (/ (1- indent) 2) quail-completion-max-depth))
	(let ((l (cdr map))
	      (newkey (make-string (1+ len) 0))
	      (i 0))
	  (if (functionp l)
	      (setq l (funcall l)))
	  ;; Set KEY in the first LEN characters of NEWKEY.
	  (while (< i len)
	    (aset newkey i (aref key i))
	    (setq i (1+ i)))
	  (setq l (reverse l))
	  (while l			; L = ((CHAR . DEFN) ....) ;
	    (aset newkey len (car (car l)))
	    (quail-completion-1 newkey (cdr (car l)) indent)
	    (setq l (cdr l)))))))

(defun quail-completion-list-translations (map key indent)
  "List all possible translations of KEY in Quail MAP with indentation INDENT."
  (let (beg (translations
	 (quail-get-translation (car map) key (length key))))
    (if (integerp translations)
	(progn
	  (insert "(1/1) 1.")
	  ;; Endow the character `translations' with `mouse-face' text
	  ;; property to enable `mouse-2' completion.
	  (setq beg (point))
	  (insert translations)
	  (put-text-property beg (point) 'mouse-face 'highlight)
	  (insert "\n"))
      ;; We need only vector part.
      (setq translations (cdr translations))
      ;; Insert every 10 elements with indices in a line.
      (let ((len (length translations))
	    (i 0)
	    num)
	(while (< i len)
	  (when (zerop (% i 10))
	    (when (>= i 10)
 	      (insert "\n")
	      (indent-to indent))
	    (insert (format "(%d/%d)" (1+ (/ i 10)) (1+ (/ len 10)))))
	  ;; We show the last digit of FROM while converting
	  ;; 0,1,..,9 to 1,2,..,0.
	  (insert (format " %d." (% (1+ i) 10)))
	  (setq beg (point))
	  (insert (aref translations i))
	  ;;  Passing the mouse over a character will highlight.
	  (put-text-property beg (point) 'mouse-face 'highlight)
	  (setq i (1+ i)))
	(insert "\n")))))

;; Choose a completion in *Quail Completions* buffer with mouse-2.

(defun quail-mouse-choose-completion (event)
  "Click on an alternative in the `*Quail Completions*' buffer to choose it."
  (interactive "e")
  ;; This function is an exact copy of the mouse.el function
  ;; `mouse-choose-completion' except that we:
  ;; 1) add two lines from `choose-completion' in simple.el to give
  ;;    the `mouse-2' click a little more leeway.
  ;; 2) don't bury *Quail Completions* buffer so comment a section, and 
  ;; 3) delete/terminate the current quail selection here.
  ;; Give temporary modes such as isearch a chance to turn off.
  (run-hooks 'mouse-leave-buffer-hook)
  (let ((buffer (window-buffer))
        choice
	base-size)
    (with-current-buffer (window-buffer (posn-window (event-start event)))
      (if completion-reference-buffer
	  (setq buffer completion-reference-buffer))
      (setq base-size completion-base-size)
      (save-excursion
	(goto-char (posn-point (event-start event)))
	(let (beg end)
	  (if (and (not (eobp)) (get-text-property (point) 'mouse-face))
	      (setq end (point) beg (1+ (point))))
	  (if (and (not (bobp)) (get-text-property (1- (point)) 'mouse-face))
	      (setq end (1- (point)) beg (point)))
	  (if (null beg)
	      (quail-error "No completion here"))
	  (setq beg (previous-single-property-change beg 'mouse-face))
	  (setq end (or (next-single-property-change end 'mouse-face)
			(point-max)))
	  (setq choice (buffer-substring beg end)))))
;    (let ((owindow (selected-window)))
;      (select-window (posn-window (event-start event)))
;      (if (and (one-window-p t 'selected-frame)
;	       (window-dedicated-p (selected-window)))
;	  ;; This is a special buffer's frame
;	  (iconify-frame (selected-frame))
;	(or (window-dedicated-p (selected-window))
;	    (bury-buffer)))
;      (select-window owindow))
    (quail-delete-region)
    (quail-choose-completion-string choice buffer base-size)
    (quail-terminate-translation)))

;; Modify the simple.el function `choose-completion-string', because
;; the simple.el function `choose-completion-delete-max-match' breaks
;; on Mule data, since the semantics of `forward-char' have changed.

(defun quail-choose-completion-string (choice &optional buffer base-size)
  (let ((buffer (or buffer completion-reference-buffer)))
    ;; If BUFFER is a minibuffer, barf unless it's the currently
    ;; active minibuffer.
    (if (and (string-match "\\` \\*Minibuf-[0-9]+\\*\\'" (buffer-name buffer))
	     (or (not (active-minibuffer-window))
		 (not (equal buffer
			     (window-buffer (active-minibuffer-window))))))
	(quail-error "Minibuffer is not active for completion")
      ;; Store the completion in `quail-current-str', which will later
      ;; be converted to a character event list, then inserted into
      ;; the buffer where completion was requested.
      (set-buffer buffer)
;      (if base-size
;	  (delete-region (+ base-size (point-min)) (point))
;	(choose-completion-delete-max-match choice))
      (setq quail-current-str choice)
      ;; Update point in the window that BUFFER is showing in.
      (let ((window (get-buffer-window buffer t)))
	(set-window-point window (point)))
      ;; If completing for the minibuffer, exit it with this choice.
      (and (not completion-no-auto-exit)
	   (equal buffer (window-buffer (minibuffer-window)))
	   minibuffer-completion-table
	   ;; If this is reading a file name, and the file name chosen
	   ;; is a directory, don't exit the minibuffer.
	   (if (and (eq minibuffer-completion-table 'read-file-name-internal)
		    (file-directory-p (buffer-string)))
	       (select-window (active-minibuffer-window))
	     (exit-minibuffer))))))

(defun quail-build-decode-map (map-list key decode-map num
					&optional maxnum ignores)
  "Build a decoding map.
Accumulate in the cdr part of DECODE-MAP all pairs of key sequences
vs the corresponding translations defined in the Quail map
specified by the first element MAP-LIST.  Each pair has the form
\(KEYSEQ . TRANSLATION).  DECODE-MAP should have the form
\(decode-map . ALIST), where ALIST is an alist of length NUM.  KEY
is a key sequence to reach MAP.
Optional 5th arg MAXNUM limits the number of accumulated pairs.
Optional 6th arg IGNORES is a list of translations to ignore."
  (let* ((map (car map-list))
	 (translation (quail-get-translation (car map) key (length key)))
	 elt)
    (cond ((integerp translation)
	   ;; Accept only non-ASCII chars not listed in IGNORES.
	   (when (and (> translation 255) (not (memq translation ignores)))
	     (setcdr decode-map
		     (cons (cons key translation) (cdr decode-map)))
	     (setq num (1+ num))))
	  ((consp translation)
	   (setq translation (cdr translation))
	   (let ((multibyte nil))
	     (mapc (function (lambda (x)
			       ;; Accept only non-ASCII chars not
			       ;; listed in IGNORES.
			       (if (and (if (integerp x) (> x 255)
					  (> (string-bytes x) (length x)))
					(not (member x ignores)))
				   (setq multibyte t))))
		   translation)
	     (when multibyte
	       (setcdr decode-map
		       (cons (cons key translation) (cdr decode-map)))
	       (setq num (+ num (length translation)))))))
    (if (and maxnum (> num maxnum))
	(- num)
      (setq map (cdr map))
      ;; Recursively check the deeper map.
      (while (and map (>= num 0))
	(setq elt (car map) map (cdr map))
	(when (and (integerp (car elt)) (consp (cdr elt))
		   (not (memq (cdr elt) map-list)))
	  (setq num (quail-build-decode-map (cons (cdr elt) map-list)
					    (format "%s%c" key (car elt))
					    decode-map num maxnum ignores))))
      num)))

(defun quail-insert-decode-map (decode-map)
  "Insert pairs of key sequences vs the corresponding translations.
These are stored in DECODE-MAP using the concise format.  DECODE-MAP
should be made by `quail-build-decode-map' (which see)."
  (setq decode-map
	(sort (cdr decode-map)
	      (function (lambda (x y)
			  (setq x (car x) y (car y))
			  (or (> (length x) (length y))
			      (and (= (length x) (length y))
				   (not (string< x y))))))))
  (let ((frame-width (frame-width (window-frame (get-buffer-window
						 (current-buffer) 'visible))))
	(single-key-width 3)
	(single-trans-width 4)
	(multiple-key-width 3)
	(single-list nil)
	(multiple-list nil)
	elt trans width pos cols rows col row str col-width)
    ;; Divide the elements of decoding map into single ones (i.e. the
    ;; one that has single translation) and multibyte ones (i.e. the
    ;; one that has multiple translations).
    (while decode-map
      (setq elt (car decode-map) decode-map (cdr decode-map)
	    trans (cdr elt))
      (if (and (vectorp trans) (= (length trans) 1))
	  (setq trans (aref trans 0)))
      (if (vectorp trans)
	  (setq multiple-list (cons elt multiple-list))
	(setq single-list (cons (cons (car elt) trans) single-list)
	      width (if (stringp trans) (string-width trans)
		      (char-width trans)))
	(if (> width single-trans-width)
	    (setq single-trans-width width)))
      (setq width (length (car elt)))
      (if (> width single-key-width)
	  (setq single-key-width width))
      (if (> width multiple-key-width)
	  (setq multiple-key-width width)))
    (when single-list
      (setq col-width (+ single-key-width 1 single-trans-width 1)
	    cols (/ frame-width col-width)
	    rows (/ (length single-list) cols))
      (if (> (% (length single-list) cols) 0)
	  (setq rows (1+ rows)))
      (insert "key")
      (indent-to (1+ single-key-width))
      (insert "char")
      (indent-to (1+ col-width))
      (insert "[type a key sequence to insert the corresponding character]\n")
      (setq pos (point))
      (insert-char ?\n (+ rows 2))
      (goto-char pos)
      (setq col (- col-width) row 0)
      (while single-list
	(setq elt (car single-list) single-list (cdr single-list))
	(when (= (% row rows) 0)
	  (goto-char pos)
	  (setq col (+ col col-width))
	  (move-to-column col t)
	  (insert-char ?- single-key-width)
	  (insert ? )
	  (insert-char ?- single-trans-width)
	  (forward-line 1))
	(move-to-column col t)
	(insert (car elt))
	(indent-to (+ col single-key-width 1))
	(insert (cdr elt))
	(forward-line 1)
	(setq row (1+ row)))
      (goto-char (point-max)))

    (when multiple-list
      (insert "key")
      (indent-to (1+ multiple-key-width))
      (insert "character(s)  [type a key (sequence) and select one from the list]\n")
      (insert-char ?- multiple-key-width)
      (insert " ------------\n")
      (while multiple-list
	(setq elt (car multiple-list) multiple-list (cdr multiple-list))
	(insert (car elt))
	(indent-to multiple-key-width)
	(if (vectorp (cdr elt))
	    (mapc (function
		   (lambda (x)
		     (let ((width (if (integerp x) (char-width x)
				    (string-width x))))
		       (when (> (+ (current-column) 1 width) frame-width)
			 (insert "\n")
			 (indent-to multiple-key-width))
		       (insert " " x))))
		  (cdr elt))
	  (insert " " (cdr elt)))
	(insert ?\n))
      (insert ?\n))))

(define-button-type 'quail-keyboard-layout-button
  :supertype 'help-xref
  'help-function '(lambda (layout) 
		    (help-setup-xref `(quail-keyboard-layout-button ,layout) nil)
		    (quail-show-keyboard-layout layout))
  'help-echo (purecopy "mouse-2, RET: show keyboard layout"))

(define-button-type 'quail-keyboard-customize-button
  :supertype 'help-customize-variable
  'help-echo (purecopy "mouse-2, RET: customize keyboard layout"))

(defun quail-help (&optional package)
  "Show brief description of the current Quail package.
Optional arg PACKAGE specifies the name of alternative Quail
package to describe."
  (interactive)
  (let ((help-xref-mule-regexp help-xref-mule-regexp-template)
	(default-enable-multibyte-characters enable-multibyte-characters)
	(package-def
	 (if package
	     (assoc package quail-package-alist)
	   quail-current-package)))
    ;; At first, make sure that the help buffer has window.
    (help-setup-xref (list #'quail-help package) (interactive-p))
    (with-output-to-temp-buffer (help-buffer)
      (with-current-buffer standard-output
	(setq quail-current-package package-def)))
    ;; Then, insert text in the help buffer while paying attention to
    ;; the width of the frame in which the buffer displayed.
    (with-current-buffer (help-buffer)
      (setq buffer-read-only nil)
      (insert "Input method: " (quail-name)
	      " (mode line indicator:"
	      (quail-title)
	      ")\n\n")
      (save-restriction
	(narrow-to-region (point) (point))
	(insert (quail-docstring))
	(goto-char (point-min))
	(with-syntax-table emacs-lisp-mode-syntax-table
	  (while (re-search-forward "\\\\<\\sw\\(\\sw\\|\\s_\\)+>" nil t)
	    (let ((sym (intern-soft
			(buffer-substring (+ (match-beginning 0) 2)
					  (1- (point))))))
	      (if (and (boundp sym)
		       (stringp (symbol-value sym)))
		  (replace-match (symbol-value sym) t t)))))
	(goto-char (point-max)))
      (or (bolp)
	  (insert "\n"))
      (insert "\n")

      (let ((done-list nil))
	;; Show keyboard layout if the current package requests it..
	(when (quail-show-layout)
	  (insert "
KEYBOARD LAYOUT
---------------
This input method works by translating individual input characters.
Assuming that your actual keyboard has the `")
	  (help-insert-xref-button
	   quail-keyboard-layout-type
	   'quail-keyboard-layout-button
	   quail-keyboard-layout-type)
	  (insert "' layout,
translation results in the following \"virtual\" keyboard layout:
")
	  (setq done-list
		(quail-insert-kbd-layout quail-keyboard-layout))
	  (insert "If your keyboard has a different layout, rearranged from
`")
	  (help-insert-xref-button
	   "standard"
	   'quail-keyboard-layout-button "standard")
	  (insert "', the \"virtual\" keyboard you get with this input method
will be rearranged in the same way.

You can set the variable `quail-keyboard-layout-type' to specify
the physical layout of your keyboard; the tables shown in
documentation of input methods including this one are based on the
physical keyboard layout as specified with that variable.
")
	  (help-insert-xref-button
	   "[customize keyboard layout]"
	   'quail-keyboard-customize-button 'quail-keyboard-layout-type)
	  (insert "\n"))

	;; Show key sequences.
	(let ((decode-map (list 'decode-map))
	      elt pos num)
	  (setq num (quail-build-decode-map (list (quail-map)) "" decode-map
					    0 512 done-list))
	  (when (> num 0)
	    (insert "
KEY SEQUENCE
-----------
")
	    (if (quail-show-layout)
		(insert "You can also input more characters")
	      (insert "You can input characters"))
	    (insert " by the following key sequences:\n")
	    (quail-insert-decode-map decode-map))))

      (quail-help-insert-keymap-description
       (quail-translation-keymap)
       "\
KEY BINDINGS FOR TRANSLATION
----------------------------\n")
      (insert ?\n)
      (if (quail-conversion-keymap)
	  (quail-help-insert-keymap-description
	   (quail-conversion-keymap)
	   "\
KEY BINDINGS FOR CONVERSION
---------------------------\n"))
      (setq quail-current-package nil)
      ;; Resize the help window again, now that it has all its contents.
      (save-selected-window
 	(select-window (get-buffer-window (current-buffer)))
	(run-hooks 'temp-buffer-show-hook)))))

(defun quail-help-insert-keymap-description (keymap &optional header)
  (let (pos1 pos2 eol)
    (setq pos1 (point))
    (if header
	(insert header))
    (save-excursion
      (insert (substitute-command-keys "\\{keymap}")))
    ;; Skip headers "key bindings", etc.
    (forward-line 3)
    (setq pos2 (point))
    (with-syntax-table emacs-lisp-mode-syntax-table
      (while (re-search-forward "\\sw\\(\\sw\\|\\s_\\)+" nil t)
	(let ((sym (intern-soft (buffer-substring (match-beginning 0)
						  (point)))))
	  (if (and sym (fboundp sym)
		   (or (eq (get sym 'quail-help) 'hide)
		       (and (quail-deterministic)
			    (eq (get sym 'quail-help) 'non-deterministic))))
	      (delete-region (line-beginning-position)
			     (1+ (line-end-position)))))))
    (goto-char pos2)
    (while (not (eobp))
      (if (looking-at "[ \t]*$")
	  (delete-region (point) (1+ (line-end-position)))
	(forward-line 1)))
    (goto-char pos2)
    (if (eobp)
	(delete-region pos1 (point)))
    (goto-char (point-max))))

(defun quail-translation-help ()
  "Show help message while translating in Quail input method."
  (interactive)
  (if (not (eq this-command last-command))
      (let (state-msg keymap)
	(if (and quail-converting (= (length quail-current-key) 0))
	    (setq state-msg
		  (format "Converting string %S by input method %S.\n"
			  quail-conversion-str (quail-name))
		  keymap (quail-conversion-keymap))
	  (setq state-msg
		(format "Translating key sequence %S by input method %S.\n"
			quail-current-key (quail-name))
		keymap (quail-translation-keymap)))
	(with-output-to-temp-buffer "*Help*"
	  (with-current-buffer standard-output
	    (insert state-msg)
	    (quail-help-insert-keymap-description
	     keymap
	     "-----------------------\n")
	    ;; Isn't this redundant ?  -stef
	    (help-mode)))))
  (let (scroll-help)
    (save-selected-window
      (select-window (get-buffer-window "*Help*"))
      (if (eq this-command last-command)
	  (if (< (window-end) (point-max))
	      (scroll-up)
	    (if (> (window-start) (point-min))
		(set-window-start (selected-window) (point-min)))))
      (setq scroll-help
	    (if (< (window-end (selected-window) 'up-to-date) (point-max))
		"Type \\[quail-translation-help] to scroll up the help"
	      (if (> (window-start) (point-min))
		  "Type \\[quail-translation-help] to see the head of help"))))
    (if scroll-help
	(progn
	  (message "%s" (substitute-command-keys scroll-help))
	  (sit-for 1)
	  (message nil)
	  (quail-update-guidance)
	  ))))

;; Quail map generator from state transition table.

(defun quail-map-from-table (table)
  "Make quail map from state transition table TABLE.

TABLE is an alist, the form is:
  ((STATE-0 TRANSITION-0-1 TRANSITION-0-2 ...) (STATE-1 ...) ...)

STATE-n are symbols to denote state.  STATE-0 is the initial state.

TRANSITION-n-m are transition rules from STATE-n, and have the form
\(RULES . STATE-x) or RULES, where STATE-x is one of STATE-n above,
RULES is a symbol whose value is an alist of keys \(string) vs the
correponding characters or strings.  The format of the symbol value of
RULES is the same as arguments to `quail-define-rules'.

If TRANSITION-n-m has the form (RULES . STATE-x), it means that
STATE-n transits to STATE-x when keys in RULES are input.  Recursive
transition is allowed, i.e. STATE-x may be STATE-n.

If TRANSITION-n-m has the form RULES, the transition terminates
when keys in RULES are input.

The generated map can be set for the current Quail package by the
function `quail-install-map' (which see)."
  (let ((state-alist (mapcar (lambda (x) (list (car x))) table))
	tail elt)
    ;; STATE-ALIST is an alist of states vs the correponding sub Quail
    ;; map.  It is now initialized to ((STATE-0) (STATE-1) ...).
    ;; Set key sequence mapping rules in cdr part of each element.
    (while table
      (quail-map-from-table-1 state-alist (car table))
      (setq table (cdr table)))

    ;; Now STATE-ALIST has the form ((STATE-0 MAPPING-RULES) ...).
    ;; Elements of MAPPING-RULES may have the form (STATE-x).  Replace
    ;; them with MAPPING-RULES of STATE-x to make elements of
    ;; STATE-ALIST valid Quail maps.
    (setq tail state-alist)
    (while tail
      (setq elt (car tail) tail (cdr tail))
      (quail-map-from-table-2 state-alist elt))

    ;; Return the Quail map for the initial state.
    (car state-alist)))

;; STATE-INFO has the form (STATE TRANSITION ...).  Set key sequence
;; mapping rules in the element of STATE-ALIST that corresponds to
;; STATE according to TRANSITION ...
(defun quail-map-from-table-1 (state-alist state-info)
  (let* ((state (car state-info))
	 (map (assq state state-alist))
	 (transitions (cdr state-info))
	 elt)
    (while transitions
      (setq elt (car transitions) transitions (cdr transitions))
      (let (rules dst-state key trans)
	;; ELT has the form (RULES-SYMBOL . STATE-x) or RULES-SYMBOL.
	;; STATE-x is one of car parts of STATE-ALIST's elements.
	(if (consp elt)
	    (setq rules (symbol-value (car elt))
		  ;; Set (STATE-x) as branches for all keys in RULES.
		  ;; It is replaced with actual branches for STATE-x
		  ;; later in `quail-map-from-table-2'.
		  dst-state (list (cdr elt)))
	  (setq rules (symbol-value elt)))
	(while rules
	  (setq key (car (car rules)) trans (cdr (car rules))
		rules (cdr rules))
	  (if (stringp trans)
	      (if (= (length trans) 1)
		  (setq trans (aref trans 0))
		(setq trans (string-to-vector trans))))
	  (set-nested-alist key trans map nil dst-state))))))

;; ELEMENT is one element of STATE-ALIST.  ELEMENT is a nested alist;
;; the form is:
;;	(STATE (CHAR NESTED-ALIST) ...)
;; NESTED-ALIST is a nested alist; the form is:
;;	(TRANS (CHAR NESTED-ALIST) ...)
;; or
;;	(TRANS (CHAR NESTED-ALIST) ... . (STATE-x))
;; Here, the task is to replace all occurrences of (STATE-x) with:
;;	(cdr (assq STATE-x STATE-ALIST))

(defun quail-map-from-table-2 (state-alist element)
  (let ((prev element)
	(tail (cdr element))
	 elt)
    (while (cdr tail)
      (setq elt (car tail) prev tail tail (cdr tail))
      (quail-map-from-table-2 state-alist (cdr elt)))
    (setq elt (car tail))
    (if (consp elt)
	(quail-map-from-table-2 state-alist (cdr elt))
      (setcdr prev (cdr (assq elt state-alist))))))

;; Concatenate translations for all heading substrings of KEY in the
;; current Quail map.  Here, `heading substring' means (substring KEY
;; 0 LEN), where LEN is 1, 2, ... (length KEY).
(defun quail-lookup-map-and-concat (key)
  (let* ((len (length key))
	 (translation-list nil)
	 map)
    (while (> len 0)
      (setq map (quail-lookup-key key len)
	    len (1- len))
      (if map
	  (let* ((def (quail-map-definition map))
		 (trans (if (consp def) (aref (cdr def) (car (car def)))
			  def)))
	    (if (integerp trans)
		(setq trans (char-to-string trans)))
	    (setq translation-list (cons trans translation-list)))))
    (apply 'concat translation-list)))


(defvar quail-directory-name "quail"
  "Name of Quail directory which contains Quail packages.
This is a sub-directory of LEIM directory.")

;;;###autoload
(defun quail-update-leim-list-file (dirname &rest dirnames)
  "Update entries for Quail packages in `LEIM' list file in directory DIRNAME.
DIRNAME is a directory containing Emacs input methods;
normally, it should specify the `leim' subdirectory
of the Emacs source tree.

It searches for Quail packages under `quail' subdirectory of DIRNAME,
and update the file \"leim-list.el\" in DIRNAME.

When called from a program, the remaining arguments are additional
directory names to search for Quail packages under `quail' subdirectory
of each directory."
  (interactive "FDirectory of LEIM: ")
  (setq dirname (expand-file-name dirname))
  (let ((leim-list (expand-file-name leim-list-file-name dirname))
	quail-dirs list-buf pkg-list pkg-buf pos)
    (if (not (file-writable-p leim-list))
	(error "Can't write to file \"%s\"" leim-list))
    (message "Updating %s ..." leim-list)
    (setq list-buf (find-file-noselect leim-list))

    ;; At first, clean up the file.
    (with-current-buffer list-buf
      (goto-char 1)

      ;; Insert the correct header.
      (if (looking-at (regexp-quote leim-list-header))
	  (goto-char (match-end 0))
	(insert leim-list-header))
      (setq pos (point))
      (if (not (re-search-forward leim-list-entry-regexp nil t))
	  nil

	;; Remove garbages after the header.
	(goto-char (match-beginning 0))
	(if (< pos (point))
	    (delete-region pos (point)))

	;; Remove all entries for Quail.
	(while (re-search-forward leim-list-entry-regexp nil 'move)
	  (goto-char (match-beginning 0))
	  (setq pos (point))
	  (condition-case nil
	      (let ((form (read list-buf)))
		(when (equal (nth 3 form) ''quail-use-package)
		  (if (eolp) (forward-line 1))
		  (delete-region pos (point))))
	    (error
	     ;; Delete the remaining contents because it seems that
	     ;; this file is broken.
	     (message "Garbage in %s deleted" leim-list)
	     (delete-region pos (point-max)))))))

    ;; Search for `quail' subdirectory under each DIRNAMES.
    (setq dirnames (cons dirname dirnames))
    (let ((l dirnames))
      (while l
	(setcar l (expand-file-name (car l)))
	(setq dirname (expand-file-name quail-directory-name (car l)))
	(if (file-readable-p dirname)
	    (setq quail-dirs (cons dirname quail-dirs))
	  (message "%s doesn't have `%s' subdirectory, just ignored"
		   (car l) quail-directory-name)
	  (setq quail-dirs (cons nil quail-dirs)))
	(setq l (cdr l)))
      (setq quail-dirs (nreverse quail-dirs)))

    ;; Insert input method registering forms.
    (while quail-dirs
      (setq dirname (car quail-dirs))
      (when dirname
	(setq pkg-list (directory-files dirname 'full "\\.el$" 'nosort))
	(while pkg-list
	  (message "Checking %s ..." (car pkg-list))
	  (with-temp-buffer
	    (insert-file-contents (car pkg-list))
	    (goto-char (point-min))
	    (while (search-forward "(quail-define-package" nil t)
	      (goto-char (match-beginning 0))
	      (condition-case nil
		  (let ((form (read (current-buffer))))
		    (with-current-buffer list-buf
		      (insert
		       (format "(register-input-method
 %S %S '%s
 %S %S
 %S)\n"
			       (nth 1 form) ; PACKAGE-NAME
			       (nth 2 form) ; LANGUAGE
			       'quail-use-package ; ACTIVATE-FUNC
			       (nth 3 form) ; PACKAGE-TITLE
			       (progn	; PACKAGE-DESCRIPTION (one line)
				 (string-match ".*" (nth 5 form))
				 (match-string 0 (nth 5 form)))
			       (file-relative-name ; PACKAGE-FILENAME
				(file-name-sans-extension (car pkg-list))
				(car dirnames))))))
		(error
		 ;; Ignore the remaining contents of this file.
		 (goto-char (point-max))
		 (message "Some part of \"%s\" is broken" (car pkg-list))))))
	  (setq pkg-list (cdr pkg-list)))
	(setq quail-dirs (cdr quail-dirs) dirnames (cdr dirnames))))

    ;; At last, write out LEIM list file.
    (with-current-buffer list-buf
      (setq buffer-file-coding-system 'iso-2022-7bit)
      (save-buffer 0))
    (kill-buffer list-buf)
    (message "Updating %s ... done" leim-list)))

(defun quail-advice (args)
  "Advise users about the characters input by the current Quail package.
The argument is a parameterized event of the form:
   (quail-advice STRING)
where STRING is a string containing the input characters.
If STRING has property `advice' and the value is a function,
call it with one argument STRING."
  (interactive "e")
  (let* ((string (nth 1 args))
	 (func (get-text-property 0 'advice string)))
    (if (functionp func)
	(funcall func string))))

(global-set-key [quail-advice] 'quail-advice)

;;
(provide 'quail)

;;; quail.el ends here
