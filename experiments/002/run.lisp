(require :asdf)
(asdf:load-asd (merge-pathnames "../../sephirion.asd" *load-truename*))
(asdf:load-system "sephirion/experiment-002")
(let ((arguments (uiop:command-line-arguments)))
  (when (> (length arguments) 1) (error "Usage: run.lisp [output-directory]"))
  (sephirion-experiment-002:run-experiments
   (if arguments (uiop:ensure-directory-pathname (first arguments))
       (uiop:pathname-directory-pathname *load-truename*))))
