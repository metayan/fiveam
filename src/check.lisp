;; -*- lisp -*-

(in-package :it.bese.FiveAM)

;;;; * Checks

;;;; At the lowest level testing the system requires that certain
;;;; forms be evaluated and that certain post conditions are met: the
;;;; value returned must satisfy a certain predicate, the form must
;;;; (or must not) signal a certain condition, etc. In FiveAM these
;;;; low level operations are called 'checks' and are defined using
;;;; the various checking macros.

;;;; Checks are the basic operators for collecting results. Tests and
;;;; test suites on the other hand allow grouping multiple checks into
;;;; logic collections.

(defvar *test-dribble* t)

(defmacro with-*test-dribble* (stream &body body)
  `(let ((*test-dribble* ,stream))
     (declare (special *test-dribble*))
     ,@body))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (def-special-environment run-state ()
    result-list
    current-test))

;;;; ** Types of test results

;;;; Every check produces a result object. 

(defclass test-result ()
  ((reason :accessor reason :initarg :reason :initform "no reason given")
   (test-case :accessor test-case :initarg :test-case))
  (:documentation "All checking macros will generate an object of
 type TEST-RESULT."))

(defclass test-passed (test-result)
  ()
  (:documentation "Class for successful checks."))

(defgeneric test-passed-p (object)
  (:method ((o t)) nil)
  (:method ((o test-passed)) t))

(defclass test-failure (test-result)
  ()
  (:documentation "Class for unsuccessful checks."))

(defgeneric test-failure-p (object)
  (:method ((o t)) nil)
  (:method ((o test-failure)) t))

(defclass unexpected-test-failure (test-failure)
  ((actual-condition :accessor actual-condition :initarg :condition))
  (:documentation "Represents the result of a test which neither
passed nor failed, but signaled an error we couldn't deal
with.

Note: This is very different than a SIGNALS check which instead
creates a TEST-PASSED or TEST-FAILURE object."))

(defclass test-skipped (test-result)
  ()
  (:documentation "A test which was not run. Usually this is due
to unsatisfied dependencies, but users can decide to skip test
when appropiate."))

(defgeneric test-skipped-p (object)
  (:method ((o t)) nil)
  (:method ((o test-skipped)) t))

(defun add-result (result-type &rest make-instance-args)
  "Create a TEST-RESULT object of type RESULT-TYPE passing it the
  initialize args MAKE-INSTANCE-ARGS and adds the resulting
  object to the list of test results."
  (with-run-state (result-list current-test)
    (let ((result (apply #'make-instance result-type (append make-instance-args (list :test-case current-test)))))
      (etypecase result
	(test-passed  (format *test-dribble* "."))
	(test-failure (format *test-dribble* "f"))
	(test-skipped (format *test-dribble* "s")))
      (push result result-list))))

;;;; ** The check operators

;;;; *** The IS check

(defmacro is (test &rest reason-args)
  "The DWIM checking operator.

If TEST returns a true value a test-passed result is generated,
otherwise a test-failure result is generated and the reason,
unless REASON-ARGS is provided, is generated based on the form of
TEST:

 (predicate expected actual) - Means that we want to check
 whether, according to PREDICATE, the ACTUAL value is
 in fact what we EXPECTED.

 (predicate value) - Means that we want to ensure that VALUE
 satisfies PREDICATE.

Wrapping the TEST form in a NOT simply preducse a negated reason string."
  (assert (listp test)
          (test)
          "Argument to IS must be a list, not ~S" test)
  `(if ,test
       (add-result 'test-passed)
       (add-result 'test-failure
		  :reason ,(if (null reason-args)
			       (list-match-case test
			         ((not (?predicate ?expected ?actual))
				  `(format nil "~S was ~S to ~S" ,?actual ',?predicate ,?expected))
				 ((not (?satisfies ?value))
				  `(format nil "~S satisfied ~S" ,?value ',?satisfies))
				 ((?predicate ?expected ?actual)
				  `(format nil "~S was not ~S to ~S" ,?actual ',?predicate ,?expected))
				 ((?satisfies ?value)
				  `(format nil "~S did not satisfy ~S" ,?value ',?satisfies))
				 (t 
				  `(is-true ,test ,@reason-args)))
			     `(format nil ,@reason-args)))))

;;;; *** Other checks

(defmacro skip (&rest reason)
  "Generates a TEST-SKIPPED result."
  `(progn
     (format *test-dribble* "s")
     (add-result 'test-skipped :reason (format nil ,@reason))))

(defmacro is-true (condition &rest reason-args)
  "Like IS this check generates a pass if CONDITION returns true
  and a failure if CONDITION returns false. Unlike IS this check
  does not inspect CONDITION to determine how to report the
  failure."
  `(if ,condition
       (add-result 'test-passed)
       (add-result 'test-failure :reason ,(if reason-args
					      `(format nil ,@reason-args)
					      `(format nil "~S did not return a true value" ',condition)))))

(defmacro is-false (condition &rest reason-args)
  "Generates a pass if CONDITION returns false, generates a
  failure otherwise. Like IS-TRUE, and unlike IS, IS-FALSE does
  not inspect CONDITION to determine what reason to give it case
  of test failure"
  `(if ,condition
       (add-result 'test-failure :reason ,(if reason-args
					      `(format nil ,@reason-args)
					      `(format nil "~S returned a true value" ',condition)))
       (add-result 'test-passed)))

(defmacro signals (condition &body body)
  "Generates a pass if BODY signals a condition of type
CONDITION. BODY is evaluated in a block named NIL, CONDITION is
not evaluated."
  (let ((block-name (gensym)))
    `(block ,block-name
       (handler-bind ((,condition (lambda (c)
                                    (declare (ignore c))
                                    ;; ok, body threw condition
                                    (add-result 'test-passed)
                                    (return-from ,block-name t))))
	 (block nil
	   ,@body
	   (add-result 'test-failure :reason (format nil "Failed to signal a ~S" ',condition))
	   (return-from ,block-name nil))))))

(defmacro finishes (&body body)
  "Generates a pass if BODY executes to normal completion. In
other words if body does signal, return-from or throw this test
fails."
  `(let ((ok nil))
     (unwind-protect
	 (progn 
	   ,@body
	   (setf ok t))
       (if ok
	   (add-result 'test-passed)
	   (add-result 'test-failure
		       :reason (format nil "Test didn't finish"))))))

(defmacro pass (&rest message-args)
  "Simply generate a PASS."
  `(add-result 'test-passed ,@(when message-args
				`(:reason (format nil ,@message-args)))))

(defmacro fail (&rest message-args)
  "Simply generate a FAIL."
  `(add-result 'test-failure ,@(when message-args
				 `(:reason (format nil ,@message-args)))))

;; Copyright (c) 2002-2003, Edward Marco Baringer
;; All rights reserved. 
;; 
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;; 
;;  - Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 
;;  - Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;;  - Neither the name of Edward Marco Baringer, nor BESE, nor the names
;;    of its contributors may be used to endorse or promote products
;;    derived from this software without specific prior written permission.
;; 
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE