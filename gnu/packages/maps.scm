;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Leo Famulari <leo@famulari.name>
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

(define-module (gnu packages maps)
  #:use-module (guix build-system glib-or-gtk)
  #:use-module (guix download)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages glib) ; intltool
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages webkit)
  #:use-module (gnu packages xml))

(define-public gnome-maps
  (package
    (name "gnome-maps")
    (version "3.20.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://gnome/sources/" name "/"
                                  (version-major+minor version) "/"
                                  name "-" version ".tar.xz"))
              (sha256
               (base32
                "1mcvx72wy3h6h0mk15gr5zdw5j4dbrxxd130vg8xbzzx7h5d2x28"))))
    (build-system glib-or-gtk-build-system)
    (arguments
     `(
;;; This seems to have no effect. Perhaps the software does not use these
;;; environment variables?
;       #:configure-flags
;       (list (string-append "LDFLAGS=-L"
;                            (assoc-ref %build-inputs "webkitgtk") "/lib"
;                            " -lwebkit2gtk-4.0 -ljavascriptcoregtk-4.0"
;                            )
;             (string-append "CFLAGS=-I"
;                            (assoc-ref %build-inputs "webkitgtk") "/include"
;                            )
;             )
       #:phases
       (modify-phases %standard-phases
         (add-after
          'install 'wrap
          (lambda* (#:key inputs outputs #:allow-other-keys)
            (let ((out (assoc-ref outputs "out"))
                  (gi-typelib-path (getenv "GI_TYPELIB_PATH")))
              (wrap-program (string-append out "/bin/gnome-maps")
               `("GI_TYPELIB_PATH" ":" prefix (,gi-typelib-path))
               `("LD_LIBRARY_PATH" ":" prefix
                 ,(map (lambda (input)
                         (string-append (assoc-ref inputs input) "/lib"))
                       '("gnome-online-accounts" "webkitgtk" "geoclue"))))))))))
    (native-inputs
     `(("gobject-introspection" ,gobject-introspection)
       ("intltool" ,intltool)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("folks" ,folks)
       ("libchamplain" ,libchamplain)
       ("libgee" ,libgee)
       ("libgweather" ,libgweather)
       ("libsecret" ,libsecret)
       ("libxml2" ,libxml2)
       ("geoclue" ,geoclue)
       ("geocode-glib" ,geocode-glib)
       ("gfbgraph" ,gfbgraph)
       ("gjs" ,gjs)
       ("glib" ,glib)
       ("gnome-online-accounts" ,gnome-online-accounts) ; necessary?
       ("rest" ,rest)
       ("webkitgtk" ,webkitgtk))) ; necessary?
    (propagated-inputs
     `(("gtk+3" ,gtk+))) ; necessary?
    (synopsis "Graphical map viewer")
    (description "GNOME Maps is a graphical map viewer.  It uses map data from
the OpenStreetMap project.")
    (home-page "https://wiki.gnome.org/Apps/Maps")
    (license gpl2+)))
