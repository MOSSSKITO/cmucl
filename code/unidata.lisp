;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Package: LISP -*-
;;;
;;; **********************************************************************
;;; This code was written by Paul Foley and has been placed in the public
;;; domain.
;;; 
(ext:file-comment "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/code/unidata.lisp,v 1.1.2.5 2009/04/15 21:19:05 rtoy Exp $")
;;;
;;; **********************************************************************
;;;
;;; Unicode Database access

(in-package "LISP")

(defconstant +unidata-path+ #p"ext-formats:unidata.bin")

(defstruct unidata
  range
  name+
  name
  category
  scase
  numeric
  decomp
  combining
  bidi
  name1+
  name1
  )

(defvar *unicode-data* (make-unidata))

;;; These need to be synched with tools/build-unidata.lisp

(defstruct dictionary
  (cdbk (ext:required-argument) :read-only t :type simple-vector)
  (keyv (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 8) (*)))
  (keyl (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 8) (*)))
  (codev (ext:required-argument) :read-only t
	 :type (simple-array (signed-byte 32) (*)))
  (nextv (ext:required-argument) :read-only t
	 :type (simple-array (unsigned-byte 32) (*)))
  (namev (ext:required-argument) :read-only t
	 :type (simple-array (unsigned-byte 32) (*))))

(defstruct range
  (codes (ext:required-argument) :read-only t
	 :type (simple-array (unsigned-byte 32) (*))))

(defstruct ntrie
  (split (ext:required-argument) :read-only t
	 :type (unsigned-byte 8))
  (hvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*)))
  (mvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*))))

(defstruct (ntrie4 (:include ntrie))
  (lvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 4) (*))))

(defstruct (ntrie8 (:include ntrie))
  (lvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 8) (*))))

(defstruct (ntrie16 (:include ntrie))
  (lvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*))))

(defstruct (ntrie32 (:include ntrie))
  (lvec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 32) (*))))


(defstruct (scase (:include ntrie32))
  (svec (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*))))

(defstruct (decomp (:include ntrie32))
  (tabl (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*))))

(defstruct (bidi (:include ntrie16))
  (tabl (ext:required-argument) :read-only t
	:type (simple-array (unsigned-byte 16) (*))))

(defconstant +decomposition-type+
  '(nil "<compat>" "<initial>" "<medial>" "<final>" "<isolated>"
    "<super>" "<sub>" "<fraction>" "<font>" "<noBreak>"
    "<vertical>" "<wide>" "<narrow>" "<small>" "<square>" "<circle>"))

(defconstant +bidi-class+
  #("L" "LRE" "LRO" "R" "AL" "RLE" "RLO" "PDF" "EN" "ES" "ET" "AN" "CS"
    "NSM" "BN" "B" "S" "WS" "ON"))



(defun search-dictionary (string dictionary)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0)
		     (ext:inhibit-warnings 3))
	   (type string string) (type dictionary dictionary))
  (let* ((codebook (dictionary-cdbk dictionary))
	 (current 0)
	 (posn 0)
	 (stack '()))
    (declare (type (unsigned-byte 32) current) (type lisp::index posn))
    (loop
      (let ((keyv (ash (aref (dictionary-nextv dictionary) current) -18)))
	(dotimes (i (aref (dictionary-keyl dictionary) keyv)
		    (if stack
			(let ((next (pop stack)))
			  (setq posn (car next) current (cdr next)))
			(return-from search-dictionary nil)))
	  (let* ((str (aref codebook (aref (dictionary-keyv dictionary)
					   (+ keyv i))))
		 (len (length str)))
	    (declare (type simple-base-string str))
	    (when (and (>= (length string) (+ posn len))
		       (string= string str :start1 posn :end1 (+ posn len)))
	      (setq current
		  (+ (logand (aref (dictionary-nextv dictionary) current)
			     #x3FFFF)
		     i))
	      (when (= (incf posn len) (length string))
		(return-from search-dictionary current))
	      (return))			; from DOTIMES - loop again
	    (when (or (string= str " ") (string= str "-"))
	      (push (cons posn
			  (+ (logand (aref (dictionary-nextv dictionary)
					   current)
				     #x3FFFF)
			     i))
		    stack))))))))

(defun search-range (code range)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code) (type range range))
  (let* ((set (range-codes range))
	 (min 0)
	 (max (length set)))
    (declare (type lisp::index min max))
    (loop for n of-type lisp::index = (logand #xFFFFFE (ash (+ min max) -1)) do
      (let* ((dmin (logand #x1FFFFF (aref set n)))
	     (dmax (logand #x1FFFFF (aref set (1+ n)))))
	(cond ((< code dmin)
	       (when (= (the lisp::index (setq max n)) min) (return nil)))
	      ((> code dmax)
	       (when (= (setq min (+ n 2)) max) (return nil)))
	      (t (return (ash n -1))))))))

(declaim (inline qref qref4 qref8 qref16 qref32))
(defun qref (ntrie code)
  (declare (optimize (speed 3) (space 0) (safety 0) (debug 0))
	   (type ntrie ntrie) (type (integer 0 #x10FFFF) code))
  (let* ((mbits (1+ (ash (ntrie-split ntrie) -4)))
	 (lbits (1+ (logand (ntrie-split ntrie) 15)))
	 (hvec (ntrie-hvec ntrie))
	 (mvec (ntrie-mvec ntrie))
	 (hi (aref hvec (ash code (- (+ mbits lbits)))))
	 (md (logand (ash code (- lbits)) (lognot (ash -1 mbits))))
	 (lo (logand code (lognot (ash -1 lbits)))))
    (declare (type (simple-array (unsigned-byte 16) (*)) hvec mvec))
    (if (= hi #xFFFF)
	nil
	(let ((md (aref mvec (+ hi md))))
	  (if (= md #xFFFF)
	      nil
	      (+ md lo))))))

(defun qref4 (ntrie code)
  (declare (optimize (speed 3) (space 0) (safety 0) (debug 0))
	   (type ntrie4 ntrie) (type (integer 0 #x10FFFF) code))
  (let ((n (qref ntrie code)))
    (if n (aref (ntrie4-lvec ntrie) n) 0)))

(defun qref8 (ntrie code)
  (declare (optimize (speed 3) (space 0) (safety 0) (debug 0))
	   (type ntrie8 ntrie) (type (integer 0 #x10FFFF) code))
  (let ((n (qref ntrie code)))
    (if n (aref (ntrie8-lvec ntrie) n) 0)))

(defun qref16 (ntrie code)
  (declare (optimize (speed 3) (space 0) (safety 0) (debug 0))
	   (type ntrie16 ntrie) (type (integer 0 #x10FFFF) code))
  (let ((n (qref ntrie code)))
    (if n (aref (ntrie16-lvec ntrie) n) 0)))

(defun qref32 (ntrie code)
  (declare (optimize (speed 3) (space 0) (safety 0) (debug 0)
		     (ext:inhibit-warnings 3)) ;; shut up about boxing return
	   (type ntrie32 ntrie) (type (integer 0 #x10FFFF) code))
  (let ((n (qref ntrie code)))
    (if n (aref (ntrie32-lvec ntrie) n) 0)))



(defun unidata-locate (stream index)
  (labels ((read16 (stm)
	     (logior (ash (read-byte stm) 8) (read-byte stm)))
	   (read32 (stm)
	     (logior (ash (read16 stm) 16) (read16 stm))))
    (unless (and (= (read32 stream) #x2A554344)
		 (= (read-byte stream) 0))
      (error "The Unicode data file is broken."))
    (let ((a (read-byte stream))
	  (b (read-byte stream))
	  (c (read-byte stream)))
      (unless (and (= a 5) (= b 1) (= c 0))
	(warn "Unicode data file is for Unicode ~D.~D.~D" a b c)))
    (dotimes (i index)
      (when (zerop (read32 stream))
	(return-from unidata-locate nil)))
    (let ((n (read32 stream)))
      (and (plusp n) (file-position stream n)))))

(defmacro defloader (name (stm locn) &body body)
  `(defun ,name ()
     (labels ((read16 (stm)
		(logior (ash (read-byte stm) 8) (read-byte stm)))
	      (read32 (stm)
		(logior (ash (read16 stm) 16) (read16 stm)))
	      (read-ntrie (bits stm)
		(let* ((split (read-byte stm))
		       (hlen (read16 stm))
		       (mlen (read16 stm))
		       (llen (read16 stm))
		       (hvec (make-array hlen
				   :element-type '(unsigned-byte 16)))
		       (mvec (make-array mlen
				   :element-type '(unsigned-byte 16)))
		       (lvec (make-array llen
				   :element-type (list 'unsigned-byte bits))))
		  (read-vector hvec stm :endian-swap :network-order)
		  (read-vector mvec stm :endian-swap :network-order)
		  (read-vector lvec stm :endian-swap :network-order)
		  (values split hvec mvec lvec))))
       (declare (ignorable #'read16 #'read32 #'read-ntrie))
       (with-open-file (,stm +unidata-path+ :direction :input
			     :element-type '(unsigned-byte 8))
	 (unless (unidata-locate ,stm ,locn)
	   (error "No data in file."))
	 ,@body))))

(defloader load-range (stm 0)
  (let* ((n (read32 stm))
	 (codes (make-array n :element-type '(unsigned-byte 32))))
    (read-vector codes stm :endian-swap :network-order)
    (setf (unidata-range *unicode-data*)
	(make-range :codes codes))))

(defloader load-names (stm 1)
  (let* ((cb (1+ (read-byte stm)))
	 (kv (read16 stm))
	 (cv (read32 stm))
	 (codebook (make-array cb))
	 (keyv (make-array kv :element-type '(unsigned-byte 8)))
	 (keyl (make-array kv :element-type '(unsigned-byte 8)))
	 (codev (make-array cv :element-type '(signed-byte 32)))
	 (nextv (make-array cv :element-type '(unsigned-byte 32)))
	 (namev (make-array cv :element-type '(unsigned-byte 32))))
    (dotimes (i cb)
      (let* ((n (read-byte stm))
	     (s (make-string n)))
	(setf (aref codebook i) s)
	(dotimes (i n) (setf (char s i) (code-char (read-byte stm))))))
    (read-vector keyv stm :endian-swap :network-order)
    (read-vector keyl stm :endian-swap :network-order)
    (read-vector codev stm :endian-swap :network-order)
    (read-vector nextv stm :endian-swap :network-order)
    (read-vector namev stm :endian-swap :network-order)
    (setf (unidata-name+ *unicode-data*)
	(make-dictionary :cdbk codebook :keyv keyv :keyl keyl
			 :codev codev :nextv nextv :namev namev))))

(defloader load-name (stm 2)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 32 stm)
    (setf (unidata-name *unicode-data*)
	(make-ntrie32 :split split :hvec hvec :mvec mvec :lvec lvec))))

(defloader load-categories (stm 3)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 8 stm)
    (setf (unidata-category *unicode-data*)
	(make-ntrie8 :split split :hvec hvec :mvec mvec :lvec lvec))))

(defloader load-scase (stm 4)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 16 stm)
    (let* ((slen (read-byte stm))
	   (svec (make-array slen :element-type '(unsigned-byte 16))))
      (read-vector svec stm :endian-swap :network-order)
      (setf (unidata-scase *unicode-data*)
	  (make-scase :split split :hvec hvec :mvec mvec :lvec lvec
		      :svec svec)))))

(defloader load-numerics (stm 5)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 32 stm)
    (setf (unidata-numeric *unicode-data*)
	(make-ntrie32 :split split :hvec hvec :mvec mvec :lvec lvec))))

(defloader load-decomp (stm 6)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 32 stm)
    (let* ((tlen (read16 stm))
	   (tabl (make-array tlen :element-type '(unsigned-byte 16))))
      (read-vector tabl stm :endian-swap :network-order)
      (setf (unidata-decomp *unicode-data*)
	  (make-decomp :split split :hvec hvec :mvec mvec :lvec lvec
		       :tabl tabl)))))

(defloader load-combining (stm 7)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 8 stm)
    (setf (unidata-combining *unicode-data*)
	(make-ntrie8 :split split :hvec hvec :mvec mvec :lvec lvec))))

(defloader load-bidi (stm 8)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 16 stm)
    (let* ((tlen (read-byte stm))
	   (tabl (make-array tlen :element-type '(unsigned-byte 16))))
      (read-vector tabl stm :endian-swap :network-order)
      (setf (unidata-bidi *unicode-data*)
	  (make-bidi :split split :hvec hvec :mvec mvec :lvec lvec
		     :tabl tabl)))))

(defloader load-1.0-names (stm 9)
  (let* ((cb (1+ (read-byte stm)))
	 (kv (read16 stm))
	 (cv (read32 stm))
	 (codebook (make-array cb))
	 (keyv (make-array kv :element-type '(unsigned-byte 8)))
	 (keyl (make-array kv :element-type '(unsigned-byte 8)))
	 (codev (make-array cv :element-type '(signed-byte 32)))
	 (nextv (make-array cv :element-type '(unsigned-byte 32)))
	 (namev (make-array cv :element-type '(unsigned-byte 32))))
    (dotimes (i cb)
      (let* ((n (read-byte stm))
	     (s (make-string n)))
	(setf (aref codebook i) s)
	(dotimes (i n) (setf (char s i) (code-char (read-byte stm))))))
    (read-vector keyv stm :endian-swap :network-order)
    (read-vector keyl stm :endian-swap :network-order)
    (read-vector codev stm :endian-swap :network-order)
    (read-vector nextv stm :endian-swap :network-order)
    (read-vector namev stm :endian-swap :network-order)
    (setf (unidata-name+ *unicode-data*)
	(make-dictionary :cdbk codebook :keyv keyv :keyl keyl
			 :codev codev :nextv nextv :namev namev))))

(defloader load-1.0-name (stm 10)
  (multiple-value-bind (split hvec mvec lvec) (read-ntrie 32 stm)
    (setf (unidata-name *unicode-data*)
	(make-ntrie32 :split split :hvec hvec :mvec mvec :lvec lvec))))


;;; Accessor functions.

(defun unicode-name-to-codepoint (name)
  (declare (type string name))
  (unless (unidata-name+ *unicode-data*) (load-names))
  (let* ((names (unidata-name+ *unicode-data*))
	 (n (search-dictionary name names)))
    (when n (aref (dictionary-codev names) n))))

(defun unicode-1.0-name-to-codepoint (name)
  (declare (type string name))
  (unless (unidata-name1+ *unicode-data*) (load-1.0-names))
  (let* ((names (unidata-name1+ *unicode-data*))
	 (n (search-dictionary name names)))
    (when n (aref (dictionary-codev names) n))))

(defun unicode-name+ (code ntrie dict)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0)
		     (ext:inhibit-warnings 3))
	   (type (integer 0 #x10FFFF) code)
	   (type ntrie32 ntrie) (type dictionary dict))
  (let* ((codebook (dictionary-cdbk dict))
	 (namev (dictionary-namev dict))
	 (nextv (dictionary-nextv dict))
	 (keyv (dictionary-keyv dict))
	 (n (qref32 ntrie code))
	 (p (ash (aref namev n) -18))
	 (s (make-string p)))
    (loop while (plusp n) do
	(let* ((prev (logand (aref namev n) #x3FFFF))
	       (temp (aref nextv prev))
	       (base (logand temp #x3FFFF))
	       (str (aref codebook
			  (aref keyv (+ (ash temp -18) (- n base))))))
	  (declare (type simple-base-string str))
	  (setq p (- p (length str)) n prev)
	  (replace s str :start1 p)))
    (if n s nil)))

(defun unicode-name (code)
  (unless (unidata-name+ *unicode-data*) (load-names))
  (unless (unidata-name *unicode-data*) (load-name))
  (unicode-name+ code (unidata-name *unicode-data*)
		 (unidata-name+ *unicode-data*)))

(defun unicode-1.0-name (code)
  (unless (unidata-name1+ *unicode-data*) (load-1.0-names))
  (unless (unidata-name1 *unicode-data*) (load-1.0-name))
  (unicode-name+ code (unidata-name1 *unicode-data*)
		 (unidata-name1+ *unicode-data*)))

(declaim (inline unicode-category))
(defun unicode-category (code)
  (declare (type (integer 0 #x10FFFF) code))
  (unless (unidata-category *unicode-data*) (load-categories))
  (qref8 (the ntrie8 (unidata-category *unicode-data*)) code))

(defun unicode-category-string (code)
  (let ((n (unicode-category code))
	(s (make-string 2)))
    (setf (schar s 0) (schar "CLMNPSZ?????????" (ldb (byte 4 4) n))
	  (schar s 1) (schar "ncdefiklmopstu??" (ldb (byte 4 0) n)))
    s))

(defun unicode-upper (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-scase *unicode-data*) (load-scase))
  (let* ((scase (unidata-scase *unicode-data*))
	 (n (logand (qref32 scase code) #xFF)))
    (if (zerop n)
	code
	(let* ((m (aref (scase-svec scase) (logand n #x7F))))
	  (if (logbitp 7 n) (+ code m) (- code m))))))

(defun unicode-lower (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-scase *unicode-data*) (load-scase))
  (let* ((scase (unidata-scase *unicode-data*))
	 (n (logand (ash (qref32 scase code) -8) #xFF)))
    (if (zerop n)
	code
	(let ((m (aref (scase-svec scase) (logand n #x7F))))
	  (if (logbitp 7 n) (+ code m) (- code m))))))

(defun unicode-title (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-scase *unicode-data*) (load-scase))
  (let* ((scase (unidata-scase *unicode-data*))
	 (n (logand (ash (qref32 scase code) -16) #xFF)))
    (if (zerop n)
	code
	(let ((m (aref (scase-svec scase) (logand n #x7F))))
	  (if (logbitp 7 n) (+ code m) (- code m))))))

(defun unicode-num1 (code)
  (declare (type (integer 0 #x10FFFF) code))
  (unless (unidata-numeric *unicode-data*) (load-numerics))
  (let ((n (qref32 (unidata-numeric *unicode-data*) code)))
    (if (logbitp 25 n) (logand (ash n -3) #xF) nil)))

(defun unicode-num2 (code)
  (declare (type (integer 0 #x10FFFF) code))
  (unless (unidata-numeric *unicode-data*) (load-numerics))
  (let ((n (qref32 (unidata-numeric *unicode-data*) code)))
    (if (logbitp 24 n) (logand (ash n -3) #xF) nil)))

(defun unicode-num3 (code)
  (declare (type (integer 0 #x10FFFF) code))
  (unless (unidata-numeric *unicode-data*) (load-numerics))
  (let ((n (qref32 (unidata-numeric *unicode-data*) code)))
    (if (logbitp 23 n)
	(let ((num (/ (logand (ash n -3) #x1FFFF) (1+ (logand n 7)))))
	  (if (logbitp 20 n) (- num) num))
	nil)))

(defun unicode-decomp (code &optional (kind :all))
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-decomp *unicode-data*) (load-decomp))
  (let* ((decomp (unidata-decomp *unicode-data*))
	 (n (qref32 decomp code))
	 (type (ldb (byte 5 27) n)))
    (if (= n 0)
	nil
	(if (or (= type 0)
		(eq kind :any)
		(and (= type 1) (eq kind :compatibility)))
	    (let ((off (logand n #xFFFF))
		  (len (ldb (byte 6 16) n)))
	      (values (subseq (decomp-tabl decomp) off (+ off len))
		      type))
	    nil))))

(defun unicode-combining-class (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-combining *unicode-data*) (load-combining))
  (qref8 (unidata-combining *unicode-data*) code))

(defun unicode-bidi-class (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-bidi *unicode-data*) (load-bidi))
  (logand (qref16 (unidata-bidi *unicode-data*) code) #x1F))

(defun unicode-bidi-class-string (code)
  (aref +bidi-class+ (unicode-bidi-class code)))

(defun unicode-bidi-mirror-p (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-bidi *unicode-data*) (load-bidi))
  (logbitp 5 (qref16 (unidata-bidi *unicode-data*) code)))

(defun unicode-mirror-codepoint (code)
  (declare (optimize (speed 3) (space 0) (debug 0) (safety 0))
	   (type (integer 0 #x10FFFF) code))
  (unless (unidata-bidi *unicode-data*) (load-bidi))
  (let* ((d (unidata-bidi *unicode-data*))
	 (x (ash (qref16 d code) -6))
	 (i (logand x #x0F))
	 (n (if (logbitp 5 x) (aref (bidi-tabl d) i) i)))
    (cond ((= x 0) nil)
	  ((logbitp 4 x) (- code n))
	  (t (+ code n)))))
