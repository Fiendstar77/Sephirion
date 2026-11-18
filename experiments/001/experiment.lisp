(defpackage #:sephirion-experiment-001
  (:use #:cl #:sephirion)
  (:shadow #:run-experiment)
  (:export #:make-propagation #:make-interaction #:make-nested #:run-experiment
           #:invalid-cases #:state-rows))
(in-package #:sephirion-experiment-001)

(defun make-propagation ()
  (make-network (list (make-realm "a" :state 3) (make-realm "b"))
                (list (make-path "ab" "a" "b" :operator :affine :gain 2 :offset 1))))

(defun make-interaction (&key (bc-enabled t))
  (make-network (list (make-realm "a" :state 1) (make-realm "b") (make-realm "c"))
                (list (make-path "ab" "a" "b" :operator :scale :gain 2)
                      (make-path "bc" "b" "c" :operator :scale :gain 3 :enabled bc-enabled)
                      (make-path "ca" "c" "a" :operator :scale :gain 1/2))))

(defun make-nested ()
  (make-network (list (make-realm "input" :state 1) (make-realm "shell")
                      (make-realm "inner" :parent "shell"))
                (list (make-path "in" "input" "shell")
                      (make-path "down" "shell" "inner"))))

(defun state-rows (network)
  (mapcar (lambda (snapshot) (mapcar #'second (getf snapshot :states)))
          (network-history network)))

(defun invalid-cases ()
  "Each thunk must reject explicitly with MODEL-ERROR, not an incidental error."
  (list
   (cons "empty identifier" (lambda () (make-realm "")))
   (cons "float state" (lambda () (make-realm "a" :state 1d0)))
   (cons "complex signal" (lambda () (transform-signal (make-path "p" "a" "b") #c(1 2))))
   (cons "nonnumeric signal" (lambda () (transform-signal (make-path "p" "a" "b") "noise")))
   (cons "oversized state" (lambda () (make-realm "a" :state (expt 2 256))))
   (cons "unsupported operator" (lambda () (make-path "p" "a" "b" :operator :resonate)))
   (cons "unsupported coefficients" (lambda () (make-path "p" "a" "b" :offset 1)))
   (cons "invalid enabled flag" (lambda () (make-path "p" "a" "b" :enabled :yes)))
   (cons "duplicate realms" (lambda () (make-network (list (make-realm "a") (make-realm "a")) nil)))
   (cons "duplicate paths"
         (lambda () (make-network (list (make-realm "a"))
                                  (list (make-path "p" "a" "a") (make-path "p" "a" "a")))))
   (cons "missing endpoint" (lambda () (make-network (list (make-realm "a"))
                                                    (list (make-path "p" "a" "missing")))))
   (cons "missing parent" (lambda () (make-network (list (make-realm "a" :parent "missing")) nil)))
   (cons "containment cycle" (lambda () (make-network (list (make-realm "a" :parent "b")
                                                           (make-realm "b" :parent "a")) nil)))
   (cons "boundary bypass"
         (lambda () (make-network (list (make-realm "outside") (make-realm "shell")
                                        (make-realm "child" :parent "shell"))
                                  (list (make-path "bypass" "outside" "child")))))
   (cons "invalid step count" (lambda () (run-network (make-propagation) -1)))
   (cons "invalid execution order" (lambda () (step-network (make-propagation) :realm-order '("a" "a"))))
   (cons "transformed signal bound"
         (lambda () (transform-signal (make-path "p" "a" "b" :operator :scale :gain 2)
                                      (expt 2 255))))
   (cons "next-state bound"
         (lambda () (step-network (make-network (list (make-realm "a" :state (expt 2 255)))
                                                (list (make-path "p" "a" "a"))))))))

(defun run-experiment (&optional (stream *standard-output*))
  "Print observations and comparisons, then interpretations. Signal on any failure."
  (let ((passed 0) (failed 0))
    (labels ((record (name observed expected)
               (let ((ok (equal observed expected)))
                 (if ok (incf passed) (incf failed))
                 (format stream "~A ~A~%  observed: ~S~%  expected: ~S~%"
                         (if ok "PASS" "FAIL") name observed expected))))
      (format stream "SEPHIRION-001 / Experiment 001~%Exact rational synchronous realm network~%~%OBSERVATIONS (states in sorted realm-ID order)~%")
      (record "A / affine propagation: b(1)=0+(2*3+1)=7"
              (state-rows (run-network (make-propagation) 1)) '((3 0) (3 7)))
      (record "B / recurrent interaction: a,b,c"
              (state-rows (run-network (make-interaction) 4))
              '((1 0 0) (1 2 0) (1 4 6) (4 6 18) (13 14 36)))
      (let ((nested (run-network (make-nested) 3)))
        (record "C / inner,input,shell: explicit boundary adds one tick per edge"
                (state-rows nested) '((0 1 0) (0 1 1) (1 1 2) (3 1 3)))
        (record "C / immediate children of shell" (realm-children nested "shell") '("inner")))
      (record "D / repeated runs have identical complete histories"
              (equal (network-history (run-network (make-interaction) 4))
                     (network-history (run-network (make-interaction) 4))) t)
      (record "E / disable bc: c stays zero; feedback to a disappears"
              (state-rows (run-network (make-interaction :bc-enabled nil) 4))
              '((1 0 0) (1 2 0) (1 4 0) (1 6 0) (1 8 0)))
      (dolist (case (invalid-cases))
        (let ((observed
                (handler-case (progn (funcall (cdr case)) :accepted)
                  (model-error (condition)
                    (format stream "  rejection: ~A~%" condition)
                    :rejected))))
          (record (format nil "F / ~A" (car case)) observed :rejected)))
      (format stream "~%VALIDATION: passed=~D failed=~D unexecuted=0~%" passed failed)
      (format stream "~%INTERPRETATION~%")
      (if (zerop failed)
          (format stream "These observations agree with the specified exact recurrence and explicit boundary routing.~%")
          (format stream "Validation failed; these observations do not establish compliance with the specification.~%"))
      (format stream "Nesting establishes containment and routing constraints; no computational advantage is established.~%No resonance, fractalization, intelligence, consciousness, or physical acoustic behavior is demonstrated.~%")
      (when (plusp failed) (error "Experiment 001 failed ~D validation cases." failed))
      (values passed failed))))
