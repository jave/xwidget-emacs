;;; ob-sh.el --- org-babel functions for shell evaluation

;; Copyright (C) 2009, 2010, 2011  Free Software Foundation, Inc.

;; Author: Eric Schulte
;; Keywords: literate programming, reproducible research
;; Homepage: http://orgmode.org
;; Version: 7.4

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

;; Org-Babel support for evaluating shell source code.

;;; Code:
(require 'ob)
(require 'ob-comint)
(require 'ob-eval)
(require 'shell)
(eval-when-compile (require 'cl))

(declare-function org-babel-comint-in-buffer "ob-comint" (buffer &rest body))
(declare-function org-babel-comint-wait-for-output "ob-comint" (buffer))
(declare-function org-babel-comint-buffer-livep "ob-comint" (buffer))
(declare-function org-babel-comint-with-output "ob-comint" (meta &rest body))
(declare-function orgtbl-to-generic "org-table" (table params))

(defvar org-babel-default-header-args:sh '())

(defvar org-babel-sh-command "sh"
  "Command used to invoke a shell.
This will be passed to  `shell-command-on-region'")

(defun org-babel-execute:sh (body params)
  "Execute a block of Shell commands with Babel.
This function is called by `org-babel-execute-src-block'."
  (let* ((session (org-babel-sh-initiate-session
		   (cdr (assoc :session params))))
         (result-params (cdr (assoc :result-params params))) 
         (full-body (org-babel-expand-body:generic
		     body params (org-babel-variable-assignments:sh params))))
    (org-babel-reassemble-table
     (org-babel-sh-evaluate session full-body result-params)
     (org-babel-pick-name
      (cdr (assoc :colname-names params)) (cdr (assoc :colnames params)))
     (org-babel-pick-name
      (cdr (assoc :rowname-names params)) (cdr (assoc :rownames params))))))

(defun org-babel-prep-session:sh (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS."
  (let* ((session (org-babel-sh-initiate-session session))
	 (var-lines (org-babel-variable-assignments:sh params)))
    (org-babel-comint-in-buffer session
      (mapc (lambda (var)
              (insert var) (comint-send-input nil t)
              (org-babel-comint-wait-for-output session)) var-lines))
    session))

(defun org-babel-load-session:sh (session body params)
  "Load BODY into SESSION."
  (save-window-excursion
    (let ((buffer (org-babel-prep-session:sh session params)))
      (with-current-buffer buffer
        (goto-char (process-mark (get-buffer-process (current-buffer))))
        (insert (org-babel-chomp body)))
      buffer)))

;; helper functions

(defun org-babel-variable-assignments:sh (params)
  "Return list of shell statements assigning the block's variables"
  (let ((sep (cdr (assoc :separator params))))
    (mapcar
     (lambda (pair)
       (format "%s=%s"
	       (car pair)
	       (org-babel-sh-var-to-sh (cdr pair) sep)))
     (mapcar #'cdr (org-babel-get-header params :var)))))

(defun org-babel-sh-var-to-sh (var &optional sep)
  "Convert an elisp value to a shell variable.
Convert an elisp var into a string of shell commands specifying a
var of the same value."
  (if (listp var)
      (flet ((deep-string (el)
                          (if (listp el)
                              (mapcar #'deep-string el)
			    (org-babel-sh-var-to-sh el sep))))
	(format "$(cat <<'BABEL_TABLE'\n%s\nBABEL_TABLE\n)"
		(orgtbl-to-generic
		 (deep-string (if (listp (car var)) var (list var)))
		 (list :sep (or sep "\t")))))
    (if (stringp var)
	(if (string-match "[\n\r]" var)
	    (format "$(cat <<BABEL_STRING\n%s\nBABEL_STRING\n)" var)
	  (format "%s" var))
      (format "%S" var))))

(defun org-babel-sh-table-or-results (results)
  "Convert RESULTS to an appropriate elisp value.
If the results look like a table, then convert them into an
Emacs-lisp table, otherwise return the results as a string."
  (org-babel-script-escape results))

(defun org-babel-sh-initiate-session (&optional session params)
  "Initiate a session named SESSION according to PARAMS."
  (when (and session (not (string= session "none")))
    (save-window-excursion
      (or (org-babel-comint-buffer-livep session)
          (progn (shell session) (get-buffer (current-buffer)))))))

(defvar org-babel-sh-eoe-indicator "echo 'org_babel_sh_eoe'"
  "String to indicate that evaluation has completed.")
(defvar org-babel-sh-eoe-output "org_babel_sh_eoe"
  "String to indicate that evaluation has completed.")

(defun org-babel-sh-evaluate (session body &optional result-params)
  "Pass BODY to the Shell process in BUFFER.
If RESULT-TYPE equals 'output then return a list of the outputs
of the statements in BODY, if RESULT-TYPE equals 'value then
return the value of the last statement in BODY."
  ((lambda (results)
     (when results
       (if (or (member "scalar" result-params)
	       (member "output" result-params))
	   results
	 (let ((tmp-file (org-babel-temp-file "sh-")))
	   (with-temp-file tmp-file (insert results))
	   (org-babel-import-elisp-from-file tmp-file)))))
   (if (not session)
       (org-babel-eval org-babel-sh-command (org-babel-trim body))
     (mapconcat
      #'org-babel-sh-strip-weird-long-prompt
      (mapcar
       #'org-babel-trim
       (butlast
	(org-babel-comint-with-output
	    (session org-babel-sh-eoe-output t body)
	  (mapc
	   (lambda (line)
	     (insert line) (comint-send-input nil t) (sleep-for 0.25))
	   (append
	    (split-string (org-babel-trim body) "\n")
	    (list org-babel-sh-eoe-indicator))))
	2)) "\n"))))

(defun org-babel-sh-strip-weird-long-prompt (string)
  "Remove prompt cruft from a string of shell output."
  (while (string-match "^% +[\r\n$]+ *" string)
    (setq string (substring string (match-end 0))))
  string)

(provide 'ob-sh)


;;; ob-sh.el ends here
