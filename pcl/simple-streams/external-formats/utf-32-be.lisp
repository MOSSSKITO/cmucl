;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Package: STREAM -*-
;;;
;;; **********************************************************************
;;; This code was written by Raymond Toy and has been placed in the public
;;; domain.
;;;
(ext:file-comment "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/pcl/simple-streams/external-formats/utf-32-be.lisp,v 1.3 2009/09/28 18:12:59 rtoy Exp $")

(in-package "STREAM")

(define-external-format :utf-32-be (:size 4)
  ()

  (octets-to-code (state input unput c c1 c2 c3 c4)
    `(let* ((,c1 ,input)
	    (,c2 ,input)
	    (,c3 ,input)
	    (,c4 ,input)
	    (,c (+ (ash ,c1 24)
		   (ash ,c2 16)
		   (ash ,c3  8)
		   ,c4)))
       (declare (type (unsigned-byte 8) ,c1 ,c2 ,c3 ,c4)
		(optimize (speed 3)))
       (cond ((or (> ,c #x10ffff)
		  (lisp::surrogatep ,c))
	      ;; Surrogates are illegal.  Use replacement character.
	      (values +replacement-character-code+ 4))
	     (t
	      (values ,c 4)))))

  (code-to-octets (code state output i)
    `(dotimes (,i 4)
       (,output (ldb (byte 8 (* 8 (- 3 ,i))) ,code)))))
