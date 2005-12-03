;;; recentf.el --- setup a menu of recently opened files

;; Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004,
;;   2005 Free Software Foundation, Inc.

;; Author: David Ponce <david@dponce.com>
;; Created: July 19 1999
;; Keywords: files

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation; either version 2, or (at your
;; option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This package maintains a menu for visiting files that were operated
;; on recently.  When enabled a new "Open Recent" sub menu is
;; displayed in the "Files" menu.  The recent files list is
;; automatically saved across Emacs sessions.  You can customize the
;; number of recent files displayed, the location of the menu and
;; others options (see the source code for details).

;;; History:
;;

;;; Code:
(require 'easymenu)
(require 'tree-widget)
(require 'timer)

;;; Internal data
;;
(defvar recentf-list nil
  "List of recently opened files.")

(defvar recentf-data-cache nil
  "Cache of data used to build the recentf menu.
The menu is rebuilt when this data has changed.")

;;; Customization
;;
(defgroup recentf nil
  "Maintain a menu of recently opened files."
  :version "21.1"
  :group 'files)

(defgroup recentf-filters nil
  "Group to customize recentf menu filters.
You should define the options of your own filters in this group."
  :group 'recentf)

(defcustom recentf-max-saved-items 20
  "*Maximum number of items of the recent list that will be saved.
A nil value means to save the whole list.
See the command `recentf-save-list'."
  :group 'recentf
  :type 'integer)

(defcustom recentf-save-file "~/.recentf"
  "*File to save the recent list into."
  :group 'recentf
  :type 'file)

(defcustom recentf-save-file-modes 384 ;; 0600
  "Mode bits of recentf save file, as an integer, or nil.
If non-nil, after writing `recentf-save-file', set its mode bits to
this value.  By default give R/W access only to the user who owns that
file.  See also the function `set-file-modes'."
  :group 'recentf
  :type '(choice (const :tag "Don't change" nil)
          integer))
  
(defcustom recentf-exclude nil
  "*List of regexps and predicates for filenames excluded from the recent list.
When a filename matches any of the regexps or satisfies any of the
predicates it is excluded from the recent list.
A predicate is a function that is passed a filename to check and that
must return non-nil to exclude it."
  :group 'recentf
  :type '(repeat (choice regexp function)))

(defcustom recentf-keep
  '(file-readable-p)
  "*List of regexps and predicates for filenames kept in the recent list.
Regexps and predicates are tried in the specified order.
When nil all filenames are kept in the recent list.
When a filename matches any of the regexps or satisfies any of the
predicates it is kept in the recent list.
The default is to keep readable files.
A predicate is a function that is passed a filename to check and that
must return non-nil to keep it.  For example, you can add the
`file-remote-p' predicate in front of this list to keep remote file
names in the recent list without checking their readability through a
remote access."
  :group 'recentf
  :type '(repeat (choice regexp function)))

(defun recentf-menu-customization-changed (variable value)
  "Function called when the recentf menu customization has changed.
Set VARIABLE with VALUE, and force a rebuild of the recentf menu."
  (when (featurep 'recentf)
    ;; Unavailable until recentf has been loaded.
    (recentf-clear-data))
  (set-default variable value))

(defcustom recentf-menu-title "Open Recent"
  "*Name of the recentf menu."
  :group 'recentf
  :type 'string
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-path '("File")
  "*Path where to add the recentf menu.
If nil add it at top level (see also `easy-menu-add-item')."
  :group 'recentf
  :type '(choice (const :tag "Top Level" nil)
                 (sexp :tag "Menu Path"))
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-before "Open File..."
  "*Name of the menu before which the recentf menu will be added.
If nil add it at end of menu (see also `easy-menu-add-item')."
  :group 'recentf
  :type '(choice (string :tag "Name")
                 (const :tag "Last" nil))
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-action 'find-file
  "*Function to invoke with a filename item of the recentf menu.
The default is to call `find-file' to edit the selected file."
  :group 'recentf
  :type 'function
  :set 'recentf-menu-customization-changed)

(defcustom recentf-max-menu-items 10
  "*Maximum number of items in the recentf menu."
  :group 'recentf
  :type 'integer
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-filter nil
  "*Function used to filter files displayed in the recentf menu.
A nil value means no filter.  The following functions are predefined:

- `recentf-sort-ascending'
    Sort menu items in ascending order.
- `recentf-sort-descending'
    Sort menu items in descending order.
- `recentf-sort-basenames-ascending'
    Sort menu items by filenames sans directory in ascending order.
- `recentf-sort-basenames-descending'
    Sort menu items by filenames sans directory in descending order.
- `recentf-sort-directories-ascending'
    Sort menu items by directories in ascending order.
- `recentf-sort-directories-descending'
    Sort menu items by directories in descending order.
- `recentf-show-basenames'
    Show filenames sans directory in menu items.
- `recentf-show-basenames-ascending'
    Show filenames sans directory in ascending order.
- `recentf-show-basenames-descending'
    Show filenames sans directory in descending order.
- `recentf-relative-filter'
    Show filenames relative to `default-directory'.
- `recentf-arrange-by-rule'
    Show sub-menus following user defined rules.
- `recentf-arrange-by-mode'
    Show a sub-menu for each major mode.
- `recentf-arrange-by-dir'
    Show a sub-menu for each directory.
- `recentf-filter-changer'
    Manage a ring of filters.

The filter function is called with one argument, the list of menu
elements used to build the menu and must return a new list of menu
elements (see `recentf-make-menu-element' for menu element form)."
  :group 'recentf
  :type '(radio (const nil)
                (function-item recentf-sort-ascending)
                (function-item recentf-sort-descending)
                (function-item recentf-sort-basenames-ascending)
                (function-item recentf-sort-basenames-descending)
                (function-item recentf-sort-directories-ascending)
                (function-item recentf-sort-directories-descending)
                (function-item recentf-show-basenames)
                (function-item recentf-show-basenames-ascending)
                (function-item recentf-show-basenames-descending)
                (function-item recentf-relative-filter)
                (function-item recentf-arrange-by-rule)
                (function-item recentf-arrange-by-mode)
                (function-item recentf-arrange-by-dir)
                (function-item recentf-filter-changer)
                function)
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-open-all-flag nil
  "*Non-nil means to show an \"All...\" item in the menu.
This item will replace the \"More...\" item."
  :group 'recentf
  :type 'boolean
  :set 'recentf-menu-customization-changed)

(defcustom recentf-menu-append-commands-flag t
  "*Non-nil means to append command items to the menu."
  :group 'recentf
  :type 'boolean
  :set 'recentf-menu-customization-changed)

(define-obsolete-variable-alias 'recentf-menu-append-commands-p
                                'recentf-menu-append-commands-flag
                                "22.1")

(defcustom recentf-auto-cleanup 'mode
  "*Define when to automatically cleanup the recent list.
The following values can be set:

- `mode'
    Cleanup when turning the mode on (default).
- `never'
    Never cleanup the list automatically.
- A number
    Cleanup each time Emacs has been idle that number of seconds.
- A time string
    Cleanup at specified time string, for example at \"11:00pm\".

Setting this variable directly does not take effect;
use \\[customize].

See also the command `recentf-cleanup', that can be used to manually
cleanup the list."
  :group 'recentf
  :type '(radio (const  :tag "When mode enabled"
                        :value mode)
                (const  :tag "Never"
                        :value never)
                (number :tag "When idle that seconds"
                        :value 300)
                (string :tag "At time"
                        :value "11:00pm"))
  :set (lambda (variable value)
         (set-default variable value)
         (when (featurep 'recentf)
           ;; Unavailable until recentf has been loaded.
           (recentf-auto-cleanup))))

(defcustom recentf-initialize-file-name-history t
  "*Non-nil means to initialize `file-name-history' with the recent list.
If `file-name-history' is not empty, do nothing."
  :group 'recentf
  :type  'boolean)

(defcustom recentf-load-hook nil
   "*Normal hook run at end of loading the `recentf' package."
  :group 'recentf
  :type 'hook)

(defcustom recentf-filename-handlers nil
  "Functions to post process recent file names.
They are successively passed a file name to transform it."
  :group 'recentf
  :type '(choice
          (const :tag "None" nil)
          (repeat :tag "Functions"
           (choice
            (const file-truename)
            (const abbreviate-file-name)
            (function :tag "Other function")))))

(defcustom recentf-show-file-shortcuts-flag t
  "Whether to show ``[N]'' for the Nth item up to 10.
If non-nil, `recentf-open-files' will show labels for keys that can be
used as shortcuts to open the Nth file."
  :group 'recentf
  :type 'boolean)

;;; Utilities
;;
(defconst recentf-case-fold-search
  (memq system-type '(vax-vms windows-nt cygwin))
  "Non-nil if recentf searches and matches should ignore case.")

(defsubst recentf-string-equal (s1 s2)
  "Return non-nil if strings S1 and S2 have identical contents.
Ignore case if `recentf-case-fold-search' is non-nil."
  (if recentf-case-fold-search
      (string-equal (downcase s1) (downcase s2))
    (string-equal s1 s2)))

(defsubst recentf-string-lessp (s1 s2)
  "Return non-nil if string S1 is less than S2 in lexicographic order.
Ignore case if `recentf-case-fold-search' is non-nil."
  (if recentf-case-fold-search
      (string-lessp (downcase s1) (downcase s2))
    (string-lessp s1 s2)))

(defun recentf-string-member (elt list)
  "Return non-nil if ELT is an element of LIST.
The value is actually the tail of LIST whose car is ELT.
ELT must be a string and LIST a list of strings.
Ignore case if `recentf-case-fold-search' is non-nil."
  (while (and list (not (recentf-string-equal elt (car list))))
    (setq list (cdr list)))
  list)

(defsubst recentf-trunc-list (l n)
  "Return from L the list of its first N elements."
  (let (nl)
    (while (and l (> n 0))
      (setq nl (cons (car l) nl)
            n  (1- n)
            l  (cdr l)))
    (nreverse nl)))

(defun recentf-dump-variable (variable &optional limit)
  "Insert a \"(setq VARIABLE value)\" in the current buffer.
When the value of VARIABLE is a list, optional argument LIMIT
specifies a maximum number of elements to insert.  By default insert
the full list."
  (let ((value (symbol-value variable)))
    (if (atom value)
        (insert (format "\n(setq %S %S)\n" variable value))
      (when (and (integerp limit) (> limit 0))
        (setq value (recentf-trunc-list value limit)))
      (insert (format "\n(setq %S\n      '(" variable))
      (dolist (e value)
        (insert (format "\n        %S" e)))
      (insert "\n        ))\n"))))

(defvar recentf-auto-cleanup-timer nil
  "Timer used to automatically cleanup the recent list.
See also the option `recentf-auto-cleanup'.")

(defun recentf-auto-cleanup ()
  "Automatic cleanup of the recent list."
  (when (timerp recentf-auto-cleanup-timer)
    (cancel-timer recentf-auto-cleanup-timer))
  (when recentf-mode
    (setq recentf-auto-cleanup-timer
          (cond
           ((eq 'mode recentf-auto-cleanup)
            (recentf-cleanup)
            nil)
           ((numberp recentf-auto-cleanup)
            (run-with-idle-timer
             recentf-auto-cleanup t 'recentf-cleanup))
           ((stringp recentf-auto-cleanup)
            (run-at-time
             recentf-auto-cleanup nil 'recentf-cleanup))))))

;;; File functions
;;
(defsubst recentf-push (filename)
  "Push FILENAME into the recent list, if it isn't there yet.
If it is there yet, move it at the beginning of the list.
If `recentf-case-fold-search' is non-nil, ignore case when comparing
filenames."
  (let ((m (recentf-string-member filename recentf-list)))
    (and m (setq recentf-list (delq (car m) recentf-list)))
    (push filename recentf-list)))

(defun recentf-apply-filename-handlers (name)
  "Apply `recentf-filename-handlers' to file NAME.
Return the transformed file name, or NAME if any handler failed, or
returned nil."
  (or (condition-case nil
          (let ((handlers recentf-filename-handlers)
                (filename name))
            (while (and filename handlers)
              (setq filename (funcall (car handlers) filename)
                    handlers (cdr handlers)))
            filename)
        (error nil))
      name))

(defsubst recentf-expand-file-name (name)
  "Convert file NAME to absolute, and canonicalize it.
NAME is first passed to the function `expand-file-name', then to
`recentf-filename-handlers' to post process it."
  (recentf-apply-filename-handlers (expand-file-name name)))

(defun recentf-include-p (filename)
  "Return non-nil if FILENAME should be included in the recent list.
That is, if it doesn't match any of the `recentf-exclude' checks."
  (let ((case-fold-search recentf-case-fold-search)
        (checks recentf-exclude)
        (keepit t))
    (while (and checks keepit)
      (setq keepit (condition-case nil
                       (not (if (stringp (car checks))
                                ;; A regexp
                                (string-match (car checks) filename)
                              ;; A predicate
                              (funcall (car checks) filename)))
                     (error nil))
            checks (cdr checks)))
    keepit))

(defun recentf-keep-p (filename)
  "Return non-nil if FILENAME should be kept in the recent list.
That is, if it matches any of the `recentf-keep' checks."
  (let* ((case-fold-search recentf-case-fold-search)
         (checks recentf-keep)
         (keepit (null checks)))
    (while (and checks (not keepit))
      (setq keepit (condition-case nil
                       (if (stringp (car checks))
                           ;; A regexp
                           (string-match (car checks) filename)
                         ;; A predicate
                         (funcall (car checks) filename))
                     (error nil))
            checks (cdr checks)))
    keepit))

(defsubst recentf-add-file (filename)
  "Add or move FILENAME at the beginning of the recent list.
Does nothing if the name satisfies any of the `recentf-exclude'
regexps or predicates."
  (setq filename (recentf-expand-file-name filename))
  (when (recentf-include-p filename)
    (recentf-push filename)))

(defsubst recentf-remove-if-non-kept (filename)
  "Remove FILENAME from the recent list, if file is not kept.
Return non-nil if FILENAME has been removed."
  (unless (recentf-keep-p filename)
    (let ((m (recentf-string-member
              (recentf-expand-file-name filename) recentf-list)))
      (and m (setq recentf-list (delq (car m) recentf-list))))))

(defsubst recentf-directory-compare (f1 f2)
  "Compare absolute filenames F1 and F2.
First compare directories, then filenames sans directory.
Return non-nil if F1 is less than F2."
  (let ((d1 (file-name-directory f1))
        (d2 (file-name-directory f2)))
    (if (recentf-string-equal d1 d2)
        (recentf-string-lessp (file-name-nondirectory f1)
                              (file-name-nondirectory f2))
      (recentf-string-lessp d1 d2))))

;;; Menu building
;;
(defsubst recentf-digit-shortcut-command-name (n)
  "Return a command name to open the Nth most recent file.
See also the command `recentf-open-most-recent-file'."
  (intern (format "recentf-open-most-recent-file-%d" n)))

(defvar recentf--shortcuts-keymap
  (let ((km (make-sparse-keymap)))
    (dolist (k '(0 9 8 7 6 5 4 3 2 1))
      (let ((cmd (recentf-digit-shortcut-command-name k)))
        ;; Define a shortcut command.
        (defalias cmd
          `(lambda ()
             (interactive)
             (recentf-open-most-recent-file ,k)))
        ;; Bind it to a digit key.
        (define-key km (vector (+ k ?0)) cmd)))
    km)
  "Digit shortcuts keymap.")

(defvar recentf-menu-items-for-commands
  (list
   ["Cleanup list"
    recentf-cleanup
    :help "Remove duplicates, and obsoletes files from the recent list"
    :active t]
   ["Edit list..."
    recentf-edit-list
    :help "Manually remove files from the recent list"
    :active t]
   ["Save list now"
    recentf-save-list
    :help "Save the list of recently opened files now"
    :active t]
   ["Options..."
    (customize-group "recentf")
    :help "Customize recently opened files menu and options"
    :active t]
   )
  "List of menu items for recentf commands.")

(defvar recentf-menu-filter-commands nil
  "This variable can be used by menu filters to setup their own command menu.
If non-nil it must contain a list of valid menu-items to be appended
to the recent file list part of the menu.  Before calling a menu
filter function this variable is reset to nil.")

(defsubst recentf-elements (n)
  "Return a list of the first N elements of the recent list."
  (recentf-trunc-list recentf-list n))

(defsubst recentf-make-menu-element (menu-item menu-value)
  "Create a new menu-element.
A menu element is a pair (MENU-ITEM . MENU-VALUE), where MENU-ITEM is
the menu item string displayed.  MENU-VALUE is the file to be open
when the corresponding MENU-ITEM is selected.  Or it is a
pair (SUB-MENU-TITLE . MENU-ELEMENTS) where SUB-MENU-TITLE is a
sub-menu title and MENU-ELEMENTS is the list of menu elements in the
sub-menu."
  (cons menu-item menu-value))

(defsubst recentf-menu-element-item (e)
  "Return the item part of the menu-element E."
  (car e))

(defsubst recentf-menu-element-value (e)
  "Return the value part of the menu-element E."
  (cdr e))

(defsubst recentf-set-menu-element-item (e item)
  "Change the item part of menu-element E to ITEM."
  (setcar e item))

(defsubst recentf-set-menu-element-value (e value)
  "Change the value part of menu-element E to VALUE."
  (setcdr e value))

(defsubst recentf-sub-menu-element-p (e)
  "Return non-nil if menu-element E defines a sub-menu."
  (consp (recentf-menu-element-value e)))

(defsubst recentf-make-default-menu-element (file)
  "Make a new default menu element with FILE.
This a menu element (FILE . FILE)."
  (recentf-make-menu-element file file))

(defsubst recentf-menu-elements (n)
  "Return a list of the first N default menu elements from the recent list.
See also `recentf-make-default-menu-element'."
  (mapcar 'recentf-make-default-menu-element
          (recentf-elements n)))

(defun recentf-apply-menu-filter (filter l)
  "Apply function FILTER to the list of menu-elements L.
It takes care of sub-menu elements in L and recursively apply FILTER
to them.  It is guaranteed that FILTER receives only a list of single
menu-elements (no sub-menu)."
  (if (and l (functionp filter))
      (let ((case-fold-search recentf-case-fold-search)
            elts others)
        ;; split L into two sub-listes, one of sub-menus elements and
        ;; another of single menu elements.
        (dolist (elt l)
          (if (recentf-sub-menu-element-p elt)
              (push elt elts)
            (push elt others)))
        ;; Apply FILTER to single elements.
        (when others
          (setq others (funcall filter (nreverse others))))
        ;; Apply FILTER to sub-menu elements.
        (setq l nil)
        (dolist (elt elts)
          (recentf-set-menu-element-value
           elt (recentf-apply-menu-filter
                filter (recentf-menu-element-value elt)))
          (push elt l))
        ;; Return the new filtered menu element list.
        (nconc l others))
    l))

;; Count the number of assigned menu shortcuts.
(defvar recentf-menu-shortcuts)

(defun recentf-make-menu-items ()
  "Make menu items from the recent list."
  (setq recentf-menu-filter-commands nil)
  (let* ((recentf-menu-shortcuts 0)
         (file-items
          (mapcar 'recentf-make-menu-item
                  (recentf-apply-menu-filter
                   recentf-menu-filter
                   (recentf-menu-elements recentf-max-menu-items)))))
    (append (or file-items (list ["No files" t
                                  :help "No recent file to open"
                                  :active nil]))
            (if recentf-menu-open-all-flag
                (list ["All..." recentf-open-files
                       :help "Open recent files through a dialog"
                       :active t])
              (and (< recentf-max-menu-items (length recentf-list))
                   (list ["More..." recentf-open-more-files
                          :help "Open files not in the menu through a dialog"
                          :active t])))
            (and recentf-menu-filter-commands
                 (cons "---"
                       recentf-menu-filter-commands))
            (and recentf-menu-append-commands-flag
                 (cons "---"
                       recentf-menu-items-for-commands)))))

(defun recentf-menu-value-shortcut (name)
  "Return a shorcut digit for file NAME.
Return nil if file NAME is not one of the ten more recent."
  (let ((i 0) k)
    (while (and (not k) (< i 10))
      (if (string-equal name (nth i recentf-list))
          (progn
            (setq recentf-menu-shortcuts (1+ recentf-menu-shortcuts))
            (setq k (% (1+ i) 10)))
        (setq i (1+ i))))
    k))

(defun recentf-make-menu-item (elt)
  "Make a menu item from menu element ELT."
  (let ((item  (recentf-menu-element-item  elt))
        (value (recentf-menu-element-value elt)))
    (if (recentf-sub-menu-element-p elt)
        (cons item (mapcar 'recentf-make-menu-item value))
      (let ((k (and (< recentf-menu-shortcuts 10)
                    (recentf-menu-value-shortcut value))))
        (vector item
                ;; If the file name is one of the ten more recent, use
                ;; a digit shortcut command to open it, else use an
                ;; anonymous command.
                (if k
                    (recentf-digit-shortcut-command-name k)
                  `(lambda ()
                     (interactive)
                     (,recentf-menu-action ,value)))
                :help (concat "Open " value)
                :active t)))))

(defsubst recentf-menu-bar ()
  "Return the keymap of the global menu bar."
  (lookup-key global-map [menu-bar]))

(defun recentf-clear-data ()
  "Clear data used to build the recentf menu.
This forces a rebuild of the menu."
  (easy-menu-remove-item (recentf-menu-bar)
                         recentf-menu-path recentf-menu-title)
  (setq recentf-data-cache nil))

;;; Predefined menu filters
;;
(defsubst recentf-sort-ascending (l)
  "Sort the list of menu elements L in ascending order.
The MENU-ITEM part of each menu element is compared."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-string-lessp
             (recentf-menu-element-item e1)
             (recentf-menu-element-item e2)))))

(defsubst recentf-sort-descending (l)
  "Sort the list of menu elements L in descending order.
The MENU-ITEM part of each menu element is compared."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-string-lessp
             (recentf-menu-element-item e2)
             (recentf-menu-element-item e1)))))

(defsubst recentf-sort-basenames-ascending (l)
  "Sort the list of menu elements L in ascending order.
Only filenames sans directory are compared."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-string-lessp
             (file-name-nondirectory (recentf-menu-element-value e1))
             (file-name-nondirectory (recentf-menu-element-value e2))))))

(defsubst recentf-sort-basenames-descending (l)
  "Sort the list of menu elements L in descending order.
Only filenames sans directory are compared."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-string-lessp
             (file-name-nondirectory (recentf-menu-element-value e2))
             (file-name-nondirectory (recentf-menu-element-value e1))))))

(defsubst recentf-sort-directories-ascending (l)
  "Sort the list of menu elements L in ascending order.
Compares directories then filenames to order the list."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-directory-compare
             (recentf-menu-element-value e1)
             (recentf-menu-element-value e2)))))

(defsubst recentf-sort-directories-descending (l)
  "Sort the list of menu elements L in descending order.
Compares directories then filenames to order the list."
  (sort (copy-sequence l)
        #'(lambda (e1 e2)
            (recentf-directory-compare
             (recentf-menu-element-value e2)
             (recentf-menu-element-value e1)))))

(defun recentf-show-basenames (l &optional no-dir)
  "Filter the list of menu elements L to show filenames sans directory.
When a filename is duplicated, it is appended a sequence number if
optional argument NO-DIR is non-nil, or its directory otherwise."
  (let (filtered-names filtered-list full name counters sufx)
    (dolist (elt l (nreverse filtered-list))
      (setq full (recentf-menu-element-value elt)
            name (file-name-nondirectory full))
      (if (not (member name filtered-names))
          (push name filtered-names)
        (if no-dir
            (if (setq sufx (assoc name counters))
                (setcdr sufx (1+ (cdr sufx)))
              (setq sufx 1)
              (push (cons name sufx) counters))
          (setq sufx (file-name-directory full)))
        (setq name (format "%s(%s)" name sufx)))
      (push (recentf-make-menu-element name full) filtered-list))))

(defsubst recentf-show-basenames-ascending (l)
  "Filter the list of menu elements L to show filenames sans directory.
Filenames are sorted in ascending order.
This filter combines the `recentf-sort-basenames-ascending' and
`recentf-show-basenames' filters."
  (recentf-show-basenames (recentf-sort-basenames-ascending l)))

(defsubst recentf-show-basenames-descending (l)
  "Filter the list of menu elements L to show filenames sans directory.
Filenames are sorted in descending order.
This filter combines the `recentf-sort-basenames-descending' and
`recentf-show-basenames' filters."
  (recentf-show-basenames (recentf-sort-basenames-descending l)))

(defun recentf-relative-filter (l)
  "Filter the list of menu-elements L to show relative filenames.
Filenames are relative to the `default-directory'."
  (mapcar #'(lambda (menu-element)
              (let* ((ful (recentf-menu-element-value menu-element))
                     (rel (file-relative-name ful default-directory)))
                (if (string-match "^\\.\\." rel)
                    menu-element
                  (recentf-make-menu-element rel ful))))
          l))

;;; Rule based menu filters
;;
(defcustom recentf-arrange-rules
  '(
    ("Elisp files (%d)" ".\\.el$")
    ("Java files (%d)"  ".\\.java$")
    ("C/C++ files (%d)" "c\\(pp\\)?$")
    )
  "*List of rules used by `recentf-arrange-by-rule' to build sub-menus.
A rule is a pair (SUB-MENU-TITLE . MATCHER).  SUB-MENU-TITLE is the
displayed title of the sub-menu where a '%d' `format' pattern is
replaced by the number of items in the sub-menu.  MATCHER is a regexp
or a list of regexps.  Items matching one of the regular expressions in
MATCHER are added to the corresponding sub-menu."
  :group 'recentf-filters
  :type '(repeat (cons string (repeat regexp)))
  :set 'recentf-menu-customization-changed)

(defcustom recentf-arrange-by-rule-others "Other files (%d)"
  "*Title of the `recentf-arrange-by-rule' sub-menu.
This is for the menu where items that don't match any
`recentf-arrange-rules' are displayed.  If nil these items are
displayed in the main recent files menu.  A '%d' `format' pattern in
the title is replaced by the number of items in the sub-menu."
  :group 'recentf-filters
  :type '(choice (const  :tag "Main menu" nil)
                 (string :tag "Title"))
  :set 'recentf-menu-customization-changed)

(defcustom recentf-arrange-by-rules-min-items 0
  "*Minimum number of items in a `recentf-arrange-by-rule' sub-menu.
If the number of items in a sub-menu is less than this value the
corresponding sub-menu items are displayed in the main recent files
menu or in the `recentf-arrange-by-rule-others' sub-menu if
defined."
  :group 'recentf-filters
  :type 'number
  :set 'recentf-menu-customization-changed)

(defcustom recentf-arrange-by-rule-subfilter nil
  "*Function called by a rule based filter to filter sub-menu elements.
A nil value means no filter.  See also `recentf-menu-filter'.
You can't use another rule based filter here."
  :group 'recentf-filters
  :type '(choice (const nil) function)
  :set (lambda (variable value)
         (when (memq value '(recentf-arrange-by-rule
                             recentf-arrange-by-mode
                             recentf-arrange-by-dir))
           (error "Recursive use of a rule based filter"))
         (recentf-menu-customization-changed variable value)))

(defun recentf-match-rule-p (matcher filename)
  "Return non-nil if the rule specified by MATCHER match FILENAME.
See `recentf-arrange-rules' for details on MATCHER."
  (if (stringp matcher)
      (string-match matcher filename)
    (while (and (consp matcher)
                (not (string-match (car matcher) filename)))
      (setq matcher (cdr matcher)))
    matcher))

(defun recentf-arrange-by-rule (l)
  "Filter the list of menu-elements L.
Arrange them in sub-menus following rules in `recentf-arrange-rules'."
  (if (not recentf-arrange-rules)
      l
    (let* ((strip (assq t recentf-arrange-rules))
           (rules (remq strip recentf-arrange-rules))
           (menus (mapcar #'(lambda (r) (list (car r))) rules))
           others l1 l2 menu file min count)
      ;; Put menu items into sub-menus as defined by rules.
      (dolist (elt l)
        (setq l1   menus ;; List of sub-menus
              l2   rules ;; List of corresponding matchers.
              file (recentf-menu-element-value elt)
              menu nil)
        ;; Apply the strip suffix rule.
        (while (recentf-match-rule-p (cdr strip) file)
          (setq file (substring file 0 (match-beginning 0))))
        ;; Search which sub-menu to put the menu item into.
        (while (and (not menu) l2)
          (when (recentf-match-rule-p (cdar l2) file)
            (setq menu (car l1))
            (recentf-set-menu-element-value
             menu (cons elt (recentf-menu-element-value menu))))
          (setq l1 (cdr l1)
                l2 (cdr l2)))
        ;; Put unmatched menu items in the `others' bin.
        (or menu (push elt others)))
      ;; Finalize the sub-menus.  That is, for each one:
      ;; - truncate it depending on the value of
      ;;   `recentf-arrange-by-rules-min-items',
      ;; - replace %d by the number of menu items,
      ;; - apply `recentf-arrange-by-rule-subfilter' to menu items.
      (setq min (if (natnump recentf-arrange-by-rules-min-items)
                    recentf-arrange-by-rules-min-items 0)
            l2 nil)
      (dolist (menu menus)
        (when (setq l1 (recentf-menu-element-value menu))
          (setq count (length l1))
          (if (< count min)
              (setq others (nconc l1 others))
            (recentf-set-menu-element-item
             menu (format (recentf-menu-element-item menu) count))
            (recentf-set-menu-element-value
             menu (recentf-apply-menu-filter
                   recentf-arrange-by-rule-subfilter (nreverse l1)))
            (push menu l2))))
      ;; Add the menu items remaining in the `others' bin.
      (if (and (stringp recentf-arrange-by-rule-others) others)
          (nreverse
           (cons
            (recentf-make-menu-element
             (format recentf-arrange-by-rule-others (length others))
             (recentf-apply-menu-filter
              recentf-arrange-by-rule-subfilter (nreverse others)))
            l2))
        (nconc
         (nreverse l2)
         (recentf-apply-menu-filter
          recentf-arrange-by-rule-subfilter (nreverse others)))))))

;;; Predefined rule based menu filters
;;
(defun recentf-build-mode-rules ()
  "Convert `auto-mode-alist' to menu filter rules.
Rules obey `recentf-arrange-rules' format."
  (let ((case-fold-search recentf-case-fold-search)
        regexp rule-name rule rules)
    (dolist (mode auto-mode-alist)
      (setq regexp (car mode)
            mode   (cdr mode))
      (when mode
        (cond
         ;; Build a special "strip suffix" rule from entries of the
         ;; form (REGEXP FUNCTION NON-NIL).  Notice that FUNCTION is
         ;; ignored by the menu filter.  So in some corner cases a
         ;; wrong mode could be guessed.
         ((and (consp mode) (cadr mode))
          (setq rule-name t))
         ((and mode (symbolp mode))
          (setq rule-name (symbol-name mode))
          (if (string-match "\\(.*\\)-mode$" rule-name)
              (setq rule-name (match-string 1 rule-name)))
          (setq rule-name (concat rule-name " (%d)"))))
        (setq rule (assoc rule-name rules))
        (if rule
            (setcdr rule (cons regexp (cdr rule)))
          (push (list rule-name regexp) rules))))
    ;; It is important to preserve auto-mode-alist order
    ;; to ensure the right file <-> mode association
    (nreverse rules)))

(defun recentf-arrange-by-mode (l)
  "Split the list of menu-elements L into sub-menus by major mode."
  (let ((recentf-arrange-rules (recentf-build-mode-rules))
        (recentf-arrange-by-rule-others "others (%d)"))
    (recentf-arrange-by-rule l)))

(defun recentf-build-dir-rules (l)
  "Convert directories in menu-elements L to menu filter rules.
Rules obey `recentf-arrange-rules' format."
  (let (dirs)
    (mapcar #'(lambda (e)
                (let ((dir (file-name-directory
                            (recentf-menu-element-value e))))
                  (or (recentf-string-member dir dirs)
                      (push dir dirs))))
            l)
    (mapcar #'(lambda (d)
                (cons (concat d " (%d)")
                      (concat "\\`" d)))
            (nreverse (sort dirs 'recentf-string-lessp)))))

(defun recentf-file-name-nondir (l)
  "Filter the list of menu-elements L to show filenames sans directory.
This simplified version of `recentf-show-basenames' does not handle
duplicates.  It is used by `recentf-arrange-by-dir' as its
`recentf-arrange-by-rule-subfilter'."
  (mapcar #'(lambda (e)
              (recentf-make-menu-element
               (file-name-nondirectory (recentf-menu-element-value e))
               (recentf-menu-element-value e)))
          l))

(defun recentf-arrange-by-dir (l)
  "Split the list of menu-elements L into sub-menus by directory."
  (let ((recentf-arrange-rules (recentf-build-dir-rules l))
        (recentf-arrange-by-rule-subfilter 'recentf-file-name-nondir)
        recentf-arrange-by-rule-others)
    (nreverse (recentf-arrange-by-rule l))))

;;; Ring of menu filters
;;
(defvar recentf-filter-changer-state nil
  "Used by `recentf-filter-changer' to hold its state.")

(defcustom recentf-filter-changer-alist
  '(
    (recentf-arrange-by-mode . "*Files by Mode*")
    (recentf-arrange-by-dir  . "*Files by Directory*")
    (recentf-arrange-by-rule . "*Files by User Rule*")
    )
  "*List of filters managed by `recentf-filter-changer'.
Each filter is defined by a pair (FUNCTION . LABEL), where FUNCTION is
the filter function, and LABEL is the menu item displayed to select
that filter."
  :group 'recentf-filters
  :type '(repeat (cons function string))
  :set (lambda (variable value)
         (setq recentf-filter-changer-state nil)
         (recentf-menu-customization-changed variable value)))

(defun recentf-filter-changer-goto-next ()
  "Go to the next filter available.
See `recentf-filter-changer'."
  (setq recentf-filter-changer-state (cdr recentf-filter-changer-state))
  (recentf-clear-data))

(defsubst recentf-filter-changer-get-current ()
  "Get the current filter available.
See `recentf-filter-changer'."
  (unless recentf-filter-changer-state
    (setq recentf-filter-changer-state recentf-filter-changer-alist))
  (car recentf-filter-changer-state))

(defsubst recentf-filter-changer-get-next ()
  "Get the next filter available.
See `recentf-filter-changer'."
  ;; At this point the current filter is the first element of
  ;; `recentf-filter-changer-state'.
  (car (or (cdr recentf-filter-changer-state)
           ;; There is no next element in
           ;; `recentf-filter-changer-state', so loop back to the
           ;; first element of `recentf-filter-changer-alist'.
           recentf-filter-changer-alist)))

(defun recentf-filter-changer (l)
  "Manage a ring of menu filters.
`recentf-filter-changer-alist' defines the filters in the ring.
Filtering of L is delegated to the current filter in the ring.  A
filter menu item is displayed allowing to dynamically activate the
next filter in the ring.  If the filter ring is empty, L is left
unchanged."
  (let ((filter (recentf-filter-changer-get-current)))
    (when filter
      (setq l (recentf-apply-menu-filter (car filter) l)
            filter (recentf-filter-changer-get-next))
      (when filter
        (setq recentf-menu-filter-commands
              (list (vector (cdr filter)
                            '(recentf-filter-changer-goto-next)
                            t)))))
    l))

;;; Hooks
;;
(defun recentf-track-opened-file ()
  "Insert the name of the file just opened or written into the recent list."
  (and buffer-file-name
       (recentf-add-file buffer-file-name))
  ;; Must return nil because it is run from `write-file-functions'.
  nil)

(defun recentf-track-closed-file ()
  "Update the recent list when a buffer is killed.
That is, remove a non kept file from the recent list."
  (and buffer-file-name
       (recentf-remove-if-non-kept buffer-file-name)))

(defun recentf-update-menu ()
  "Update the recentf menu from the current recent list."
  (let ((cache (cons default-directory recentf-list)))
    ;; Does nothing, if nothing has changed.
    (unless (equal recentf-data-cache cache)
      (setq recentf-data-cache cache)
      (condition-case err
          (easy-menu-add-item
           (recentf-menu-bar) recentf-menu-path
           (easy-menu-create-menu recentf-menu-title
                                  (recentf-make-menu-items))
           recentf-menu-before)
        (error
         (message "recentf update menu failed: %s"
                  (error-message-string err)))))))

(defconst recentf-used-hooks
  '(
    (find-file-hook       recentf-track-opened-file)
    (write-file-functions recentf-track-opened-file)
    (kill-buffer-hook     recentf-track-closed-file)
    (menu-bar-update-hook recentf-update-menu)
    (kill-emacs-hook      recentf-save-list)
    )
  "Hooks used by recentf.")

(defsubst recentf-enabled-p ()
  "Return non-nil if recentf mode is currently enabled."
  (memq 'recentf-update-menu menu-bar-update-hook))

;;; Commands
;;

;;; Common dialog stuff
;;
(defun recentf-cancel-dialog (&rest ignore)
  "Cancel the current dialog.
IGNORE arguments."
  (interactive)
  (kill-buffer (current-buffer))
  (message "Dialog canceled"))

(defun recentf-dialog-goto-first (widget-type)
  "Move the cursor to the first WIDGET-TYPE in current dialog.
Go to the beginning of buffer if not found."
  (goto-char (point-min))
  (condition-case nil
      (let (done)
        (widget-move 1)
        (while (not done)
          (if (eq widget-type (widget-type (widget-at (point))))
              (setq done t)
            (widget-move 1))))
    (goto-char (point-min))))

(defvar recentf-dialog-mode-map
  (let ((km (copy-keymap recentf--shortcuts-keymap)))
    (set-keymap-parent km widget-keymap)
    (define-key km "q" 'recentf-cancel-dialog)
    (define-key km [follow-link] "\C-m")
    km)
  "Keymap used in recentf dialogs.")

(define-derived-mode recentf-dialog-mode nil "recentf-dialog"
  "Major mode of recentf dialogs.

\\{recentf-dialog-mode-map}"
  :syntax-table nil
  :abbrev-table nil
  (setq truncate-lines t))

(defmacro recentf-dialog (name &rest forms)
  "Show a dialog buffer with NAME, setup with FORMS."
  (declare (indent 1) (debug t))
  `(with-current-buffer (get-buffer-create ,name)
    ;; Cleanup buffer
    (let ((inhibit-read-only t)
          (ol (overlay-lists)))
      (mapc 'delete-overlay (car ol))
      (mapc 'delete-overlay (cdr ol))
      (erase-buffer))
    (recentf-dialog-mode)
    ,@forms
    (widget-setup)
    (switch-to-buffer (current-buffer))))

;;; Edit list dialog
;;
(defvar recentf-edit-list nil)

(defun recentf-edit-list-select (widget &rest ignore)
  "Toggle a file selection based on the checkbox WIDGET state.
IGNORE other arguments."
  (let ((value (widget-get widget :tag))
        (check (widget-value widget)))
    (if check
        (add-to-list 'recentf-edit-list value)
      (setq recentf-edit-list (delq value recentf-edit-list)))
    (message "%s %sselected" value (if check "" "un"))))

(defun recentf-edit-list-validate (&rest ignore)
  "Process the recent list when the edit list dialog is committed.
IGNORE arguments."
  (if recentf-edit-list
      (let ((i 0))
        (dolist (e recentf-edit-list)
          (setq recentf-list (delq e recentf-list)
                i (1+ i)))
        (kill-buffer (current-buffer))
        (message "%S file(s) removed from the list" i)
        (recentf-clear-data))
    (message "No file selected")))

(defun recentf-edit-list ()
  "Show a dialog to delete selected files from the recent list."
  (interactive)
  (recentf-dialog (format "*%s - Edit list*" recentf-menu-title)
    (set (make-local-variable 'recentf-edit-list) nil)
    (widget-insert
     "Click on OK to delete selected files from the recent list.
Click on Cancel or type `q' to cancel.\n")
    ;; Insert the list of files as checkboxes
    (dolist (item recentf-list)
      (widget-create 'checkbox
                     :value nil         ; unselected checkbox
                     :format "\n %[%v%]  %t"
                     :tag item
                     :notify 'recentf-edit-list-select))
    (widget-insert "\n\n")
    (widget-create
     'push-button
     :notify 'recentf-edit-list-validate
     :help-echo "Delete selected files from the recent list"
     "Ok")
    (widget-insert " ")
    (widget-create
     'push-button
     :notify 'recentf-cancel-dialog
     "Cancel")
    (recentf-dialog-goto-first 'checkbox)))

;;; Open file dialog
;;
(defun recentf-open-files-action (widget &rest ignore)
  "Open the file stored in WIDGET's value when notified.
IGNORE other arguments."
  (kill-buffer (current-buffer))
  (funcall recentf-menu-action (widget-value widget)))

;; List of files associated to a digit shortcut key.
(defvar recentf--files-with-key nil)

(defun recentf-show-digit-shortcut-filter (l)
  "Filter the list of menu-elements L to show digit shortcuts."
  (let ((i 0))
    (dolist (e l)
      (setq i (1+ i))
      (recentf-set-menu-element-item
       e (format "[%d] %s" (% i 10) (recentf-menu-element-item e))))
    l))

(defun recentf-open-files-item (menu-element)
  "Return a widget to display MENU-ELEMENT in a dialog buffer."
  (if (consp (cdr menu-element))
      ;; Represent a sub-menu with a tree widget
      `(tree-widget
        :open t
        :match ignore
        :node (item :tag ,(car menu-element)
                    :sample-face bold
                    :format "%{%t%}:\n")
        ,@(mapcar 'recentf-open-files-item
                  (cdr menu-element)))
    ;; Represent a single file with a link widget
    `(link :tag ,(car menu-element)
           :button-prefix ""
           :button-suffix ""
           :button-face default
           :format "%[%t%]\n"
           :help-echo ,(concat "Open " (cdr menu-element))
           :action recentf-open-files-action
           ,(cdr menu-element))))

(defun recentf-open-files-items (files)
  "Return a list of widgets to display FILES in a dialog buffer."
  (set (make-local-variable 'recentf--files-with-key)
       (recentf-trunc-list files 10))
  (mapcar 'recentf-open-files-item
          (append
           ;; When requested group the files with shortcuts together
           ;; at the top of the list.
           (when recentf-show-file-shortcuts-flag
             (setq files (nthcdr 10 files))
             (recentf-apply-menu-filter
              'recentf-show-digit-shortcut-filter
              (mapcar 'recentf-make-default-menu-element
                      recentf--files-with-key)))
           ;; Then the other files.
           (recentf-apply-menu-filter
            recentf-menu-filter
            (mapcar 'recentf-make-default-menu-element
                    files)))))

(defun recentf-open-files (&optional files buffer-name)
  "Show a dialog to open a recent file.
If optional argument FILES is non-nil, it is a list of recently-opened
files to choose from.  It defaults to the whole recent list.
If optional argument BUFFER-NAME is non-nil, it is a buffer name to
use for the dialog.  It defaults to \"*`recentf-menu-title'*\"."
  (interactive)
  (recentf-dialog (or buffer-name (format "*%s*" recentf-menu-title))
    (widget-insert "Click on a file"
                   (if recentf-show-file-shortcuts-flag
                       ", or type the corresponding digit key,"
                     "")
                   " to open it.\n"
                   "Click on Cancel or type `q' to cancel.\n")
    ;; Use a L&F that looks like the recentf menu.
    (tree-widget-set-theme "folder")
    (apply 'widget-create
           `(group
             :indent 2
             :format "\n%v\n"
             ,@(recentf-open-files-items (or files recentf-list))))
    (widget-create
     'push-button
     :notify 'recentf-cancel-dialog
     "Cancel")
    (recentf-dialog-goto-first 'link)))

(defun recentf-open-more-files ()
  "Show a dialog to open a recent file that is not in the menu."
  (interactive)
  (recentf-open-files (nthcdr recentf-max-menu-items recentf-list)
                      (format "*%s - More*" recentf-menu-title)))

(defun recentf-open-most-recent-file (&optional n)
  "Open the Nth most recent file.
Optional argument N must be a valid digit number.  It defaults to 1.
1 opens the most recent file, 2 the second most recent one, etc..
0 opens the tenth most recent file."
  (interactive "p")
  (cond
   ((zerop n) (setq n 10))
   ((and (> n 0) (< n 10)))
   ((error "Recent file number out of range [0-9], %d" n)))
  (let ((file (nth (1- n) (or recentf--files-with-key recentf-list))))
    (unless file (error "Not that many recent files"))
    ;; Close the open files dialog.
    (when recentf--files-with-key
      (kill-buffer (current-buffer)))
    (funcall recentf-menu-action file)))

;;; Save/load/cleanup the recent list
;;
(defconst recentf-save-file-header
  ";;; Automatically generated by `recentf' on %s.\n"
  "Header to be written into the `recentf-save-file'.")

(defconst recentf-save-file-coding-system
  (if (coding-system-p 'utf-8-emacs)
      'utf-8-emacs
    'emacs-mule)
  "Coding system of the file `recentf-save-file'.")

(defun recentf-save-list ()
  "Save the recent list.
Write data into the file specified by `recentf-save-file'."
  (interactive)
  (condition-case error
      (with-temp-buffer
        (erase-buffer)
        (set-buffer-file-coding-system recentf-save-file-coding-system)
        (insert (format recentf-save-file-header (current-time-string)))
        (recentf-dump-variable 'recentf-list recentf-max-saved-items)
        (recentf-dump-variable 'recentf-filter-changer-state)
        (insert "\n\n;;; Local Variables:\n"
                (format ";;; coding: %s\n" recentf-save-file-coding-system)
                ";;; End:\n")
        (write-file (expand-file-name recentf-save-file))
        (when recentf-save-file-modes
          (set-file-modes recentf-save-file recentf-save-file-modes))
        nil)
    (error
     (warn "recentf mode: %s" (error-message-string error)))))

(defun recentf-load-list ()
  "Load a previously saved recent list.
Read data from the file specified by `recentf-save-file'.
When `recentf-initialize-file-name-history' is non-nil, initialize an
empty `file-name-history' with the recent list."
  (interactive)
  (let ((file (expand-file-name recentf-save-file)))
    (when (file-readable-p file)
      (load-file file)
      (and recentf-initialize-file-name-history
           (not file-name-history)
           (setq file-name-history (mapcar 'abbreviate-file-name
                                           recentf-list))))))

(defun recentf-cleanup ()
  "Cleanup the recent list.
That is, remove duplicates, non-kept, and excluded files."
  (interactive)
  (message "Cleaning up the recentf list...")
  (let ((n 0) newlist)
    (dolist (f recentf-list)
      (setq f (recentf-expand-file-name f))
      (if (and (recentf-include-p f)
               (recentf-keep-p f)
               (not (recentf-string-member f newlist)))
          (push f newlist)
        (setq n (1+ n))
        (message "File %s removed from the recentf list" f)))
    (message "Cleaning up the recentf list...done (%d removed)" n)
    (setq recentf-list (nreverse newlist))))

;;; The minor mode
;;
(defvar recentf-mode-map (make-sparse-keymap)
  "Keymap to use in recentf mode.")

;;;###autoload
(define-minor-mode recentf-mode
  "Toggle recentf mode.
With prefix argument ARG, turn on if positive, otherwise off.
Returns non-nil if the new state is enabled.

When recentf mode is enabled, it maintains a menu for visiting files
that were operated on recently.

\\{recentf-mode-map}"
  :global t
  :group 'recentf
  :keymap recentf-mode-map
  (unless (and recentf-mode (recentf-enabled-p))
    (if recentf-mode
        (recentf-load-list)
      (recentf-save-list))
    (recentf-auto-cleanup)
    (recentf-clear-data)
    (let ((hook-setup (if recentf-mode 'add-hook 'remove-hook)))
      (dolist (hook recentf-used-hooks)
        (apply hook-setup hook)))
    (run-hooks 'recentf-mode-hook)
    (when (interactive-p)
      (message "Recentf mode %sabled" (if recentf-mode "en" "dis"))))
  recentf-mode)

(provide 'recentf)

(run-hooks 'recentf-load-hook)

;; arch-tag: 78f1eec9-0d16-4d19-a4eb-2e4529edb62a
;;; recentf.el ends here
