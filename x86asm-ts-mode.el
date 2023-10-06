;;; x86asm-ts-mode.el --- Major mode for x86 assembly using tree sitter -*- lexical-binding: t; -*-

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/x86asm-ts-mode
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; Created:  5 October 2023
;; Keywords: tree-sitter asm x86 objdump assembly

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Major mode for x86 assembly source code using tree-sitter. Works reasonably
;; well for objdump output as well.
;;
;; Missing:
;; - no real support for indentation.
;;
;; See https://github.com/bearcove/tree-sitter-x86asm for more details and
;; missing features.
;;
;;; Installation:
;;
;; 1. Install x86asm tree-sitter library from
;; https://github.com/bearcove/tree-sitter-x86asm
;; 2. Require this file.
;;
;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'treesit)

(defcustom x86asm-ts-mode-indent-level 8
  "Number of spaces for each indententation step."
  :group 'asm
  :type 'integer
  :safe 'integerp)

;;; Syntax

(defvar x86asm-ts-mode--syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23" st)
    (modify-syntax-entry ?$  "." st)
    st)
  "Syntax table in use in x86asm Mode buffers.")

;;; Indentation

(defvar x86asm-ts-mode--indent-rules
  '((x86asm
     ((parent-is "source_file") parent 0)
     ((node-is ")") parent-bol 0)
     ((node-is ">") parent-bol 0)
     ((node-is "]") parent-bol 0)
     (no-node parent-bol x86asm-ts-mode-indent-level)
     (catch-all parent-bol x86asm-ts-mode-indent-level)))
  "Tree-sitter indentation rules for x86asm.")

;;; Font-Lock

(defvar x86asm-ts-mode--feature-list
  '(( comment definition)
    ( keyword string builtin)
    ( literal label variable escape-sequence constant)
    ( bracket delimiter operator error misc-punctuation))
  "`treesit-font-lock-feature-list' for `x86asm-ts-mode'.")

(defvar x86asm-ts-mode--keywords
  '("section" "extern" "global" "ptr" "info")
  "x86asm keywords for tree-sitter font-locking.")

(defvar x86asm-ts-mode--builtin-functions nil
  "x86asm builtin functions for tree-sitter font-locking.")

(defvar x86asm-ts-mode--builtin-variables nil
  "x86asm builtin variables for tree-sitter font-lock.")

(defvar x86asm-ts-mode--operators
  '("+" "*")
  "x86asm operators for tree-sitter font-lock.")


(defvar x86asm-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'x86asm
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'x86asm
   :feature 'string
   '((string_literal) @font-lock-string-face
     [(objdump_file_format)] @font-lock-string-face
     (objdump_disas_of_section
      [_] @font-lock-doc-face
      (section_name) @font-lock-constant-face))

   :language 'x86asm
   :feature 'keyword
   `([,@x86asm-ts-mode--keywords] @font-lock-keyword-face
     [(mnemonic) (width) (ptr)] @font-lock-keyword-face
     (shell_cmd _ @font-lock-keyword-face))

   :language 'x86asm
   :feature 'builtin
   `([(register) (segment) (builtin_kw)] @font-lock-builtin-face)

   :language 'x86asm
   :feature 'literal
   '((integer_literal) @font-lock-number-face)

   :language 'x86asm
   :feature 'constant
   '((section_name) @font-lock-constant-face)
   
   :language 'x86asm
   :feature 'definition
   '((label_name) @font-lock-function-name-face
     (extern (identifier) @font-lock-function-name-face)
     [(objdump_addr) (objdump_machine_code_bytes)] @font-lock-constant-face
     (objdump_section_label (identifier) @font-lock-function-name-face))

   :language 'x86asm
   :feature 'variable
   '((global (identifier) @font-lock-variable-use-face)
     (operand_ident) @font-lock-variable-use-face)
   
   :language 'x86asm
   :feature 'bracket
   '(["(" ")" "<" ">" "[" "]"] @font-lock-bracket-face)

   :language 'x86asm
   :feature 'operator
   `([,@x86asm-ts-mode--operators] @font-lock-operator-face)

   :language 'x86asm
   :feature 'delimiter
   '([":" ","] @font-lock-delimiter-face)

   :language 'x86asm
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   ;; :language 'x86asm
   ;; :feature 'misc-punctuation
   ;; :override 'append
   ;; '()

   :language 'x86asm
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for x86asm.")

;;; Navigation

(defun x86asm-ts-mode--defun-name (node)
  "Find name of NODE."
  (treesit-node-text
   (or (treesit-node-child-by-field-name node "name")
       node)))

(defvar x86asm-ts-mode--sentence-nodes nil
  "See `treesit-sentence-type-regexp' for more information.")

(defvar x86asm-ts-mode--sexp-nodes nil ;; '(not "[](),[{}]")
  "See `treesit-sexp-type-regexp' for more information.")

(defvar x86asm-ts-mode--text-nodes (rx (or "comment" "string_literal" "objdump"))
  "See `treesit-text-type-regexp' for more information.")

;;;###autoload
(define-derived-mode x86asm-ts-mode prog-mode "x86"
  "Major mode for editing x86 assembly source code."
  :group 'asm
  :syntax-table x86asm-ts-mode--syntax-table
  (when (treesit-ready-p 'x86asm)
    (treesit-parser-create 'x86asm)

    ;; Comments
    (setq-local comment-start ";")
    (setq-local comment-end "")
    (setq-local comment-start-skip ";+[ \t]*")
    (setq-local comment-add 1)
    (setq-local parse-sexp-ignore-comments t)
    
    ;; Indentation
    (setq-local treesit-simple-indent-rules x86asm-ts-mode--indent-rules)

    ;; Font-Locking
    (setq-local treesit-font-lock-settings x86asm-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list x86asm-ts-mode--feature-list)

    ;; Navigation
    (setq-local treesit-defun-prefer-top-level t)
    (setq-local treesit-defun-name-function #'x86asm-ts-mode--defun-name)
    (setq-local treesit-defun-type-regexp (rx (or "label")))
    
    ;; navigation objects
    (setq-local treesit-thing-settings
                `((x86asm
                   (sexp ,x86asm-ts-mode--sexp-nodes)
                   (sentence ,x86asm-ts-mode--sentence-nodes)
                   (text ,x86asm-ts-mode--text-nodes))))

    ;; Imenu
    (setq-local treesit-simple-imenu-settings `(("Label" "\\`label_name\\'")))

    (treesit-major-mode-setup)))

(when (treesit-ready-p 'x86asm)
  (add-to-list
   'auto-mode-alist (cons (rx "." (or "s" "S" "asm") eos) 'x86asm-ts-mode)))

(provide 'x86asm-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; x86asm-ts-mode.el ends here
