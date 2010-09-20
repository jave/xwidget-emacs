;;; nnimap.el --- IMAP interface for Gnus

;; Copyright (C) 2010 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;;         Simon Josefsson <simon@josefsson.org>

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

;; nnimap interfaces Gnus with IMAP servers.

;;; Code:

(eval-and-compile
  (require 'nnheader))

(eval-when-compile
  (require 'cl))

(require 'nnheader)
(require 'gnus-util)
(require 'gnus)
(require 'nnoo)
(require 'netrc)

(nnoo-declare nnimap)

(defvoo nnimap-address nil
  "The address of the IMAP server.")

(defvoo nnimap-server-port nil
  "The IMAP port used.
If nnimap-stream is `ssl', this will default to `imaps'.  If not,
it will default to `imap'.")

(defvoo nnimap-stream 'ssl
  "How nnimap will talk to the IMAP server.
Values are `ssl' and `network'.")

(defvoo nnimap-shell-program (if (boundp 'imap-shell-program)
				 (if (listp imap-shell-program)
				     (car imap-shell-program)
				   imap-shell-program)
			       "ssh %s imapd"))

(defvoo nnimap-inbox nil
  "The mail box where incoming mail arrives and should be split out of.")

(defvoo nnimap-expunge-inbox nil
  "If non-nil, expunge the inbox after fetching mail.
This is always done if the server supports UID EXPUNGE, but it's
not done by default on servers that doesn't support that command.")

(defvoo nnimap-authenticator nil
  "How nnimap authenticate itself to the server.
Possible choices are nil (use default methods) or `anonymous'.")

(defvoo nnimap-fetch-partial-articles nil
  "If non-nil, nnimap will fetch partial articles.
If t, nnimap will fetch only the first part.  If a string, it
will fetch all parts that have types that match that string.  A
likely value would be \"text/\" to automatically fetch all
textual parts.")

(defvoo nnimap-connection-alist nil)

(defvoo nnimap-current-infos nil)

(defvar nnimap-process nil)

(defvar nnimap-status-string "")

(defvar nnimap-split-download-body-default nil
  "Internal variable with default value for `nnimap-split-download-body'.")

(defstruct nnimap
  group process commands capabilities select-result newlinep)

(defvar nnimap-object nil)

(defvar nnimap-mark-alist
  '((read "\\Seen")
    (tick "\\Flagged")
    (reply "\\Answered")
    (expire "gnus-expire")
    (dormant "gnus-dormant")
    (score "gnus-score")
    (save "gnus-save")
    (download "gnus-download")
    (forward "gnus-forward")))

(defvar nnimap-split-methods nil)

(defun nnimap-buffer ()
  (nnimap-find-process-buffer nntp-server-buffer))

(deffoo nnimap-retrieve-headers (articles &optional group server fetch-old)
  (with-current-buffer nntp-server-buffer
    (erase-buffer)
    (when (nnimap-possibly-change-group group server)
      (with-current-buffer (nnimap-buffer)
	(nnimap-send-command "SELECT %S" (utf7-encode group t))
	(erase-buffer)
	(nnimap-wait-for-response
	 (nnimap-send-command
	  "UID FETCH %s %s"
	  (nnimap-article-ranges (gnus-compress-sequence articles))
	  (format "(UID RFC822.SIZE BODYSTRUCTURE %s)"
		  (format
		   (if (member "IMAP4REV1"
			       (nnimap-capabilities nnimap-object))
		       "BODY.PEEK[HEADER.FIELDS %s]"
		     "RFC822.HEADER.LINES %s")
		   (append '(Subject From Date Message-Id
				     References In-Reply-To Xref)
			   nnmail-extra-headers))))
	 t)
	(nnimap-transform-headers))
      (insert-buffer-substring
       (nnimap-find-process-buffer (current-buffer))))
    t))

(defun nnimap-transform-headers ()
  (goto-char (point-min))
  (let (article bytes lines size)
    (block nil
      (while (not (eobp))
	(while (not (looking-at "^\\* [0-9]+ FETCH.*UID \\([0-9]+\\)"))
	  (delete-region (point) (progn (forward-line 1) (point)))
	  (when (eobp)
	    (return)))
	(setq article (match-string 1)
	      bytes (nnimap-get-length)
	      lines nil)
	(beginning-of-line)
	(setq size
	      (and (re-search-forward "RFC822.SIZE \\([0-9]+\\)"
				      (line-end-position)
				      t)
		   (match-string 1)))
	(beginning-of-line)
	(when (search-forward "BODYSTRUCTURE" (line-end-position) t)
	  (let ((structure (ignore-errors (read (current-buffer)))))
	    (while (and (consp structure)
			(not (stringp (car structure))))
	      (setq structure (car structure)))
	    (setq lines (nth 7 structure))))
	(delete-region (line-beginning-position) (line-end-position))
	(insert (format "211 %s Article retrieved." article))
	(forward-line 1)
	(when size
	  (insert (format "Chars: %s\n" size)))
	(when lines
	  (insert (format "Lines: %s\n" lines)))
	(re-search-forward "^\r$")
	(delete-region (line-beginning-position) (line-end-position))
	(insert ".")
	(forward-line 1)))))

(defun nnimap-get-length ()
  (and (re-search-forward "{\\([0-9]+\\)}" (line-end-position) t)
       (string-to-number (match-string 1))))

(defun nnimap-article-ranges (ranges)
  (let (result)
    (cond
     ((numberp ranges)
      (number-to-string ranges))
     ((numberp (cdr ranges))
      (format "%d:%d" (car ranges) (cdr ranges)))
     (t
      (dolist (elem ranges)
	(push
	 (if (consp elem)
	     (format "%d:%d" (car elem) (cdr elem))
	   (number-to-string elem))
	 result))
      (mapconcat #'identity (nreverse result) ",")))))

(deffoo nnimap-open-server (server &optional defs)
  (if (nnimap-server-opened server)
      t
    (unless (assq 'nnimap-address defs)
      (setq defs (append defs (list (list 'nnimap-address server)))))
    (nnoo-change-server 'nnimap server defs)
    (or (nnimap-find-connection nntp-server-buffer)
	(nnimap-open-connection nntp-server-buffer))))

(defun nnimap-make-process-buffer (buffer)
  (with-current-buffer
      (generate-new-buffer (format "*nnimap %s %s %s*"
				   nnimap-address nnimap-server-port
				   (gnus-buffer-exists-p buffer)))
    (mm-disable-multibyte)
    (buffer-disable-undo)
    (gnus-add-buffer)
    (set (make-local-variable 'after-change-functions) nil)
    (set (make-local-variable 'nnimap-object) (make-nnimap))
    (push (list buffer (current-buffer)) nnimap-connection-alist)
    (current-buffer)))

(defun nnimap-open-shell-stream (name buffer host port)
  (let ((process-connection-type nil))
    (start-process name buffer shell-file-name
		   shell-command-switch
		   (format-spec
		    nnimap-shell-program
		    (format-spec-make
		     ?s host
		     ?p port)))))

(defun nnimap-credentials (address ports)
  (let (port credentials)
    ;; Request the credentials from all ports, but only query on the
    ;; last port if all the previous ones have failed.
    (while (and (null credentials)
		(setq port (pop ports)))
      (setq credentials
	    (auth-source-user-or-password
	     '("login" "password") address port nil (null ports))))
    credentials))

(defun nnimap-open-connection (buffer)
  (with-current-buffer (nnimap-make-process-buffer buffer)
    (let* ((coding-system-for-read 'binary)
	   (coding-system-for-write 'binary)
	   (ports
	    (cond
	     ((eq nnimap-stream 'network)
	      (open-network-stream
	       "*nnimap*" (current-buffer) nnimap-address
	       (or nnimap-server-port
		   (if (netrc-find-service-number "imap")
		       "imap"
		     "143")))
	      '("143" "imap"))
	     ((eq nnimap-stream 'shell)
	      (nnimap-open-shell-stream
	       "*nnimap*" (current-buffer) nnimap-address
	       (or nnimap-server-port "imap"))
	      '("imap"))
	     ((eq nnimap-stream 'ssl)
	      (open-tls-stream
	       "*nnimap*" (current-buffer) nnimap-address
	       (or nnimap-server-port
		   (if (netrc-find-service-number "imaps")
		       "imaps"
		     "993")))
	      '("143" "993" "imap" "imaps"))))
	   connection-result login-result credentials)
      (setf (nnimap-process nnimap-object)
	    (get-buffer-process (current-buffer)))
      (when (and (nnimap-process nnimap-object)
		 (memq (process-status (nnimap-process nnimap-object))
		       '(open run)))
	(gnus-set-process-query-on-exit-flag (nnimap-process nnimap-object) nil)
	(when (setq connection-result (nnimap-wait-for-connection))
	  (unless (equal connection-result "PREAUTH")
	    (if (not (setq credentials
			   (if (eq nnimap-authenticator 'anonymous)
			       (list "anonymous"
				     (message-make-address))
			     (nnimap-credentials
			      nnimap-address
			      (if nnimap-server-port
				  (cons (format "%s" nnimap-server-port) ports)
				ports)))))
		(setq nnimap-object nil)
	      (setq login-result (nnimap-command "LOGIN %S %S"
						 (car credentials)
						 (cadr credentials)))
	      (unless (car login-result)
		(delete-process (nnimap-process nnimap-object))
		(setq nnimap-object nil))))
	  (when nnimap-object
	    (setf (nnimap-capabilities nnimap-object)
		  (mapcar
		   #'upcase
		   (or (nnimap-find-parameter "CAPABILITY" (cdr login-result))
		       (nnimap-find-parameter
			"CAPABILITY" (cdr (nnimap-command "CAPABILITY"))))))
	    (when (member "QRESYNC" (nnimap-capabilities nnimap-object))
	      (nnimap-command "ENABLE QRESYNC"))
	    t))))))

(defun nnimap-find-parameter (parameter elems)
  (let (result)
    (dolist (elem elems)
      (cond
       ((equal (car elem) parameter)
	(setq result (cdr elem)))
       ((and (equal (car elem) "OK")
	     (consp (cadr elem))
	     (equal (caadr elem) parameter))
	(setq result (cdr (cadr elem))))))
    result))

(deffoo nnimap-close-server (&optional server)
  t)

(deffoo nnimap-request-close ()
  t)

(deffoo nnimap-server-opened (&optional server)
  (and (nnoo-current-server-p 'nnimap server)
       nntp-server-buffer
       (gnus-buffer-live-p nntp-server-buffer)
       (nnimap-find-connection nntp-server-buffer)))

(deffoo nnimap-status-message (&optional server)
  nnimap-status-string)

(deffoo nnimap-request-article (article &optional group server to-buffer)
  (with-current-buffer nntp-server-buffer
    (let ((result (nnimap-possibly-change-group group server))
	  parts)
      (when (stringp article)
	(setq article (nnimap-find-article-by-message-id group article)))
      (when (and result
		 article)
	(erase-buffer)
	(with-current-buffer (nnimap-buffer)
	  (erase-buffer)
	  (when nnimap-fetch-partial-articles
	    (if (eq nnimap-fetch-partial-articles t)
		(setq parts '(1))
	      (nnimap-command "UID FETCH %d (BODYSTRUCTURE)" article)
	      (goto-char (point-min))
	      (when (re-search-forward "FETCH.*BODYSTRUCTURE" nil t)
		(let ((structure (ignore-errors (read (current-buffer)))))
		  (setq parts (nnimap-find-wanted-parts structure))))))
	  (setq result
		(nnimap-command
		 (if (member "IMAP4REV1" (nnimap-capabilities nnimap-object))
		     "UID FETCH %d BODY.PEEK[]"
		   "UID FETCH %d RFC822.PEEK")
		 article))
	  ;; Check that we really got an article.
	  (goto-char (point-min))
	  (unless (looking-at "\\* [0-9]+ FETCH")
	    (setq result nil)))
	(let ((buffer (nnimap-find-process-buffer (current-buffer))))
	  (when (car result)
	    (with-current-buffer (or to-buffer nntp-server-buffer)
	      (insert-buffer-substring buffer)
	      (goto-char (point-min))
	      (let ((bytes (nnimap-get-length)))
		(delete-region (line-beginning-position)
			       (progn (forward-line 1) (point)))
		(goto-char (+ (point) bytes))
		(delete-region (point) (point-max))
		(nnheader-ms-strip-cr))
	      (cons group article))))))))

(defun nnimap-find-wanted-parts (structure)
  (message-flatten-list (nnimap-find-wanted-parts-1 structure "")))

(defun nnimap-find-wanted-parts-1 (structure prefix)
  (let ((num 1)
	parts)
    (while (consp (car structure))
      (let ((sub (pop structure)))
	(if (consp (car sub))
	    (push (nnimap-find-wanted-parts-1
		   sub (if (string= prefix "")
			   (number-to-string num)
			 (format "%s.%s" prefix num)))
		  parts)
	  (let ((type (format "%s/%s" (nth 0 sub) (nth 1 sub))))
	    (when (string-match nnimap-fetch-partial-articles type)
	      (push (if (string= prefix "")
			(number-to-string num)
		      (format "%s.%s" prefix num))
		    parts)))
	  (incf num))))
    (nreverse parts)))

(deffoo nnimap-request-group (group &optional server dont-check info)
  (let ((result (nnimap-possibly-change-group group server))
	articles active marks high low)
    (with-current-buffer nntp-server-buffer
      (when result
	(if (and dont-check
		 (setq active (nth 2 (assoc group nnimap-current-infos))))
	    (insert (format "211 %d %d %d %S\n"
			    (- (cdr active) (car active))
			    (car active)
			    (cdr active)
			    group))
	  (with-current-buffer (nnimap-buffer)
	    (erase-buffer)
	    (let ((group-sequence
		   (nnimap-send-command "SELECT %S" (utf7-encode group)))
		  (flag-sequence
		   (nnimap-send-command "UID FETCH 1:* FLAGS")))
	      (nnimap-wait-for-response flag-sequence)
	      (setq marks
		    (nnimap-flags-to-marks
		     (nnimap-parse-flags
		      (list (list group-sequence flag-sequence 1 group)))))
	      (when info
		(nnimap-update-infos marks (list info)))
	      (goto-char (point-max))
	      (cond
	       (marks
		(setq high (nth 3 (car marks))
		      low (nth 4 (car marks))))
	       ((re-search-backward "UIDNEXT \\([0-9]+\\)" nil t)
		(setq high (string-to-number (match-string 1))
		      low 1)))))
	  (erase-buffer)
	  (insert
	   (format
	    "211 %d %d %d %S\n"
	    (1+ (- high low))
	    low high group))))
      t)))

(deffoo nnimap-request-delete-group (group &optional force server)
  (when (nnimap-possibly-change-group nil server)
    (with-current-buffer (nnimap-buffer)
      (car (nnimap-command "DELETE %S" (utf7-encode group))))))

(defun nnimap-get-flags (spec)
  (let ((articles nil)
	elems)
    (with-current-buffer (nnimap-buffer)
      (erase-buffer)
      (nnimap-wait-for-response (nnimap-send-command
				 "UID FETCH %s FLAGS" spec))
      (goto-char (point-min))
      (while (re-search-forward "^\\* [0-9]+ FETCH (\\(.*\\))" nil t)
	(setq elems (nnimap-parse-line (match-string 1)))
	(push (cons (string-to-number (cadr (member "UID" elems)))
		    (cadr (member "FLAGS" elems)))
	      articles)))
    (nreverse articles)))

(deffoo nnimap-close-group (group &optional server)
  t)

(deffoo nnimap-request-move-article (article group server accept-form
					     &optional last internal-move-group)
  (when (nnimap-possibly-change-group group server)
    ;; If the move is internal (on the same server), just do it the easy
    ;; way.
    (let ((message-id (message-field-value "message-id")))
      (if internal-move-group
	  (let ((result
		 (with-current-buffer (nnimap-buffer)
		   (nnimap-command "UID COPY %d %S"
				   article
				   (utf7-encode internal-move-group t)))))
	    (when (car result)
	      (nnimap-delete-article article)
	      (cons internal-move-group
		    (nnimap-find-article-by-message-id
		     internal-move-group message-id))))
	(with-temp-buffer
	  (when (nnimap-request-article article group server (current-buffer))
	    (let ((result (eval accept-form)))
	      (when result
		(nnimap-delete-article article)
		result))))))))

(deffoo nnimap-request-expire-articles (articles group &optional server force)
  (cond
   ((not (nnimap-possibly-change-group group server))
    articles)
   (force
    (unless (nnimap-delete-article articles)
      (message "Article marked for deletion, but not expunged."))
    nil)
   (t
    articles)))

(defun nnimap-find-article-by-message-id (group message-id)
  (when (nnimap-possibly-change-group group nil)
    (with-current-buffer (nnimap-buffer)
      (let ((result
	     (nnimap-command "UID SEARCH HEADER Message-Id %S" message-id))
	    article)
	(when (car result)
	  ;; Select the last instance of the message in the group.
	  (and (setq article
		     (car (last (assoc "SEARCH" (cdr result)))))
	       (string-to-number article)))))))

(defun nnimap-delete-article (articles)
  (with-current-buffer (nnimap-buffer)
    (nnimap-command "UID STORE %s +FLAGS.SILENT (\\Deleted)"
		    (nnimap-article-ranges articles))
    (when (member "UIDPLUS" (nnimap-capabilities nnimap-object))
      (nnimap-send-command "UID EXPUNGE %s"
			   (nnimap-article-ranges articles))
      t)))

(deffoo nnimap-request-scan (&optional group server)
  (when (and (nnimap-possibly-change-group nil server)
	     (equal group nnimap-inbox)
	     nnimap-inbox
	     nnimap-split-methods)
    (nnimap-split-incoming-mail)))

(defun nnimap-marks-to-flags (marks)
  (let (flags flag)
    (dolist (mark marks)
      (when (setq flag (cadr (assq mark nnimap-mark-alist)))
	(push flag flags)))
    flags))

(deffoo nnimap-request-set-mark (group actions &optional server)
  (when (nnimap-possibly-change-group group server)
    (let (sequence)
      (with-current-buffer (nnimap-buffer)
	;; Just send all the STORE commands without waiting for
	;; response.  If they're successful, they're successful.
	(dolist (action actions)
	  (destructuring-bind (range action marks) action
	    (let ((flags (nnimap-marks-to-flags marks)))
	      (when flags
		(setq sequence (nnimap-send-command
				"UID STORE %s %sFLAGS.SILENT (%s)"
				(nnimap-article-ranges range)
				(if (eq action 'del)
				    "-"
				  "+")
				(mapconcat #'identity flags " ")))))))
	;; Wait for the last command to complete to avoid later
	;; syncronisation problems with the stream.
	(when sequence
	  (nnimap-wait-for-response sequence))))))

(deffoo nnimap-request-accept-article (group &optional server last)
  (when (nnimap-possibly-change-group nil server)
    (nnmail-check-syntax)
    (let ((message (buffer-string))
	  (message-id (message-field-value "message-id"))
	  sequence)
      (with-current-buffer (nnimap-buffer)
	(setq sequence (nnimap-send-command
			"APPEND %S {%d}" (utf7-encode group t)
			(length message)))
	(process-send-string (get-buffer-process (current-buffer)) message)
	(process-send-string (get-buffer-process (current-buffer))
			     (if (nnimap-newlinep nnimap-object)
				 "\n"
			       "\r\n"))
	(let ((result (nnimap-get-response sequence)))
	  (when result
	    (cons group
		  (nnimap-find-article-by-message-id group message-id))))))))

(defun nnimap-add-cr ()
  (goto-char (point-min))
  (while (re-search-forward "\r?\n" nil t)
    (replace-match "\r\n" t t)))

(defun nnimap-get-groups ()
  (let ((result (nnimap-command "LIST \"\" \"*\""))
	groups)
    (when (car result)
      (dolist (line (cdr result))
	(when (and (equal (car line) "LIST")
		   (not (and (caadr line)
			     (string-match "noselect" (caadr line)))))
	  (push (car (last line)) groups)))
      (nreverse groups))))

(deffoo nnimap-request-list (&optional server)
  (nnimap-possibly-change-group nil server)
  (with-current-buffer nntp-server-buffer
    (erase-buffer)
    (let ((groups
	   (with-current-buffer (nnimap-buffer)
	     (nnimap-get-groups)))
	  sequences responses)
      (when groups
	(with-current-buffer (nnimap-buffer)
	  (dolist (group groups)
	    (push (list (nnimap-send-command "EXAMINE %S" (utf7-encode group t))
			group)
		  sequences))
	  (nnimap-wait-for-response (caar sequences))
	  (setq responses
		(nnimap-get-responses (mapcar #'car sequences))))
	(dolist (response responses)
	  (let* ((sequence (car response))
		 (response (cadr response))
		 (group (cadr (assoc sequence sequences))))
	    (when (and group
		       (equal (caar response) "OK"))
	      (let ((uidnext (nnimap-find-parameter "UIDNEXT" response))
		    highest exists)
		(dolist (elem response)
		  (when (equal (cadr elem) "EXISTS")
		    (setq exists (string-to-number (car elem)))))
		(when uidnext
		  (setq highest (1- (string-to-number (car uidnext)))))
		(cond
		 ((null highest)
		  (insert (format "%S 0 1 y\n" (utf7-decode group t))))
		 ((zerop exists)
		  ;; Empty group.
		  (insert (format "%S %d %d y\n"
				  (utf7-decode group t) highest (1+ highest))))
		 (t
		  ;; Return the widest possible range.
		  (insert (format "%S %d 1 y\n" (utf7-decode group t)
				  (or highest exists)))))))))
	t))))

(deffoo nnimap-retrieve-group-data-early (server infos)
  (when (nnimap-possibly-change-group nil server)
    (with-current-buffer (nnimap-buffer)
      ;; QRESYNC handling isn't implemented.
      (let ((qresyncp (member "notQRESYNC" (nnimap-capabilities nnimap-object)))
	    marks groups sequences)
	;; Go through the infos and gather the data needed to know
	;; what and how to request the data.
	(dolist (info infos)
	  (setq marks (gnus-info-marks info))
	  (push (list (gnus-group-real-name (gnus-info-group info))
		      (cdr (assq 'active marks))
		      (cdr (assq 'uid marks)))
		groups))
	;; Then request the data.
	(erase-buffer)
	(dolist (elem groups)
	  (if (and qresyncp
		   (nth 2 elem))
	      (push
	       (list 'qresync
		     (nnimap-send-command "EXAMINE %S (QRESYNC (%s %s))"
					  (car elem)
					  (car (nth 2 elem))
					  (cdr (nth 2 elem)))
		     nil
		     (car elem))
	       sequences)
	    (let ((start
		   (if (nth 1 elem)
		       ;; Fetch the last 100 flags.
		       (max 1 (- (cdr (nth 1 elem)) 100))
		     1)))
	      (push (list (nnimap-send-command "EXAMINE %S" (car elem))
			  (nnimap-send-command "UID FETCH %d:* FLAGS" start)
			  start
			  (car elem))
		    sequences))))
	sequences))))

(deffoo nnimap-finish-retrieve-group-infos (server infos sequences)
  (when (and sequences
	     (nnimap-possibly-change-group nil server))
    (with-current-buffer (nnimap-buffer)
      ;; Wait for the final data to trickle in.
      (nnimap-wait-for-response (cadar sequences))
      ;; Now we should have all the data we need, no matter whether
      ;; we're QRESYNCING, fetching all the flags from scratch, or
      ;; just fetching the last 100 flags per group.
      (nnimap-update-infos (nnimap-flags-to-marks
			    (nnimap-parse-flags
			     (nreverse sequences)))
			   infos)
      ;; Finally, just return something resembling an active file in
      ;; the nntp buffer, so that the agent can save the info, too.
      (with-current-buffer nntp-server-buffer
	(erase-buffer)
	(dolist (info infos)
	  (let* ((group (gnus-info-group info))
		 (active (gnus-active group)))
	    (when active
	      (insert (format "%S %d %d y\n"
			      (gnus-group-real-name group)
			      (cdr active)
			      (car active))))))))))

(defun nnimap-update-infos (flags infos)
  (dolist (info infos)
    (let ((group (gnus-group-real-name (gnus-info-group info))))
      (nnimap-update-info info (cdr (assoc group flags))))))

(defun nnimap-update-info (info marks)
  (when marks
    (destructuring-bind (existing flags high low uidnext start-article) marks
      (let ((group (gnus-info-group info))
	    (completep (and start-article
			    (= start-article 1))))
	;; First set the active ranges based on high/low.
	(if (or completep
		(not (gnus-active group)))
	    (gnus-set-active group
			     (if high
				 (cons low high)
			       ;; No articles in this group.
			       (cons (1- uidnext) uidnext)))
	  (setcdr (gnus-active group) high))
	;; Then update the list of read articles.
	(let* ((unread
		(gnus-compress-sequence
		 (gnus-set-difference
		  (gnus-set-difference
		   existing
		   (cdr (assoc "\\Seen" flags)))
		  (cdr (assoc "\\Flagged" flags)))))
	       (read (gnus-range-difference
		      (cons start-article high) unread)))
	  (when (> start-article 1)
	    (setq read
		  (gnus-range-nconcat
		   (if (> start-article 1)
		       (gnus-sorted-range-intersection
			(cons 1 (1- start-article))
			(gnus-info-read info))
		     (gnus-info-read info))
		   read)))
	  (gnus-info-set-read info read)
	  ;; Update the marks.
	  (setq marks (gnus-info-marks info))
	  ;; Note the active level for the next run-through.
	  (let ((active (assq 'active marks)))
	    (if active
		(setcdr active (gnus-active group))
	      (push (cons 'active (gnus-active group)) marks)))
	  (dolist (type (cdr nnimap-mark-alist))
	    (let ((old-marks (assoc (car type) marks))
		  (new-marks (gnus-compress-sequence
			      (cdr (assoc (cadr type) flags)))))
	      (setq marks (delq old-marks marks))
	      (pop old-marks)
	      (when (and old-marks
			 (> start-article 1))
		(setq old-marks (gnus-range-difference
				 old-marks
				 (cons start-article high)))
		(setq new-marks (gnus-range-nconcat old-marks new-marks)))
	      (when new-marks
		(push (cons (car type) new-marks) marks)))
	    (gnus-info-set-marks info marks t)
	    (nnimap-store-info info (gnus-active group))))))))

(defun nnimap-store-info (info active)
  (let* ((group (gnus-group-real-name (gnus-info-group info)))
	 (entry (assoc group nnimap-current-infos)))
    (if entry
	(setcdr entry (list info active))
      (push (list group info active) nnimap-current-infos))))

(defun nnimap-flags-to-marks (groups)
  (let (data group totalp uidnext articles start-article mark)
    (dolist (elem groups)
      (setq group (car elem)
	    uidnext (cadr elem)
	    start-article (caddr elem)
	    articles (cdddr elem))
      (let ((high (caar articles))
	    marks low existing)
	(dolist (article articles)
	  (setq low (car article))
	  (push (car article) existing)
	  (dolist (flag (cdr article))
	    (setq mark (assoc flag marks))
	    (if (not mark)
		(push (list flag (car article)) marks)
	      (setcdr mark (cons (car article) (cdr mark)))))
	  (push (list group existing marks high low uidnext start-article)
		data))))
    data))

(defun nnimap-parse-flags (sequences)
  (goto-char (point-min))
  (let (start end articles groups uidnext elems)
    (dolist (elem sequences)
      (destructuring-bind (group-sequence flag-sequence totalp group) elem
	;; The EXAMINE was successful.
	(when (and (search-forward (format "\n%d OK " group-sequence) nil t)
		   (progn
		     (forward-line 1)
		     (setq start (point))
		     (if (re-search-backward "UIDNEXT \\([0-9]+\\)"
					       (or end (point-min)) t)
			 (setq uidnext (string-to-number (match-string 1)))
		       (setq uidnext nil))
		     (goto-char start))
		   ;; The UID FETCH FLAGS was successful.
		   (search-forward (format "\n%d OK " flag-sequence) nil t))
	  (setq end (point))
	  (goto-char start)
	  (while (re-search-forward "^\\* [0-9]+ FETCH (\\(.*\\))" end t)
	    (setq elems (nnimap-parse-line (match-string 1)))
	    (push (cons (string-to-number (cadr (member "UID" elems)))
			(cadr (member "FLAGS" elems)))
		  articles))
	  (push (nconc (list group uidnext totalp) articles) groups)
	  (setq articles nil))))
    groups))

(defun nnimap-find-process-buffer (buffer)
  (cadr (assoc buffer nnimap-connection-alist)))

(deffoo nnimap-request-post (&optional server)
  (setq nnimap-status-string "Read-only server")
  nil)

(defun nnimap-possibly-change-group (group server)
  (let ((open-result t))
    (when (and server
	       (not (nnimap-server-opened server)))
      (setq open-result (nnimap-open-server server)))
    (cond
     ((not open-result)
      nil)
     ((not group)
      t)
     (t
      (with-current-buffer (nnimap-buffer)
	(if (equal group (nnimap-group nnimap-object))
	    t
	  (let ((result (nnimap-command "SELECT %S" (utf7-encode group t))))
	    (when (car result)
	      (setf (nnimap-group nnimap-object) group
		    (nnimap-select-result nnimap-object) result)
	      result))))))))

(defun nnimap-find-connection (buffer)
  "Find the connection delivering to BUFFER."
  (let ((entry (assoc buffer nnimap-connection-alist)))
    (when entry
      (if (and (buffer-name (cadr entry))
	       (get-buffer-process (cadr entry))
	       (memq (process-status (get-buffer-process (cadr entry)))
		     '(open run)))
	  (get-buffer-process (cadr entry))
	(setq nnimap-connection-alist (delq entry nnimap-connection-alist))
	nil))))

(defvar nnimap-sequence 0)

(defun nnimap-send-command (&rest args)
  (process-send-string
   (get-buffer-process (current-buffer))
   (nnimap-log-command
    (format "%d %s%s\n"
	    (incf nnimap-sequence)
	    (apply #'format args)
	    (if (nnimap-newlinep nnimap-object)
		""
	      "\r"))))
  nnimap-sequence)

(defun nnimap-log-command (command)
  (with-current-buffer (get-buffer-create "*imap log*")
    (goto-char (point-max))
    (insert (format-time-string "%H:%M:%S") " " command))
  command)

(defun nnimap-command (&rest args)
  (erase-buffer)
  (let* ((sequence (apply #'nnimap-send-command args))
	 (response (nnimap-get-response sequence)))
    (if (equal (caar response) "OK")
	(cons t response)
      (nnheader-report 'nnimap "%s"
		       (mapconcat (lambda (a)
				    (format "%s" a))
				  (car response) " "))
      nil)))

(defun nnimap-get-response (sequence)
  (nnimap-wait-for-response sequence)
  (nnimap-parse-response))

(defun nnimap-wait-for-connection ()
  (let ((process (get-buffer-process (current-buffer))))
    (goto-char (point-min))
    (while (and (memq (process-status process)
		      '(open run))
		(not (re-search-forward "^\\* .*\n" nil t)))
      (nnheader-accept-process-output process)
      (goto-char (point-min)))
    (forward-line -1)
    (and (looking-at "\\* \\([A-Z0-9]+\\)")
	 (match-string 1))))

(defun nnimap-wait-for-response (sequence &optional messagep)
  (let ((process (get-buffer-process (current-buffer))))
    (goto-char (point-max))
    (while (and (memq (process-status process)
		      '(open run))
		(not (re-search-backward (format "^%d .*\n" sequence)
					 (max (point-min) (- (point) 500))
					 t)))
      (when messagep
	(message "Read %dKB" (/ (buffer-size) 1000)))
      (nnheader-accept-process-output process)
      (goto-char (point-max)))))

(defun nnimap-parse-response ()
  (let ((lines (split-string (nnimap-last-response-string) "\r\n" t))
	result)
    (dolist (line lines)
      (push (cdr (nnimap-parse-line line)) result))
    ;; Return the OK/error code first, and then all the "continuation
    ;; lines" afterwards.
    (cons (pop result)
	  (nreverse result))))

;; Parse an IMAP response line lightly.  They look like
;; "* OK [UIDVALIDITY 1164213559] UIDs valid", typically, so parse
;; the lines into a list of strings and lists of string.
(defun nnimap-parse-line (line)
  (let (char result)
    (with-temp-buffer
      (insert line)
      (goto-char (point-min))
      (while (not (eobp))
	(if (eql (setq char (following-char)) ? )
	    (forward-char 1)
	  (push
	   (cond
	    ((eql char ?\[)
	     (split-string (buffer-substring
			    (1+ (point)) (1- (search-forward "]")))))
	    ((eql char ?\()
	     (split-string (buffer-substring
			    (1+ (point)) (1- (search-forward ")")))))
	    ((eql char ?\")
	     (forward-char 1)
	     (buffer-substring (point) (1- (search-forward "\""))))
	    (t
	     (buffer-substring (point) (if (search-forward " " nil t)
					   (1- (point))
					 (goto-char (point-max))))))
	   result)))
      (nreverse result))))

(defun nnimap-last-response-string ()
  (save-excursion
    (forward-line 1)
    (let ((end (point)))
      (forward-line -1)
      (when (not (bobp))
	(forward-line -1)
	(while (and (not (bobp))
		    (eql (following-char) ?*))
	  (forward-line -1))
	(unless (eql (following-char) ?*)
	  (forward-line 1)))
      (buffer-substring (point) end))))

(defun nnimap-get-responses (sequences)
  (let (responses)
    (dolist (sequence sequences)
      (goto-char (point-min))
      (when (re-search-forward (format "^%d " sequence) nil t)
	(push (list sequence (nnimap-parse-response))
	      responses)))
    responses))

(defvar nnimap-incoming-split-list nil)

(defun nnimap-fetch-inbox (articles)
  (erase-buffer)
  (nnimap-wait-for-response
   (nnimap-send-command
    "UID FETCH %s %s"
    (nnimap-article-ranges articles)
    (format "(UID %s%s)"
	    (format
	     (if (member "IMAP4REV1"
			 (nnimap-capabilities nnimap-object))
		 "BODY.PEEK[HEADER] BODY.PEEK"
	       "RFC822.PEEK"))
	    (if nnimap-split-download-body-default
		"[]"
	      "[1]")))
   t))

(defun nnimap-split-incoming-mail ()
  (with-current-buffer (nnimap-buffer)
    (let ((nnimap-incoming-split-list nil)
	  (nnmail-split-methods nnimap-split-methods)
	  (nnmail-inhibit-default-split-group t)
	  (groups (nnimap-get-groups))
	  new-articles)
      (erase-buffer)
      (nnimap-command "SELECT %S" nnimap-inbox)
      (setq new-articles (nnimap-new-articles (nnimap-get-flags "1:*")))
      (when new-articles
	(nnimap-fetch-inbox new-articles)
	(nnimap-transform-split-mail)
	(nnheader-ms-strip-cr)
	(nnmail-cache-open)
	(nnmail-split-incoming (current-buffer)
			       #'nnimap-save-mail-spec
			       nil nil
			       #'nnimap-dummy-active-number)
	(when nnimap-incoming-split-list
	  (let ((specs (nnimap-make-split-specs nnimap-incoming-split-list))
		sequences)
	    ;; Create any groups that doesn't already exist on the
	    ;; server first.
	    (dolist (spec specs)
	      (unless (member (car spec) groups)
		(nnimap-command "CREATE %S" (utf7-encode (car spec) t))))
	    ;; Then copy over all the messages.
	    (erase-buffer)
	    (dolist (spec specs)
	      (let ((group (car spec))
		    (ranges (cdr spec)))
		(push (list (nnimap-send-command "UID COPY %s %S"
						 (nnimap-article-ranges ranges)
						 (utf7-encode group t))
			    ranges)
		      sequences)))
	    ;; Wait for the last COPY response...
	    (when sequences
	      (nnimap-wait-for-response (caar sequences))
	      ;; And then mark the successful copy actions as deleted,
	      ;; and possibly expunge them.
	      (nnimap-mark-and-expunge-incoming
	       (nnimap-parse-copied-articles sequences)))))))))

(defun nnimap-mark-and-expunge-incoming (range)
  (when range
    (setq range (nnimap-article-ranges range))
    (nnimap-send-command
     "UID STORE %s +FLAGS.SILENT (\\Deleted)" range)
    (cond
     ;; If the server supports it, we now delete the message we have
     ;; just copied over.
     ((member "UIDPLUS" (nnimap-capabilities nnimap-object))
      (nnimap-send-command "UID EXPUNGE %s" range))
     ;; If it doesn't support UID EXPUNGE, then we only expunge if the
     ;; user has configured it.
     (nnimap-expunge-inbox
      (nnimap-send-command "EXPUNGE")))))

(defun nnimap-parse-copied-articles (sequences)
  (let (sequence copied range)
    (goto-char (point-min))
    (while (re-search-forward "^\\([0-9]+\\) OK " nil t)
      (setq sequence (string-to-number (match-string 1)))
      (when (setq range (cadr (assq sequence sequences)))
	(push (gnus-uncompress-range range) copied)))
    (gnus-compress-sequence (sort (apply #'nconc copied) #'<))))

(defun nnimap-new-articles (flags)
  (let (new)
    (dolist (elem flags)
      (when (or (null (cdr elem))
		(and (not (member "\\Deleted" (cdr elem)))
		     (not (member "\\Seen" (cdr elem)))))
	(push (car elem) new)))
    (gnus-compress-sequence (nreverse new))))

(defun nnimap-make-split-specs (list)
  (let ((specs nil)
	entry)
    (dolist (elem list)
      (destructuring-bind (article spec) elem
	(dolist (group (delete nil (mapcar #'car spec)))
	  (unless (setq entry (assoc group specs))
	    (push (setq entry (list group)) specs))
	  (setcdr entry (cons article (cdr entry))))))
    (dolist (entry specs)
      (setcdr entry (gnus-compress-sequence (sort (cdr entry) #'<))))
    specs))

(defun nnimap-transform-split-mail ()
  (goto-char (point-min))
  (let (article bytes)
    (block nil
      (while (not (eobp))
	(while (not (looking-at "^\\* [0-9]+ FETCH.*UID \\([0-9]+\\)"))
	  (delete-region (point) (progn (forward-line 1) (point)))
	  (when (eobp)
	    (return)))
	(setq article (match-string 1)
	      bytes (nnimap-get-length))
	(delete-region (line-beginning-position) (line-end-position))
	;; Insert MMDF separator, and a way to remember what this
	;; article UID is.
	(insert (format "\^A\^A\^A\^A\n\nX-nnimap-article: %s" article))
	(forward-char (1+ bytes))
	(setq bytes (nnimap-get-length))
	(delete-region (line-beginning-position) (line-end-position))
	(forward-char (1+ bytes))
	(delete-region (line-beginning-position) (line-end-position))))))

(defun nnimap-dummy-active-number (group &optional server)
  1)

(defun nnimap-save-mail-spec (group-art &optional server full-nov)
  (let (article)
    (goto-char (point-min))
    (if (not (re-search-forward "X-nnimap-article: \\([0-9]+\\)" nil t))
	(error "Invalid nnimap mail")
      (setq article (string-to-number (match-string 1))))
    (push (list article group-art)
	  nnimap-incoming-split-list)))

(provide 'nnimap)

;;; nnimap.el ends here
