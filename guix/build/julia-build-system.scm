;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017 Leo Famulari <leo@famulari.name>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (guix build julia-build-system)
  #:use-module ((guix build gnu-build-system) #:prefix gnu:)
  #:use-module (guix build utils)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (%standard-phases
            julia-build))

;; Commentary:
;;
;; Build procedures for Julia packages.  This is the builder-side code.
;;
;; Code:

;; Copied from python-build-system.
(define (julia-version julia)
  (let* ((version (last (string-split julia #\-)))
         (components (string-split version #\.))
         (major+minor (take components 2)))
    (string-join major+minor ".")))

(define* (install-source #:key outputs inputs (module-name #f)
                         #:allow-other-keys)
  (let* ((out (assoc-ref outputs "out"))
         (source (getcwd))
         (julia (assoc-ref inputs "julia"))
         (dst (string-append out "/v" (julia-version julia)
                             "/" module-name)))
    (copy-recursively source dst)))

(define* (build #:key outputs inputs (module-name #f) #:allow-other-keys)
  "Build a given Julia package."
  (let* ((out (assoc-ref outputs "out"))
         (julia (assoc-ref inputs "julia")))
    ;; XXX Where to put the precompiled "system images" (.ji files).
    ;;
    ;; Currently, the whole dependency graph's "image" files are placed there.
    ;; We might need to build a symlink union of the inputs and pass it to the
    ;; internal Julia array LOAD_CACHE_PATH in order to prevent this.
    (setenv "JULIA_PKGDIR" out)
    ;; Export an environment variable containing a list of the inputs' source
    ;; code directories.
    (set-path-environment-variable "JULIA_LOAD_PATH"
                                   (list "src" ; Necessary? Or does Julia always look in ./src?
                                         (string-append "v" (julia-version julia)))
                                   (match inputs
                                     (((_ . dir) ...)
                                      dir)) )
    (if (file-exists? "deps/build.jl")
      ;; Use the build scripts.
      (begin (display "build script found") (newline))
      ;; There are no build scripts, so just "pre-compile" the module.
      (zero? (system* "julia" "-e" (string-append "using " module-name))))))

(define %standard-phases
  (modify-phases gnu:%standard-phases
    (delete 'configure)
    (delete 'patch-dot-desktop-files)
    (add-before 'build 'install-source install-source)
    (replace 'build build)
    (delete 'check) ; TODO
    (delete 'install) ; TODO
    ))

(define* (julia-build #:key inputs (phases %standard-phases)
                      #:allow-other-keys #:rest args)
  "Build the given Julia package, applying all of PHASES in order."
  (apply gnu:gnu-build #:inputs inputs #:phases phases args))
