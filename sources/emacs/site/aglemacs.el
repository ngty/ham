(provide 'aglemacs)
(require 'ni-base)

;;;======================================================================
;;; Files handling...
;;;======================================================================

;; Disable the version control things, slows down stuff and not that usefull
(setq vc-handled-backends nil)

(NotBatchMode

 ;; Editing files larger than ~500K is really too painfull if
 ;; font-lock and a language mode is enabled so just disable it in
 ;; that case.
 (defun my-find-file-check-make-large-file-fundamental-hook ()
   "If a file is over a given size, make the buffer read only."
   (when (> (buffer-size) (* 512 1024))
     ;; (setq buffer-read-only t)
     ;; (buffer-disable-undo)
     (fundamental-mode)
     (setq truncate-lines t)
     (message "Buffer is set to fundamental mode because it is large.")
     ))

 (add-hook 'find-file-hook 'my-find-file-check-make-large-file-fundamental-hook)
)

;;;======================================================================
;;; LLVM
;;;======================================================================
(NotBatchMode
 (require 'llvm-mode)
 (require 'tablegen-mode))

;;;======================================================================
;;; Encoding
;;;======================================================================
(agl-begin-time-block "Encoding")

(prefer-coding-system 'utf-8-unix)
(set-buffer-file-coding-system 'utf-8-unix)

(require 'whitespace)
(autoload 'whitespace-mode "whitespace" "Toggle Whitespace viz" t)

(setq nuke-trailing-whitespace-p t)
(add-hook 'before-save-hook 'agl-to-utf8)

(defun agl-to-utf8 ()
  "Cleanup file : remove all ^M, trailing spaces and make sure it's encoded in UTF-8."
  (interactive)
  (let ((cur (point)))
    (beginning-of-buffer)
    (delete-trailing-whitespace)
    (set-buffer-file-coding-system 'utf-8-unix 't)
    (goto-char cur)))

;;;======================================================================
;;; Font lock (syntax highlighting)
;;;======================================================================
(agl-begin-time-block "Font lock (syntax highlighting)")
(global-font-lock-mode t)
(setq font-lock-maximum-size 256000)

;;;======================================================================
;;; C-mode
;;;======================================================================

;; Indent C preprocessor
;; Two functions are provided: 'ppindent-c' and 'ppindent-h' which
;; does not indent the first level, assuming that .h/.hpp files use an
;; #ifdef guard around the entire file.
(require 'ppindent)

;; This should be the same as the default value of `cc-other-file-alist' except
;; for the addition of Objective-C ".m" and ".mm" files.
(setq cc-other-file-alist
      '(("\\.cc\\'"  (".hh" ".h"))
        ("\\.hh\\'"  (".cc" ".C"))

        ("\\.c\\'"   (".h"))
        ("\\.h\\'"   (".c" ".cc" ".C" ".CC" ".cxx" ".cpp" ".m" ".mm"))

        ("\\.m\\'"    (".h"))
        ("\\.mm\\'"    (".h"))

        ("\\.C\\'"   (".H"  ".hh" ".h"))
        ("\\.H\\'"   (".C"  ".CC"))

        ("\\.CC\\'"  (".HH" ".H"  ".hh" ".h"))
        ("\\.HH\\'"  (".CC"))

        ("\\.c\\+\\+\\'" (".h++" ".hh" ".h"))
        ("\\.h\\+\\+\\'" (".c++"))

        ("\\.cpp\\'" (".hpp" ".hh" ".h"))
        ("\\.hpp\\'" (".cpp"))

        ("\\.cxx\\'" (".hxx" ".hh" ".h"))
        ("\\.hxx\\'" (".cxx"))))

;;;======================================================================
;;; Htmlize
;;;======================================================================
(agl-begin-time-block "Htmlize")
;; Makes sure the CSS isnt inlined so we can customize the html's source code color
(require 'htmlize)

;; Used by muse, don't remove
(defun htmlize-region-for-paste (beg end)
  "Htmlize the region and return just the HTML as a string.
This forces the `inline-css' style and only returns the HTML body,
but without the BODY tag.  This should make it useful for inserting
the text to another HTML buffer."
  (let ((htmlbuf (htmlize-region beg end)))
    (unwind-protect
        (with-current-buffer htmlbuf
          (buffer-substring (plist-get htmlize-buffer-places 'content-start)
                            (plist-get htmlize-buffer-places 'content-end)))
      (kill-buffer htmlbuf))))

;;;======================================================================
;;; Modes
;;;======================================================================
(agl-begin-time-block "Modes")

(setq standard-indent 2)

(defun ni-make-newline-indent ()
  "Sets up preferred newline behavior. Not set by default. Meant
  to be added to `c-mode-common-hook'."
  (interactive)
  (define-key c-mode-base-map "\C-m" 'newline-and-indent)
  (define-key c-mode-base-map [ret] 'newline-and-indent))

;;*** DOS BATCH FILES ***************************************************
(require 'batch-mode)

;;*** Bash Script *******************************************************
(add-to-list 'auto-mode-alist '("\\.sed\\'" . sh-mode))

;;*** C/C++ Style *******************************************************
(NotBatchMode
 (require 'google-c-style)
 (add-hook 'c-mode-common-hook 'google-set-c-style)
 ;; (add-hook 'c-mode-common-hook 'ni-make-newline-indent)
)

(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.inl\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.cni\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.metal\\'" . c++-mode))

(setq auto-mode-alist
      (cons '("\\.m$" . objc-mode) auto-mode-alist))

;;*** Java **************************************************************
(NotBatchMode
 (require 'eclipse-java-style)

 (add-hook 'java-mode-hook (lambda ()
                             (eclipse-set-java-style)
                             (ni-make-newline-indent)))
)

;;*** LUA ***************************************************************
(setq auto-mode-alist (cons '("\\.lua$" . lua-mode) auto-mode-alist))
(autoload 'lua-mode "lua-mode" "Lua editing mode." t)

;;*** JavaScript ********************************************************
(setq js-indent-level 2)
(add-to-list 'auto-mode-alist '("\\.js\\'" . js-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . js-mode))
(add-to-list 'auto-mode-alist '("\\.jsw\\'" . js-mode))
(add-to-list 'auto-mode-alist '("\\.jsr\\'" . js-mode))

;;*** CoffeeScript ******************************************************
(require 'coffee-mode)
(defun coffee-custom ()
  "coffee-mode-hook"
  (set (make-local-variable 'tab-width) 2))

(add-hook 'coffee-mode-hook
          '(lambda() (coffee-custom)))

;;*** PHP ***************************************************************
(autoload 'php-mode "php-mode-improved" nil t)
(add-to-list 'auto-mode-alist '("\\.php\\'" . php-mode))
(add-to-list 'auto-mode-alist '("\\.php3\\'" . php-mode))
(add-to-list 'auto-mode-alist '("\\.php4\\'" . php-mode))
(add-to-list 'auto-mode-alist '("\\.php5\\'" . php-mode))

;;*** niScript **********************************************************
(autoload 'niscript-mode "niscript" nil t)
(add-to-list 'auto-mode-alist '("\\.ni\\'" . niscript-mode))
(add-to-list 'auto-mode-alist '("\\.nim\\'" . niscript-mode))
(add-to-list 'auto-mode-alist '("\\.nip\\'" . niscript-mode))
(add-to-list 'auto-mode-alist '("\\.niw\\'" . niscript-mode))

;;*** TypeScript ********************************************************
(autoload 'typescript-mode "typescript" nil t)
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-mode))

;;*** C# ****************************************************************
(autoload 'csharp-mode "csharp-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.cs\\'" . csharp-mode))

;;*** VB.NET ************************************************************
(autoload 'vbnet-mode "vbnet-mode" "Visual Basic .NET Mode" t)
(setq auto-mode-alist (append '(("\\.\\(frm\\|bas\\|cls\\)$" .
                                 vbnet-mode)) auto-mode-alist))

;;*** VB ****************************************************************
(autoload 'visual-basic-mode "vb-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.vba\\'" . visual-basic-mode))
(add-to-list 'auto-mode-alist '("\\.vbs\\'" . visual-basic-mode))

;;*** XML ***************************************************************
(require 'xml-lite)
(add-hook 'xml-lite-mode-hook
          '(lambda ()
             (setq xml-lite-indent-offset 2)
             (setq sgml-basic-offset 2)
             ))

(add-hook 'sgml-mode-hook
          '(lambda ()
             (xml-lite-mode)
             ))

(add-to-list 'auto-mode-alist '("\\.gml\\'" . xml-lite-mode))
(add-to-list 'auto-mode-alist '("\\.xml\\'" . xml-lite-mode))
(add-to-list 'auto-mode-alist '("\\.xslt\\'" . xml-lite-mode))

;;*** CSS ***************************************************************
(setq css-indent-offset 2)
(add-to-list 'auto-mode-alist '("\\.css\\'" . css-mode))
(add-to-list 'auto-mode-alist '("\\.rcss\\'" . css-mode))
(autoload 'css-mode "css-mode" nil t)

;;*** YAWS **************************************************************
(autoload 'iss-mode "iss-mode" "Innosetup Script Mode" t)
(add-to-list 'auto-mode-alist '("\\.iss\\'" . iss-mode))

;;*** CG/HLSL/GLSL ******************************************************
(add-to-list 'auto-mode-alist '("\\.cg\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.cgc\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.cgh\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.vert\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.frag\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.glsl\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.hlsl\\'" . c++-mode))

;;*** Actionscript ****************************************************************
(autoload 'actionscript-mode "actionscript-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.as\\'" . actionscript-mode))
(add-to-list 'auto-mode-alist '("\\.es\\'" . actionscript-mode))


;;*** Objective-C *****************************************************************
(add-to-list 'auto-mode-alist '("\\.mm\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.lnt\\'" . c++-mode))

;;*** XML *************************************************************************
(add-to-list 'auto-mode-alist '("\\.xml\\'" . xml-lite-mode))
(add-to-list 'auto-mode-alist '("\\.xsl\\'" . xml-lite-mode))
(add-to-list 'auto-mode-alist '("\\.xslt\\'" . xml-lite-mode))

;;*** Rust ************************************************************************
(autoload 'rust-mode "rust-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-mode))
(autoload 'toml-mode "toml-mode" nil t) ;; used by cargo (rust's build system)
(add-to-list 'auto-mode-alist '("\\.toml$" . toml-mode))

;;;======================================================================
;;; IDO completion
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "IDO completion")

 (if (< emacs-major-version 22) ;newer version included in Emacs 22, that doesn't work with 21
     (load-library "ido-old")
   (require 'ido))

 (ido-mode t)

 ;; Fix the Freeze when having a long list of buffer in the fuzzy
 ;; match and typing a miss-spelled name.
 ;; ---- from http://www.emacswiki.org/emacs/TextMate ----
 ;; I found this had terrible behavior (emacs seizing up) if I typoed
 ;; and my typo was not a match in the TAGS file. The following fixed
 ;; the issue for me:
 ;; https://bitbucket.org/durin42/dotfiles/src/tip/.elisp/settings/50.localfuncs.el#cl-9
 (defvar af-ido-flex-fuzzy-limit (* 2000 5))
 (defadvice ido-set-matches-1 (around my-ido-set-matches-1 activate)
   (let ((ido-enable-flex-matching (< (* (length (ad-get-arg 0)) (length ido-text))
                                      af-ido-flex-fuzzy-limit)))
     ad-do-it))

 (add-hook 'ido-define-mode-map-hook 'ido-my-keys)
 (defun ido-my-keys ()
   (define-key ido-mode-map "\t" 'ido-complete) ; tab is better for completion lists
   (define-key ido-mode-map (kbd "tab") 'ido-complete)
   (define-key ido-mode-map "\C-t" 'ido-toggle-regexp) ; same as in isearch
   (define-key ido-mode-map "\C-d" 'ido-enter-dired))  ; cool

 (setq
  ido-decorations (quote ("\n-> " "" "\n   " "\n   ..." "[" "]" " [No match]" " [Matched]" " [Not readable]" " [Too big]" " [Confirm]"))
  ido-save-directory-list-file nil
  ido-ignore-buffers '("\\` " "^\*Back" "^\*Compile-Log" "^\*Ido")
  ;; ido-confirm-unique-completion t    ; Wait for RET, even on unique
  ido-everywhere t                      ; Enabled for various dialogs
  ido-case-fold  t                      ; Case-insensitive
  ido-use-filename-at-point nil         ; Use filename at point
  ido-use-url-at-point nil              ; Don't use url at point
  ido-enable-flex-matching t            ; More flexible
  ido-max-prospects 8                   ; Keep minibuffer clean
  ido-create-new-buffer 'always
  ido-enable-tramp-completion nil
  ido-enable-last-directory-history nil
  ido-record-commands nil
  ido-max-work-directory-list 0
  ido-max-work-file-list 0
  )
)

;;;======================================================================
;;; Utils
;;;======================================================================
(agl-begin-time-block "Utils")

(defun uniq-lines (beg end)
  "Unique lines in region.
Called from a program, there are two arguments:
BEG and END (region to sort)."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (not (eobp))
        (kill-line 1)
        (yank)
        (let ((next-line (point)))
          (while
              (re-search-forward
               (format "^%s" (regexp-quote (car kill-ring))) nil t)
            (replace-match "" nil nil))
          (goto-char next-line))))))

(defun agl-search-word-backward ()
  "Find the previous occurrence of the current word."
  (interactive)
  (let ((cur (point)))
    (skip-syntax-backward "w_")
    (goto-char
     (if (re-search-backward (concat "\\_<" (current-word) "\\_>") nil t)
         (match-beginning 0)
       cur))))

(defun agl-search-word-forward ()
  "Find the next occurrance of the current word."
  (interactive)
  (let ((cur (point)))
    (skip-syntax-forward "w_")
    (goto-char
     (if (re-search-forward (concat "\\_<" (current-word) "\\_>") nil t)
         (match-beginning 0)
       cur))))

(NotBatchMode
 (global-set-key '[(control meta up)] 'agl-search-word-backward)
 (global-set-key '[(control meta down)] 'agl-search-word-forward))

(defun agl-comment-and-go-down ()
  "Comments the current line and goes to the next one" (interactive)
  (condition-case nil (comment-region (point-at-bol) (point-at-eol)) (error nil))
  (end-of-line)
  (next-line 1)
  (back-to-indentation))
(defun agl-uncomment-and-go-up ()
  "Uncomments the current line and goes to the previous one" (interactive)
  (condition-case nil (uncomment-region (point-at-bol) (point-at-eol)) (error nil))
  (back-to-indentation)
  (next-line -1))

(defun agl-increment-number-at-point (&optional amount)
  "Increment the number under point by `amount'"
  (interactive "p")
  (let ((num (number-at-point)))
    (when (numberp num)
      (let ((newnum (+ num amount))
            (p (point)))
        (save-excursion
          (skip-chars-backward "-.0123456789")
          (delete-region (point) (+ (point) (length (number-to-string num))))
          (insert (number-to-string newnum)))
        (goto-char p)))))

(defun agl-decrement-number-at-point (&optional amount)
  (interactive "p")
  "Decrement the number under point by `amount'"
  (agl-increment-number-at-point (- (abs amount))))

(defun goto-match-paren (arg)
  "Go to the matching parenthesis if on parenthesis, otherwise insert the character typed."
  (interactive "p")
  (cond ((looking-at "\\s\(") (forward-list 1) (backward-char 1))
    ((looking-at "\\s\)") (forward-char 1) (backward-list 1))
    (t                    (self-insert-command (or arg 1))) ))

(defun agl-increase-font-size ()
  (interactive)
  (set-face-attribute 'default
                      nil
                      :height
                      (ceiling (* 1.10
                                  (face-attribute 'default :height)))))
(defun agl-decrease-font-size ()
  (interactive)
  (set-face-attribute 'default
                      nil
                      :height
                      (floor (* 0.9
                                  (face-attribute 'default :height)))))

(defun agl-previous-input ()
  "Console previous input"
  (interactive)
  (goto-char (point-max))
  (comint-previous-input 1))

(defun agl-next-input ()
  "Console previous input"
  (interactive)
  (goto-char (point-max))
  (comint-next-input 1))

(defun day-name ()
  (let ((date (calendar-day-of-week
               (calendar-current-date)))) ; 0-6
    (catch 'return
      (case date
        (0
         (throw 'return "Sunday"))
        (6
         (throw 'return "Saturday"))
        (t
         (throw 'return "weekday"))))))

(defun agl-bash-cmd-to-string (aCmd)
  (PrognInHamShell
   (shell-command-to-string aCmd)))

(defun agl-uuid1 ()
  "Generate a type 1 UUID and return it."
  (interactive)
  (agl-bash-cmd-to-string "genuuid 1"))
(defun agl-uuid2 ()
  "Generate a type 2 UUID and return it."
  (interactive)
  (agl-bash-cmd-to-string "genuuid 2"))
(defun agl-uuid3 ()
  "Generate a type 3 UUID and return it."
  (interactive)
  (agl-bash-cmd-to-string "genuuid 3"))

(defun agl-uuid1-to-buffer ()
  "Generate a type 1 UUID and copy it in the clipboard."
  (interactive)
  (insert (agl-uuid1)))
(defun agl-uuid2-to-buffer ()
  "Generate a type 2 UUID and copy it in the clipboard."
  (interactive)
  (insert (agl-uuid2)))
(defun agl-uuid3-to-buffer ()
  "Generate a type 3 UUID and copy it in the clipboard."
  (interactive)
  (insert (agl-uuid3)))

;;;======================================================================
;;; Search / Find in files
;;;======================================================================
(agl-begin-time-block "Search / Find in files")

;; hippie expand functions
;; 28.11.2003: from MicheleBini (emacs wiki page)
;; completes via calc:
;; You must be on the end of the line. The line must end with: " = "
;; Then you can invoke this completion function!!
(defun agl-try-complete-with-calc-result (arg)
  "Try the complete an expression using the calculator"
  (and
   (not arg) (eolp)
   (save-excursion
     (beginning-of-line)
     (when (and (boundp 'comment-start)
		comment-start)
       (when (looking-at
	      (concat
	       "[ \n\t]*"
	       (regexp-quote comment-start)))
	 (goto-char (match-end 0))
	 (when (looking-at "[^\n\t ]+")
	   (goto-char (match-end 0)))))
     (looking-at ".* \\(\\([;=]\\) +$\\)")) ;
   (save-match-data
     (require 'calc nil t))
   ;;(require 'calc-aent)
   (let ((start (match-beginning 0))
	 (op (match-string-no-properties 2)))
   (save-excursion
     (goto-char (match-beginning 1))
     (if (re-search-backward (concat "[\n" op "]") start t)
	 (goto-char (match-end 0)) (goto-char start))
     (looking-at (concat " *\\(.*[^ ]\\) +" op "\\( +\\)$"))
     (goto-char (match-end 2))
     (let* ((b (match-beginning 2))
	    (e (match-end 2))
	    (a (match-string-no-properties 1))
	    (r (calc-do-calc-eval a nil nil)))
       (when (string-equal a r)
	 (let ((b (save-excursion
		    (and (search-backward "\n\n" nil t)
			 (match-end 0))))
	       (p (current-buffer))
	       (pos start)
	       (s nil))
	   (setq r
		 (calc-do-calc-eval
		  (with-temp-buffer
		    (insert a)
		    (goto-char (point-min))
		    (while (re-search-forward
			    "[^0-9():!^ \t-][^():!^ \t]*" nil t)
		      (setq s (match-string-no-properties 0))
		      (let ((r
			     (save-match-data
			       (save-excursion
				 (set-buffer p)
				 (goto-char pos)
				 (and
				  ;; TODO: support for line
				  ;; indentation
				  (re-search-backward
				   (concat "^" (regexp-quote s)
					   " =")
				   b t)
				  (progn
				    (end-of-line)
				    (search-backward "=" nil t)
				    (and (looking-at "=\\(.*\\)$")
					 (match-string-no-properties 1))))))))
			(if r (replace-match (concat "(" r ")") t t))))
		    (buffer-substring (point-min) (point-max)))
		  nil nil))))
       (and
	r
	(progn
	  (he-init-string b e)
	  (he-substitute-string (concat " " r))
	  t)))))))

;;;======================================================================
;;; Overlays
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "Overlays")
 (require 'custom)

 (defvar all-overlays ())

 (defun agl-delete-this-overlay(overlay is-after begin end &optional len)
   (delete-overlay overlay)
   )

 (defun agl-highlight-current-line()
   (interactive)
   (interactive)
   (setq current-point (point))
   (beginning-of-line)
   (setq beg (point))
   (forward-line 1)
   (setq end (point))
   ;; Create and place the overlay
   (setq error-line-overlay (make-overlay 1 1))
   ;; Append to list of all overlays
   (setq all-overlays (cons error-line-overlay all-overlays))

   (if (= agl-kColorTheme 1)
       (overlay-put error-line-overlay
                    'face '(background-color . "#AAEEAA"))
     (overlay-put error-line-overlay
                  'face '(background-color . "#115511"))
     )

   (overlay-put error-line-overlay
                'modification-hooks (list 'agl-delete-this-overlay))
   (move-overlay error-line-overlay beg end)
   (goto-char current-point)
   )

 (defun agl-delete-all-overlays()
   (interactive)
   (while all-overlays
     (delete-overlay (car all-overlays))
     (setq all-overlays (cdr all-overlays))
     )
   )

 (defun highlight-error-lines(compilation-buffer, process-result)
   (interactive)
   (delete-all-overlays)
   (condition-case nil
       (while t
         (next-error)
         (highlight-current-line)
         )
     (error nil))
   )
)

;;;======================================================================
;;; Dired mode
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "Dired mode")

;; Dired customizations
(setq ls-lisp-dirs-first t)

;; use a single buffer for dired mode
(require 'dired-single)
(defun my-dired-init ()
  "Bunch of stuff to run for dired, either immediately or when it's loaded."
  ;; add other stuff here
  (define-key dired-mode-map [return] 'joc-dired-single-buffer)
  (define-key dired-mode-map [C-return] 'dired-find-file-other-window)
  (define-key dired-mode-map [mouse-1] 'joc-dired-single-buffer-mouse)
  (define-key dired-mode-map [delete] 'dired-do-delete)
  (define-key dired-mode-map "^"
    (function
     (lambda nil (interactive) (joc-dired-single-buffer "..")))))
;; if dired's already loaded, then the keymap will be bound
(if (boundp 'dired-mode-map)
    ;; we're good to go; just add our bindings
    (my-dired-init)
  ;; it's not loaded yet, so add our bindings to the load-hook
  (add-hook 'dired-load-hook 'my-dired-init))
)

;;;======================================================================
;;; WindMove
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "WindMove")

 (defconst agl-kMadeFrame 0)

 (defun agl-make-frame () ""
   (interactive)
   (defconst agl-kMadeFrame 1)
   (make-frame-command)
   (tool-bar-mode -1)
   (other-frame 1)
   (ham-shell-unique))

 (defun agl-other-frame () ""
   (interactive)
   (if (< (length (visible-frame-list)) 2)
       (agl-make-frame)
     (other-frame 1)))

 ;; Save the current buffer, switch to the other frame, and run the latest command.
 ;; This works only if the other frame is a shell.
 (defun agl-other-frame-and-run-last-shell-command () ""
   (interactive)
   (save-buffer)
   (agl-other-frame)
   (agl-previous-input)
   (comint-send-input))

 ;; Open the other frame and run the latest command
 ;; This works only if the other frame is a shell of course...
 (define-key global-map [(control return)] 'agl-other-frame-and-run-last-shell-command)

 ;; Move to the 'next' window (in clockwise order)
 (global-set-key (key "C-1") 'other-window)
 (global-set-key (key "C-2") 'other-window)
 ;; Move to the other frame (other OS window)
 (global-set-key (key "M-9") 'agl-make-frame)
 (global-set-key (key "M-`") 'agl-other-frame)
 ;; Forward/Backward paragraph
 (global-set-key (key "M-p") 'backward-paragraph)
 (global-set-key (key "M-n") 'forward-paragraph)
)

;;;======================================================================
;;; Basic stuffs
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "Basic stuffs")

 (global-auto-revert-mode 1)
 (global-set-key (key "C-x C-r") 'revert-buffer)
 (set-default 'truncate-partial-width-windows nil)
 (set-default 'truncate-lines nil)

 (setq-default fill-column 78)

 (put 'erase-buffer 'disabled nil)
 (put 'upcase-region 'disabled nil)

 ;; Toggle word wrap
 (defun agl-toggle-word-wrap ()
   (interactive)
   (if (eval truncate-lines) (setq truncate-lines nil) (setq truncate-lines t))
   (recenter))

 (show-paren-mode t)
 (setq next-line-add-newlins nil)
 ;; Set the characters displayed in the modeline for each of the encoding
 (setq eol-mnemonic-dos ?\\
       eol-mnemonic-unix ?/
       eol-mnemonic-mac ?:
       eol-mnemonic-undecided ??)
)

;; tab size
(setq default-tab-width 2)
;; use this to change the indentation offset
(setq c-basic-offset 2)
;; use tabs for indentation (t)
(setq-default indent-tabs-mode nil)

; Show the column number
(column-number-mode nil)

;; get rid of the default messages on startup
(setq initial-scratch-message nil)
(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message t)

;; Remove the menu bar, scroll bar, tool bar, tab bar...
;; (if (boundp 'menu-bar-mode)
    ;; (menu-bar-mode -1))
(if (boundp 'scroll-bar-mode)
    (scroll-bar-mode -1))
(if (boundp 'tool-bar-mode)
    (tool-bar-mode -1))
(if (boundp 'tabbar-mode)
    (tabbar-mode -1))

;; no blinkies...
(blink-cursor-mode -1)

(transient-mark-mode 1)         ; make the current 'selection' visible
(delete-selection-mode 1)       ; delete the selection area with a keypress
(fset 'yes-or-no-p 'y-or-n-p)   ; enable one letter y/n answers to yes/no
(global-font-lock-mode 1)       ; always do syntax highlighting
(file-name-shadow-mode 1)       ; be smart about filenames (understand ~/ etc.)
(set-language-environment "UTF-8") ; prefer utf-8 for language settings
(setq x-select-enable-clipboard t) ; copy-paste should work
(setq confirm-nonexistent-file-or-buffer nil) ; annoying confirmation if a file or buffer does not exist when you use C-x C-f or C-x b

;; format the title-bar to always include the buffer name
;;(setq frame-title-format "emacs - %b")
;; format the title-bar to show the full path name of the buffer
(NotBatchMode
 (setq-default
  frame-title-format
  (list '((buffer-file-name "emacs - %f"
                            (dired-directory
                             dired-directory
                             (revert-buffer-function " %b"
                                                     ("%b - Dir:  " default-directory)))))))
)

; isearch - the defaults are _so_ annoying...
(define-key isearch-mode-map (kbd "<backspace>") 'isearch-del-char) ; bs means bs
(define-key isearch-mode-map (kbd "<delete>")    'isearch-delete-char)  ; delete means delete

(global-set-key [?\C-x ?t] 'anchored-transpose)
(autoload 'anchored-transpose "anchored-transpose" nil t)

;;;======================================================================
;;; Autoindent yank
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "Autoindent yank")

;; automatically indenting yanked text if in programming-modes
(defvar yank-indent-modes '(emacs-lisp-mode
                            erlang-mode
                            niscript-mode
                            c-mode c++-mode
                            tcl-mode sql-mode
                            perl-mode cperl-mode
                            java-mode jde-mode
                            lisp-interaction-mode
                            LaTeX-mode TeX-mode)
  "Modes in which to indent regions that are yanked (or yank-popped)")

(defvar yank-advised-indent-threshold 1000
  "Threshold (# chars) over which indentation does not automatically occur.")

(defun yank-advised-indent-function (beg end)
  "Do indentation, as long as the region isn't too large."
  (if (<= (- end beg) yank-advised-indent-threshold)
      (indent-region beg end nil)))

(defadvice yank (after yank-indent activate)
  "If current mode is one of 'yank-indent-modes, indent yanked text (with prefix arg don't indent)."
  (if (and (not (ad-get-arg 0))
           (member major-mode yank-indent-modes))
      (let ((transient-mark-mode nil))
    (yank-advised-indent-function (region-beginning) (region-end)))))

(defadvice yank-pop (after yank-pop-indent activate)
  "If current mode is one of 'yank-indent-modes, indent yanked text (with prefix arg don't indent)."
  (if (and (not (ad-get-arg 0))
           (member major-mode yank-indent-modes))
    (let ((transient-mark-mode nil))
    (yank-advised-indent-function (region-beginning) (region-end)))))
)

;;;======================================================================
;;; CMake
;;;======================================================================
(NotBatchMode
 (require 'cmake-mode)
 (setq auto-mode-alist
       (append '(("CMakeLists\\.txt\\'" . cmake-mode)
                 ("\\.cmake\\'" . cmake-mode))
               auto-mode-alist)))

;;;======================================================================
;;; Buffer name uniquify
;;;======================================================================
(NotBatchMode
 (require 'uniquify)
 (setq uniquify-buffer-name-style 'forward)
 )

;;;======================================================================
;;; MarkDown
;;;======================================================================
(autoload 'markdown-mode "markdown-mode"
  "Major mode for editing Markdown files" t)

(add-to-list 'auto-mode-alist '("\\.md\\'" . gfm-mode))

;;;======================================================================
;;; Main Keyboard Shortcuts
;;;======================================================================
(NotBatchMode
 (agl-begin-time-block "Main Keyboard Shortcuts")

 (defun make-agl-expand ()
   (make-hippie-expand-function
    '(agl-try-complete-with-calc-result
      try-expand-dabbrev-visible
      try-expand-dabbrev
      try-expand-dabbrev-all-buffers) t))

 ;; kill current buffer without confirmation
 (defun kill-current-buffer ()
   "Kill the current buffer, without confirmation."
   (interactive)
   (save-buffer)
   (kill-buffer (current-buffer)))
 (global-set-key [(meta delete)] 'kill-current-buffer)

 ;; Shell
 (global-set-key (kbd "C-0") 'ham-shell-unique)
 (global-set-key (kbd "M-0") 'erase-buffer)

 ;; Toggle word wrap
 (global-set-key (kbd "C-6") 'agl-toggle-word-wrap)
 (global-set-key (kbd "M-6") 'whitespace-mode)
 ;; Ctrl-=/- increase/decrease font size
 (global-set-key (kbd "C-=") 'agl-increase-font-size)
 (global-set-key (kbd "C--") 'agl-decrease-font-size)

 ;; Make the sequence "C-c g" execute the `goto-line' command,
 ;; which prompts for a line number to jump to.
 (global-set-key "\C-c\C-g" 'goto-line)

 ;; Imenu
 (global-set-key "\C-c\C-f" 'agl-goto-symbol)
 (global-set-key "\C-cf" 'agl-goto-symbol)

 ;; undo on C-z, move the suspend/iconify to C-/
 (global-set-key "\C-z" 'undo)

 ;; remap regex search to Atl-s/r
 (global-set-key "\M-s" 'isearch-forward-regexp)
 (global-set-key (kbd "C-M-s") 'isearch-forward-regexp)
 (global-set-key "\M-r" 'isearch-backward-regexp)
 (global-set-key (kbd "C-M-r") 'isearch-forward-regexp)

 ;; alias qrr to query-replace-regexp
 (defalias 'qrr 'query-replace-regexp)
 (global-set-key "\C-h\C-h" 'qrr)
 ;; dtou
 (global-set-key "\C-h\C-d" 'agl-to-utf8)
 ;; find occurences
 (global-set-key "\C-h\C-i" 'agl-occur-identifier)
 ;; occurences
 (global-set-key "\C-h\C-o" 'occur)

 ;; extended expand
 (global-set-key [(meta /)] (make-agl-expand))

 ;; Matching parenthesis
 (global-set-key "\M-5" 'goto-match-paren)

 ;; alias y to yes and n to no
 (defalias 'yes-or-no-p 'y-or-n-p)

 ;; Previous/Next errors
 (define-key global-map "\M-3" 'previous-error)
 (define-key global-map "\M-4" 'next-error)

 ;; shift-down comments the current line and goes down
 (define-key global-map [(shift down)] 'agl-comment-and-go-down)
 ;; shift-up uncomments the current line and goes up
 (define-key global-map [(shift up)] 'agl-uncomment-and-go-up)
 ;; inc number under cursor
 (define-key global-map [(meta up)] 'agl-increment-number-at-point)
 ;; dec number under cursor
 (define-key global-map [(meta down)] 'agl-decrement-number-at-point)
 ;; UUID generation
 (global-set-key (kbd "C-M-S-g") 'agl-uuid1-to-buffer)
 (global-set-key (kbd "C-M-g") 'agl-uuid2-to-buffer)
 (global-set-key (kbd "M-G") 'agl-uuid3-to-buffer)

 ;; Begin/end of buffer
 (define-key global-map (kbd "C-S-a") 'beginning-of-buffer)
 (define-key global-map (kbd "C-S-e") 'end-of-buffer)

 ;; Emacs on OSX, put back the keys to a sane (windows/linux-like) default
 (OSX
  (global-set-key [ns-drag-file] 'ns-find-file)
  (setq ns-pop-up-frames nil)
  (global-set-key (kbd "<home>") 'move-beginning-of-line)
  (global-set-key (kbd "<end>") 'move-end-of-line))
)

;;;======================================================================
;;; mark-multiple.el
;;;======================================================================
(add-to-list 'load-path (concat ENV_DEVENV_EMACS_SCRIPTS "/mark-multiple.el"))

(require 'inline-string-rectangle)
(global-set-key (kbd "C-x r t") 'inline-string-rectangle)

(require 'mark-more-like-this)

(defun mark-next-like-this (arg)
  "Find and mark the next part of the buffer matching the currently active region
With negative ARG, delete the last one instead.
With zero ARG, skip the last one and mark next."
  (interactive "p")
  (unless (or (region-active-p)
              mm/master)
    (er/mark-symbol)
    (error "Nothing marked, marked symbol."))
  (if (< arg 0)
      (mm/remove-mirror (mm/furthest-mirror-after-master)))
  (if (>= arg 0)
      (progn
        (when (null mm/master)
          (mm/create-master (region-beginning) (region-end)))

        (save-excursion
          (goto-char (mm/last-overlay-end))
          (if (= arg 0)
              (mm/remove-mirror (mm/furthest-mirror-after-master)))
          (let ((case-fold-search nil)
                (master-str (mm/master-substring)))
            (if (search-forward master-str nil t)
                (mm/add-mirror (- (point) (length master-str)) (point))
              (error "no more found \"%s\" forward"
                     (substring-no-properties master-str))))))))

(global-set-key (kbd "C-<") 'mark-previous-like-this)
(global-set-key (kbd "C->") 'mark-next-like-this)
;; like the other two, but takes an argument (negative is previous)
(global-set-key (kbd "C-M-m") 'mark-more-like-this)
(global-set-key (kbd "C-*") 'mark-all-like-this)

(require 'rename-sgml-tag)
(define-key sgml-mode-map (kbd "C-c C-r") 'rename-sgml-tag)

;;;======================================================================
;;; Macros
;;;======================================================================
(NotBatchMode
 (defun save-macro (name)
   "save a macro. Take a name as argument
     and save the last defined macro under
     this name at the end of your .emacs"
   (interactive "Name of the macro :")  ; ask for the name of the macro
   (kmacro-name-last-macro name)         ; use this name for the macro
   (find-file "~/.emacs")                ; open ~/.emacs
   (goto-char (point-max))               ; go to the end of the .emacs
   (newline)                             ; insert a newline
   (insert-kbd-macro name)               ; copy the macro
   (newline)                             ; insert a newline
   (switch-to-buffer nil))               ; return to the initial buffer

 (fset 'macro-join-line
       (lambda (&optional arg)
         "Keyboard macro."
         (interactive "p")
         (kmacro-exec-ring-item
          (quote ([5 67108896 down 134217837 32] 0 "%d")) arg)))
 (global-set-key (kbd "C-S-j") 'macro-join-line)

 (defun goto-match-paren2 (arg)
   "Go to the matching parenthesis if on parenthesis. Else go to the
   opening parenthesis one level up."
   (interactive "p")
   (cond ((looking-at "\\s\(") (forward-list 1))
         (t
          (backward-char 1)
          (cond ((looking-at "\\s\)")
                 (forward-char 1) (backward-list 1))
                (t
                 (while (not (looking-at "\\s("))
                   (backward-char 1)
                   (cond ((looking-at "\\s\)")
                          (message "->> )")
                          (forward-char 1)
                          (backward-list 1)
                          (backward-char 1)))
                   ))))))

 (global-set-key (kbd "C-.") 'goto-match-paren2)

 (global-set-key "\C-cy" '(lambda ()
                            (interactive)
                            (popup-menu 'yank-menu)))
)
