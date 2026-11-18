(require :asdf)
(asdf:load-asd (merge-pathnames "../sephirion.asd" *load-truename*))
(asdf:test-system "sephirion")
