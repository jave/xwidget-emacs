;;; wisent-grammar.el --- Wisent's input grammar mode

;; Copyright (C) 2002-2011 Free Software Foundation, Inc.
;;
;; Author: David Ponce <david@dponce.com>
;; Maintainer: David Ponce <david@dponce.com>
;; Created: 26 Aug 2002
;; Keywords: syntax
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
;;
;; Major mode for editing Wisent's input grammar (.wy) files.

;;; Code:
(require 'semantic/grammar)
(require 'semantic/find)

(defsubst wisent-grammar-region-placeholder (symb)
  "Given a $N placeholder symbol in SYMB, return a $regionN symbol.
Return nil if $N is not a valid placeholder symbol."
  (let ((n (symbol-name symb)))
    (if (string-match "^[$]\\([1-9][0-9]*\\)$" n)
        (intern (concat "$region" (match-string 1 n))))))

(defun wisent-grammar-EXPAND (symb nonterm)
  "Expand call to EXPAND grammar macro.
Return the form to parse from within a nonterminal.
SYMB is a $I placeholder symbol that gives the bounds of the area to
parse.
NONTERM is the nonterminal symbol to start with."
  (unless (member nonterm (semantic-grammar-start))
    (error "EXPANDFULL macro called with %s, but not used with %%start"
           nonterm))
  (let (($ri (wisent-grammar-region-placeholder symb)))
    (if $ri
        `(semantic-bovinate-from-nonterminal
          (car ,$ri) (cdr ,$ri) ',nonterm)
      (error "Invalid form (EXPAND %s %s)" symb nonterm))))

(defun wisent-grammar-EXPANDFULL (symb nonterm)
  "Expand call to EXPANDFULL grammar macro.
Return the form to recursively parse an area.
SYMB is a $I placeholder symbol that gives the bounds of the area.
NONTERM is the nonterminal symbol to start with."
  (unless (member nonterm (semantic-grammar-start))
    (error "EXPANDFULL macro called with %s, but not used with %%start"
           nonterm))
  (let (($ri (wisent-grammar-region-placeholder symb)))
    (if $ri
        `(semantic-parse-region
          (car ,$ri) (cdr ,$ri) ',nonterm 1)
      (error "Invalid form (EXPANDFULL %s %s)" symb nonterm))))

(defun wisent-grammar-TAG (name class &rest attributes)
  "Expand call to TAG grammar macro.
Return the form to create a generic semantic tag.
See the function `semantic-tag' for the meaning of arguments NAME,
CLASS and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag ,name ,class ,@attributes)))

(defun wisent-grammar-VARIABLE-TAG (name type default-value &rest attributes)
  "Expand call to VARIABLE-TAG grammar macro.
Return the form to create a semantic tag of class variable.
See the function `semantic-tag-new-variable' for the meaning of
arguments NAME, TYPE, DEFAULT-VALUE and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-variable ,name ,type ,default-value ,@attributes)))

(defun wisent-grammar-FUNCTION-TAG (name type arg-list &rest attributes)
  "Expand call to FUNCTION-TAG grammar macro.
Return the form to create a semantic tag of class function.
See the function `semantic-tag-new-function' for the meaning of
arguments NAME, TYPE, ARG-LIST and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-function ,name ,type ,arg-list ,@attributes)))

(defun wisent-grammar-TYPE-TAG (name type members parents &rest attributes)
  "Expand call to TYPE-TAG grammar macro.
Return the form to create a semantic tag of class type.
See the function `semantic-tag-new-type' for the meaning of arguments
NAME, TYPE, MEMBERS, PARENTS and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-type ,name ,type ,members ,parents ,@attributes)))

(defun wisent-grammar-INCLUDE-TAG (name system-flag &rest attributes)
  "Expand call to INCLUDE-TAG grammar macro.
Return the form to create a semantic tag of class include.
See the function `semantic-tag-new-include' for the meaning of
arguments NAME, SYSTEM-FLAG and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-include ,name ,system-flag ,@attributes)))

(defun wisent-grammar-PACKAGE-TAG (name detail &rest attributes)
  "Expand call to PACKAGE-TAG grammar macro.
Return the form to create a semantic tag of class package.
See the function `semantic-tag-new-package' for the meaning of
arguments NAME, DETAIL and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-package ,name ,detail ,@attributes)))

(defun wisent-grammar-CODE-TAG (name detail &rest attributes)
  "Expand call to CODE-TAG grammar macro.
Return the form to create a semantic tag of class code.
See the function `semantic-tag-new-code' for the meaning of arguments
NAME, DETAIL and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-code ,name ,detail ,@attributes)))

(defun wisent-grammar-ALIAS-TAG (name aliasclass definition &rest attributes)
  "Expand call to ALIAS-TAG grammar macro.
Return the form to create a semantic tag of class alias.
See the function `semantic-tag-new-alias' for the meaning of arguments
NAME, ALIASCLASS, DEFINITION and ATTRIBUTES."
  `(wisent-raw-tag
    (semantic-tag-new-alias ,name ,aliasclass ,definition ,@attributes)))

(defun wisent-grammar-EXPANDTAG (raw-tag)
  "Expand call to EXPANDTAG grammar macro.
Return the form to produce a list of cooked tags from raw form of
Semantic tag RAW-TAG."
  `(wisent-cook-tag ,raw-tag))

(defun wisent-grammar-AST-ADD (ast &rest nodes)
  "Expand call to AST-ADD grammar macro.
Return the form to update the abstract syntax tree AST with NODES.
See also the function `semantic-ast-add'."
  `(semantic-ast-add ,ast ,@nodes))

(defun wisent-grammar-AST-PUT (ast &rest nodes)
  "Expand call to AST-PUT grammar macro.
Return the form to update the abstract syntax tree AST with NODES.
See also the function `semantic-ast-put'."
  `(semantic-ast-put ,ast ,@nodes))

(defun wisent-grammar-AST-GET (ast node)
  "Expand call to AST-GET grammar macro.
Return the form to get, from the abstract syntax tree AST, the value
of NODE.
See also the function `semantic-ast-get'."
  `(semantic-ast-get ,ast ,node))

(defun wisent-grammar-AST-GET1 (ast node)
  "Expand call to AST-GET1 grammar macro.
Return the form to get, from the abstract syntax tree AST, the first
value of NODE.
See also the function `semantic-ast-get1'."
  `(semantic-ast-get1 ,ast ,node))

(defun wisent-grammar-AST-GET-STRING (ast node)
  "Expand call to AST-GET-STRING grammar macro.
Return the form to get, from the abstract syntax tree AST, the value
of NODE as a string.
See also the function `semantic-ast-get-string'."
  `(semantic-ast-get-string ,ast ,node))

(defun wisent-grammar-AST-MERGE (ast1 ast2)
  "Expand call to AST-MERGE grammar macro.
Return the form to merge the abstract syntax trees AST1 and AST2.
See also the function `semantic-ast-merge'."
  `(semantic-ast-merge ,ast1 ,ast2))

(defun wisent-grammar-SKIP-BLOCK (&optional symb)
  "Expand call to SKIP-BLOCK grammar macro.
Return the form to skip a parenthesized block.
Optional argument SYMB is a $I placeholder symbol that gives the
bounds of the block to skip.  By default, skip the block at `$1'.
See also the function `wisent-skip-block'."
  (let ($ri)
    (when symb
      (unless (setq $ri (wisent-grammar-region-placeholder symb))
        (error "Invalid form (SKIP-BLOCK %s)" symb)))
    `(wisent-skip-block ,$ri)))

(defun wisent-grammar-SKIP-TOKEN ()
  "Expand call to SKIP-TOKEN grammar macro.
Return the form to skip the lookahead token.
See also the function `wisent-skip-token'."
  `(wisent-skip-token))

(defun wisent-grammar-assocs ()
  "Return associativity and precedence level definitions."
  (mapcar
   #'(lambda (tag)
       (cons (intern (semantic-tag-name tag))
             (mapcar #'semantic-grammar-item-value
                     (semantic-tag-get-attribute tag :value))))
   (semantic-find-tags-by-class 'assoc (current-buffer))))

(defun wisent-grammar-terminals ()
  "Return the list of terminal symbols.
Keep order of declaration in the WY file without duplicates."
  (let (terms)
    (mapcar
     #'(lambda (tag)
         (mapcar #'(lambda (name)
                     (add-to-list 'terms (intern name)))
                 (cons (semantic-tag-name tag)
                       (semantic-tag-get-attribute tag :rest))))
     (semantic--find-tags-by-function
      #'(lambda (tag)
          (memq (semantic-tag-class tag) '(token keyword)))
      (current-buffer)))
    (nreverse terms)))

;; Cache of macro definitions currently in use.
(defvar wisent--grammar-macros nil)

(defun wisent-grammar-expand-macros (expr)
  "Expand expression EXPR into a form without grammar macros.
Return the expanded expression."
  (if (or (atom expr) (semantic-grammar-quote-p (car expr)))
      expr ;; Just return atom or quoted expression.
    (let* ((expr  (mapcar 'wisent-grammar-expand-macros expr))
           (macro (assq (car expr) wisent--grammar-macros)))
      (if macro ;; Expand Semantic built-in.
          (apply (cdr macro) (cdr expr))
        expr))))

(defun wisent-grammar-nonterminals ()
  "Return the list form of nonterminal definitions."
  (let ((nttags (semantic-find-tags-by-class
                 'nonterminal (current-buffer)))
        ;; Setup the cache of macro definitions.
        (wisent--grammar-macros (semantic-grammar-macros))
        rltags nterms rules rule elems elem actn sexp prec)
    (while nttags
      (setq rltags (semantic-tag-components (car nttags))
            rules  nil)
      (while rltags
        (setq elems (semantic-tag-get-attribute (car rltags) :value)
              prec  (semantic-tag-get-attribute (car rltags) :prec)
              actn  (semantic-tag-get-attribute (car rltags) :expr)
              rule  nil)
        (when elems ;; not an EMPTY rule
          (while elems
            (setq elem  (car elems)
                  elems (cdr elems))
            (setq elem (if (consp elem) ;; mid-rule action
                           (wisent-grammar-expand-macros (read (car elem)))
                         (semantic-grammar-item-value elem)) ;; item
                  rule (cons elem rule)))
          (setq rule (nreverse rule)))
        (if prec
            (setq prec (vector (semantic-grammar-item-value prec))))
        (if actn
            (setq sexp (wisent-grammar-expand-macros (read actn))))
        (setq rule (if actn
                       (if prec
                           (list rule prec sexp)
                         (list rule sexp))
                     (if prec
                         (list rule prec)
                       (list rule))))
        (setq rules (cons rule rules)
              rltags (cdr rltags)))
      (setq nterms (cons (cons (intern (semantic-tag-name (car nttags)))
                               (nreverse rules))
                         nterms)
            nttags (cdr nttags)))
    (nreverse nterms)))

(defun wisent-grammar-grammar ()
  "Return Elisp form of the grammar."
  (let* ((terminals    (wisent-grammar-terminals))
         (nonterminals (wisent-grammar-nonterminals))
         (assocs       (wisent-grammar-assocs)))
    (cons terminals (cons assocs nonterminals))))

(defun wisent-grammar-parsetable-builder ()
  "Return the value of the parser table."
  `(progn
     ;; Ensure that the grammar [byte-]compiler is available.
     (eval-when-compile (require 'semantic/wisent/comp))
     (wisent-compile-grammar
      ',(wisent-grammar-grammar)
      ',(semantic-grammar-start))))

(defun wisent-grammar-setupcode-builder ()
  "Return the parser setup code."
  (format
   "(semantic-install-function-overrides\n\
      '((parse-stream . wisent-parse-stream)))\n\
    (setq semantic-parser-name \"LALR\"\n\
          semantic--parse-table %s\n\
          semantic-debug-parser-source %S\n\
          semantic-flex-keywords-obarray %s\n\
          semantic-lex-types-obarray %s)\n\
    ;; Collect unmatched syntax lexical tokens\n\
    (semantic-make-local-hook 'wisent-discarding-token-functions)\n\
    (add-hook 'wisent-discarding-token-functions\n\
              'wisent-collect-unmatched-syntax nil t)"
   (semantic-grammar-parsetable)
   (buffer-name)
   (semantic-grammar-keywordtable)
   (semantic-grammar-tokentable)))

(defvar wisent-grammar-menu
  '("WY Grammar"
    ["LALR Compiler Verbose" wisent-toggle-verbose-flag
     :style toggle :active (boundp 'wisent-verbose-flag)
     :selected (and (boundp 'wisent-verbose-flag)
                    wisent-verbose-flag)]
    )
  "WY mode specific grammar menu.
Menu items are appended to the common grammar menu.")

(define-derived-mode wisent-grammar-mode semantic-grammar-mode "WY"
  "Major mode for editing Wisent grammars."
  (semantic-grammar-setup-menu wisent-grammar-menu)
  (semantic-install-function-overrides
   '((grammar-parsetable-builder . wisent-grammar-parsetable-builder)
     (grammar-setupcode-builder  . wisent-grammar-setupcode-builder)
     )))

(add-to-list 'auto-mode-alist '("\\.wy$" . wisent-grammar-mode))

(defvar-mode-local wisent-grammar-mode semantic-grammar-macros
  '(
    (ASSOC          . semantic-grammar-ASSOC)
    (EXPAND         . wisent-grammar-EXPAND)
    (EXPANDFULL     . wisent-grammar-EXPANDFULL)
    (TAG            . wisent-grammar-TAG)
    (VARIABLE-TAG   . wisent-grammar-VARIABLE-TAG)
    (FUNCTION-TAG   . wisent-grammar-FUNCTION-TAG)
    (TYPE-TAG       . wisent-grammar-TYPE-TAG)
    (INCLUDE-TAG    . wisent-grammar-INCLUDE-TAG)
    (PACKAGE-TAG    . wisent-grammar-PACKAGE-TAG)
    (EXPANDTAG      . wisent-grammar-EXPANDTAG)
    (CODE-TAG       . wisent-grammar-CODE-TAG)
    (ALIAS-TAG      . wisent-grammar-ALIAS-TAG)
    (AST-ADD        . wisent-grammar-AST-ADD)
    (AST-PUT        . wisent-grammar-AST-PUT)
    (AST-GET        . wisent-grammar-AST-GET)
    (AST-GET1       . wisent-grammar-AST-GET1)
    (AST-GET-STRING . wisent-grammar-AST-GET-STRING)
    (AST-MERGE      . wisent-grammar-AST-MERGE)
    (SKIP-BLOCK     . wisent-grammar-SKIP-BLOCK)
    (SKIP-TOKEN     . wisent-grammar-SKIP-TOKEN)
    )
  "Semantic grammar macros used in wisent grammars.")

;;; wisent-grammar.el ends here
