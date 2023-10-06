# Major mode for x86 assembly/objdump using tree-sitter

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This package is compatible with and was tested against the tree-sitter grammar
for x86 assembly found at https://github.com/bearcove/tree-sitter-x86asm.

It provides font-locking, imenu, and limited indentation/navigation support for
x86 assembly buffers.

## Installing

Emacs 29.1 or above with tree-sitter support is required. 

Tree-sitter starter guide: https://git.savannah.gnu.org/cgit/emacs.git/tree/admin/notes/tree-sitter/starter-guide?h=emacs-29

### Install tree-sitter parser for x86

Add the source to `treesit-language-source-alist`. 

```elisp
(add-to-list
 'treesit-language-source-alist
 '(x86asm "https://github.com/bearcove/tree-sitter-x86asm"))
```

Then run `M-x treesit-install-language-grammar` and select `x86asm` to install.

### Install x86asm-ts-mode.el from source

- Clone this repository
- Add the following to your emacs config

```elisp
(require "[cloned nverno/x86asm-ts-mode]/x86asm-ts-mode.el")
```

### Troubleshooting

If you get the following warning:

```
⛔ Warning (treesit): Cannot activate tree-sitter, because tree-sitter
library is not compiled with Emacs [2 times]
```

Then you do not have tree-sitter support for your emacs installation.

If you get the following warnings:
```
⛔ Warning (treesit): Cannot activate tree-sitter, because language grammar for x86asm is unavailable (not-found): (libtree-sitter-x86asm libtree-sitter-x86asm.so) No such file or directory
```

then the x86asm grammar files are not properly installed on your system.
