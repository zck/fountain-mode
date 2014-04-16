;;; fountain-export.el --- Export engine for Fountain Mode

;; Copyright (C) 2014  Paul Rankin

;; Author: Paul Rankin <paul@tilk.co>
;; Keywords: wp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(defgroup fountain-export ()
  "Options for exporting Fountain files."
  :prefix 'fountain-export-
  :group 'fountain)

;;; customizable variables =============================================

(defcustom fountain-export-buffer-name
  "*Fountain Mode Export*"
  "Buffer name to use when not exporting a file."
  :type 'string
  :group 'fountain-export)

(defcustom fountain-export-html-template
  "<!DOCTYPE html>
<!-- Created by Fountain Mode version ${fountain-version} for Emacs -->
<html>
<head>
<link rel=\"stylesheet\" href=\"${cssfile}\">
</head>
<body>
$ {content}
</body>
</html>
"
  "HTML template inserted into export buffer.
See `fountain-export-format-template'."
  :type 'string
  :group 'fountain-export)

;;; internal functions =================================================

(defun fountain-export-fontify-buffer ()
  "Ensure the buffer is fontified."
  (save-excursion
    (save-restriction
      (widen)
      (if font-lock-mode
        (let ((font-lock-maximum-decoration t)
              (fontjob (make-progress-reporter "Fontifying buffer..." 0 100))
              (chunk (/ (buffer-size) 100))
              (n 0))
          (goto-char (point-min))
          (while (< (point) (buffer-end 1))
            (let ((end (+ (point) chunk)))
              (jit-lock-fontify-now (point) end)
              (goto-char end)
              (progress-reporter-update fontjob n)
              (setq n (+ n 1))))
          (progress-reporter-done fontjob))))))

(defun fountain-export-escape-chars (substring)
  ""
  (with-temp-buffer
    (insert substring)
    (format-replace-strings '(("\n" . "</br>"))
                            nil (point-min) (point-max))
    (substring-no-properties (buffer-string))))

(defun fountain-export-create-element (substring)
  "Return a HTML div element with face and substring of SUBSTRING.
Stylesheet class is taken from face, while content is taken from
of SUBSTRING."
  (let ((class (if (get-text-property 0 'face substring)
                   (let* ((s (symbol-name (get-text-property 0 'face substring)))
                          (s (s-chop-suffix "-highlight" s))
                          (s (s-chop-prefix "fountain-" s))) s)
                 "action"))
        (content (substring-no-properties substring)))
    (unless (string= class "comment")
      (format "<div class=\"%s\">%s</div>"
              class content))))

(defun fountain-export-format-template (template)
  "Format TEMPLATE according to the following list.

Internal function, will not work outside of
`fountain-export-html'."
  (s-format template 'aget
            `(("fountain-version" . ,fountain-version)
              ("htmlfile" . ,htmlfile)
              ("cssfile" . ,(concat name ".css")))))

(defun fountain-export-html ()
  "Convert current buffer to HTML, writing result to new buffer."
  (interactive)
  (save-excursion
    (save-restriction
      (widen)
      (let ((exportjob (make-progress-reporter "Exporting buffer..." 0 100)))
        ;; fontify the entire buffer
        (fountain-export-fontify-buffer)
        ;; create the stylesheet
        (let* ((sourcebuf (current-buffer))
               (name (if (buffer-file-name)
                         (file-name-base (buffer-file-name))
                       fountain-export-buffer-name))
               (htmlfile (concat name ".html"))
               (htmlbuf (generate-new-buffer htmlfile)))
          (goto-char (point-min))
          ;; FIXME: single line breaks
          (while (null (eobp))
            (let ((end (next-property-change (point))))
              (when end
                (let* ((s (buffer-substring (point) end))
                       (s (s-presence (s-trim s))))
                  (when s
                    (setq element (fountain-export-create-element s))
                    (with-current-buffer htmlbuf
                      (with-silent-modifications
                        (insert element "\n"))))
                  (goto-char end)))
              (unless (looking-at ".\\|\\'")
                (forward-char 1))
              (progress-reporter-update exportjob
                                        (* (/ (point) (buffer-size)) 100))))
          ;; replace single newlines in element string with "</br>"
          ;; append element string to content string
          ;; create the export buffer
          ;; (with-current-buffer htmlbuf
          ;;   (with-silent-modifications
          ;;     (insert (fountain-export-format-template
          ;;              fountain-export-html-template))))
          ;; insert content string into htmlbuf
          (switch-to-buffer-other-window htmlbuf)
          ;; indent according to HTML mode
          (set-auto-mode)
          (indent-region (point-min) (point-max))
          (progress-reporter-done exportjob))))))

(provide 'fountain-export)
;;; fountain-export.el ends here
