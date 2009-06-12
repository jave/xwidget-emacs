;; mule-charsets.el -- Generate Mule-orignal charset maps.
;; Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H13PRO009

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.


(if (not (or (and (= emacs-major-version 21) (= emacs-minor-version 4))
	     (= emacs-major-version 22)))
    (error "Use Emacs of version 21.4 or any of version 22"))

(defun func (start end)
  (while (<= start end)
    (let ((split (split-char start))
	  (unicode (encode-char start 'ucs)))
      (if unicode
	  (if (nth 2 split)
	      (insert (format "0x%02X%02X 0x%04X\n"
			      (nth 1 split) (nth 2 split) unicode))
	    (insert (format "0x%02X 0x%04X\n" (nth 1 split) unicode)))))
    (setq start (1+ start))))

(defconst charset-alist
  '(("MULE-ethiopic.map" . ethiopic)
    ("MULE-ipa.map" . ipa)
    ("MULE-is13194.map" . indian-is13194)
    ("MULE-sisheng.map" . chinese-sisheng)
    ("MULE-tibetan.map" . tibetan)
    ("MULE-lviscii.map" . vietnamese-viscii-lower)
    ("MULE-uviscii.map" . vietnamese-viscii-upper)))

(defconst header
  (format
   "# Generated by running amdin/charsets/mule-charsets.el in Emacs %d.%d.\n"
   emacs-major-version emacs-minor-version))

(dolist (elt charset-alist)
  (with-temp-buffer
    (insert header)
    (map-charset-chars 'func (cdr elt))
    (write-file (car elt))))

;;; arch-tag: 515989d7-2e2d-41cc-9163-05ad472fede4
