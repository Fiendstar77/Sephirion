;;;; SEPHIRION — recursive computational architecture research.

(asdf:defsystem "sephirion"
  :description "Recursive Realms, Transformative Paths, Emergent Dynamics"
  :version "0.2.0"
  :serial t
  :components ((:file "src/package")
               (:file "src/acoustics")
               (:file "src/realms")
               (:file "src/acoustic-network")
               (:file "src/acoustic-integration")
               (:file "src/acoustic-measurement"))
  :in-order-to ((asdf:test-op (asdf:test-op "sephirion/tests"))))

(asdf:defsystem "sephirion/experiment-001"
  :depends-on ("sephirion")
  :components ((:file "experiments/001/experiment")))

(asdf:defsystem "sephirion/experiment-002"
  :depends-on ("sephirion")
  :serial t
  :components ((:file "experiments/002/fixtures")
               (:file "experiments/002/experiment")))

(asdf:defsystem "sephirion/tests"
  :depends-on ("sephirion" "sephirion/experiment-001" "sephirion/experiment-002")
  :serial t
  :components ((:file "tests/acoustics")
               (:file "tests/realms")
               (:file "tests/acoustic-network"))
  :perform (asdf:test-op (operation system)
             (declare (ignore operation system))
             (uiop:symbol-call :sephirion-tests :run-tests)
             (uiop:symbol-call :sephirion-realm-tests :run-tests)
             (uiop:symbol-call :sephirion-acoustic-tests :run-tests)))
