;;; etags.el --- tags facility for Emacs.

;; Copyright (C) 1985, 1986, 1988, 1992 Free Software Foundation, Inc.

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
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.


;;;###autoload
(defvar tags-file-name nil "\
*File name of tag table.
To switch to a new tag table, setting this variable is sufficient.
Use the `etags' program to make a tag table file.")

(defvar tag-table-files nil
  "List of file names covered by current tag table.
nil means it has not been computed yet; do (tag-table-files) to compute it.")

(defvar last-tag nil
  "Tag found by the last find-tag.")

;;;###autoload
(defun visit-tags-table (file)
  "Tell tags commands to use tag table file FILE.
FILE should be the name of a file created with the `etags' program.
A directory name is ok too; it means file TAGS in that directory."
  (interactive (list (read-file-name "Visit tags table: (default TAGS) "
				     default-directory
				     (concat default-directory "TAGS")
				     t)))
  (setq file (expand-file-name file))
  ;; Get rid of the prefixes added by the automounter.
  (if (and (string-match "^/tmp_mnt/" file)
	   (file-exists-p (file-name-directory
			   (substring file (1- (match-end 0))))))
      (setq file (substring file (1- (match-end 0)))))
  (if (file-directory-p file)
      (setq file (concat file "TAGS")))
  (setq tag-table-files nil
	tags-file-name file))

(defun visit-tags-table-buffer ()
  "Select the buffer containing the current tag table.
This is a file whose name is in the variable tags-file-name."
  (or tags-file-name
      (call-interactively 'visit-tags-table))
  (set-buffer (or (get-file-buffer tags-file-name)
		  (progn
		    (setq tag-table-files nil)
		    (find-file-noselect tags-file-name))))
  (or (verify-visited-file-modtime (get-file-buffer tags-file-name))
      (cond ((yes-or-no-p "Tags file has changed, read new contents? ")
	     (revert-buffer t t)
	     (setq tag-table-files nil))))
  (or (eq (char-after 1) ?\^L)
      (error "File %s not a valid tag table" tags-file-name)))

(defun file-of-tag ()
  "Return the file name of the file whose tags point is within.
Assumes the tag table is the current buffer.
File name returned is relative to tag table file's directory."
  (let ((opoint (point))
	prev size)
    (save-excursion
     (goto-char (point-min))
     (while (< (point) opoint)
       (forward-line 1)
       (end-of-line)
       (skip-chars-backward "^,\n")
       (setq prev (point))
       (setq size (read (current-buffer)))
       (goto-char prev)
       (forward-line 1)
       (forward-char size))
     (goto-char (1- prev))
     (buffer-substring (point)
		       (progn (beginning-of-line) (point))))))

;;;###autoload
(defun tag-table-files ()
  "Return a list of files in the current tag table.
File names returned are absolute."
  (save-excursion
   (visit-tags-table-buffer)
   (or tag-table-files
       (let (files)
	(goto-char (point-min))
	(while (not (eobp))
	  (forward-line 1)
	  (end-of-line)
	  (skip-chars-backward "^,\n")
	  (setq prev (point))
	  (setq size (read (current-buffer)))
	  (goto-char prev)
	  (setq files (cons (expand-file-name
			     (buffer-substring (1- (point))
					       (save-excursion
						 (beginning-of-line)
						 (point)))
			     (file-name-directory tags-file-name))
			    files))
	  (forward-line 1)
	  (forward-char size))
	(setq tag-table-files (nreverse files))))))

;; Return a default tag to search for, based on the text at point.
(defun find-tag-default ()
  (save-excursion
    (while (looking-at "\\sw\\|\\s_")
      (forward-char 1))
    (if (re-search-backward "\\sw\\|\\s_" nil t)
	(progn (forward-char 1)
	       (buffer-substring (point)
				 (progn (forward-sexp -1)
					(while (looking-at "\\s'")
					  (forward-char 1))
					(point))))
      nil)))

(defun find-tag-tag (string)
  (let* ((default (find-tag-default))
	 (spec (read-string
		(if default
		    (format "%s(default %s) " string default)
		  string))))
    (list (if (equal spec "")
	      default
	    spec))))

(defun tags-tag-match (tagname exact)
  "Search for a match to the given tagname."
  (if (not exact)
      (search-forward tagname nil t)
    (not (error-occurred
	  (while
	      (progn
		(search-forward tagname)
		(let ((before (char-syntax (char-after (1- (match-beginning 1)))))
		      (after (char-syntax (char-after (match-end 1)))))
		  (not (or (= before ?w) (= before ?_))
			   (= after ?w) (= after ?_)))
		))))
    )
  )

(defun find-tag-noselect (tagname exact &optional next)
  "Find a tag and return its buffer, but don't select or display it."
  (let (buffer file linebeg startpos (obuf (current-buffer)))
    ;; save-excursion will do the wrong thing if the buffer containing the
    ;; tag being searched for is current-buffer
    (unwind-protect
	(progn
	  (visit-tags-table-buffer)
	  (if (not next)
	      (goto-char (point-min))
	    (setq tagname last-tag))
	  (setq last-tag tagname)
	  (while (progn
		   (if (not (tags-tag-match tagname exact))
		       (error "No %sentries matching %s"
			      (if next "more " "") tagname))
		   (not (looking-at "[^\n\177]*\177"))))
	  (search-forward "\177")
	  (setq file (expand-file-name (file-of-tag)
				       (file-name-directory tags-file-name)))
	  (setq linebeg
		(buffer-substring (1- (point))
				  (save-excursion (beginning-of-line) (point))))
	  (search-forward ",")
	  (setq startpos (read (current-buffer)))
	  (prog1
	      (set-buffer (find-file-noselect file))
	    (widen)
	    (push-mark)
	    (let ((offset 1000)
		  found
		  (pat (concat "^" (regexp-quote linebeg))))
	      (or startpos (setq startpos (point-min)))
	      (while (and (not found)
			  (progn
			    (goto-char (- startpos offset))
			    (not (bobp))))
		(setq found
		      (re-search-forward pat (+ startpos offset) t))
		(setq offset (* 3 offset)))
	      (or found
		  (re-search-forward pat nil t)
		  (error "%s not found in %s" pat file)))
	    (beginning-of-line)))
      (set-buffer obuf))
    ))

;;;###autoload
(defun find-tag (tagname &optional next other-window)
  "Find tag (in current tag table) whose name contains TAGNAME.
 Selects the buffer that the tag is contained in
and puts point at its definition.
 If TAGNAME is a null string, the expression in the buffer
around or before point is used as the tag name.
 If second arg NEXT is non-nil (interactively, with prefix arg),
searches for the next tag in the tag table
that matches the tagname used in the previous find-tag.

See documentation of variable tags-file-name."
  (interactive (if current-prefix-arg
		   '(nil t)
		 (find-tag-tag "Find tag: ")))
  (let ((tagbuf (find-tag-noselect tagname nil next)))
    (if other-window
	(switch-to-buffer-other-window tagbuf)
      (switch-to-buffer tagbuf))
    )
;; I turned this off because people complain that it causes trouble
;; when they find a tag during a tags-search.  M-0 M-. is easy enough. --RMS
;;  (setq tags-loop-form '(find-tag nil t))
  ;; Return t in case used as the tags-loop-form.
  t)

;;;###autoload
(define-key esc-map "." 'find-tag)

;;;###autoload
(defun find-tag-other-window (tagname &optional next)
  "Find tag (in current tag table) whose name contains TAGNAME.
 Selects the buffer that the tag is contained in in another window
and puts point at its definition.
 If TAGNAME is a null string, the expression in the buffer
around or before point is used as the tag name.
 If second arg NEXT is non-nil (interactively, with prefix arg),
searches for the next tag in the tag table
that matches the tagname used in the previous find-tag.

See documentation of variable tags-file-name."
  (interactive (if current-prefix-arg
		   '(nil t)
		   (find-tag-tag "Find tag other window: ")))
  (find-tag tagname next t))
;;;###autoload
(define-key ctl-x-4-map "." 'find-tag-other-window)

;;;###autoload
(defun find-tag-other-frame (tagname &optional next)
  "Find tag (in current tag table) whose name contains TAGNAME.
 Selects the buffer that the tag is contained in in another frame
and puts point at its definition.
 If TAGNAME is a null string, the expression in the buffer
around or before point is used as the tag name.
 If second arg NEXT is non-nil (interactively, with prefix arg),
searches for the next tag in the tag table
that matches the tagname used in the previous find-tag.

See documentation of variable tags-file-name."
  (interactive (if current-prefix-arg
		   '(nil t)
		   (find-tag-tag "Find tag other window: ")))
  (let ((pop-up-screens t))
    (find-tag tagname next t)))
;;;###autoload
(define-key ctl-x-5-map "." 'find-tag-other-frame)

(defvar next-file-list nil
  "List of files for next-file to process.")

;;;###autoload
(defun next-file (&optional initialize)
  "Select next file among files in current tag table.
Non-nil argument (prefix arg, if interactive)
initializes to the beginning of the list of files in the tag table."
  (interactive "P")
  (if initialize
      (setq next-file-list (tag-table-files)))
  (or next-file-list
      (error "All files processed."))
  (find-file (car next-file-list))
  (setq next-file-list (cdr next-file-list)))

(defvar tags-loop-form nil
  "Form for tags-loop-continue to eval to process one file.
If it returns nil, it is through with one file; move on to next.")

;;;###autoload
(defun tags-loop-continue (&optional first-time)
  "Continue last \\[tags-search] or \\[tags-query-replace] command.
Used noninteractively with non-nil argument
to begin such a command.  See variable tags-loop-form."
  (interactive)
  (if first-time
      (progn (next-file t)
	     (goto-char (point-min))))
  (while (not (eval tags-loop-form))
    (next-file)
    (message "Scanning file %s..." buffer-file-name)
    (goto-char (point-min))))
;;;###autoload
(define-key esc-map "," 'tags-loop-continue)

;;;###autoload
(defun tags-search (regexp)
  "Search through all files listed in tag table for match for REGEXP.
Stops when a match is found.
To continue searching for next match, use command \\[tags-loop-continue].

See documentation of variable tags-file-name."
  (interactive "sTags search (regexp): ")
  (if (and (equal regexp "")
	   (eq (car tags-loop-form) 're-search-forward))
      (tags-loop-continue nil)
    (setq tags-loop-form
	  (list 're-search-forward regexp nil t))
    (tags-loop-continue t)))

;;;###autoload
(defun tags-query-replace (from to &optional delimited)
  "Query-replace-regexp FROM with TO through all files listed in tag table.
Third arg DELIMITED (prefix arg) means replace only word-delimited matches.
If you exit (C-G or ESC), you can resume the query-replace
with the command \\[tags-loop-continue].

See documentation of variable tags-file-name."
  (interactive "sTags query replace (regexp): \nsTags query replace %s by: \nP")
  (setq tags-loop-form
	(list 'and (list 'save-excursion
			 (list 're-search-forward from nil t))
	      (list 'not (list 'perform-replace from to t t 
			       (not (null delimited))))))
  (tags-loop-continue t))

;;;###autoload
(defun list-tags (string)
  "Display list of tags in file FILE.
FILE should not contain a directory spec
unless it has one in the tag table."
  (interactive "sList tags (in file): ")
  (with-output-to-temp-buffer "*Tags List*"
    (princ "Tags in file ")
    (princ string)
    (terpri)
    (save-excursion
     (visit-tags-table-buffer)
     (goto-char 1)
     (search-forward (concat "\f\n" string ","))
     (forward-line 1)
     (while (not (or (eobp) (looking-at "\f")))
       (princ (buffer-substring (point)
				(progn (skip-chars-forward "^\177")
				       (point))))
       (terpri)
       (forward-line 1)))))

;;;###autoload
(defun tags-apropos (string)
  "Display list of all tags in tag table REGEXP matches."
  (interactive "sTag apropos (regexp): ")
  (with-output-to-temp-buffer "*Tags List*"
    (princ "Tags matching regexp ")
    (prin1 string)
    (terpri)
    (save-excursion
     (visit-tags-table-buffer)
     (goto-char 1)
     (while (re-search-forward string nil t)
       (beginning-of-line)
       (princ (buffer-substring (point)
				(progn (skip-chars-forward "^\177")
				       (point))))
       (terpri)
       (forward-line 1)))))

(provide 'etags)

;;; etags.el ends here
