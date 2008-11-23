;;; org-attach.el --- Manage file attachments to org-mode tasks

;; Copyright (C) 2008 Free Software Foundation, Inc.

;; Author: John Wiegley <johnw@newartisans.com>
;; Keywords: org data task
;; Version: 6.13

;; This file is part of GNU Emacs.
;;
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

;; See the Org-mode manual for information on how to use it.
;;
;; Attachments are managed in a special directory called "data", which
;; lives in the directory given by `org-directory'.  If this data
;; directory is initialized as a Git repository, then org-attach will
;; automatically commit changes when it sees them.
;;
;; Attachment directories are identified using a UUID generated for the
;; task which has the attachments.  These are added as property to the
;; task when necessary, and should not be deleted or changed by the
;; user, ever.  UUIDs are generated by a mechanism defined in the variable
;; `org-id-method'.

;;; Code:

(eval-when-compile
  (require 'cl))
(require 'org-id)
(require 'org)

(defgroup org-attach nil
  "Options concerning entry attachments in Org-mode."
  :tag "Org Attach"
  :group 'org)

(defcustom org-attach-directory "data/"
  "The directory where attachments are stored.
If this is a relative path, it will be interpreted relative to the directory
where the Org file lives."
  :group 'org-attach
  :type 'direcory)

(defcustom org-attach-auto-tag "ATTACH"
  "Tag that will be triggered automatically when an entry has an attachment."
  :group 'org-attach
  :type '(choice
	  (const :tag "None" nil)
	  (string :tag "Tag")))

(defcustom org-attach-file-list-property "Attachments"
  "The property used to keep a list of attachment belonging to this entry.
This is not really needed, so you may set this to nil if you don't want it."
  :group 'org-attach
  :type '(choice
	  (const :tag "None" nil)
	  (string :tag "Tag")))

(defcustom org-attach-method 'cp
  "The preferred method to attach a file.
Allowed values are:

mv    rename the file to move it into the attachment directory
cp    copy the file
ln    create a hard link.  Note that this is not supported
      on all systems, and then the result is not defined."
  :group 'org-attach
  :type '(choice
	  (const :tag "Copy" cp)
	  (const :tag "Move/Rename" mv)
	  (const :tag "Link" ln)))

(defcustom org-attach-expert nil
  "Non-nil means do not show the splash buffer with the attach dispatcher."
  :group 'org-attach
  :type 'boolean)

;;;###autoload
(defun org-attach ()
  "The dispatcher for attachment commands.
Shows a list of commands and prompts for another key to execute a command."
  (interactive)
  (let (c marker)
    (when (eq major-mode 'org-agenda-mode)
      (setq marker (or (get-text-property (point) 'org-hd-marker)
		       (get-text-property (point) 'org-marker)))
      (unless marker
	(error "No task in current line")))
    (save-excursion
      (when marker
	(set-buffer (marker-buffer marker))
	(goto-char marker))
      (org-back-to-heading t)
      (save-excursion
	(save-window-excursion
	  (unless org-attach-expert
	    (with-output-to-temp-buffer "*Org Attach*"
	      (princ "Select an Attachment Command:

a       Select a file and attach it to the task, using `org-attach-method'.
c/m/l   Attach a file using copy/move/link method.
n       Create a new attachment, as an Emacs buffer.
z       Synchronize the current task with its attachment
        directory, in case you added attachments yourself.

o       Open current task's attachments.
O       Like \"o\", but force opening in Emacs.
f       Open current task's attachment directory.
F       Like \"f\", but force using dired in Emacs.

d       Delete one attachment, you will be prompted for a file name.
D       Delete all of a task's attachments.  A safer way is
        to open the directory in dired and delete from there.")))
	  (org-fit-window-to-buffer (get-buffer-window "*Org Attach*"))
	  (message "Select command: [acmlzoOfFdD]")
	  (setq c (read-char-exclusive))
	  (and (get-buffer "*Org Attach*") (kill-buffer "*Org Attach*"))))
      (cond
       ((memq c '(?a ?\C-a)) (call-interactively 'org-attach-attach))
       ((memq c '(?c ?\C-c))
	(let ((org-attach-method 'cp)) (call-interactively 'org-attach-attach)))
       ((memq c '(?m ?\C-m))
	(let ((org-attach-method 'mv)) (call-interactively 'org-attach-attach)))
       ((memq c '(?l ?\C-l))
	(let ((org-attach-method 'ln)) (call-interactively 'org-attach-attach)))
       ((memq c '(?n ?\C-n)) (call-interactively 'org-attach-new))
       ((memq c '(?z ?\C-z)) (call-interactively 'org-attach-sync))
       ((memq c '(?o ?\C-o)) (call-interactively 'org-attach-open))
       ((eq c ?O)            (call-interactively 'org-attach-open-in-emacs))
       ((memq c '(?f ?\C-f)) (call-interactively 'org-attach-reveal))
       ((memq c '(?F))       (call-interactively 'org-attach-reveal-in-emacs))
       ((memq c '(?d ?\C-d)) (call-interactively
			      'org-attach-delete-one))
       ((eq c ?D)            (call-interactively 'org-attach-delete-all))
       ((eq c ?q)            (message "Abort"))
       (t (error "No such attachment command %c" c))))))

(defun org-attach-dir (&optional create-if-not-exists-p)
  "Return the directory associated with the current entry.
If the directory does not exist and CREATE-IF-NOT-EXISTS-P is non-nil,
the directory and the corresponding ID will be created."
  (when (and (not (buffer-file-name (buffer-base-buffer)))
	     (not (file-name-absolute-p org-attach-directory)))
    (error "Need absolute `org-attach-directory' to attach in buffers without filename."))
  (let ((uuid (org-id-get (point) create-if-not-exists-p)))
    (when (or uuid create-if-not-exists-p)
      (unless uuid
	(error "ID retrieval/creation failed"))
      (let ((attach-dir (expand-file-name
			 (format "%s/%s"
				 (substring uuid 0 2)
				 (substring uuid 2))
			 (expand-file-name org-attach-directory))))
	(if (and create-if-not-exists-p
		 (not (file-directory-p attach-dir)))
	    (make-directory attach-dir t))
	(and (file-exists-p attach-dir)
	     attach-dir)))))

(defun org-attach-commit ()
  "Commit changes to git if `org-attach-directory' is properly initialized.
This checks for the existence of a \".git\" directory in that directory."
  (let ((dir (expand-file-name org-attach-directory)))
    (if (file-exists-p (expand-file-name ".git" dir))
	(shell-command
	 (concat "(cd " dir "; "
		 " git add .; "
		 " git ls-files --deleted -z | xargs -0 git rm; "
		 " git commit -m 'Synchronized attachments')")))))
  
(defun org-attach-tag (&optional off)
  "Turn the autotag on or (if OFF is set) off."
  (when org-attach-auto-tag
    (save-excursion
      (org-back-to-heading t)
      (org-toggle-tag org-attach-auto-tag (if off 'off 'on)))))

(defun org-attach-untag ()
  "Turn the autotag off."
  (org-attach-tag 'off))

(defun org-attach-attach (file &optional visit-dir method)
  "Move/copy/link FILE into the attachment directory of the current task.
If VISIT-DIR is non-nil, visit the directory with dired.
METHOD may be `cp', `mv', or `ln', default taken from `org-attach-method'."
  (interactive "fFile to keep as an attachment: \nP")
  (setq method (or method org-attach-method))
  (let ((basename (file-name-nondirectory file)))
    (when org-attach-file-list-property
      (org-entry-add-to-multivalued-property
       (point) org-attach-file-list-property basename))
    (let* ((attach-dir (org-attach-dir t))
	   (fname (expand-file-name basename attach-dir)))
      (cond
       ((eq method 'mv)	(rename-file file fname))
       ((eq method 'cp)	(copy-file file fname))
       ((eq method 'ln) (add-name-to-file file fname)))
      (org-attach-commit)
      (org-attach-tag)
      (if visit-dir
	  (dired attach-dir)
	(message "File \"%s\" is now a task attachment." basename)))))

(defun org-attach-attach-cp ()
  "Attach a file by copying it."
  (interactive)
  (let ((org-attach-method 'cp)) (call-interactively 'org-attach-attach)))
(defun org-attach-attach-mv ()
  "Attach a file by moving (renaming) it."
  (interactive)
  (let ((org-attach-method 'mv)) (call-interactively 'org-attach-attach)))
(defun org-attach-attach-ln ()
  "Attach a file by creating a hard link to it.
Beware that this does not work on systems that do not support hard links.
On some systems, this apparently does copy the file instead."
  (interactive)
  (let ((org-attach-method 'ln)) (call-interactively 'org-attach-attach)))

(defun org-attach-new (file)
  "Create a new attachment FILE for the current task.
The attachment is created as an Emacs buffer."
  (interactive "sCreate attachment named: ")
  (when org-attach-file-list-property
    (org-entry-add-to-multivalued-property
     (point) org-attach-file-list-property file))
  (let ((attach-dir (org-attach-dir t)))
    (org-attach-tag)
    (find-file (expand-file-name file attach-dir))
    (message "New attachment %s" file)))

(defun org-attach-delete-one (&optional file)
  "Delete a single attachment."
  (interactive)
  (let* ((attach-dir (org-attach-dir t))
	 (files (org-attach-file-list attach-dir))
	 (file (or file
		   (org-ido-completing-read
		    "Delete attachment: "
		    (mapcar (lambda (f)
			      (list (file-name-nondirectory f)))
			    files)))))
    (setq file (expand-file-name file attach-dir))
    (unless (file-exists-p file)
      (error "No such attachment: %s" file))
    (delete-file file)))

(defun org-attach-delete-all (&optional force)
  "Delete all attachments from the current task.
This actually deletes the entire attachment directory.
A safer way is to open the directory in dired and delete from there."
  (interactive "P")
  (when org-attach-file-list-property
    (org-entry-delete (point) org-attach-file-list-property))
  (let ((attach-dir (org-attach-dir)))
    (when 
	(and attach-dir
	     (or force
		 (y-or-n-p "Are you sure you want to remove all attachments of this entry? ")))
      (shell-command (format "rm -fr %s" attach-dir))
      (message "Attachment directory removed")
      (org-attach-commit)
      (org-attach-untag))))

(defun org-attach-sync ()
  "Synchronize the current tasks with its attachments.
This can be used after files have been added externally."
  (interactive)
  (org-attach-commit)
  (when org-attach-file-list-property
    (org-entry-delete (point) org-attach-file-list-property))
  (let ((attach-dir (org-attach-dir)))
    (when attach-dir
      (let ((files (org-attach-file-list attach-dir)))
	(and files (org-attach-tag))
	(when org-attach-file-list-property
	  (dolist (file files)
	    (unless (string-match "^\\." file)
	      (org-entry-add-to-multivalued-property
	       (point) org-attach-file-list-property file))))))))

(defun org-attach-file-list (dir)
  "Return a list of files in the attachment directory.
This ignores files starting with a \".\", and files ending in \"~\"."
  (delq nil
	(mapcar (lambda (x) (if (string-match "^\\." x) nil x))
		(directory-files dir nil "[^~]\\'"))))

(defun org-attach-reveal ()
  "Show the attachment directory of the current task in dired."
  (interactive)
  (let ((attach-dir (org-attach-dir t)))
    (org-open-file attach-dir)))

(defun org-attach-reveal-in-emacs ()
  "Show the attachment directory of the current task.
This will attempt to use an external program to show the directory."
  (interactive)
  (let ((attach-dir (org-attach-dir t)))
    (dired attach-dir)))

(defun org-attach-open (&optional in-emacs)
  "Open an attachment of the current task.
If there are more than one attachment, you will be prompted for the file name.
This command will open the file using the settings in `org-file-apps'
and in the system-specific variants of this variable.
If IN-EMACS is non-nil, force opening in Emacs."
  (interactive "P")
  (let* ((attach-dir (org-attach-dir t))
	 (files (org-attach-file-list attach-dir))
	 (file (if (= (length files) 1)
		   (car files)
		 (org-ido-completing-read "Open attachment: "
				  (mapcar 'list files) nil t))))
    (org-open-file (expand-file-name file attach-dir) in-emacs)))

(defun org-attach-open-in-emacs ()
  "Open attachment, force opening in Emacs.
See `org-attach-open'."
  (interactive)
  (org-attach-open 'in-emacs))

(defun org-attach-expand (file)
  "Return the full path to the current entry's attachment file FILE.
Basically, this adds the path to the attachment directory."
  (expand-file-name file (org-attach-dir)))

(defun org-attach-expand-link (file)
  "Return a file link pointing to the current entry's attachment file FILE.
Basically, this adds the path to the attachment directory, and a \"file:\"
prefix."
  (concat "file:" (org-attach-expand file)))

(provide 'org-attach)

;; arch-tag: fce93c2e-fe07-4fa3-a905-e10dcc7a6248
;;; org-attach.el ends here
