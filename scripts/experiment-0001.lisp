(require :asdf)
(asdf:load-asd (merge-pathnames "../sephirion.asd" *load-truename*))
(asdf:load-system "sephirion")
(sephirion:run-experiment
 (merge-pathnames "../reports/experiment-0001/"
                  (uiop:pathname-directory-pathname *load-truename*)))
