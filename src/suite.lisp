;; -*- lisp -*-

(in-package :it.bese.FiveAM)

;;;; * Test Suites

;;;; Test suites allow us to collect multiple tests into a single
;;;; object and run them all using asingle name. Test suites do not
;;;; affect teh way test are run northe way the results are handled,
;;;; they are simply a test organizing group.

;;;; Test suites can contain both tests and other test suites. Running
;;;; a test suite causes all of its tests and test suites to be
;;;; run. Suites do not affect test dependencies, running a test suite
;;;; can cause tests which are not in the suite to be run.

;;;; ** Creating Suits

(defmacro def-suite (name &key description in)
  "Define a new test-suite named NAME.

IN (a symbol), if provided, causes this suite te be nested in the
suite named by IN."
  `(progn
     (make-suite ',name
		 ,@(when description `(:description ,description))
		 ,@(when in `(:in ',in)))
     ',name))

(defun make-suite (name &key description in)
  "Create a new test suite object."
  (let ((suite (make-instance 'test-suite :name name)))
    (when description
      (setf (description suite) description))
    (loop for i in (ensure-list in)
	  for in-suite = (get-test i)
	  do (progn
	       (when (null in-suite)
		 (cerror "Create a new suite named ~A." "Unknown suite ~A." i)
		 (setf (get-test in-suite) (make-suite i)
		       in-suite (get-test in-suite)))
	       (setf (gethash name (tests in-suite)) suite)))
    (setf (get-test name) suite)
    suite))

;;;; ** Managing the Current Suite

(defvar *suite* (setf (get-test 'NIL)
		      (make-suite 'NIL :description "Global Suite"))
  "The current test suite object")

(defmacro in-suite (suite-name)
  "Set the *suite* special variable so that all tests defined
after the execution of this form are, unless specified otherwise,
in the test-suite named SUITE-NAME.

See also: DEF-SUITE *SUITE*"
  (with-unique-names (suite)
    `(progn
       (if-bind ,suite (get-test ',suite-name)
           (setf *suite* ,suite)
	   (progn
	     (cerror "Create a new suite named ~A."
		     "Unkown suite ~A." ',suite-name)
	     (setf (get-test ',suite-name) (make-suite ',suite-name)
		   *suite* (get-test ',suite-name))))
       ',suite-name)))

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