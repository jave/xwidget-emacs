;;; double.el --- support for keyboard remapping with double clicking

;; Copyright (C) 1994, 1997, 1998 Free Software Foundation, Inc.

;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Keywords: i18n

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

;; This mode is intended for use with languages that adds a small
;; number of extra letters not available on the keyboard.
;;
;; Examples includes Scandinavian and German with an US keyboard.
;;
;; The idea is that certain keys are overloaded.  When you press it
;; once it will insert one string, and when you press it twice the
;; string will be replaced by another.  This can be used for mapping
;; keys on a US keyboard to generate characters according to the local
;; keyboard convention when pressed once, and according to US keyboard
;; convention when pressed twice.
;;
;; To use this mode, you must define the variable `double-map' and
;; then enable double mode with `M-x double-mode'.  Read the
;; documentation for both of them.
;;
;; The default mapping is for getting Danish/Norwegian keyboard layout
;; using ISO Latin 1 on a US keyboard.
;;
;; Important node: While I would like to hear comments, bug reports,
;; suggestions, please do @strong{not} expect me to put other mappings
;; than the default into this file.  There are billions and billions
;; of such mappings, and just supporting the most common would
;; increase the size of this nice small file manyfold.

;;; Code:

(defgroup double nil
  "Remap keyboard, but get original by typing the same key twice."
  :group 'i18n)

(defcustom double-map
  '((?\; "\346" ";")
    (?\' "\370" "'")
    (?\[ "\345" "[")
    (?\: "\306" ":")
    (?\" "\330" "\"")
    (?\{ "\305" "{"))
  "Alist of key translations activated by double mode.

Each entry is a list with three elements:
1. The key activating the translation.
2. The string to be inserted when the key is pressed once.
3. The string to be inserted when the key is pressed twice."
  :group 'double
  :type '(repeat (list (character :tag "Key")
		       (string :tag "Once")
		       (string :tag "Twice"))))

(defcustom double-prefix-only t
  "*Non-nil means that Double mode mapping only works for prefix keys.
That is, for any key `X' in `double-map', `X' alone will be mapped
but not `C-u X' or `ESC X' since the X is not the prefix key."
  :group 'double
  :type 'boolean)

;;; Read Event

(defvar double-last-event nil)
;; The last key that generated a double key event.

(defun double-read-event (prompt)
  ;; Read an event
  (if isearch-mode (isearch-update))
  (if prompt
      (prog2 (message "%s%c" prompt double-last-event)
	  (read-event)
	(message ""))
    (read-event)))

(global-set-key [ignore] '(lambda () (interactive)))

(or (boundp 'isearch-mode-map)
    (load-library "isearch"))

(define-key isearch-mode-map [ignore]
  (function (lambda () (interactive) (isearch-update))))

(defun double-translate-key (prompt)
  ;; Translate input events using double map.
  (let ((key last-input-char))
    (cond (unread-command-events
	   ;; Artificial event, ignore it.
	   (vector key))
	  ((and double-prefix-only
		(> (length (this-command-keys)) 1))
	   ;; This is not a prefix key, ignore it.
	   (vector key))
	  ((eq key 'magic-start)
	   ;; End of generated event.  See if he will repeat it...
	   (let ((new (double-read-event prompt))
		 (entry (assoc double-last-event double-map)))
	     (force-window-update (selected-window))
	     (if (eq new double-last-event)
		 (progn
		   (setq unread-command-events
			 (append (make-list (1- (length (nth 1 entry)))
					    127)
				 (nth 2 entry)
				 '(magic-end)))
		   (vector 127))
	       (setq unread-command-events (list new))
	       [ignore])))
	  ((eq key 'magic-end)
	   ;; End of double event.  Ignore.
	   [ignore])
	  (t
	   ;; New key.
	   (let ((exp (nth 1 (assoc key double-map))))
	     (setq double-last-event key)
	     (setq unread-command-events
		   (append (substring exp 1) '(magic-start)))
	     (vector (aref exp 0)))))))

;;; Key Translation Map

(defun double-setup (enable-flag)
  (if enable-flag
      (progn
	;; Set up key-translation-map as indicated by `double-map'.
	(kill-local-variable 'key-translation-map)
	(make-local-variable 'key-translation-map)
	(setq key-translation-map (if (keymapp key-translation-map)
				      (copy-keymap key-translation-map)
				    (make-sparse-keymap)))
	(mapcar (function (lambda (entry)
			    (define-key key-translation-map
			      (vector (nth 0 entry))
			      'double-translate-key)))
		(append double-map '((magic-start) (magic-end)))))
    (kill-local-variable 'key-translation-map)))

;;; Mode

;;;###autoload
(defcustom double-mode nil
  "Toggle Double mode.
Setting this variable directly does not take effect;
use either \\[customize] or the function `double-mode'."
  :set (lambda (symbol value)
	 (double-mode (if value 1 0)))
  :initialize 'custom-initialize-default
  :link '(emacs-commentary-link "double")
  :type 'boolean
  :require 'double
  :group 'double)
(make-variable-buffer-local 'double-mode)

(or (assq 'double-mode minor-mode-alist)
    (setq minor-mode-alist
	  (cons '(double-mode " Double") minor-mode-alist)))

;; This feature seemed useless and it confused describe-mode,
;;  so I deleted it.
;;;(defvar double-mode-name "Double")
;;;;; Name of current double mode.
;;; (make-variable-buffer-local 'double-mode-name)

;;;###autoload
(defun double-mode (arg)
  "Toggle Double mode.
With prefix arg, turn Double mode on iff arg is positive.

When Double mode is on, some keys will insert different strings
when pressed twice.  See variable `double-map' for details."
  (interactive "P")
  (if (or (and (null arg) double-mode)
	  (<= (prefix-numeric-value arg) 0))
      ;; Turn it off
      (if double-mode
	  (progn
	    (let ((double-map))
	      (double-setup nil))
	    (setq double-mode nil)
	    (force-mode-line-update)))
    ;;Turn it on
    (if double-mode
	()
      (double-setup t)
      (setq double-mode t)
      (force-mode-line-update))))

(provide 'double)

;;; arch-tag: 2e170036-44cb-4493-bc32-ada0a4395221
;;; double.el ends here
