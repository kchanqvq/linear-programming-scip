(in-package #:linear-programming-scip)

(define-foreign-library libscip
  (t (:default "libscip")))

(use-foreign-library libscip)

;; based on headers from SCIP version 9.1.0

(defcenum retcode
  (:okay 1)
  (:error 0)
  (:nomemory  -1)
  (:readerror  -2)
  (:writeerror  -3)
  (:nofile  -4)
  (:filecreateerror  -5)
  (:lperror  -6)
  (:noproblem  -7)
  (:invalidcall  -8)
  (:invaliddata  -9)
  (:invalidresult  -10)
  (:pluginnotfound  -11)
  (:parameterunknown  -12)
  (:parameterwrongtype  -13)
  (:parameterwrongval  -14)
  (:keyalreadyexisting  -15)
  (:maxdepthlevel  -16)
  (:brancherror  -17)
  (:notimplemented  -18))

(defcenum vartype
  (:binary 0)
  (:integer 1)
  (:continuous 3))

(defcenum objsense
  (:maximize -1)
  (:minimize 1))

(defcenum param-emphasis
  (:default 0)
  (:cpsolver 1)
  (:easycip 2)
  (:feasibility 3)
  (:hardlp 4)
  (:optimality 5)
  (:counter 6)
  (:phasefeas 7)
  (:phaseimprove 8)
  (:phaseproof 9)
  (:numerics 10)
  (:benchmark 11))

(defcenum status
  (:unknown 0)
  (:optimal 1)
  (:infeasible 2)
  (:unbounded 3)
  (:infeasible-or-unbounded 4)
  (:user-interrupt 10)
  (:terminate 11)
  (:node-limit 20)
  (:total-node-limit 21)
  (:stall-node-limit 22)
  (:time-limit 23)
  (:mem-limit 24)
  (:gap-limit 25)
  (:primal-limit 26)
  (:dual-limit 27)
  (:sol-limit 28)
  (:best-sol-limit 29)
  (:restart-limit 30))

;; Functions

(defcfun ("SCIPinfinity" %infinity) :double (scip :pointer))

(defcfun ("SCIPcreate" %create) retcode (scip (:pointer :pointer)))

(defcfun ("SCIPfree" %free) retcode (scip (:pointer :pointer)))

(defcfun ("SCIPincludeDefaultPlugins" %include-default-plugins)
    retcode
  (scip :pointer))

(defcfun ("SCIPsetRealParam" %set-real-param)
    retcode
  (scip :pointer)
  (name :string)
  (value :double))

(defcfun ("SCIPsetLongintParam" %set-longint-param)
    retcode
  (scip :pointer)
  (name :string)
  (value :long-long))

(defcfun ("SCIPsetEmphasis" %set-emphasis)
    retcode
  (scip :pointer)
  (emphasis param-emphasis)
  (quiet :boolean))

(defcfun ("SCIPsetObjsense" %set-objsense)
    retcode
  (scip :pointer)
  (objsense objsense))

(defcfun ("SCIPcreateProbBasic" %create-prob-basic)
    retcode
  (scip :pointer)
  (name :string))

(defcfun ("SCIPcreateVarBasic" %create-var-basic)
    retcode
  (scip :pointer)
  (var (:pointer :pointer))
  (name :string)
  (lower-bound :double)
  (upper-bound :double)
  (objective-value :double)
  (var-type vartype))

(defcfun ("SCIPreleaseVar" %release-var)
    retcode
  (scip :pointer)
  (var (:pointer :pointer)))

(defcfun ("SCIPaddVar" %add-var)
    retcode
  (scip :pointer)
  (var :pointer))

(defcfun ("SCIPcreateConsBasicLinear" %create-cons-basic-linear)
    retcode
  (scip :pointer)
  (cons (:pointer :pointer))
  (name :string)
  (nvars :int)
  (vars (:pointer :pointer))
  (vals (:pointer :double))
  (lhs :double)
  (rhs :double))

(defcfun ("SCIPreleaseCons" %release-cons)
    retcode
  (scip :pointer)
  (cons (:pointer :pointer)))

(defcfun ("SCIPaddCons" %add-cons)
    retcode
  (scip :pointer)
  (cons :pointer))

(defcfun ("SCIPsolve" %solve) retcode (scip :pointer))

(defcfun ("SCIPgetStatus" %get-status) status (scip :pointer))

(defcfun ("SCIPgetBestSol" %get-best-sol) :pointer (scip :pointer))

(defcfun ("SCIPgetSolVals" %get-sol-vals)
    retcode
  (scip :pointer)
  (sol :pointer)
  (nvars :int)
  (vars (:pointer :pointer))
  (vals (:pointer :double)))

(defcfun ("SCIPgetSolOrigObj" %get-sol-orig-obj)
    :double
  (scip :pointer)
  (sol :pointer))
