;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Package: CL-USER -*-
;;;
;;; A very rudimentary machine translator to convert English to Pig
;;; Latin.  Written by Paul Foley.
;;;
;;; DO-TRANSLATIONS will translate all of the pot files in the given
;;; directory, placing the translations in the subdirectory
;;; en@piglatin/LC_MESSAGES.

(in-package "CL-USER")

(defun latinize-1 (word)
  (cond ((string= word "I") "Iway")
	((string= word "a") "away")
	((string= word "A") "Away")
	((<= (length word) 1) word)
	(t
	 (let ((case (cond ((every #'upper-case-p word) :uppercase)
			   ((upper-case-p (char word 0)) :capitalized)
			   (t :lowercase)))
	       (orig-word word)
	       (word (string-downcase word)))
	   (flet ((casify (string)
		    (case case
		      (:uppercase (nstring-upcase string))
		      (:lowercase (nstring-downcase string))
		      (:capitalized (nstring-capitalize string)))))
	     (cond ((and (char= (char word 0) #\*)
			 (char= (char word (1- (length word))) #\*))
		    orig-word)
		   ((eq case :uppercase)
		    ;; For CMUCL's docstrings, if the word is
		    ;; uppercase, let's not change it.  This usually
		    ;; means it a reference to either a Lisp function
		    ;; or variable that should probably not be
		    ;; changed.
		    (casify word))
		   ((position (char word 0) "AEIOUaeiou")
		    (casify (concatenate 'string word "way")))
		   ((and (> (length word) 3)
			 (member (subseq word 0 3)
				 '("sch" "str")
				 :test #'string=))
		    (casify (concatenate 'string (subseq word 3)
					 (subseq word 0 3) "ay")))
		   ((member (subseq word 0 2)
			    '("br" "bl" "ch" "cr" "cl" "dr" "fr" "fl" "gr" "gh"
			      "gl" "kr" "kl" "mn" "pr" "ph" "pl" "qu" "rh" "sp"
			      "sh" "sl" "sc" "sn" "tr" "th" "wr" "wh" "zh")
			    :test #'string=)
		    (casify (concatenate 'string (subseq word 2)
					 (subseq word 0 2) "ay")))
		   (t
		    (casify (concatenate 'string (subseq word 1)
					 (subseq word 0 1) "ay")))))))))

(defun latinize (string)
  (flet ((word-constituent-p (c)
	   (or (char= c #\*)
	       (alpha-char-p c)))
	 (word-constituent-*-p (c)
	   (or (char= c #\*)
	       (char= c #\-)
	       (alpha-char-p c))))
    (with-output-to-string (str)
      (loop for i = -1 then k
	    as j = 0 then
	       (or (position-if #'word-constituent-p string :start k)
		   (length string))
	    as k = (if (and (< j (length string))
			    (char= (char string j) #\*))
		       (position-if-not #'word-constituent-*-p string :start j)
		       (position-if-not #'word-constituent-p string :start j))
	    unless (minusp i) do (write-string string str :start i :end j)
	    do (write-string (latinize-1 (subseq string j k)) str)
	    while k))))


(defconstant +piglatin-header+
  "\"Project-Id-Version: CMUCL ~X\\n\"
\"PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE\\n\"
\"Last-Translator: Automatic translation\\n\"
\"Language-Team: Pig Latin (auto-translated)\\n\"
\"Language: Pig Latin\\n\"
\"MIME-Version: 1.0\\n\"
\"Content-Type: text/plain; charset=UTF-8\\n\"
\"Content-Transfer-Encoding: 8bit\\n\"
\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"
")


(defun read-pot-string (stream char)
  (declare (ignore char))
  (let ((backslash nil))
    (with-output-to-string (out)
      (loop for ch = (read-char stream t nil t)
	    until (and (not backslash) (char= ch #\")) do
	(write-char ch out)
	(cond (backslash (setq backslash nil))
	      ((char= ch #\\) (setq backslash t)))))))

(defun latinize-pot (in out)
  (let ((state 0)
	(string nil)
	(plural nil)
	(count 0))
    (with-open-file (pot in :direction :input :external-format :utf-8)
      (with-open-file (po out :direction :output :external-format :utf-8
			  :if-does-not-exist :create
			  :if-exists :supersede)
	(let ((*readtable* (copy-readtable nil)))
	  (set-macro-character #\# (lambda (stream char)
				     (declare (ignore char))
				     (list (read-line stream t nil t))))
	  (set-macro-character #\" #'read-pot-string)
	  (loop for item = (read pot nil pot) until (eq item pot) do
	       (cond ((consp item)
		      (write-char #\# po) (write-string (car item) po) (terpri po))
		     ((eq item 'msgid)
		      (write-string "msgid " po)
		      (incf count)
		      (setq state 1))
		     ((eq item 'msgid_plural)
		      (write-string "msgid_plural " po)
		      (setq state 2))
		     ((eq item 'msgstr)
		      (write-string "msgstr " po)
		      (when (equal string '(""))
			(format po +piglatin-header+ (c::backend-fasl-file-version c::*native-backend*))
			(setq string nil))
		      (dolist (x string)
			(write-char #\" po)
			(write-string x po)
			(write-char #\" po)
			(terpri po))
		      (terpri po)
		      (setq state 0 string nil))
		     ((eq item 'msgstr[0])
		      (write-string "msgstr[0] " po)
		      (dolist (x string)
			(write-char #\" po)
			(write-string x po)
			(write-char #\" po)
			(terpri po))
		      (write-string "msgstr[1] " po)
		      (dolist (x plural)
			(write-char #\" po)
			(write-string x po)
			(write-char #\" po)
			(terpri po))
		      (terpri po)
		      (setq state 0 string nil plural nil))
		     ((not (stringp item)) (error "Something's wrong"))
		     ((= state 1)
		      (write-char #\" po)
		      (write-string item po)
		      (write-char #\" po)
		      (terpri po)
		      (setq string (nconc string (list (latinize item)))))
		     ((= state 2)
		      (write-char #\" po)
		      (write-string item po)
		      (write-char #\" po)
		      (terpri po)
		      (setq plural (nconc plural (list (latinize item))))))))))
    (format t "~&Translated ~D messages~%" count)))

;; Translate all of the pot files in DIR
(defun do-translations (&optional (dir "target:i18n/locale"))
  (dolist (pot (directory (merge-pathnames (make-pathname :name :wild :type "pot" :version :newest)
					   dir)))
    (let ((po (merge-pathnames (make-pathname :directory '(:relative "en@piglatin" "LC_MESSAGES")
					      :name (pathname-name pot) :type "po")
			       dir)))
      (format t "~A -> ~A~%" pot po)
      (latinize-pot pot po))))
