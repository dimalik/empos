;;; empos.el --- Locate bibtex citations from within emacs

;; Copyright (C) 2015, Dimitris Alikaniotis

;; Author: Dimitris Alikaniotis <da352 [at] cam.ac.uk>
;; Keywords: citations, reference, bibtex, reftex
;; URL: http://github.com/dimalik/empos/
;; Version: 0.1
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:
;;
;; * Redistributions of source code must retain the above copyright
;;   notice, this list of conditions and the following disclaimer.
;; * Redistributions in binary form must reproduce the above copyright
;;   notice, this list of conditions and the following disclaimer in the
;;   documentation and/or other materials provided with the distribution.
;; * Neither the name of this package nor the
;;   names of its contributors may be used to endorse or promote products
;;   derived from this software without specific prior written permission.
;;
;; This software is provided by the copyright holders and contributors "as
;; is" and any express or implied warranties, including, but not limited
;; to, the implied warranties of merchantability and fitness for a
;; particular purpose are disclaimed. In no event shall Nathan Grigg be
;; liable for any direct, indirect, incidental, special, exemplary, or
;; consequential damages (including, but not limited to, procurement of
;; substitute goods or services; loss of use, data, or profits; or business
;; interruption) however caused and on any theory of liability, whether in
;; contract, strict liability, or tort (including negligence or otherwise)
;; arising in any way out of the use of this software, even if advised of
;; the possibility of such damage.
;;
;; (also known as the New BSD License)
;;
;;; Commentary:
;;
;; Emacs wrapper for pyopl (python online paper locator) to search and fetch
;; scientific citations online and add them to a bib file.
;;
;;; Installation:
;;
;;   (require 'empos)
;;   (setq empos-available-engines '("arxiv" "crossref"))
;;   (setq empos-favorite-engines '("crossref")) <- optional
;;   (setq empos-bib-file "path/to/bibliography.bib")
;;   (setq empos-secondary-bib "path/to/a/folder")
;;
;;  empos-available-engines should contain engines that have been installed in pyopl.
;;  empos-favorite-engines contains the engines to be used. Note this is a custom variable
;;    and can be set through customization.
;;  empos-bib-file is the (absolute) path to the master bibliography file in which the
;;    references are appended.
;;  empos-secondary-bib is the (absolute) path to a folder in which the citations are going
;;    to be added.
;;
;;; Use:
;;
;; The extension is essentially a wrapper for pyopl written for emacs.
;; It works by calling pyopl with arguments specified in emacs, displaying
;; the results in a separate buffer and saving the references in a specified
;; location.
;;
;; The location of the pyopl executable is considered to be global (i.e, it can be
;; invoked like this:
;;
;; >> pyopl "you talkin to me"
;; )
;;
;; In case something goes wrong and this does not work (might be the case in
;; virtualenvs), you can respecify the variable `pyopl-path'.
;;
;; The engines which are used are specified in `empos-favorite-engines' which is a list
;; of string containing the names of the engines. If no such variable is declared then
;; the search is done on all available engines defined in `empos-available-engines'.
;;
;; The actual search is carried by an interactive function `empos-search' displaying its
;; output on a new buffer defining an minor mode called `empos-mode' to ensure better
;; interaction.
;;
;; Upon hitting <RET> the function `empos-get-identifier' is called using a regex to
;; fetch the relevant id and engine and calling pyopl executable again, this time in
;; fetch mode.
;;
;;; Code:

(defcustom empos-available-engines nil
  "List of the available engines for pyopl. This should be specified
in the .emacs file.")

(defcustom empos-favorite-engines empos-available-engines
  "List of your favourite engines. When specified then empos-search
uses only these to find your query. If not specified empos-search
uses all available engines found in the empos-available-engines variable
in .emacs."
  :type 'list
  :require 'empos-base
  :group 'empos-engines)

(defconst empos-citation-height 4
  "The number of lines each citation has when searched from empos.py.")

(defcustom pyopl-path "pyopl"
  "Path to the pyopl executable. Normally, this would be available globally
(i.e. invakable as a terminal command), however, in the case something goes
wrong, you can specify the full path in this variable.")

;; quick helper functions for empos-mode
(defun empos-quit-window ()
  (interactive)
  (empos-mode nil)
  (quit-window))

(defun empos-move-up ()
  (interactive)
  (previous-line empos-citation-height))

(defun empos-move-down ()
  (interactive)
  (next-line empos-citation-height))

(defun visual-line-line-range ()
  (save-excursion
    (cons (progn (vertical-motion 0) (point))
	  (progn (vertical-motion empos-citation-height) (point)))))

(defvar empos-mode-map
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map)
    (define-key map "q" 'empos-quit-window)
    (define-key map (kbd "<down>") 'empos-move-down)
    (define-key map (kbd "<up>") 'empos-move-up)
    (define-key map (kbd "<return>")  'empos-get-identifier)
    (define-key map (kbd "RET") 'empos-get-identifier)
    map))


;;;###autoload
(define-minor-mode empos-mode
  "A temporary minor mode to be activated only specific to a buffer."
  nil
  :lighter " Empos"
  :keymap empos-mode-map
  (toggle-truncate-lines)
  (setq hl-line-range-function 'visual-line-line-range)
  (hl-line-mode 1))

(defun empos-take-me-to-first-line ()
  ;; ensure we are on the first line of the reference
  ;; which contains the identifier and the engine
  ;; useful only in the case where empos-move-[up|down]
  ;; do not work for some reason.
  (interactive)
  (beginning-of-line)
  (let ((current-line-num (+ 1 (count-lines 1 (point)))))
    (while (not (eq (% current-line-num empos-citation-height) 1))
      (forward-line -1)
      (setq current-line-num (+ 1 (count-lines 1 (point)))))))

(defun empos-get-identifier ()
  ;; regex the first line to get the identifier and the engine needed
  ;; then feed it to empos.py to get the citation and save it.
  (interactive)
  (empos-take-me-to-first-line)
  (let ((line (thing-at-point 'line t)))
    (if (string-match "\\[\\(.*\\)\\][[:blank:]]*\(\\(.*\\)\)" line)
	(let* ((identifier (match-string 1 line))
	       (engine (match-string 2 line))
	       (script (format "%s --fetch --engines=\"%s\" --bib=\"%s\""
			       pyopl-path engine empos-bib-file)))
	  (if (boundp 'empos-secondary-bib)
	      (setq script (concat script (format " --secondary-bib=\"%s\"" empos-secondary-bib))))
	  (setq script (concat script (format " \"%s\"" identifier)))
	  (shell-command script nil)
	  (message "Article with id %s was successfully copied to your library." identifier)
	  (empos-mode nil)
	  (kill-buffer-and-window)))))

(defun empos-search (q &optional engines)
  ;; for now, one time engine change is not available
  ;; searches are performed using the favourite engines
  ;; list. However, we do leave the engines argument here
  ;; in case we want to implement later some within
  ;; buffer change in the engines
  (interactive "sEnter query: ")
  (unless engines (setq engines empos-favorite-engines))
  (setq engines (mapconcat 'identity engines ","))
  (let* ((scriptName (format "%s --search --engines=%s \"%s\""
			    pyopl-path engines q)))
    (save-excursion
      (switch-to-buffer-other-window "*Empos*")
      (shell-command scriptName "*Empos*")
      (empos-mode 1))))

(provide 'empos)
