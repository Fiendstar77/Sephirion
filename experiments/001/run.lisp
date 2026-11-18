(require :asdf)
(asdf:load-asd (merge-pathnames "../../sephirion.asd" *load-truename*))
(asdf:load-system "sephirion/experiment-001")
(sephirion-experiment-001:run-experiment)
