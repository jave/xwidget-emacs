;;; mh-speed.el --- Speedbar interface for MH-E.

;; Copyright (C) 2002, 2003 Free Software Foundation, Inc.

;; Author: Satyaki Das <satyaki@theforce.stanford.edu>
;; Maintainer: Bill Wohler <wohler@newt.com>
;; Keywords: mail
;; See: mh-e.el

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
;;   Future versions should only use flists.

;; Speedbar support for MH-E package.

;;; Change Log:

;;; Code:

;; Requires
(require 'cl)
(require 'mh-e)
(require 'speedbar)

;; Global variables
(defvar mh-speed-refresh-flag nil)
(defvar mh-speed-last-selected-folder nil)
(defvar mh-speed-folder-map (make-hash-table :test #'equal))
(defvar mh-speed-flists-cache (make-hash-table :test #'equal))
(defvar mh-speed-flists-process nil)
(defvar mh-speed-flists-timer nil)
(defvar mh-speed-partial-line "")

;; Add our stealth update function
(unless (member 'mh-speed-stealth-update
                (cdr (assoc "files" speedbar-stealthy-function-list)))
  ;; Is changing constant lists in elisp safe?
  (setq speedbar-stealthy-function-list
        (copy-tree speedbar-stealthy-function-list))
  (push 'mh-speed-stealth-update
        (cdr (assoc "files" speedbar-stealthy-function-list))))

;; Functions called by speedbar to initialize display...
;;;###mh-autoload
(defun mh-folder-speedbar-buttons (buffer)
  "Interface function to create MH-E speedbar buffer.
BUFFER is the MH-E buffer for which the speedbar buffer is to be created."
  (unless (get-text-property (point-min) 'mh-level)
    (erase-buffer)
    (clrhash mh-speed-folder-map)
    (speedbar-make-tag-line 'bracket ?+ 'mh-speed-toggle nil " " 'ignore nil
                            'mh-speedbar-folder-face 0)
    (forward-line -1)
    (setf (gethash nil mh-speed-folder-map)
          (set-marker (or (gethash nil mh-speed-folder-map) (make-marker))
                      (1+ (line-beginning-position))))
    (add-text-properties
     (line-beginning-position) (1+ (line-beginning-position))
     `(mh-folder nil mh-expanded nil mh-children-p t mh-level 0))
    (mh-speed-stealth-update t)
    (when mh-speed-run-flists-flag
      (mh-speed-flists nil))))

;;;###mh-autoload
(defalias 'mh-show-speedbar-buttons 'mh-folder-speedbar-buttons)
;;;###mh-autoload
(defalias 'mh-letter-speedbar-buttons 'mh-folder-speedbar-buttons)

;; Keymaps for speedbar...
(defvar mh-folder-speedbar-key-map (speedbar-make-specialized-keymap)
  "Specialized speedbar keymap for MH-E buffers.")
(gnus-define-keys mh-folder-speedbar-key-map
  "+"           mh-speed-expand-folder
  "-"           mh-speed-contract-folder
  "\r"          mh-speed-view
  "f"           mh-speed-flists
  "i"           mh-speed-invalidate-map)

(defvar mh-show-speedbar-key-map mh-folder-speedbar-key-map)
(defvar mh-letter-speedbar-key-map mh-folder-speedbar-key-map)

;; Menus for speedbar...
(defvar mh-folder-speedbar-menu-items
  '(["Visit Folder" mh-speed-view
     (save-excursion
       (set-buffer speedbar-buffer)
       (get-text-property (line-beginning-position) 'mh-folder))]
    ["Expand nested folders" mh-speed-expand-folder
     (and (get-text-property (line-beginning-position) 'mh-children-p)
          (not (get-text-property (line-beginning-position) 'mh-expanded)))]
    ["Contract nested folders" mh-speed-contract-folder
     (and (get-text-property (line-beginning-position) 'mh-children-p)
          (get-text-property (line-beginning-position) 'mh-expanded))]
    ["Run Flists" mh-speed-flists t]
    ["Invalidate cached folders" mh-speed-invalidate-map t])
  "Extra menu items for speedbar.")

(defvar mh-show-speedbar-menu-items mh-folder-speedbar-menu-items)
(defvar mh-letter-speedbar-menu-items mh-folder-speedbar-menu-items)

(defmacro mh-speed-select-attached-frame ()
  "Compatibility macro to handle speedbar versions 0.11a and 0.14beta4."
  (cond ((fboundp 'dframe-select-attached-frame)
         '(dframe-select-attached-frame speedbar-frame))
        ((boundp 'speedbar-attached-frame)
         '(select-frame speedbar-attached-frame))
        (t (error "Installed speedbar version not supported by MH-E"))))

(defun mh-speed-update-current-folder (force)
  "Update speedbar highlighting of the current folder.
The function tries to be smart so that work done is minimized. The currently
highlighted folder is cached and no highlighting happens unless it changes.
Also highlighting is suspended while the speedbar frame is selected.
Otherwise you get the disconcerting behavior of folders popping open on their
own when you are trying to navigate around in the speedbar buffer.

The update is always carried out if FORCE is non-nil."
  (let* ((lastf (selected-frame))
         (newcf (save-excursion
                  (mh-speed-select-attached-frame)
                  (prog1 (mh-speed-extract-folder-name (buffer-name))
                    (select-frame lastf))))
         (lastb (current-buffer))
         (case-fold-search t))
    (when (or force
              (and mh-speed-refresh-flag (not (eq lastf speedbar-frame)))
              (and (stringp newcf)
                   (equal (substring newcf 0 1) "+")
                   (not (equal newcf mh-speed-last-selected-folder))))
      (setq mh-speed-refresh-flag nil)
      (select-frame speedbar-frame)
      (set-buffer speedbar-buffer)

      ;; Remove highlight from previous match...
      (mh-speed-highlight mh-speed-last-selected-folder
                          'mh-speedbar-folder-face)

      ;; If we found a match highlight it...
      (when (mh-speed-goto-folder newcf)
        (mh-speed-highlight newcf 'mh-speedbar-selected-folder-face))

      (setq mh-speed-last-selected-folder newcf)
      (speedbar-position-cursor-on-line)
      (set-window-point (frame-first-window speedbar-frame) (point))
      (set-buffer lastb)
      (select-frame lastf))
    (when (eq lastf speedbar-frame)
      (setq mh-speed-refresh-flag t))))

(defun mh-speed-normal-face (face)
  "Return normal face for given FACE."
  (cond ((eq face 'mh-speedbar-folder-with-unseen-messages-face)
         'mh-speedbar-folder-face)
        ((eq face 'mh-speedbar-selected-folder-with-unseen-messages-face)
         'mh-speedbar-selected-folder-face)
        (t face)))

(defun mh-speed-bold-face (face)
  "Return bold face for given FACE."
  (cond ((eq face 'mh-speedbar-folder-face)
         'mh-speedbar-folder-with-unseen-messages-face)
        ((eq face 'mh-speedbar-selected-folder-face)
         'mh-speedbar-selected-folder-with-unseen-messages-face)
        (t face)))

(defun mh-speed-highlight (folder face)
  "Set FOLDER to FACE."
  (save-excursion
    (speedbar-with-writable
      (goto-char (gethash folder mh-speed-folder-map (point)))
      (beginning-of-line)
      (if (re-search-forward "([1-9][0-9]*/[0-9]+)" (line-end-position) t)
          (setq face (mh-speed-bold-face face))
        (setq face (mh-speed-normal-face face)))
      (beginning-of-line)
      (when (re-search-forward "\\[.\\] " (line-end-position) t)
        (put-text-property (point) (line-end-position) 'face face)))))

(defun mh-speed-stealth-update (&optional force)
  "Do stealth update.
With non-nil FORCE, the update is always carried out."
  (cond ((save-excursion (set-buffer speedbar-buffer)
                         (get-text-property (point-min) 'mh-level))
         ;; Execute this hook and *don't* run anything else
         (mh-speed-update-current-folder force)
         nil)
        ;; Otherwise on to your regular programming
        (t t)))

(defun mh-speed-goto-folder (folder)
  "Move point to line containing FOLDER.
The function will expand out parent folders of FOLDER if needed."
  (let ((prefix folder)
        (suffix-list ())
        (last-slash t))
    (while (and (not (gethash prefix mh-speed-folder-map)) last-slash)
      (setq last-slash (mh-search-from-end ?/ prefix))
      (when (integerp last-slash)
        (push (substring prefix (1+ last-slash)) suffix-list)
        (setq prefix (substring prefix 0 last-slash))))
    (let ((prefix-position (gethash prefix mh-speed-folder-map)))
      (if prefix-position
          (goto-char prefix-position)
        (goto-char (point-min))
        (mh-speed-toggle)
        (unless (get-text-property (point) 'mh-expanded)
          (mh-speed-toggle))
        (goto-char (gethash prefix mh-speed-folder-map))))
    (while suffix-list
      ;; We always need atleast one toggle. We need two if the directory list
      ;; is stale since a folder was added.
      (when (equal prefix (get-text-property (line-beginning-position)
                                             'mh-folder))
        (mh-speed-toggle)
        (unless (get-text-property (point) 'mh-expanded)
          (mh-speed-toggle)))
      (setq prefix (format "%s/%s" prefix (pop suffix-list)))
      (goto-char (gethash prefix mh-speed-folder-map (point))))
    (beginning-of-line)
    (equal folder (get-text-property (point) 'mh-folder))))

(defun mh-speed-extract-folder-name (buffer)
  "Given an MH-E BUFFER find the folder that should be highlighted.
Do the right thing for the different kinds of buffers that MH-E uses."
  (save-excursion
    (set-buffer buffer)
    (cond ((eq major-mode 'mh-folder-mode)
           mh-current-folder)
          ((eq major-mode 'mh-show-mode)
           (set-buffer mh-show-folder-buffer)
           mh-current-folder)
          ((eq major-mode 'mh-letter-mode)
           (when (string-match mh-user-path buffer-file-name)
             (let* ((rel-path (substring buffer-file-name (match-end 0)))
                    (directory-end (mh-search-from-end ?/ rel-path)))
               (when directory-end
                 (format "+%s" (substring rel-path 0 directory-end)))))))))

(defun mh-speed-add-buttons (folder level)
  "Add speedbar button for FOLDER which is at indented by LEVEL amount."
  (let ((folder-list (mh-sub-folders folder)))
    (mapc
     (lambda (f)
       (let* ((folder-name (format "%s%s%s" (or folder "+")
                                   (if folder "/" "") (car f)))
              (counts (gethash folder-name mh-speed-flists-cache)))
         (speedbar-with-writable
           (speedbar-make-tag-line
            'bracket (if (cdr f) ?+ ? )
            'mh-speed-toggle nil
            (format "%s%s"
                    (car f)
                    (if counts
                        (format " (%s/%s)" (car counts) (cdr counts))
                      ""))
            'mh-speed-view nil
            (if (and counts (> (car counts) 0))
                'mh-speedbar-folder-with-unseen-messages-face
              'mh-speedbar-folder-face)
            level)
           (save-excursion
             (forward-line -1)
             (setf (gethash folder-name mh-speed-folder-map)
                   (set-marker (or (gethash folder-name mh-speed-folder-map)
                                   (make-marker))
                               (1+ (line-beginning-position))))
             (add-text-properties
              (line-beginning-position) (1+ (line-beginning-position))
              `(mh-folder ,folder-name
                          mh-expanded nil
                          mh-children-p ,(not (not (cdr f)))
                          ,@(if counts `(mh-count
                                         (,(car counts) . ,(cdr counts))) ())
                          mh-level ,level))))))
     folder-list)))

;;;###mh-autoload
(defun mh-speed-toggle (&rest args)
  "Toggle the display of child folders.
The otional ARGS are ignored and there for compatibilty with speedbar."
  (interactive)
  (declare (ignore args))
  (beginning-of-line)
  (let ((parent (get-text-property (point) 'mh-folder))
        (kids-p (get-text-property (point) 'mh-children-p))
        (expanded (get-text-property (point) 'mh-expanded))
        (level (get-text-property (point) 'mh-level))
        (point (point))
        start-region)
    (speedbar-with-writable
      (cond ((not kids-p) nil)
            (expanded
             (forward-line)
             (setq start-region (point))
             (while (and (get-text-property (point) 'mh-level)
                         (> (get-text-property (point) 'mh-level) level))
               (let ((folder (get-text-property (point) 'mh-folder)))
                 (when (gethash folder mh-speed-folder-map)
                   (set-marker (gethash folder mh-speed-folder-map) nil)
                   (remhash folder mh-speed-folder-map)))
               (forward-line))
             (delete-region start-region (point))
             (forward-line -1)
             (speedbar-change-expand-button-char ?+)
             (add-text-properties
              (line-beginning-position) (1+ (line-beginning-position))
              '(mh-expanded nil)))
            (t
             (forward-line)
             (mh-speed-add-buttons parent (1+ level))
             (goto-char point)
             (speedbar-change-expand-button-char ?-)
             (add-text-properties
              (line-beginning-position) (1+ (line-beginning-position))
              `(mh-expanded t)))))))

(defalias 'mh-speed-expand-folder 'mh-speed-toggle)
(defalias 'mh-speed-contract-folder 'mh-speed-toggle)

;;;###mh-autoload
(defun mh-speed-view (&rest args)
  "View folder on current line.
Optional ARGS are ignored."
  (interactive)
  (declare (ignore args))
  (let* ((folder (get-text-property (line-beginning-position) 'mh-folder))
         (range (and (stringp folder) (mh-read-msg-range folder))))
    (when (stringp folder)
      (speedbar-with-attached-buffer
       (mh-visit-folder folder range)
       (delete-other-windows)))))

(defvar mh-speed-current-folder nil)
(defvar mh-speed-flists-folder nil)

;;;###mh-autoload
(defun mh-speed-flists (force &optional folder)
  "Execute flists -recurse and update message counts.
If FORCE is non-nil the timer is reset. If FOLDER is non-nil then flists is run
only for that one folder."
  (interactive (list t))
  (when force
    (when mh-speed-flists-timer
      (cancel-timer mh-speed-flists-timer)
      (setq mh-speed-flists-timer nil))
    (when (and (processp mh-speed-flists-process)
               (not (eq (process-status mh-speed-flists-process) 'exit)))
      (set-process-filter mh-speed-flists-process t)
      (kill-process mh-speed-flists-process)
      (setq mh-speed-partial-line "")
      (setq mh-speed-flists-process nil)))
  (setq mh-speed-flists-folder folder)
  (unless mh-speed-flists-timer
    (setq mh-speed-flists-timer
          (run-at-time
           nil (and mh-speed-run-flists-flag mh-speed-flists-interval)
           (lambda ()
             (unless (and (processp mh-speed-flists-process)
                          (not (eq (process-status mh-speed-flists-process)
                                   'exit)))
               (setq mh-speed-current-folder
                     (concat
                      (with-temp-buffer
                        (call-process (expand-file-name "folder" mh-progs)
                                      nil '(t nil) nil "-fast")
                        (buffer-substring (point-min) (1- (point-max))))
                      "+"))
               (setq mh-speed-flists-process
                     (start-process "*flists*" nil
                                    (expand-file-name "flists" mh-progs)
                                    (or mh-speed-flists-folder "-recurse")
                                    (if mh-speed-flists-folder "-noall" "-all")
                                    "-sequence" (symbol-name mh-unseen-seq)))
               ;; Run flists on all folders the next time around...
               (setq mh-speed-flists-folder nil)
               (set-process-filter mh-speed-flists-process
                                   'mh-speed-parse-flists-output)))))))

;; Copied from mh-make-folder-list-filter...
(defun mh-speed-parse-flists-output (process output)
  "Parse the incremental results from flists.
PROCESS is the flists process and OUTPUT is the results that must be handled
next."
  (let ((prevailing-match-data (match-data))
        (position 0)
        line-end line folder unseen total)
    (unwind-protect
        (while (setq line-end (string-match "\n" output position))
          (setq line (format "%s%s"
                             mh-speed-partial-line
                             (substring output position line-end))
                mh-speed-partial-line "")
          (multiple-value-setq (folder unseen total)
            (mh-parse-flist-output-line line mh-speed-current-folder))
          (when (and folder unseen total
                     (let ((old-pair (gethash folder mh-speed-flists-cache)))
                       (or (not (equal (car old-pair) unseen))
                           (not (equal (cdr old-pair) total)))))
            (setf (gethash folder mh-speed-flists-cache) (cons unseen total))
            (save-excursion
              (when (buffer-live-p (get-buffer speedbar-buffer))
                (set-buffer speedbar-buffer)
                (speedbar-with-writable
                  (when (get-text-property (point-min) 'mh-level)
                    (let ((pos (gethash folder mh-speed-folder-map))
                          face)
                      (when pos
                        (goto-char pos)
                        (goto-char (line-beginning-position))
                        (cond
                         ((null (get-text-property (point) 'mh-count))
                          (goto-char (line-end-position))
                          (setq face (get-text-property (1- (point)) 'face))
                          (insert (format " (%s/%s)" unseen total))
                          (mh-speed-highlight 'unknown face)
                          (goto-char (line-beginning-position))
                          (add-text-properties (point) (1+ (point))
                                               `(mh-count (,unseen . ,total))))
                         ((not (equal (get-text-property (point) 'mh-count)
                                      (cons unseen total)))
                          (goto-char (line-end-position))
                          (setq face (get-text-property (1- (point)) 'face))
                          (re-search-backward " " (line-beginning-position) t)
                          (delete-region (point) (line-end-position))
                          (insert (format " (%s/%s)" unseen total))
                          (mh-speed-highlight 'unknown face)
                          (goto-char (line-beginning-position))
                          (add-text-properties
                           (point) (1+ (point))
                           `(mh-count (,unseen . ,total))))))))))))
          (setq position (1+ line-end)))
      (set-match-data prevailing-match-data))
    (setq mh-speed-partial-line (substring output position))))

;;;###mh-autoload
(defun mh-speed-invalidate-map (folder)
  "Remove FOLDER from various optimization caches."
  (interactive (list ""))
  (save-excursion
    (set-buffer speedbar-buffer)
    (let* ((speedbar-update-flag nil)
           (last-slash (mh-search-from-end ?/ folder))
           (parent (if last-slash (substring folder 0 last-slash) nil))
           (parent-position (gethash parent mh-speed-folder-map))
           (parent-change nil))
      (when parent-position
        (let ((parent-kids (mh-sub-folders parent)))
          (cond ((null parent-kids)
                 (setq parent-change ?+))
                ((and (null (cdr parent-kids))
                      (equal (if last-slash
                                 (substring folder (1+ last-slash))
                               (substring folder 1))
                             (caar parent-kids)))
                 (setq parent-change ? ))))
        (goto-char parent-position)
        (when (equal (get-text-property (line-beginning-position) 'mh-folder)
                     parent)
          (when (get-text-property (line-beginning-position) 'mh-expanded)
            (mh-speed-toggle))
          (when parent-change
            (speedbar-with-writable
              (mh-speedbar-change-expand-button-char parent-change)
              (add-text-properties
               (line-beginning-position) (1+ (line-beginning-position))
               `(mh-children-p ,(equal parent-change ?+)))))
          (mh-speed-highlight mh-speed-last-selected-folder
                              'mh-speedbar-folder-face)
          (setq mh-speed-last-selected-folder nil)
          (setq mh-speed-refresh-flag t)))
      (when (equal folder "")
        (clrhash mh-sub-folders-cache)))))

;;;###mh-autoload
(defun mh-speed-add-folder (folder)
  "Add FOLDER since it is being created.
The function invalidates the latest ancestor that is present."
  (save-excursion
    (set-buffer speedbar-buffer)
    (let ((speedbar-update-flag nil)
          (last-slash (mh-search-from-end ?/ folder))
          (ancestor folder)
          (ancestor-pos nil))
      (block while-loop
        (while last-slash
          (setq ancestor (substring ancestor 0 last-slash))
          (setq ancestor-pos (gethash ancestor mh-speed-folder-map))
          (when ancestor-pos
            (return-from while-loop))
          (setq last-slash (mh-search-from-end ?/ ancestor))))
      (unless ancestor-pos (setq ancestor nil))
      (goto-char (or ancestor-pos (gethash nil mh-speed-folder-map)))
      (speedbar-with-writable
        (mh-speedbar-change-expand-button-char ?+)
        (add-text-properties
         (line-beginning-position) (1+ (line-beginning-position))
         `(mh-children-p t)))
      (when (get-text-property (line-beginning-position) 'mh-expanded)
        (mh-speed-toggle))
      (setq mh-speed-refresh-flag t))))

;; Make it slightly more general to allow for [ ] buttons to be changed to
;; [+].
(defun mh-speedbar-change-expand-button-char (char)
  "Change the expansion button character to CHAR for the current line."
  (save-excursion
    (beginning-of-line)
    (if (re-search-forward "\\[.\\]" (line-end-position) t)
        (speedbar-with-writable
          (backward-char 2)
          (delete-char 1)
          (insert-char char 1 t)
          (put-text-property (point) (1- (point)) 'invisible nil)
          ;; make sure we fix the image on the text here.
          (mh-funcall-if-exists
           speedbar-insert-image-button-maybe (- (point) 2) 3)))))

(provide 'mh-speed)

;;; Local Variables:
;;; indent-tabs-mode: nil
;;; sentence-end-double-space: nil
;;; End:

;;; mh-speed.el ends here
