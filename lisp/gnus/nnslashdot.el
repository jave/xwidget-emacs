;;; nnslashdot.el --- interfacing with Slashdot
;; Copyright (C) 1999, 2000, 2001 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: news

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

;; Note: You need to have `url' and `w3' installed for this
;; backend to work.

;;; Code:

(eval-when-compile (require 'cl))

(require 'nnoo)
(require 'message)
(require 'gnus-util)
(require 'gnus)
(require 'nnmail)
(require 'mm-util)
(eval-when-compile
  (ignore-errors
    (require 'nnweb)))
;; Report failure to find w3 at load time if appropriate.
(eval '(require 'nnweb))

(nnoo-declare nnslashdot)

(defvoo nnslashdot-directory (nnheader-concat gnus-directory "slashdot/")
  "Where nnslashdot will save its files.")

(defvoo nnslashdot-active-url "http://slashdot.org/search.pl?section=&min=%d"
  "Where nnslashdot will fetch the active file from.")

(defvoo nnslashdot-comments-url "http://slashdot.org/comments.pl?sid=%s&threshold=%d&commentsort=%d&mode=flat&startat=%d"
  "Where nnslashdot will fetch comments from.")

(defvoo nnslashdot-article-url
    "http://slashdot.org/article.pl?sid=%s&mode=nocomment"
  "Where nnslashdot will fetch the article from.")

(defvoo nnslashdot-backslash-url "http://slashdot.org/slashdot.xml"
  "Where nnslashdot will fetch the stories from.")

(defvoo nnslashdot-threshold -1
  "The article threshold.")

(defvoo nnslashdot-threaded t
  "Whether the nnslashdot groups should be threaded or not.")

(defvoo nnslashdot-group-number 0
  "The number of non-fresh groups to keep updated.")

(defvoo nnslashdot-login-name ""
  "The login name to use when posting.")

(defvoo nnslashdot-password ""
  "The password to use when posting.")

;;; Internal variables

(defvar nnslashdot-groups nil)
(defvar nnslashdot-buffer nil)
(defvar nnslashdot-headers nil)

;;; Interface functions

(nnoo-define-basics nnslashdot)

(deffoo nnslashdot-retrieve-headers (articles &optional group server fetch-old)
  (nnslashdot-possibly-change-server group server)
  (condition-case why
      (unless gnus-nov-is-evil
	(nnslashdot-retrieve-headers-1 articles group))
    (search-failed (nnslashdot-lose why))))

(deffoo nnslashdot-retrieve-headers-1 (articles group)
  (let* ((last (car (last articles)))
	 (start (if nnslashdot-threaded 1 (pop articles)))
	 (entry (assoc group nnslashdot-groups))
	 (sid (nth 2 entry))
	 (first-comments t)
	 headers article subject score from date lines parent point cid
	 s startats changed)
    (save-excursion
      (set-buffer nnslashdot-buffer)
      (let ((case-fold-search t))
	(erase-buffer)
	(when (= start 1)
	  (nnweb-insert (format nnslashdot-article-url
				(nnslashdot-sid-strip sid)) t)
	  (goto-char (point-min))
	  (re-search-forward "Posted by[ \t\r\n]+")
	  (when (looking-at "\\(<a[^>]+>\\)?[ \t\r\n]*\\([^<\r\n]+\\)")
	    (setq from (nnweb-decode-entities-string (match-string 2))))
	  (search-forward "on ")
	  (setq date (nnslashdot-date-to-date
		      (buffer-substring (point) (1- (search-forward "<")))))
	  (setq lines (/ (- (point)
			    (progn (forward-line 1) (point)))
			 60))
	  (push
	   (cons
	    1
	    (make-full-mail-header
	     1 group from date
	     (concat "<" (nnslashdot-sid-strip sid) "%1@slashdot>")
	     "" 0 lines nil nil))
	   headers)
	  (setq start (if nnslashdot-threaded 2 (pop articles))))
	(while (and start (<= start last))
	  (setq point (goto-char (point-max)))
	  (nnweb-insert
	   (format nnslashdot-comments-url
		   (nnslashdot-sid-strip sid)
		   nnslashdot-threshold 0 (- start 2))
	   t)
	  (when (and nnslashdot-threaded first-comments)
	    (setq first-comments nil)
	    (goto-char (point-max))
	    (while (re-search-backward "startat=\\([0-9]+\\)" nil t)
	      (setq s (string-to-number (match-string 1)))
	      (unless (memq s startats)
		(push s startats)))
	    (setq startats (sort startats '<)))
	  (setq article (if (and article (< start article)) article start))
	  (goto-char point)
	  (while (re-search-forward
		  "<a name=\"\\([0-9]+\\)\"><\\(b\\|H4\\)>\\([^<]+\\)</\\(b\\|H4\\)>.*score:\\([^)]+\\))"
		  nil t)
	    (setq cid (match-string 1)
		  subject (match-string 3)
		  score (match-string 5))
	    (unless (assq article (nth 4 entry))
	      (setcar (nthcdr 4 entry) (cons (cons article cid) (nth 4 entry)))
	      (setq changed t))
	    (when (string-match "^Re: *" subject)
	      (setq subject (concat "Re: " (substring subject (match-end 0)))))
	    (setq subject (nnweb-decode-entities-string subject))
	    (search-forward "<BR>")
	    (if (looking-at
		 "by[ \t\n]+<a[^>]+>\\([^<]+\\)</a>[ \t\n]*(\\(<[^>]+>\\)*\\([^<>)]+\\))")
		(progn
		  (goto-char (- (match-end 0) 5))
		  (setq from (concat
			      (nnweb-decode-entities-string (match-string 1))
			      " <" (match-string 3) ">")))
	      (setq from "")
	      (when (looking-at "by \\([^<>]*\\) on ")
		(goto-char (- (match-end 0) 5))
		(setq from (nnweb-decode-entities-string (match-string 1)))))
	    (search-forward " on ")
	    (setq date
		  (nnslashdot-date-to-date
		   (buffer-substring (point) (progn (skip-chars-forward "^()<>\n\r") (point)))))
	    (setq lines (/ (abs (- (search-forward "<td")
				   (search-forward "</td>")))
			   70))
	    (if (not
		 (re-search-forward ".*cid=\\([0-9]+\\)\">Parent</A>" nil t))
		(setq parent nil)
	      (setq parent (match-string 1))
	      (when (string= parent "0")
		(setq parent nil)))
	    (push
	     (cons
	      article
	      (make-full-mail-header
	       article
	       (concat subject " (" score ")")
	       from date
	       (concat "<" (nnslashdot-sid-strip sid) "%" cid "@slashdot>")
	       (if parent
		   (concat "<" (nnslashdot-sid-strip sid) "%"
			   parent "@slashdot>")
		 "")
	       0 lines nil nil))
	     headers)
	    (while (and articles (<= (car articles) article))
	      (pop articles))
	    (setq article (1+ article)))
	  (if nnslashdot-threaded
	      (progn
		(setq start (pop startats))
		(if start (setq start (+ start 2))))
	    (setq start (pop articles))))))
    (if changed (nnslashdot-write-groups))
    (setq nnslashdot-headers (sort headers 'car-less-than-car))
    (save-excursion
      (set-buffer nntp-server-buffer)
      (erase-buffer)
      (mm-with-unibyte-current-buffer
       (dolist (header nnslashdot-headers)
	 (nnheader-insert-nov (cdr header)))))
    'nov))

(deffoo nnslashdot-request-group (group &optional server dont-check)
  (nnslashdot-possibly-change-server nil server)
  (let ((elem (assoc group nnslashdot-groups)))
    (cond
     ((not elem)
      (nnheader-report 'nnslashdot "Group does not exist"))
     (t
      (nnheader-report 'nnslashdot "Opened group %s" group)
      (nnheader-insert
       "211 %d %d %d %s\n" (cadr elem) 1 (cadr elem)
       (prin1-to-string group))))))

(deffoo nnslashdot-close-group (group &optional server)
  (nnslashdot-possibly-change-server group server)
  (when (gnus-buffer-live-p nnslashdot-buffer)
    (save-excursion
      (set-buffer nnslashdot-buffer)
      (kill-buffer nnslashdot-buffer)))
  t)

(deffoo nnslashdot-request-article (article &optional group server buffer)
  (nnslashdot-possibly-change-server group server)
  (let (contents cid)
    (condition-case why
	(save-excursion
	  (set-buffer nnslashdot-buffer)
	  (let ((case-fold-search t))
	    (goto-char (point-min))
	    (when (and (stringp article)
		       (string-match "%\\([0-9]+\\)@" article))
	      (setq cid (match-string 1 article))
	      (let ((map (nth 4 (assoc group nnslashdot-groups))))
		(while map
		  (if (equal (cdar map) cid)
		      (setq article (caar map)
			    map nil)
		    (setq map (cdr map))))))
	    (when (numberp article)
	      (if (= article 1)
		  (progn
		    (re-search-forward
		     "Posted by")
		    (search-forward "<BR>")
		    (setq contents
			  (buffer-substring
			   (point)
			   (progn
			     (re-search-forward
			      "&lt;&nbsp;[ \t\r\n]*<A HREF=\"\\(\\(http:\\)?//slashdot\\.org\\)?/article")
			     (match-beginning 0)))))
		(setq cid (cdr (assq article
				     (nth 4 (assoc group nnslashdot-groups)))))
		(search-forward (format "<a name=\"%s\">" cid))
		(setq contents
		      (buffer-substring
		       (re-search-forward "<td[^>]*>")
		       (search-forward "</td>")))))))
      (search-failed (nnslashdot-lose why)))

    (when contents
      (save-excursion
	(set-buffer (or buffer nntp-server-buffer))
	(erase-buffer)
	(mm-with-unibyte-current-buffer
	  (insert contents)
	  (goto-char (point-min))
	  (while (re-search-forward "\\(<br>\r?\\)+" nil t)
	    (replace-match "<p>" t t))
	  (goto-char (point-min))
	  (insert "Content-Type: text/html\nMIME-Version: 1.0\n")
	  (insert "Newsgroups: " (caddr (assoc group nnslashdot-groups))
		  "\n")
	  (let ((header (cdr (assq article nnslashdot-headers))))
	    (nnheader-insert-header header))
	  (nnheader-report 'nnslashdot "Fetched article %s" article))
	(cons group article)))))

(deffoo nnslashdot-close-server (&optional server)
  (when (and (nnslashdot-server-opened server)
	     (gnus-buffer-live-p nnslashdot-buffer))
    (save-excursion
      (set-buffer nnslashdot-buffer)
      (kill-buffer nnslashdot-buffer)))
  (nnoo-close-server 'nnslashdot server))

(deffoo nnslashdot-request-list (&optional server)
  (nnslashdot-possibly-change-server nil server)
  (let ((number 0)
	sid elem description articles gname)
    (condition-case why
	;; First we do the Ultramode to get info on all the latest groups.
	(progn
	  (mm-with-unibyte-buffer
	    (nnweb-insert nnslashdot-backslash-url t)
	    (goto-char (point-min))
	    (while (search-forward "<story>" nil t)
	      (narrow-to-region (point) (search-forward "</story>"))
	      (goto-char (point-min))
	      (re-search-forward "<title>\\([^<]+\\)</title>")
	      (setq description
		    (nnweb-decode-entities-string (match-string 1)))
	      (re-search-forward "<url>\\([^<]+\\)</url>")
	      (setq sid (match-string 1))
	      (string-match "sid=\\([0-9/]+\\)\\(.shtml\\|$\\)" sid)
	      (setq sid (match-string 1 sid))
	      (re-search-forward "<comments>\\([^<]+\\)</comments>")
	      (setq articles (string-to-number (match-string 1)))
	      (setq gname (concat description " (" sid ")"))
	      (if (setq elem (assoc gname nnslashdot-groups))
		  (setcar (cdr elem) articles)
		(push (list gname articles sid (current-time) nil)
		      nnslashdot-groups))
	      (goto-char (point-max))
	      (widen)))
	  ;; Then do the older groups.
	  (while (> (- nnslashdot-group-number number) 0)
	    (mm-with-unibyte-buffer
	      (let ((case-fold-search t))
		(nnweb-insert (format nnslashdot-active-url number) t)
		(goto-char (point-min))
		(while (re-search-forward
			"article.pl\\?sid=\\([^&]+\\).*<b>\\([^<]+\\)</b>"
			nil t)
		  (setq sid (match-string 1)
			description
			(nnweb-decode-entities-string (match-string 2)))
		  (forward-line 1)
		  (when (re-search-forward "<b>\\([0-9]+\\)</b>" nil t)
		    (setq articles (string-to-number (match-string 1))))
		  (setq gname (concat description " (" sid ")"))
		  (if (setq elem (assoc gname nnslashdot-groups))
		      (setcar (cdr elem) articles)
		    (push (list gname articles sid (current-time) nil)
			  nnslashdot-groups)))))
	    (incf number 30)))
      (search-failed (nnslashdot-lose why)))
    (nnslashdot-write-groups)
    (nnslashdot-generate-active)
    t))

(deffoo nnslashdot-request-newgroups (date &optional server)
  (nnslashdot-possibly-change-server nil server)
  (nnslashdot-generate-active)
  t)

(deffoo nnslashdot-request-post (&optional server)
  (nnslashdot-possibly-change-server nil server)
  (let ((sid (nnslashdot-sid-strip (message-fetch-field "newsgroups")))
	(subject (message-fetch-field "subject"))
	(references (car (last (split-string
				(message-fetch-field "references")))))
	body quoted pid)
    (string-match "%\\([0-9]+\\)@slashdot" references)
    (setq pid (match-string 1 references))
    (message-goto-body)
    (narrow-to-region (point) (progn (message-goto-signature) (point)))
    (goto-char (point-min))
    (while (not (eobp))
      (if (looking-at "> ")
	  (progn
	    (delete-region (point) (+ (point) 2))
	    (unless quoted
	      (insert "<blockquote>\n"))
	    (setq quoted t))
	(when quoted
	  (insert "</blockquote>\n")
	  (setq quoted nil)))
      (forward-line 1))
    (goto-char (point-min))
    (while (re-search-forward "^ *\n" nil t)
      (replace-match "<p>\n"))
    (widen)
    (when (message-goto-signature)
      (forward-line -1)
      (insert "<p>\n")
      (while (not (eobp))
	(end-of-line)
	(insert "<br>")
	(forward-line 1)))
    (message-goto-body)
    (setq body (buffer-substring (point) (point-max)))
    (erase-buffer)
    (nnweb-fetch-form
     "http://slashdot.org/comments.pl"
     `(("sid" . ,sid)
       ("pid" . ,pid)
       ("rlogin" . "userlogin")
       ("unickname" . ,nnslashdot-login-name)
       ("upasswd" . ,nnslashdot-password)
       ("postersubj" . ,subject)
       ("op" . "Submit")
       ("postercomment" . ,body)
       ("posttype" . "html")))))

(deffoo nnslashdot-request-delete-group (group &optional force server)
  (nnslashdot-possibly-change-server group server)
  (setq nnslashdot-groups (delq (assoc group nnslashdot-groups)
				nnslashdot-groups))
  (nnslashdot-write-groups))

(deffoo nnslashdot-request-close ()
  (setq nnslashdot-headers nil
	nnslashdot-groups nil))

(deffoo nnslashdot-request-expire-articles
    (articles group &optional server force)
  (nnslashdot-possibly-change-server group server)
  (let ((item (assoc group nnslashdot-groups)))
    (when item
      (if (fourth item)
	  (when (and (>= (length articles) (cadr item)) ;; All are expirable.
		     (nnmail-expired-article-p
		      group
		      (fourth item)
		      force))
	    (setq nnslashdot-groups (delq item nnslashdot-groups))
	    (nnslashdot-write-groups)
	    (setq articles nil)) ;; all expired.
	(setcdr (cddr item) (list (current-time)))
	(nnslashdot-write-groups))))
  articles)

(nnoo-define-skeleton nnslashdot)

;;; Internal functions

(defun nnslashdot-possibly-change-server (&optional group server)
  (nnslashdot-init server)
  (when (and server
	     (not (nnslashdot-server-opened server)))
    (nnslashdot-open-server server))
  (unless nnslashdot-groups
    (nnslashdot-read-groups)))

(defun nnslashdot-make-tuple (tuple n)
  (prog1
      tuple
    (while (> n 1)
      (unless (cdr tuple)
	(setcdr tuple (list nil)))
      (setq tuple (cdr tuple)
	    n (1- n)))))

(defun nnslashdot-read-groups ()
  (let ((file (expand-file-name "groups" nnslashdot-directory)))
    (when (file-exists-p file)
      (mm-with-unibyte-buffer
	(insert-file-contents file)
	(goto-char (point-min))
	(setq nnslashdot-groups (read (current-buffer))))
      (if (and nnslashdot-groups (< (length (car nnslashdot-groups)) 5))
	  (let ((groups nnslashdot-groups))
	    (while groups
	      (nnslashdot-make-tuple (car groups) 5)
	      (setq groups (cdr groups))))))))

(defun nnslashdot-write-groups ()
  (with-temp-file (expand-file-name "groups" nnslashdot-directory)
    (gnus-prin1 nnslashdot-groups)))

(defun nnslashdot-init (server)
  "Initialize buffers and such."
  (unless (file-exists-p nnslashdot-directory)
    (gnus-make-directory nnslashdot-directory))
  (unless (gnus-buffer-live-p nnslashdot-buffer)
    (setq nnslashdot-buffer
	  (save-excursion
	    (nnheader-set-temp-buffer
	     (format " *nnslashdot %s*" server))))
    (push nnslashdot-buffer gnus-buffers)))

(defun nnslashdot-date-to-date (sdate)
  (condition-case err
      (let ((elem (delete "" (split-string sdate))))
	(concat (substring (nth 0 elem) 0 3) " "
		(substring (nth 1 elem) 0 3) " "
		(substring (nth 2 elem) 0 2) " "
		(substring (nth 3 elem) 1 6) " "
		(format-time-string "%Y") " "
		(nth 4 elem)))
    (error "")))

(defun nnslashdot-generate-active ()
  (save-excursion
    (set-buffer nntp-server-buffer)
    (erase-buffer)
    (dolist (elem nnslashdot-groups)
      (insert (prin1-to-string (car elem))
	      " " (number-to-string (cadr elem)) " 1 y\n"))))

(defun nnslashdot-lose (why)
  (error "Slashdot HTML has changed; please get a new version of nnslashdot"))

(defalias 'nnslashdot-sid-strip 'identity)

(provide 'nnslashdot)

;;; arch-tag: aa73df7a-f7e6-4eef-bdea-5ce2f8c691b3
;;; nnslashdot.el ends here
