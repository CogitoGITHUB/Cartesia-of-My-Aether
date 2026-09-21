;;; early-init.el --- -*- lexical-binding: t -*-

(setq make-backup-files nil)
(setq-default truncate-lines nil)
(setq-default word-wrap t)
(add-hook 'after-init-hook #'global-visual-line-mode)

(setopt use-short-answers t)
(unless noninteractive
  (menu-bar-mode -1)
  (when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
  (when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1)))

(add-to-list 'default-frame-alist '(background-color . "#000000"))
(add-to-list 'default-frame-alist '(foreground-color . "#FFFFFF"))
(unless noninteractive
  (ignore-errors
    (set-face-attribute 'default nil
                        :foreground "#FFFFFF"
                        :background "#000000")))

(defvar my/message-noise-regexp
  (mapconcat
   #'identity
   '("Omitting\\.\\.\\."
     "Nothing to omit"
     "Omitted [0-9]+ lines? in "
     "Cleaning up the recentf list"
     "Wrote .*/recentf"
     "Loading .*/recentf"
     "Formats have changed, recompiling"
     "Updating buffer list"
     "Commands: m, u,"
     "Function provided is already compiled"
     "\\[yas\\] "
     "Prepared just-in-time loading of snippets"
     "Package cl is deprecated"
     "ad-handle-definition:"
     "ATTENTION: org-noter"
     "setup-children.*:class must also"
     " is an obsolete alias"
     "open-code ‘anonymous lambda’"
     "deprecated positional arguments to ‘define-minor-mode’"
     "Manifolding Atlas: opening database"
     "Manifolding Atlas: database ready"
     "For information about GNU Emacs")
   "\\|"))

(defun my/quiet-message-filter (orig fmt &rest args)
  (let ((text (ignore-errors
                (and (stringp fmt) (apply #'format fmt args)))))
    (if (and text (string-match-p my/message-noise-regexp text))
        nil
      (apply orig fmt args))))
(advice-add 'message :around #'my/quiet-message-filter)

(defun my/quiet-warning-filter (orig type msg &rest args)
  (let ((text (ignore-errors (and (stringp msg) msg))))
    (if (and text (string-match-p my/message-noise-regexp text))
        nil
      (apply orig type msg args))))
(advice-add 'display-warning :around #'my/quiet-warning-filter)

(defun my/quiet-lwarn (orig type level fmt &rest args)
  (let ((text (ignore-errors (and (stringp fmt)
                                  (apply #'format fmt args)))))
    (if (and text (string-match-p my/message-noise-regexp text))
        nil
      (apply orig type level fmt args))))
(advice-add 'lwarn :around #'my/quiet-lwarn)

;; recentf autosave chatters via C-level write-region — stop it.
(with-eval-after-load 'recentf
  (when (and (boundp 'recentf-auto-save-timer) recentf-auto-save-timer)
    (cancel-timer recentf-auto-save-timer)
    (setq recentf-auto-save-timer nil)))

;; Messages janitor: wipe accumulated chatter once init settles.
(defun my/messages-janitor ()
  (when (get-buffer "*Messages*")
    (with-current-buffer "*Messages*"
      (let ((inhibit-read-only t)) (erase-buffer)))))
(add-hook 'after-init-hook
          (lambda () (run-with-idle-timer 20 nil #'my/messages-janitor)))

(add-to-list 'warning-suppress-types '(org-version-mismatch))

(let ((site-lisp (expand-file-name "~/.guix-profile/share/emacs/site-lisp/")))
  (when (file-directory-p site-lisp)
    (let ((dirs (directory-files site-lisp t "^[^.]")))
      (dolist (dir (reverse dirs))
        (when (file-directory-p dir)
          (push dir load-path))))))

(let ((site-lisp "/run/current-system/profile/share/emacs/site-lisp/"))
  (when (file-directory-p site-lisp)
    (let ((dirs (directory-files site-lisp t "^[^.]")))
      (dolist (dir (reverse dirs))
        (when (file-directory-p dir)
          (push dir load-path))))))

;;; early-init.el ends here
