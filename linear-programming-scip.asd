(asdf:defsystem :linear-programming-scip
  :name "linear-programming-scip"
  :description "A backend for linear-programming using SCIP"
  :author "Qiantan Hong <qthong@stanford.edu>"
  :license "GPL 3.0"
  :version "1.0.0"
  :bug-tracker "https://github.com/kchanqvq/linear-programming-scip/issues"
  :mailto "qthong@stanford.edu"
  :source-control (:git "https://github.com/kchanqvq/linear-programming-scip.git")
  :depends-on (:cffi :linear-programming)
  :serial t
  :components ((:file "package")
               (:file "ffi")
               (:file "high-level")))
