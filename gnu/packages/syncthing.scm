;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Petter <petter@mykolab.ch>
;;; Copyright © 2016, 2017, 2018, 2019, 2020, 2021 Leo Famulari <leo@famulari.name>
;;; Copyright © 2020 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2020-2022 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2020 Giacomo Leidi <goodoldpaul@autistici.org>
;;; Copyright © 2021 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;; Copyright © 2021 Arun Isaac <arunisaac@systemreboot.net>
;;; Copyright © 2022 John Kehayias <john.kehayias@protonmail.com>
;;; Copyright © 2023 Benjamin Slade <slade@lambda-y.net>
;;; Copyright © 2024 David Pflug <david@pflug.io>
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

(define-module (gnu packages syncthing)
  #:use-module (guix build-system go)
  #:use-module (guix build-system python)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix licenses)
  #:use-module (gnu packages)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages golang-build)
  #:use-module (gnu packages golang-compression)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages time))

(define-public syncthing
  (package
    (name "syncthing")
    (version "1.27.8")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/syncthing/syncthing"
                                  "/releases/download/v" version
                                  "/syncthing-source-v" version ".tar.gz"))
              (sha256
               (base32
                "1j28jmg5yjb3zmyghc6rmkr8hhvbhbq2nbw0r5w01lvjksalmv49"))))
    (build-system go-build-system)
    ;; The primary Syncthing executable goes to "out", while the auxiliary
    ;; server programs and utility tools go to "utils".  This reduces the size
    ;; of "out" by ~144 MiB.
    (outputs '("out" "utils"))
    (arguments
     (list #:modules '((srfi srfi-26) ; for cut
                       (guix build utils)
                       (guix build go-build-system))
           #:import-path "github.com/syncthing/syncthing"
           ;; We don't need to install the source code for end-user applications.
           #:install-source? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-before 'build 'increase-test-timeout
                 (lambda _
                   (substitute* "src/github.com/syncthing/syncthing/build.go"
                     (("120s") "999s"))))

               (replace 'build
                 (lambda _
                   (with-directory-excursion "src/github.com/syncthing/syncthing"
                     ;; XXX The only way to build Syncthing without its automatic
                     ;; updater and to build the utilities is to "build all" and then
                     ;; "build syncthing" again with -no-upgrade.
                     ;; https://github.com/syncthing/syncthing/issues/6118
                     (invoke "go" "run" "build.go")
                     (delete-file "bin/syncthing")
                     (invoke "go" "run" "build.go" "-no-upgrade" "build" "syncthing"))))

             (replace 'check
               (lambda* (#:key tests? #:allow-other-keys)
                 (when tests?
                   (with-directory-excursion "src/github.com/syncthing/syncthing"
                     (invoke "go" "run" "build.go" "test")))))

             (replace 'install
               (lambda _
                 (with-directory-excursion "src/github.com/syncthing/syncthing/bin"
                   (install-file "../syncthing" (string-append #$output "/bin"))
                   (for-each (cut install-file <> (string-append #$output:utils "/bin/"))
                             '("stcompdirs" "stcrashreceiver"
                               "stdisco" "stdiscosrv" "stevents" "stfileinfo"
                               "stfinddevice" "stfindignored" "stgenfiles"
                               "strelaypoolsrv" "strelaysrv" "stsigtool"
                               "stvanity" "stwatchfile" "ursrv")))))

         (add-after 'install 'install-docs
           (lambda _
             (let ((man (string-append #$output "/share/man"))
                   (man:utils (string-append #$output:utils "/share/man")))
               ;; Install all the man pages to "out".
               (for-each
                (lambda (file)
                  (install-file file
                                (string-append man "/man" (string-take-right file 1))))
                (find-files "src/github.com/syncthing/syncthing/man" "\\.[1-9]"))
               ;; Copy all the man pages to "utils"
               (copy-recursively man man:utils)
               ;; Delete extraneous man pages from "out" and "utils",
               ;; respectively.
               (delete-file (string-append man "/man1/stdiscosrv.1"))
               (delete-file (string-append man "/man1/strelaysrv.1"))
               (delete-file (string-append man:utils  "/man1/syncthing.1"))))))))
    (synopsis "Decentralized continuous file system synchronization")
    (description "Syncthing is a peer-to-peer file synchronization tool that
supports a wide variety of computing platforms.  It uses the Block Exchange
Protocol.")
    (home-page "https://github.com/syncthing/syncthing")
    (properties
     '((release-monitoring-url . "https://syncthing.net/downloads/")
       (upstream-name . "syncthing-source")
       ;; The hashing code greatly benefits from newer architecture support.
       (tunable? . #t)))
    (license mpl2.0)))

(define-public syncthing-gtk
  ;; The commit used below corresponds to the latest commit of the
  ;; python3-port branch maintained by Debian.  Upstream hasn't bothered
  ;; porting to Python 3 (see:
  ;; https://github.com/kozec/syncthing-gtk/issues/487).
  (let ((revision "1")
        (commit "c46fbd8ad1d12d409da8942702a2f119cf45514a"))
    (package
      (name "syncthing-gtk")
      (version (git-version "0.9.4.4" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://salsa.debian.org/debian/syncthing-gtk.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "1x1c8snf0jpgjmyyidjw0015ksk5ishqn817wx8vs9i0lfgnnbbg"))))
      (build-system python-build-system)
      (arguments
       `(#:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'hardcode-dependencies
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((psmisc (assoc-ref inputs "psmisc"))
                     (syncthing (assoc-ref inputs "syncthing")))
                 ;; Hardcode dependencies paths to avoid propagation.
                 (substitute* "syncthing_gtk/tools.py"
                   (("killall") (string-append psmisc "/bin/killall")))
                 (substitute* "syncthing_gtk/configuration.py"
                   (("/usr/bin/syncthing") (string-append syncthing
                                                          "/bin/syncthing"))))))
           (add-after 'unpack 'fix-autostart-path
             ;; Change the autostart .desktop file 'Exec' command so it finds
             ;; the Python wrapper of 'syncthing-gtk', rather than the unwrapped
             ;; '.syncthing-gtk-real'.
             (lambda _
               (substitute* "syncthing_gtk/tools.py"
                 (("return executable")
                   "return \"syncthing-gtk\""))))
           (add-after 'unpack 'remove-windows.py
             (lambda _
               ;; A Windows-specific module that fails to load with
               ;; "ModuleNotFoundError: No module named 'msvcrt'.
               (delete-file "syncthing_gtk/windows.py")))
           (add-after 'wrap 'wrap-libs
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((out (assoc-ref outputs "out")))
                 (wrap-program (string-append out "/bin/syncthing-gtk")
                   `("GI_TYPELIB_PATH" ":" prefix
                     (,(getenv "GI_TYPELIB_PATH"))))))))))
      (inputs
       (list gtk+
             libappindicator
             libnotify
             python-bcrypt
             python-dateutil
             python-pycairo
             python-pygobject
             psmisc
             syncthing))
      (home-page "https://github.com/syncthing/syncthing-gtk")
      (synopsis "GTK3 based GUI and notification area icon for Syncthing")
      (description "@code{syncthing-gtk} is a GTK3 Python based GUI and
notification area icon for Syncthing.  Supported Syncthing features:

@itemize
@item Everything that WebUI can display
@item Adding, editing and deleting nodes
@item Adding, editing and deleting repositories
@item Restart, shutdown server
@item Editing daemon settings
@end itemize\n")
      (license gpl2))))

(define-public qsyncthingtray
  (deprecated-package "qsyncthingtray" syncthing-gtk))

(define-public go-github-com-syncthing-notify
  (let ((commit "69c7a957d3e261f9744f46b3dd4d608d8480ad90")
        (revision "5"))
    (package
      (name "go-github-com-syncthing-notify")
      (version (git-version "0.0.0" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                       (url "https://github.com/syncthing/notify")
                       (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "1mmdzyfnmjabyhbipl4bggw4w5nlxyyjp0d93qd824kj07kmsr1f"))))
      (build-system go-build-system)
      (arguments
       '(#:import-path "github.com/syncthing/notify"))
      (propagated-inputs
       (list go-golang-org-x-sys))
      (synopsis "File system event notification library")
      (description "This package provides @code{notify}, a file system event
notification library in Go.")
      (home-page "https://github.com/syncthing/notify")
      (license expat))))
