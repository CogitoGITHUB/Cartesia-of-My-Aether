;;; foundation-init.el --- generated from Manifolding-Emacs-Foundation.org
;;
;; ┌─────────────────────────────────────────────────────────────┐
;; │  BOOT ORDER                                                 │
;; │  1. straight.el bootstrap                                   │
;; │  2. straight/build/* → load-path                            │
;; │  3. org from GNU ELPA                                       │
;; │  4. leaf + leaf-keywords                                    │
;; │  5. manifolding-emacs (literate loader)                     │
;; │  6. Manifolding-Emacs/modules/*.org                         │
;; └─────────────────────────────────────────────────────────────┘

(defun my/init-note (fmt &rest args)
  (let ((message-log-max nil)) (apply #'message fmt args)))

;; (my/init-note "[init] straight bootstrap…")
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (when (file-exists-p bootstrap-file)
    (load bootstrap-file nil 'nomessage)))
;; (my/init-note "[init] straight ready")

(let ((straight-build-dir
       (expand-file-name "straight/build/" user-emacs-directory)))
  (when (file-directory-p straight-build-dir)
    (dolist (dir (directory-files straight-build-dir t "^[^.]" t))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

(when (file-exists-p "/etc/ssl/certs/ca-certificates.crt")
  (push "GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt" process-environment))

(condition-case nil
    (progn
      (set-face-attribute 'default nil :foreground "#FFFFFF" :background "#000000")
      (set-face-attribute 'mode-line nil :foreground "#FFFFFF" :background "#000000" :box nil)
      (set-face-attribute 'mode-line-inactive nil :foreground "#FFFFFF" :background "#000000" :box nil)
      (set-face-attribute 'header-line nil :foreground "#FFFFFF" :background "#000000"))
  (error nil))

(condition-case nil
    (progn
      (dolist (pkg '("nerd-icons" "doom-modeline"))
        (let ((dir (expand-file-name
                    (concat "straight/build/" pkg "/") user-emacs-directory)))
          (when (file-directory-p dir) (add-to-list 'load-path dir))))
      (require 'nerd-icons)
      (require 'doom-modeline)
      (setq doom-modeline-icon t
            doom-modeline-height 28
            doom-modeline-bar-width 4
            doom-modeline-minor-modes nil
            doom-modeline-buffer-encoding nil
            doom-modeline-percent-position nil)
      ;; Define the SAME spec modeline.org uses, so the early modeline
      ;; is identical to the final one.  Enabling the mode WITHOUT this
      ;; definition trips its mode-hook on the not-yet-defined
      ;; `my/setup-modeline' and leaves the vanilla modeline up.
      (doom-modeline-def-segment my-modaled-state
        "Display modaled state with nerd-icons."
        (when (bound-and-true-p modaled-state)
          (pcase modaled-state
            ("normal"  (nerd-icons-mdicon "nf-md-alpha_n_circle" :face 'doom-modeline-evil-normal-state))
            ("insert"  (nerd-icons-mdicon "nf-md-alpha_i_circle" :face 'doom-modeline-evil-insert-state))
            ("visual"  (nerd-icons-mdicon "nf-md-alpha_v_circle" :face 'doom-modeline-evil-visual-state))
            ("org"     (nerd-icons-mdicon "nf-md-alpha_o_circle" :face 'doom-modeline-evil-operator-state))
            ("motion"  (nerd-icons-mdicon "nf-md-alpha_m_circle" :face 'doom-modeline-evil-motion-state)))))
      (doom-modeline-def-modeline 'my-modeline
        '(bar buffer-position major-mode)
        '(battery time vcs my-modaled-state))
      (doom-modeline-mode 1)
      (doom-modeline-set-modeline 'my-modeline t))
  (error nil))
;; (my/init-note "[init] modeline ready")

;; (my/init-note "[init] loading org + leaf…")
(straight-use-package 'org)

(straight-use-package 'leaf)
(straight-use-package 'leaf-keywords)
(eval-and-compile
  (leaf-keywords-init))
;; (my/init-note "[init] core ready")

(defun my/load-literate-loader (&optional file)
  "Tangle the loader org to .el, then load it."
  (or file (setq file
                 (expand-file-name "manifolding-emacs.org"
                                   (expand-file-name "Manifolding-Emacs/"
                                                     user-emacs-directory))))
  (unless (file-exists-p file)
    (error "[init] literate loader missing: %s" file))
  (let ((el (concat (file-name-sans-extension file) ".el")))
    ;; (my/init-note "[init] tangling loader…")
    (with-demoted-errors "[init] tangle failed: %s"
      (org-babel-tangle-file file))
    ;; (my/init-note "[init] loading literate loader…")
    (load el nil t)))

(add-to-list 'load-path (expand-file-name "lisp/" user-emacs-directory))
(my/load-literate-loader)

;; (my/init-note "[init] loader ready — booting modules…")

(setq manifolding-emacs--boot-warnings '())
(advice-add 'manifolding-emacs-boot :before
            (lambda () (setq manifolding-emacs--boot-warnings '())))
(advice-add 'display-warning :before
            (lambda (type message &rest _)
              (push (list :type type :message message)
                    manifolding-emacs--boot-warnings)))

(setq manifolding-emacs-package-method 'leaf
      manifolding-emacs-org-directory
      (expand-file-name "Manifolding-Emacs/modules" user-emacs-directory)
      manifolding-emacs-output-directory
      (expand-file-name "manifolding-emacs" user-emacs-directory))
(setq inhibit-startup-screen t)
(manifolding-emacs-boot)

(global-auto-revert-mode 1)
(setq auto-revert-verbose nil
      revert-without-query '(".*")
      global-auto-revert-non-file-buffers t)

;; Everything else lives in Manifolding-Emacs/modules/*.org.
;; See keyboard.org for keybindings.
;; See buffer-management.org for buffer lifecycle.

;;; foundation-init.el ends here
