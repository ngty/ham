;;; shell.el --- specialized comint.el for running the shell

;; Copyright (C) 1988, 1993, 1994, 1995, 1996, 1997, 2000, 2001,
;;   2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

;; Author: Olin Shivers <shivers@cs.cmu.edu>
;;	Simon Marshall <simon@gnu.org>
;; Maintainer: FSF <emacs-devel@gnu.org>
;; Keywords: processes

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

;; This file defines a ham-shell-in-a-buffer package (shell mode) built on
;; top of comint mode.  This is actually cmushell with things renamed
;; to replace its counterpart in Emacs 18.  cmushell is more
;; featureful, robust, and uniform than the Emacs 18 version.

;; Since this mode is built on top of the general command-interpreter-in-
;; a-buffer mode (comint mode), it shares a common base functionality,
;; and a common set of bindings, with all modes derived from comint mode.
;; This makes these modes easier to use.

;; For documentation on the functionality provided by comint mode, and
;; the hooks available for customising it, see the file comint.el.
;; For further information on shell mode, see the comments below.

;; Needs fixin:
;; When sending text from a source file to a subprocess, the process-mark can
;; move off the window, so you can lose sight of the process interactions.
;; Maybe I should ensure the process mark is in the window when I send
;; text to the process? Switch selectable?

;; YOUR .EMACS FILE
;;=============================================================================
;; Some suggestions for your .emacs file.
;;
;; ;; Define M-# to run some strange command:
;; (eval-after-load "shell"
;;  '(define-key ham-shell-mode-map "\M-#" 'shells-dynamic-spell))

;; Brief Command Documentation:
;;============================================================================
;; Comint Mode Commands: (common to shell and all comint-derived modes)
;;
;; m-p	   comint-previous-input    	   Cycle backwards in input history
;; m-n	   comint-next-input  	    	   Cycle forwards
;; m-r     comint-previous-matching-input  Previous input matching a regexp
;; m-s     comint-next-matching-input      Next input that matches
;; m-c-l   comint-show-output		   Show last batch of process output
;; return  comint-send-input
;; c-d	   comint-delchar-or-maybe-eof	   Delete char unless at end of buff.
;; c-c c-a comint-bol                      Beginning of line; skip prompt
;; c-c c-u comint-kill-input	    	   ^u
;; c-c c-w backward-kill-word    	   ^w
;; c-c c-c comint-interrupt-subjob 	   ^c
;; c-c c-z comint-stop-subjob	    	   ^z
;; c-c c-\ comint-quit-subjob	    	   ^\
;; c-c c-o comint-kill-output		   Delete last batch of process output
;; c-c c-r comint-show-output		   Show last batch of process output
;; c-c c-l comint-dynamic-list-input-ring  List input history
;;         send-invisible                  Read line w/o echo & send to proc
;;         comint-continue-subjob	   Useful if you accidentally suspend
;;					        top-level job
;; comint-mode-hook is the comint mode hook.

;; Shell Mode Commands:
;;         shell			Fires up the shell process
;; tab     comint-dynamic-complete	Complete filename/command/history
;; m-?     comint-dynamic-list-filename-completions
;;					List completions in help buffer
;; m-c-f   ham-shell-forward-command	Forward a shell command
;; m-c-b   ham-shell-backward-command	Backward a shell command
;; 	   dirs				Resync the buffer's dir stack
;; 	   ham-shell-dirtrack-mode		Turn dir tracking on/off
;;         comint-strip-ctrl-m		Remove trailing ^Ms from output
;;
;; The shell mode hook is ham-shell-mode-hook
;; comint-prompt-regexp is initialised to ham-shell-prompt-pattern, for backwards
;; compatibility.

;; Read the rest of this file for more information.

;;; Code:

(require 'comint)

;;; Customization and Buffer Variables

(defgroup shell nil
  "Running shell from within Emacs buffers."
  :group 'processes
  :group 'unix)

(defgroup ham-shell-directories nil
  "Directory support in shell mode."
  :group 'shell)

(defgroup ham-shell-faces nil
  "Faces in shell buffers."
  :group 'shell)

;; Just in case the faces are not supported
;; by current theme since the defvar itself
;; will not override previous values if any.
(defvar font-ut-green 'font-lock-type-face "Green font for success!")
(defvar font-ut-red 'font-lock-constant-face "Red font for failure!")
(defvar font-ut-light 'font-lock-string-face "Light font for highlight!")
(defvar font-ut-dark 'font-lock-preprocessor-face "dark font for highlight!")

;;;###autoload
(defcustom ham-shell-dumb-ham-shell-regexp (purecopy "cmd\\(proxy\\)?\\.exe")
  "Regexp to match shells that don't save their command history, and
don't handle the backslash as a quote character.  For shells that
match this regexp, Emacs will write out the command history when the
shell finishes, and won't remove backslashes when it unquotes shell
arguments."
  :type 'regexp
  :group 'shell)

(defcustom ham-shell-prompt-pattern "^[^#$%>\n]*[#$%>] *"
  "Regexp to match prompts in the inferior shell.
Defaults to \"^[^#$%>\\n]*[#$%>] *\", which works pretty well.
This variable is used to initialize `comint-prompt-regexp' in the
shell buffer.

If `comint-use-prompt-regexp' is nil, then this variable is only used
to determine paragraph boundaries.  See Info node `Shell Prompts' for
how Shell mode treats paragraphs.

The pattern should probably not match more than one line.  If it does,
Shell mode may become confused trying to distinguish prompt from input
on lines which don't start with a prompt.

This is a fine thing to set in your `.emacs' file."
  :type 'regexp
  :group 'shell)

(defcustom ham-shell-completion-fignore nil
  "List of suffixes to be disregarded during file/command completion.
This variable is used to initialize `comint-completion-fignore' in the shell
buffer.  The default is nil, for compatibility with most shells.
Some people like (\"~\" \"#\" \"%\").

This is a fine thing to set in your `.emacs' file."
  :type '(repeat (string :tag "Suffix"))
  :group 'shell)

(defvar ham-shell-delimiter-argument-list '(?\| ?& ?< ?> ?\( ?\) ?\;)
  "List of characters to recognize as separate arguments.
This variable is used to initialize `comint-delimiter-argument-list' in the
shell buffer.  The value may depend on the operating system or shell.

This is a fine thing to set in your `.emacs' file.")

(defvar ham-shell-file-name-chars
  (if (memq system-type '(ms-dos windows-nt cygwin))
      "~/A-Za-z0-9_^$!#%&{}@`'.,:()-"
    "[]~/A-Za-z0-9+@:_.$#%,={}-")
  "String of characters valid in a file name.
This variable is used to initialize `comint-file-name-chars' in the
shell buffer.  The value may depend on the operating system or shell.

This is a fine thing to set in your `.emacs' file.")

(defvar ham-shell-file-name-quote-list
  (if (memq system-type '(ms-dos windows-nt))
      nil
    (append ham-shell-delimiter-argument-list '(?\s ?$ ?\* ?\! ?\" ?\' ?\` ?\# ?\\)))
  "List of characters to quote when in a file name.
This variable is used to initialize `comint-file-name-quote-list' in the
shell buffer.  The value may depend on the operating system or shell.

This is a fine thing to set in your `.emacs' file.")

(defvar ham-shell-dynamic-complete-functions
  '(comint-replace-by-expanded-history
    ham-shell-dynamic-complete-environment-variable
    ham-shell-dynamic-complete-command
    ham-shell-replace-by-expanded-directory
    ham-shell-dynamic-complete-filename
    comint-dynamic-complete-filename)
  "List of functions called to perform completion.
This variable is used to initialize `comint-dynamic-complete-functions' in the
shell buffer.

This is a fine thing to set in your `.emacs' file.")

(defcustom ham-shell-command-regexp "[^;&|\n]+"
  "Regexp to match a single command within a pipeline.
This is used for directory tracking and does not do a perfect job."
  :type 'regexp
  :group 'shell)

(defcustom ham-shell-command-separator-regexp "[;&|\n \t]*"
  "Regexp to match a single command within a pipeline.
This is used for directory tracking and does not do a perfect job."
  :type 'regexp
  :group 'shell)

(defcustom ham-shell-completion-execonly t
  "If non-nil, use executable files only for completion candidates.
This mirrors the optional behavior of tcsh.

Detecting executability of files may slow command completion considerably."
  :type 'boolean
  :group 'shell)

(defcustom ham-shell-popd-regexp "popd"
  "Regexp to match subshell commands equivalent to popd."
  :type 'regexp
  :group 'ham-shell-directories)

(defcustom ham-shell-pushd-regexp "pushd"
  "Regexp to match subshell commands equivalent to pushd."
  :type 'regexp
  :group 'ham-shell-directories)

(defcustom ham-shell-pushd-tohome nil
  "If non-nil, make pushd with no arg behave as \"pushd ~\" (like cd).
This mirrors the optional behavior of tcsh."
  :type 'boolean
  :group 'ham-shell-directories)

(defcustom ham-shell-pushd-dextract nil
  "If non-nil, make \"pushd +n\" pop the nth dir to the stack top.
This mirrors the optional behavior of tcsh."
  :type 'boolean
  :group 'ham-shell-directories)

(defcustom ham-shell-pushd-dunique nil
  "If non-nil, make pushd only add unique directories to the stack.
This mirrors the optional behavior of tcsh."
  :type 'boolean
  :group 'ham-shell-directories)

(defcustom ham-shell-cd-regexp "cd"
  "Regexp to match subshell commands equivalent to cd."
  :type 'regexp
  :group 'ham-shell-directories)

(defcustom ham-shell-chdrive-regexp
  (if (memq system-type '(ms-dos windows-nt))
      ; NetWare allows the five chars between upper and lower alphabetics.
      "[]a-zA-Z^_`\\[\\\\]:"
    nil)
  "If non-nil, is regexp used to track drive changes."
  :type '(choice regexp
		 (const nil))
  :group 'ham-shell-directories)

(defcustom ham-shell-dirtrack-verbose t
  "If non-nil, show the directory stack following directory change.
This is effective only if directory tracking is enabled.
The `dirtrack' package provides an alternative implementation of this feature -
see the function `dirtrack-mode'."
  :type 'boolean
  :group 'ham-shell-directories)

(defcustom explicit-ham-shell-file-name nil
  "If non-nil, is file name to use for explicitly requested inferior shell."
  :type '(choice (const :tag "None" nil) file)
  :group 'shell)

;; Note: There are no explicit references to the variable `explicit-csh-ham-args'.
;; It is used implicitly by M-x shell when the shell is `csh'.
(defcustom explicit-csh-ham-args
  (if (eq system-type 'hpux)
      ;; -T persuades HP's csh not to think it is smarter
      ;; than us about what terminal modes to use.
      '("-i" "-T")
    '("-i"))
  "Args passed to inferior shell by \\[shell], if the shell is csh.
Value is a list of strings, which may be nil."
  :type '(repeat (string :tag "Argument"))
  :group 'shell)

;; Note: There are no explicit references to the variable `explicit-bash-ham-args'.
;; It is used implicitly by M-x shell when the interactive shell is `bash'.
(defcustom explicit-bash-ham-args
  (let* ((prog (or (and (boundp 'explicit-ham-shell-file-name) explicit-ham-shell-file-name)
		   (getenv "ESHELL") shell-file-name))
	 (name (file-name-nondirectory prog)))
    ;; Tell bash not to use readline, except for bash 1.x which
    ;; doesn't grook --noediting.  Bash 1.x has -nolineediting, but
    ;; process-send-eof cannot terminate bash if we use it.
    (if (and (not purify-flag)
	     (equal name "bash")
	     (file-executable-p prog)
	     (string-match "bad option"
			   (shell-command-to-string
			    (concat (shell-quote-argument prog)
				    " --noediting"))))
	'("-i")
      '("--noediting" "-i")))
  "Args passed to inferior shell by \\[shell], if the shell is bash.
Value is a list of strings, which may be nil."
  :type '(repeat (string :tag "Argument"))
  :group 'shell)

(defcustom ham-shell-input-autoexpand 'history
  "If non-nil, expand input command history references on completion.
This mirrors the optional behavior of tcsh (its autoexpand and histlit).

If the value is `input', then the expansion is seen on input.
If the value is `history', then the expansion is only when inserting
into the buffer's input ring.  See also `comint-magic-space' and
`comint-dynamic-complete'.

This variable supplies a default for `comint-input-autoexpand',
for Shell mode only."
  :type '(choice (const :tag "off" nil)
		 (const input)
		 (const history)
		 (const :tag "on" t))
  :group 'shell)

(defvar ham-shell-dirstack nil
  "List of directories saved by pushd in this buffer's shell.
Thus, this does not include the shell's current directory.")

(defvar ham-shell-dirtrackp t
  "Non-nil in a shell buffer means directory tracking is enabled.")

(defvar ham-shell-last-dir nil
  "Keep track of last directory for ksh `cd -' command.")

(defvar ham-shell-dirstack-query nil
  "Command used by `ham-shell-resync-dirs' to query the shell.")

(defvar ham-shell-mode-map nil)
(cond ((not ham-shell-mode-map)
       (setq ham-shell-mode-map (nconc (make-sparse-keymap) comint-mode-map))
       (define-key ham-shell-mode-map "\C-c\C-f" 'ham-shell-forward-command)
       (define-key ham-shell-mode-map "\C-c\C-b" 'ham-shell-backward-command)
       (define-key ham-shell-mode-map "\t" 'comint-dynamic-complete)
       (define-key ham-shell-mode-map "\M-?"
	 'comint-dynamic-list-filename-completions)
       (define-key ham-shell-mode-map [menu-bar completion]
	 (cons "Complete"
	       (copy-keymap (lookup-key comint-mode-map [menu-bar completion]))))
       (define-key-after (lookup-key ham-shell-mode-map [menu-bar completion])
	 [complete-env-variable] '("Complete Env. Variable Name" .
				   ham-shell-dynamic-complete-environment-variable)
	 'complete-file)
       (define-key-after (lookup-key ham-shell-mode-map [menu-bar completion])
	 [expand-directory] '("Expand Directory Reference" .
			      ham-shell-replace-by-expanded-directory)
	 'complete-expand)))

(defcustom ham-shell-mode-hook '()
  "Hook for customizing Shell mode."
  :type 'hook
  :group 'shell)

(defvar ham-shell-font-lock-keywords
  '(
    ("^.*\\[Begin\\].*\\[Begin\\]" . font-ut-light)
    ("^.*\\[End\\].*\\[End\\]" . font-ut-dark)
    ("^\\[S\\].*$" . font-ut-green)
    ("^\\[F\\].*(Line.\ [0-9]\\{1,4\\})" . font-ut-red)
    ("^\\[F\\].*$" . font-ut-red)
    ("^.* failed$" . font-ut-red)
    ("^.* succeeded$" . font-ut-green)
    ("(.*succeeded.*)" . font-ut-green)
    ("(.*failed.*)" . font-ut-red)
    ("^.* error: Failure.*$" . font-lock-warning-face)
    ("^.* warning: Failure.*$" . font-lock-warning-face)
    ("^################################$" . font-lock-warning-face)
    ("^#.*compilation error.*$" . font-lock-warning-face)
    ("^###.*run-time error.*$" . font-lock-comment-face)
    ("^---.*CALLSTACK.*$" . font-lock-comment-face)
    ("^#.*$" . font-lock-keyword-face)
    ("^\\.\\.\\..*$" . font-lock-string-face)
    ("^:::.*$" . font-lock-type-face)
    ("^==.*$" . font-lock-builtin-face)
    ("^= TODO.*$" . font-lock-builtin-face)
    ("^D/.*$" . font-lock-preprocessor-face)
    ("^V/.*$" . font-lock-type-face)
    ("^E/.*$" . font-lock-constant-face)
    ("^W/.*$" . font-lock-builtin-face)
    ("^I/.*$" . font-lock-keyword-face)
    ("^F/.*$" . font-lock-warning-face)
    ("^.*:[0-9]*: error:.*$" . font-lock-constant-face)
    ("^.*:[0-9]*: warning:.*$" . font-lock-builtin-face)
    ("^.*:[0-9]*: note:.*$" . font-lock-preprocessor-face)
    ("^.*([0-9]+).*error.*$" . font-lock-constant-face)
    ("^.*([0-9]+).*warning.*$" . font-lock-builtin-face)
    ("^.*([0-9]+).*NOTE.*$" . font-lock-preprocessor-face)
    ("^.*([0-9]+).*TODO.*$" . font-lock-type-face)
    ("^.*\\.java:[0-9]*: .*$" . font-lock-constant-face)
    ("^error:.*$" . font-lock-constant-face)
    ("^warning:.*$" . font-lock-builtin-face)
    ("^info:.*$" . font-lock-keyword-face)
    ("^debug:.*$" . font-lock-preprocessor-face)
    )
  "Additional expressions to highlight in Shell mode.")

;;; Basic Procedures

(put 'ham-shell-mode 'mode-class 'special)

(define-derived-mode ham-shell-mode comint-mode "hamShell"
  "Major mode for interacting with an inferior shell.\\<ham-shell-mode-map>
\\[comint-send-input] after the end of the process' output sends the text from
    the end of process to the end of the current line.
\\[comint-send-input] before end of process output copies the current line minus the prompt to
    the end of the buffer and sends it (\\[comint-copy-old-input] just copies the current line).
\\[send-invisible] reads a line of text without echoing it, and sends it to
    the shell.  This is useful for entering passwords.  Or, add the function
    `comint-watch-for-password-prompt' to `comint-output-filter-functions'.

If you want to make multiple shell buffers, rename the `*shell*' buffer
using \\[rename-buffer] or \\[rename-uniquely] and start a new shell.

If you want to make shell buffers limited in length, add the function
`comint-truncate-buffer' to `comint-output-filter-functions'.

If you accidentally suspend your process, use \\[comint-continue-subjob]
to continue it.

`cd', `pushd' and `popd' commands given to the shell are watched by Emacs to
keep this buffer's default directory the same as the shell's working directory.
While directory tracking is enabled, the shell's working directory is displayed
by \\[list-buffers] or \\[mouse-buffer-menu] in the `File' field.
\\[dirs] queries the shell and resyncs Emacs' idea of what the current
    directory stack is.
\\[ham-shell-dirtrack-mode] turns directory tracking on and off.
\(The `dirtrack' package provides an alternative implementation of this
feature - see the function `dirtrack-mode'.)

\\{ham-shell-mode-map}
Customization: Entry to this mode runs the hooks on `comint-mode-hook' and
`ham-shell-mode-hook' (in that order).  Before each input, the hooks on
`comint-input-filter-functions' are run.  After each shell output, the hooks
on `comint-output-filter-functions' are run.

Variables `ham-shell-cd-regexp', `ham-shell-chdrive-regexp', `ham-shell-pushd-regexp'
and `ham-shell-popd-regexp' are used to match their respective commands,
while `ham-shell-pushd-tohome', `ham-shell-pushd-dextract' and `ham-shell-pushd-dunique'
control the behavior of the relevant command.

Variables `comint-completion-autolist', `comint-completion-addsuffix',
`comint-completion-recexact' and `comint-completion-fignore' control the
behavior of file name, command name and variable name completion.  Variable
`ham-shell-completion-execonly' controls the behavior of command name completion.
Variable `ham-shell-completion-fignore' is used to initialize the value of
`comint-completion-fignore'.

Variables `comint-input-ring-file-name' and `comint-input-autoexpand' control
the initialization of the input ring history, and history expansion.

Variables `comint-output-filter-functions', a hook, and
`comint-scroll-to-bottom-on-input' and `comint-scroll-to-bottom-on-output'
control whether input and output cause the window to scroll to the end of the
buffer."
  (setq comint-prompt-regexp ham-shell-prompt-pattern)
  (setq comint-completion-fignore ham-shell-completion-fignore)
  (setq comint-delimiter-argument-list ham-shell-delimiter-argument-list)
  (setq comint-file-name-chars ham-shell-file-name-chars)
  (setq comint-file-name-quote-list ham-shell-file-name-quote-list)
  (set (make-local-variable 'comint-dynamic-complete-functions)
       ham-shell-dynamic-complete-functions)
  (set (make-local-variable 'paragraph-separate) "\\'")
  (make-local-variable 'paragraph-start)
  (setq paragraph-start comint-prompt-regexp)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(ham-shell-font-lock-keywords t))
  (make-local-variable 'ham-shell-dirstack)
  (setq ham-shell-dirstack nil)
  (make-local-variable 'ham-shell-last-dir)
  (setq ham-shell-last-dir nil)
  (setq comint-input-autoexpand ham-shell-input-autoexpand)
  (ham-shell-dirtrack-mode 1)
  ;; This is not really correct, since the shell buffer does not really
  ;; edit this directory.  But it is useful in the buffer list and menus.
  (setq list-buffers-directory (expand-file-name default-directory))
  ;; ham-shell-dependent assignments.
  (when (ring-empty-p comint-input-ring)
    (let ((shell (file-name-nondirectory (car
		   (process-command (get-buffer-process (current-buffer)))))))
      (setq comint-input-ring-file-name
	    (or (getenv "HISTFILE")
		(cond ((string-equal shell "bash") "~/.bash_history")
		      ((string-equal shell "ksh") "~/.sh_history")
		      (t "~/.history"))))
      (if (or (equal comint-input-ring-file-name "")
	      (equal (file-truename comint-input-ring-file-name)
		     (file-truename "/dev/null")))
	  (setq comint-input-ring-file-name nil))
      ;; Arrange to write out the input ring on exit, if the shell doesn't
      ;; do this itself.
      (if (and comint-input-ring-file-name
	       (string-match ham-shell-dumb-ham-shell-regexp shell))
	  (set-process-sentinel (get-buffer-process (current-buffer))
				#'ham-shell-write-history-on-exit))
      (setq ham-shell-dirstack-query
	    (cond ((string-equal shell "sh") "pwd")
		  ((string-equal shell "ksh") "echo $PWD ~-")
		  (t "dirs")))
      ;; Bypass a bug in certain versions of bash.
      (when (string-equal shell "bash")
        (add-hook 'comint-output-filter-functions
                  'ham-shell-filter-ctrl-a-ctrl-b nil t)))
    (comint-read-input-ring t)))

(defun ham-shell-filter-ctrl-a-ctrl-b (string)
  "Remove `^A' and `^B' characters from comint output.

Bash uses these characters as internal quoting characters in its
prompt.  Due to a bug in some bash versions (including 2.03,
2.04, and 2.05b), they may erroneously show up when bash is
started with the `--noediting' option and Select Graphic
Rendition (SGR) control sequences (formerly known as ANSI escape
sequences) are used to color the prompt.

This function can be put on `comint-output-filter-functions'.
The argument STRING is ignored."
  (let ((pmark (process-mark (get-buffer-process (current-buffer)))))
    (save-excursion
      (goto-char (or (and (markerp comint-last-output-start)
			  (marker-position comint-last-output-start))
		     (point-min)))
      (while (re-search-forward "[\C-a\C-b]" pmark t)
        (replace-match "")))))

(defun ham-shell-write-history-on-exit (process event)
  "Called when the shell process is stopped.

Writes the input history to a history file
`comint-input-ring-file-name' using `comint-write-input-ring'
and inserts a short message in the shell buffer.

This function is a sentinel watching the shell interpreter process.
Sentinels will always get the two parameters PROCESS and EVENT."
  ;; Write history.
  (comint-write-input-ring)
  (let ((buf (process-buffer process)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (insert (format "\nProcess %s %s\n" process event))))))

;;;###autoload
(defun ham-shell (&optional buffer)
  "Run an inferior shell, with I/O through BUFFER (which defaults to `*shell*').
Interactively, a prefix arg means to prompt for BUFFER.
If `default-directory' is a remote file name, it is also prompted
to change if called with a prefix arg.

If BUFFER exists but shell process is not running, make new shell.
If BUFFER exists and shell process is running, just switch to BUFFER.
Program used comes from variable `explicit-ham-shell-file-name',
 or (if that is nil) from the ESHELL environment variable,
 or (if that is nil) from `shell-file-name'.
If a file `~/.emacs_SHELLNAME' exists, or `~/.emacs.d/init_SHELLNAME.sh',
it is given as initial input (but this may be lost, due to a timing
error, if the shell discards input when it starts up).
The buffer is put in Shell mode, giving commands for sending input
and controlling the subjobs of the shell.  See `ham-shell-mode'.
See also the variable `ham-shell-prompt-pattern'.

To specify a coding system for converting non-ASCII characters
in the input and output to the shell, use \\[universal-coding-system-argument]
before \\[shell].  You can also specify this with \\[set-buffer-process-coding-system]
in the shell buffer, after you start the shell.
The default comes from `process-coding-system-alist' and
`default-process-coding-system'.

The shell file name (sans directories) is used to make a symbol name
such as `explicit-csh-ham-args'.  If that symbol is a variable,
its value is used as a list of arguments when invoking the shell.
Otherwise, one argument `-i' is passed to the shell.

\(Type \\[describe-mode] in the shell buffer for a list of commands.)"
  (interactive
   (list
    (and current-prefix-arg
         (prog1
             (read-buffer "Shell buffer: "
                          (generate-new-buffer-name "*shell*"))
           (if (file-remote-p default-directory)
               ;; It must be possible to declare a local default-directory.
               (setq default-directory
                     (expand-file-name
                      (read-file-name
                       "Default directory: " default-directory default-directory
                       t nil 'file-directory-p))))))))
  (require 'ansi-color)
  (setq buffer (get-buffer-create (or buffer "*shell*")))
  ;; Pop to buffer, so that the buffer's window will be correctly set
  ;; when we call comint (so that comint sets the COLUMNS env var properly).
  (pop-to-buffer-same-window buffer)
  (unless (comint-check-proc buffer)
    (let* ((prog (or explicit-ham-shell-file-name
                     (getenv "ESHELL") shell-file-name))
           (name (file-name-sans-extension (file-name-nondirectory "bash.exe")))
           (startfile-name (intern-soft (concat "explicit-" name "-ham-startfile")))
           (xargs-name (intern-soft (concat "explicit-" name "-ham-args"))))
      (apply 'make-comint-in-buffer "shell" buffer prog
             (if (and startfile-name (boundp startfile-name))
                 (let ((startfile (symbol-value startfile-name)))
                   (if (file-exists-p startfile) startfile)))
             (if (and xargs-name (boundp xargs-name))
                 (symbol-value xargs-name)
               '("-i")))
      (rename-uniquely)
      (ham-shell-mode)))
  buffer)

;; Don't do this when shell.el is loaded, only while dumping.
;;;###autoload (add-hook 'same-window-buffer-names (purecopy "*shell*"))

;;; Directory tracking
;;
;; This code provides the shell mode input sentinel
;;     HAM-SHELL-DIRECTORY-TRACKER
;; that tracks cd, pushd, and popd commands issued to the shell, and
;; changes the current directory of the shell buffer accordingly.
;;
;; This is basically a fragile hack, although it's more accurate than
;; the version in Emacs 18's shell.el. It has the following failings:
;; 1. It doesn't know about the cdpath shell variable.
;; 2. It cannot infallibly deal with command sequences, though it does well
;;    with these and with ignoring commands forked in another shell with ()s.
;; 3. More generally, any complex command is going to throw it. Otherwise,
;;    you'd have to build an entire shell interpreter in Emacs Lisp.  Failing
;;    that, there's no way to catch shell commands where cd's are buried
;;    inside conditional expressions, aliases, and so forth.
;;
;; The whole approach is a crock. Shell aliases mess it up. File sourcing
;; messes it up. You run other processes under the shell; these each have
;; separate working directories, and some have commands for manipulating
;; their w.d.'s (e.g., the lcd command in ftp). Some of these programs have
;; commands that do *not* affect the current w.d. at all, but look like they
;; do (e.g., the cd command in ftp).  In shells that allow you job
;; control, you can switch between jobs, all having different w.d.'s. So
;; simply saying %3 can shift your w.d..
;;
;; The solution is to relax, not stress out about it, and settle for
;; a hack that works pretty well in typical circumstances. Remember
;; that a half-assed solution is more in keeping with the spirit of Unix,
;; anyway. Blech.
;;
;; One good hack not implemented here for users of programmable shells
;; is to program up the shell w.d. manipulation commands to output
;; a coded command sequence to the tty. Something like
;;     ESC | <cwd> |
;; where <cwd> is the new current working directory. Then trash the
;; directory tracking machinery currently used in this package, and
;; replace it with a process filter that watches for and strips out
;; these messages.

(defun ham-shell-directory-tracker (str)
  "Tracks cd, pushd and popd commands issued to the shell.
This function is called on each input passed to the shell.
It watches for cd, pushd and popd commands and sets the buffer's
default directory to track these commands.

You may toggle this tracking on and off with \\[ham-shell-dirtrack-mode].
If Emacs gets confused, you can resync with the shell with \\[dirs].
\(The `dirtrack' package provides an alternative implementation of this
feature - see the function `dirtrack-mode'.)

See variables `ham-shell-cd-regexp', `ham-shell-chdrive-regexp', `ham-shell-pushd-regexp',
and  `ham-shell-popd-regexp', while `ham-shell-pushd-tohome', `ham-shell-pushd-dextract',
and `ham-shell-pushd-dunique' control the behavior of the relevant command.

Environment variables are expanded, see function `substitute-in-file-name'."
  (if ham-shell-dirtrackp
      ;; We fail gracefully if we think the command will fail in the shell.
      (condition-case chdir-failure
	  (let ((start (progn (string-match
			       (concat "^" ham-shell-command-separator-regexp)
			       str) ; skip whitespace
			      (match-end 0)))
		end cmd arg1)
	    (while (string-match ham-shell-command-regexp str start)
	      (setq end (match-end 0)
		    cmd (comint-arguments (substring str start end) 0 0)
		    arg1 (comint-arguments (substring str start end) 1 1))
	      (if arg1
		  (setq arg1 (ham-shell-unquote-argument arg1)))
	      (cond ((string-match (concat "\\`\\(" ham-shell-popd-regexp
					   "\\)\\($\\|[ \t]\\)")
				   cmd)
		     (ham-shell-process-popd (comint-substitute-in-file-name arg1)))
		    ((string-match (concat "\\`\\(" ham-shell-pushd-regexp
					   "\\)\\($\\|[ \t]\\)")
				   cmd)
		     (ham-shell-process-pushd (comint-substitute-in-file-name arg1)))
		    ((string-match (concat "\\`\\(" ham-shell-cd-regexp
					   "\\)\\($\\|[ \t]\\)")
				   cmd)
		     (ham-shell-process-cd (comint-substitute-in-file-name arg1)))
		    ((and ham-shell-chdrive-regexp
			  (string-match (concat "\\`\\(" ham-shell-chdrive-regexp
						"\\)\\($\\|[ \t]\\)")
					cmd))
		     (ham-shell-process-cd (comint-substitute-in-file-name cmd))))
	      (setq start (progn (string-match ham-shell-command-separator-regexp
					       str end)
				 ;; skip again
				 (match-end 0)))))
	(error "Couldn't cd"))))

(defun ham-shell-unquote-argument (string)
  "Remove all kinds of shell quoting from STRING."
  (save-match-data
    (let ((idx 0) next inside
	  (quote-chars
	   (if (string-match ham-shell-dumb-ham-shell-regexp
			     (file-name-nondirectory
			      (car (process-command (get-buffer-process (current-buffer))))))
	       "['`\"]"
	     "[\\'`\"]")))
      (while (and (< idx (length string))
		  (setq next (string-match quote-chars string next)))
	(cond ((= (aref string next) ?\\)
	       (setq string (replace-match "" nil nil string))
	       (setq next (1+ next)))
	      ((and inside (= (aref string next) inside))
	       (setq string (replace-match "" nil nil string))
	       (setq inside nil))
	      (inside
	       (setq next (1+ next)))
	      (t
	       (setq inside (aref string next))
	       (setq string (replace-match "" nil nil string)))))
      string)))

;; popd [+n]
(defun ham-shell-process-popd (arg)
  (let ((num (or (ham-shell-extract-num arg) 0)))
    (cond ((and num (= num 0) ham-shell-dirstack)
	   (ham-shell-cd (car ham-shell-dirstack))
	   (setq ham-shell-dirstack (cdr ham-shell-dirstack))
	   (ham-shell-dirstack-message))
	  ((and num (> num 0) (<= num (length ham-shell-dirstack)))
	   (let* ((ds (cons nil ham-shell-dirstack))
		  (cell (nthcdr (1- num) ds)))
	     (rplacd cell (cdr (cdr cell)))
	     (setq ham-shell-dirstack (cdr ds))
	     (ham-shell-dirstack-message)))
	  (t
	   (error "Couldn't popd")))))

;; Return DIR prefixed with comint-file-name-prefix as appropriate.
(defun ham-shell-prefixed-directory-name (dir)
  (if (= (length comint-file-name-prefix) 0)
      dir
    (if (file-name-absolute-p dir)
	;; The name is absolute, so prepend the prefix.
	(concat comint-file-name-prefix dir)
      ;; For relative name we assume default-directory already has the prefix.
      (expand-file-name dir))))

;; cd [dir]
(defun ham-shell-process-cd (arg)
  (let ((new-dir (cond ((zerop (length arg)) (concat comint-file-name-prefix
						     "~"))
		       ((string-equal "-" arg) ham-shell-last-dir)
		       (t (ham-shell-prefixed-directory-name arg)))))
    (setq ham-shell-last-dir default-directory)
    (ham-shell-cd new-dir)
    (ham-shell-dirstack-message)))

;; pushd [+n | dir]
(defun ham-shell-process-pushd (arg)
  (let ((num (ham-shell-extract-num arg)))
    (cond ((zerop (length arg))
	   ;; no arg -- swap pwd and car of stack unless ham-shell-pushd-tohome
	   (cond (ham-shell-pushd-tohome
		  (ham-shell-process-pushd (concat comint-file-name-prefix "~")))
		 (ham-shell-dirstack
		  (let ((old default-directory))
		    (ham-shell-cd (car ham-shell-dirstack))
		    (setq ham-shell-dirstack (cons old (cdr ham-shell-dirstack)))
		    (ham-shell-dirstack-message)))
		 (t
		  (message "Directory stack empty."))))
	  ((numberp num)
	   ;; pushd +n
	   (cond ((> num (length ham-shell-dirstack))
		  (message "Directory stack not that deep."))
		 ((= num 0)
		  (error (message "Couldn't cd")))
		 (ham-shell-pushd-dextract
		  (let ((dir (nth (1- num) ham-shell-dirstack)))
		    (ham-shell-process-popd arg)
		    (ham-shell-process-pushd default-directory)
		    (ham-shell-cd dir)
		    (ham-shell-dirstack-message)))
		 (t
		  (let* ((ds (cons default-directory ham-shell-dirstack))
			 (dslen (length ds))
			 (front (nthcdr num ds))
			 (back (reverse (nthcdr (- dslen num) (reverse ds))))
			 (new-ds (append front back)))
		    (ham-shell-cd (car new-ds))
		    (setq ham-shell-dirstack (cdr new-ds))
		    (ham-shell-dirstack-message)))))
	  (t
	   ;; pushd <dir>
	   (let ((old-wd default-directory))
	     (ham-shell-cd (ham-shell-prefixed-directory-name arg))
	     (if (or (null ham-shell-pushd-dunique)
		     (not (member old-wd ham-shell-dirstack)))
		 (setq ham-shell-dirstack (cons old-wd ham-shell-dirstack)))
	     (ham-shell-dirstack-message))))))

;; If STR is of the form +n, for n>0, return n. Otherwise, nil.
(defun ham-shell-extract-num (str)
  (and (string-match "^\\+[1-9][0-9]*$" str)
       (string-to-number str)))

(defvaralias 'ham-shell-dirtrack-mode 'ham-shell-dirtrackp)
(define-minor-mode ham-shell-dirtrack-mode
  "Turn directory tracking on and off in a shell buffer.
The `dirtrack' package provides an alternative implementation of this
feature - see the function `dirtrack-mode'."
  nil nil nil
  (setq list-buffers-directory (if ham-shell-dirtrack-mode default-directory))
  (if ham-shell-dirtrack-mode
      (add-hook 'comint-input-filter-functions 'ham-shell-directory-tracker nil t)
    (remove-hook 'comint-input-filter-functions 'ham-shell-directory-tracker t)))

(define-obsolete-function-alias 'ham-shell-dirtrack-toggle 'ham-shell-dirtrack-mode
  "23.1")

(defun ham-shell-cd (dir)
  "Do normal `cd' to DIR, and set `list-buffers-directory'."
  (cd dir)
  (if ham-shell-dirtrackp
      (setq list-buffers-directory default-directory)))

(defun ham-shell-resync-dirs ()
  "Resync the buffer's idea of the current directory stack.
This command queries the shell with the command bound to
`ham-shell-dirstack-query' (default \"dirs\"), reads the next
line output and parses it to form the new directory stack.
DON'T issue this command unless the buffer is at a shell prompt.
Also, note that if some other subprocess decides to do output
immediately after the query, its output will be taken as the
new directory stack -- you lose.  If this happens, just do the
command again."
  (interactive)
  (let* ((proc (get-buffer-process (current-buffer)))
	 (pmark (process-mark proc))
	 (started-at-pmark (= (point) (marker-position pmark))))
    (save-excursion
      (goto-char pmark)
      ;; If the process echoes commands, don't insert a fake command in
      ;; the buffer or it will appear twice.
      (unless comint-process-echoes
	(insert ham-shell-dirstack-query) (insert "\n"))
      (sit-for 0)			; force redisplay
      (comint-send-string proc ham-shell-dirstack-query)
      (comint-send-string proc "\n")
      (set-marker pmark (point))
      (let ((pt (point))
	    (regexp
	     (concat
	      (if comint-process-echoes
		  ;; Skip command echo if the process echoes
		  (concat "\\(" (regexp-quote ham-shell-dirstack-query) "\n\\)")
		"\\(\\)")
	      "\\(.+\n\\)")))
	;; This extra newline prevents the user's pending input from spoofing us.
	(insert "\n") (backward-char 1)
	;; Wait for one line.
	(while (not (looking-at regexp))
	  (accept-process-output proc)
	  (goto-char pt)))
      (goto-char pmark) (delete-char 1) ; remove the extra newline
      ;; That's the dirlist. grab it & parse it.
      (let* ((dl (buffer-substring (match-beginning 2) (1- (match-end 2))))
	     (dl-len (length dl))
	     (ds '())			; new dir stack
	     (i 0))
	(while (< i dl-len)
	  ;; regexp = optional whitespace, (non-whitespace), optional whitespace
	  (string-match "\\s *\\(\\S +\\)\\s *" dl i) ; pick off next dir
	  (setq ds (cons (concat comint-file-name-prefix
				 (substring dl (match-beginning 1)
					    (match-end 1)))
			 ds))
	  (setq i (match-end 0)))
	(let ((ds (nreverse ds)))
	  (condition-case nil
	      (progn (ham-shell-cd (car ds))
		     (setq ham-shell-dirstack (cdr ds)
			   ham-shell-last-dir (car ham-shell-dirstack))
		     (ham-shell-dirstack-message))
	    (error (message "Couldn't cd"))))))
    (if started-at-pmark (goto-char (marker-position pmark)))))

;; For your typing convenience:
(defalias 'dirs 'ham-shell-resync-dirs)


;; Show the current dirstack on the message line.
;; Pretty up dirs a bit by changing "/usr/jqr/foo" to "~/foo".
;; (This isn't necessary if the dirlisting is generated with a simple "dirs".)
;; All the commands that mung the buffer's dirstack finish by calling
;; this guy.
(defun ham-shell-dirstack-message ()
  (when ham-shell-dirtrack-verbose
    (let* ((msg "")
	   (ds (cons default-directory ham-shell-dirstack))
	   (home (expand-file-name (concat comint-file-name-prefix "~/")))
	   (homelen (length home)))
      (while ds
	(let ((dir (car ds)))
	  (and (>= (length dir) homelen)
	       (string= home (substring dir 0 homelen))
	       (setq dir (concat "~/" (substring dir homelen))))
	  ;; Strip off comint-file-name-prefix if present.
	  (and comint-file-name-prefix
	       (>= (length dir) (length comint-file-name-prefix))
	       (string= comint-file-name-prefix
			(substring dir 0 (length comint-file-name-prefix)))
	       (setq dir (substring dir (length comint-file-name-prefix)))
	       (setcar ds dir))
	  (setq msg (concat msg (directory-file-name dir) " "))
	  (setq ds (cdr ds))))
      (message "%s" msg))))

;; This was mostly copied from ham-shell-resync-dirs.
(defun ham-shell-snarf-envar (var)
  "Return as a string the shell's value of environment variable VAR."
  (let* ((cmd (format "printenv '%s'\n" var))
	 (proc (get-buffer-process (current-buffer)))
	 (pmark (process-mark proc)))
    (goto-char pmark)
    (insert cmd)
    (sit-for 0)				; force redisplay
    (comint-send-string proc cmd)
    (set-marker pmark (point))
    (let ((pt (point)))			; wait for 1 line
      ;; This extra newline prevents the user's pending input from spoofing us.
      (insert "\n") (backward-char 1)
      (while (not (looking-at ".+\n"))
	(accept-process-output proc)
	(goto-char pt)))
    (goto-char pmark) (delete-char 1)	; remove the extra newline
    (buffer-substring (match-beginning 0) (1- (match-end 0)))))

(defun ham-shell-copy-environment-variable (variable)
  "Copy the environment variable VARIABLE from the subshell to Emacs.
This command reads the value of the specified environment variable
in the shell, and sets the same environment variable in Emacs
\(what `getenv' in Emacs would return) to that value.
That value will affect any new subprocesses that you subsequently start
from Emacs."
  (interactive (list (read-envvar-name "\
Copy Shell environment variable to Emacs: ")))
  (setenv variable (ham-shell-snarf-envar variable)))

(defun ham-shell-forward-command (&optional arg)
  "Move forward across ARG shell command(s).  Does not cross lines.
See `ham-shell-command-regexp'."
  (interactive "p")
  (let ((limit (save-excursion (end-of-line nil) (point))))
    (if (re-search-forward (concat ham-shell-command-regexp "\\([;&|][\t ]*\\)+")
			   limit 'move arg)
	(skip-syntax-backward " "))))


(defun ham-shell-backward-command (&optional arg)
  "Move backward across ARG shell command(s).  Does not cross lines.
See `ham-shell-command-regexp'."
  (interactive "p")
  (let ((limit (save-excursion (comint-bol nil) (point))))
    (when (> limit (point))
      (setq limit (line-beginning-position)))
    (skip-syntax-backward " " limit)
    (if (re-search-backward
	 (format "[;&|]+[\t ]*\\(%s\\)" ham-shell-command-regexp) limit 'move arg)
	(progn (goto-char (match-beginning 1))
	       (skip-chars-forward ";&|")))))

(defun ham-shell-dynamic-complete-command ()
  "Dynamically complete the command at point.
This function is similar to `comint-dynamic-complete-filename', except that it
searches `exec-path' (minus the trailing Emacs library path) for completion
candidates.  Note that this may not be the same as the shell's idea of the
path.

Completion is dependent on the value of `ham-shell-completion-execonly', plus
those that effect file completion.  See `ham-shell-dynamic-complete-as-command'.

Returns t if successful."
  (interactive)
  (let ((filename (comint-match-partial-filename)))
    (if (and filename
	     (save-match-data (not (string-match "[~/]" filename)))
	     (eq (match-beginning 0)
		 (save-excursion (ham-shell-backward-command 1) (point))))
	(prog2 (unless (window-minibuffer-p (selected-window))
		 (message "Completing command name..."))
	    (ham-shell-dynamic-complete-as-command)))))


(defun ham-shell-dynamic-complete-as-command ()
  "Dynamically complete at point as a command.
See `ham-shell-dynamic-complete-filename'.  Returns t if successful."
  (let* ((filename (or (comint-match-partial-filename) ""))
	 (filenondir (file-name-nondirectory filename))
	 (path-dirs (cdr (reverse exec-path)))
	 (cwd (file-name-as-directory (expand-file-name default-directory)))
	 (ignored-extensions
	  (and comint-completion-fignore
	       (mapconcat (function (lambda (x) (concat (regexp-quote x) "$")))
			  comint-completion-fignore "\\|")))
	 (dir "") (comps-in-dir ())
	 (file "") (abs-file-name "") (completions ()))
    ;; Go thru each dir in the search path, finding completions.
    (while path-dirs
      (setq dir (file-name-as-directory (comint-directory (or (car path-dirs) ".")))
	    comps-in-dir (and (file-accessible-directory-p dir)
			      (file-name-all-completions filenondir dir)))
      ;; Go thru each completion found, to see whether it should be used.
      (while comps-in-dir
	(setq file (car comps-in-dir)
	      abs-file-name (concat dir file))
	(if (and (not (member file completions))
		 (not (and ignored-extensions
			   (string-match ignored-extensions file)))
		 (or (string-equal dir cwd)
		     (not (file-directory-p abs-file-name)))
		 (or (null ham-shell-completion-execonly)
		     (file-executable-p abs-file-name)))
	    (setq completions (cons file completions)))
	(setq comps-in-dir (cdr comps-in-dir)))
      (setq path-dirs (cdr path-dirs)))
    ;; OK, we've got a list of completions.
    (let ((success (let ((comint-completion-addsuffix nil))
		     (comint-dynamic-simple-complete filenondir completions))))
      (if (and (memq success '(sole shortest)) comint-completion-addsuffix
	       (not (file-directory-p (comint-match-partial-filename))))
	  (insert " "))
      success)))

(defun ham-shell-dynamic-complete-filename ()
  "Dynamically complete the filename at point.
This completes only if point is at a suitable position for a
filename argument."
  (interactive)
  (let ((opoint (point))
	(beg (comint-line-beginning-position)))
    (when (save-excursion
	    (goto-char (if (re-search-backward "[;|&]" beg t)
			   (match-end 0)
			 beg))
	    (re-search-forward "[^ \t][ \t]" opoint t))
      (comint-dynamic-complete-as-filename))))

(defun ham-shell-match-partial-variable ()
  "Return the shell variable at point, or nil if none is found."
  (save-excursion
    (let ((limit (point)))
      (if (re-search-backward "[^A-Za-z0-9_{}]" nil 'move)
	  (or (looking-at "\\$") (forward-char 1)))
      ;; Anchor the search forwards.
      (if (or (eolp) (looking-at "[^A-Za-z0-9_{}$]"))
	  nil
	(re-search-forward "\\$?{?[A-Za-z0-9_]*}?" limit)
	(buffer-substring (match-beginning 0) (match-end 0))))))

(defun ham-shell-dynamic-complete-environment-variable ()
  "Dynamically complete the environment variable at point.
Completes if after a variable, i.e., if it starts with a \"$\".
See `ham-shell-dynamic-complete-as-environment-variable'.

This function is similar to `comint-dynamic-complete-filename', except that it
searches `process-environment' for completion candidates.  Note that this may
not be the same as the interpreter's idea of variable names.  The main problem
with this type of completion is that `process-environment' is the environment
which Emacs started with.  Emacs does not track changes to the environment made
by the interpreter.  Perhaps it would be more accurate if this function was
called `ham-shell-dynamic-complete-process-environment-variable'.

Returns non-nil if successful."
  (interactive)
  (let ((variable (ham-shell-match-partial-variable)))
    (if (and variable (string-match "^\\$" variable))
	(prog2 (unless (window-minibuffer-p (selected-window))
		 (message "Completing variable name..."))
	    (ham-shell-dynamic-complete-as-environment-variable)))))


(defun ham-shell-dynamic-complete-as-environment-variable ()
  "Dynamically complete at point as an environment variable.
Used by `ham-shell-dynamic-complete-environment-variable'.
Uses `comint-dynamic-simple-complete'."
  (let* ((var (or (ham-shell-match-partial-variable) ""))
	 (variable (substring var (or (string-match "[^$({]\\|$" var) 0)))
	 (variables (mapcar (function (lambda (x)
					(substring x 0 (string-match "=" x))))
			    process-environment))
	 (addsuffix comint-completion-addsuffix)
	 (comint-completion-addsuffix nil)
	 (success (comint-dynamic-simple-complete variable variables)))
    (if (memq success '(sole shortest))
	(let* ((var (ham-shell-match-partial-variable))
	       (variable (substring var (string-match "[^$({]" var)))
	       (protection (cond ((string-match "{" var) "}")
				 ((string-match "(" var) ")")
				 (t "")))
	       (suffix (cond ((null addsuffix) "")
			     ((file-directory-p
			       (comint-directory (getenv variable))) "/")
			     (t " "))))
	  (insert protection suffix)))
    success))


(defun ham-shell-replace-by-expanded-directory ()
  "Expand directory stack reference before point.
Directory stack references are of the form \"=digit\" or \"=-\".
See `default-directory' and `ham-shell-dirstack'.

Returns t if successful."
  (interactive)
  (if (comint-match-partial-filename)
      (save-excursion
	(goto-char (match-beginning 0))
	(let ((stack (cons default-directory ham-shell-dirstack))
	      (index (cond ((looking-at "=-/?")
			    (length ham-shell-dirstack))
			   ((looking-at "=\\([0-9]+\\)/?")
			    (string-to-number
			     (buffer-substring
			      (match-beginning 1) (match-end 1)))))))
	  (cond ((null index)
		 nil)
		((>= index (length stack))
		 (error "Directory stack not that deep"))
		(t
		 (replace-match (file-name-as-directory (nth index stack)) t t)
		 (message "Directory item: %d" index)
		 t))))))

(provide 'ham-shell)

;; arch-tag: bcb5f12a-c1f4-4aea-a809-2504bd5bd797
;;; shell.el ends here
