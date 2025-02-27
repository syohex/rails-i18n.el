;;; rails-i18n.el --- Seach and insert i18n on ruby code -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Otávio Schwanck dos Santos

;; Author: Otávio Schwanck dos Santos <otavioschwanck@gmail.com>
;; Keywords: tools languages
;; Version: 0.1
;; Package-Requires: ((emacs "27.2") (yaml "0.1.0"))
;; Homepage: https://github.com/otavioschwanck/rails-i18n.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a package to help you find and insert rails i18n into your code.
;; Instead of going to the yaml files and copy i18n by i18n, you just call 'rails-i18n-insert-with-cache',
;; It will fetch and save on cache all i18n used by your application, so you have a reliable and easy way to search
;; and insert your i18ns.

;;; Code:

(defvar rails-i18n-use-double-quotes nil "If t, use double quotes instead single-quotes.")
(defvar rails-i18n-project-root-function 'projectile-project-root "Function used to get project root.")
(defvar rails-i18n-project-name-function 'projectile-project-name "Function used to get project name.")
(defvar rails-i18n-locales-directory "config/locales" "I18n locales folder.")
(defvar rails-i18n-locales-regexp "\\.yml$" "Query to get the the yamls to i18n.")
(defvar rails-i18n-separator ":      " "Query to get the the yamls to i18n.")
(defvar rails-i18n-cache '() "Initialize the i18n cache.")

(defun rails-i18n--read-lines (filePath)
  "Return filePath's file content. FILEPATH: Path of yaml."
  (condition-case nil (yaml-parse-string (with-temp-buffer
                                           (insert-file-contents filePath)
                                           (buffer-string))) (error nil)))

(defun rails-i18n--quotes ()
  "Return the quote to be used."
  (if rails-i18n-use-double-quotes "\"" "'"))

;;;###autoload
(defun rails-i18n-insert-no-cache ()
  "Search and insert the i18n, refreshing the cache."
  (interactive)
  (message "Reading the yml files.  it can take some time...")
  (let* ((collection (rails-i18n--parse-yamls))
         (selectedI18n (completing-read "Select your I18n: " collection)))
    (rails-i18n--set-cache collection)
    (rails-i18n--insert-i18n selectedI18n)))

;;;###autoload
(defun rails-i18n-insert-with-cache ()
  "Search and insert the i18n, searching on cache.  If cache is nil, refresh the cache."
  (interactive)
  (let ((cachedI18n (rails-i18n--get-cached)))
    (if cachedI18n
        (rails-i18n--insert-i18n (completing-read "Select your I18n: " cachedI18n))
      (rails-i18n-insert-no-cache))))

(defun rails-i18n--get-cached ()
  "Get the cached routes if not exists."
  (cdr (assoc (funcall rails-i18n-project-name-function) rails-i18n-cache)))

(defun rails-i18n--insert-i18n (i18nString)
  "Insert the i18n on code. I18NSTRING: string to be inserted."
  (let ((ignoreClass (rails-i18n--guess-use-class))
        (hasArguments (string-match-p "%{\\([a-z]+[_]*[a-z]*\\)}"
                                      (nth 1 (split-string i18nString rails-i18n-separator)))))
    (insert
     (if ignoreClass "" "I18n.")
     "t(" (rails-i18n--quotes) (nth 0 (split-string i18nString rails-i18n-separator)) (rails-i18n--quotes) ")")
    (when hasArguments (forward-char -1) (insert ", "))))

(defun rails-i18n--guess-use-class ()
  "Guess if current file needs to pass the class."
  (string-match-p "app/views\\|app/helpers" (buffer-file-name)))

(defun rails-i18n--set-cache (val)
  "Set the cache values. VAL:  Value to set."
  (when (assoc (funcall rails-i18n-project-name-function) rails-i18n-cache)
    (setq rails-i18n-cache (remove (assoc (funcall rails-i18n-project-name-function) rails-i18n-cache) rails-i18n-cache)))
  (setq rails-i18n-cache (cons `(,(funcall rails-i18n-project-name-function) . ,val) rails-i18n-cache))
  (add-to-list 'savehist-additional-variables 'rails-i18n-cache))

(defun rails-i18n--parse-yamls ()
  "Return the parsed yaml list."
  (let ((files (rails-i18n--get-yaml-files))
        ($result))
    (mapc
     (lambda (file)
       (let ((parsed-file (rails-i18n--read-lines file)))
         (if (eq (type-of parsed-file) 'hash-table)
             (push (flatten-list
                    (rails-i18n--parse-yaml
                     []
                     parsed-file )) $result)
           (message "Cannot read %s - error on parse." file))))
     files)
    (cl-remove-duplicates (flatten-list $result))))

(defun rails-i18n--get-yaml-files ()
  "Find all i18n files."
  (directory-files-recursively
   (concat (funcall rails-i18n-project-root-function) rails-i18n-locales-directory) rails-i18n-locales-regexp))

(defun rails-i18n--parse-yaml (previousKey yamlHashTable)
  "Parse the yaml into an single list.  PREVIOUSKEY: key to be mounted.  YAMLHASHTABLE:  Value to be parsed."
  (if (eq (type-of yamlHashTable) 'hash-table)
      (progn
        (let ($result)
          (maphash
           (lambda (k v)
             (push (rails-i18n--parse-yaml
                    (append previousKey
                            (make-vector 1 (symbol-name k)) nil) v) $result))
           yamlHashTable)

          $result))
    (rails-i18n--mount-string previousKey yamlHashTable)))

(defun rails-i18n--mount-string (previousKey string)
  "Create the string to be selected. PREVIOUSKEY: list of keys to mount. STRING: Value to the i18n."
  (concat "."
          (string-join (remove (nth 0 previousKey) previousKey) ".")
          rails-i18n-separator
          (propertize (format "%s" string) 'face 'bold)))

(add-to-list 'savehist-additional-variables 'rails-i18n-cache)

(provide 'rails-i18n)
;;; rails-i18n.el ends here
