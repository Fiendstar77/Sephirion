;;;; SEPHIRION — recursive computational architecture research.

(asdf:defsystem "sephirion"
  :description "Recursive Realms, Transformative Paths, Emergent Dynamics"
  :version "0.1.0"
  :serial t
  :components ((:file "src/package")
               (:file "src/acoustics")
               (:file "src/realms"))
  :in-order-to ((asdf:test-op (asdf:test-op "sephirion/tests"))))

(asdf:defsystem "sephirion/experiment-001"
  :depends-on ("sephirion")
  :components ((:file "experiments/001/experiment")))

(asdf:defsystem "sephirion/tests"
  :depends-on ("sephirion" "sephirion/experiment-001")
  :serial t
  :components ((:file "tests/acoustics")
               (:file "tests/realms"))
  :perform (asdf:test-op (operation system)
             (declare (ignore operation system))
             (uiop:symbol-call :sephirion-tests :run-tests)
             (uiop:symbol-call :sephirion-realm-tests :run-tests)))
