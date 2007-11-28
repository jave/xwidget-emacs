;;; ntlm.el --- NTLM (NT LanManager) authentication support

;; Copyright (C) 2001, 2007  Free Software Foundation, Inc.

;; Author: Taro Kawagishi <tarok@transpulse.org>
;; Keywords: NTLM, SASL
;; Version: 1.00
;; Created: February 2001

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This library is a direct translation of the Samba release 2.2.0
;; implementation of Windows NT and LanManager compatible password
;; encryption.
;; 
;; Interface functions:
;; 
;; ntlm-build-auth-request
;;   This will return a binary string, which should be used in the
;;   base64 encoded form and it is the caller's responsibility to encode
;;   the returned string with base64.
;;
;; ntlm-build-auth-response
;;   It is the caller's responsibility to pass a base64 decoded string
;;   (which will be a binary string) as the first argument and to
;;   encode the returned string with base64.  The second argument user
;;   should be given in user@domain format.
;; 
;; ntlm-get-password-hashes
;;
;;
;; NTLM authentication procedure example:
;;
;;  1. Open a network connection to the Exchange server at the IMAP port (143)
;;  2. Receive an opening message such as:
;;     "* OK Microsoft Exchange IMAP4rev1 server version 5.5.2653.7 (XXXX) ready"
;;  3. Ask for IMAP server capability by sending "NNN capability"
;;  4. Receive a capability message such as:
;;     "* CAPABILITY IMAP4 IMAP4rev1 IDLE LITERAL+ LOGIN-REFERRALS MAILBOX-REFERRALS NAMESPACE AUTH=NTLM"
;;  5. Ask for NTLM authentication by sending a string
;;     "NNN authenticate ntlm"
;;  6. Receive continuation acknowledgment "+"
;;  7. Send NTLM authentication request generated by 'ntlm-build-auth-request
;;  8. Receive NTLM challenge string following acknowledgment "+"
;;  9. Generate response to challenge by 'ntlm-build-auth-response
;;     (here two hash function values of the user password are encrypted)
;; 10. Receive authentication completion message such as
;;     "NNN OK AUTHENTICATE NTLM completed."

;;; Code:

(require 'md4)

;;;
;;; NTLM authentication interface functions

(defun ntlm-build-auth-request (user &optional domain)
  "Return the NTLM authentication request string for USER and DOMAIN.
USER is a string representing a user name to be authenticated and
DOMAIN is a NT domain.  USER can include a NT domain part as in
user@domain where the string after @ is used as the domain if DOMAIN
is not given."
  (interactive)
  (let ((request-ident (concat "NTLMSSP" (make-string 1 0)))
	(request-msgType (concat (make-string 1 1) (make-string 3 0)))
					;0x01 0x00 0x00 0x00
	(request-flags (concat (make-string 1 7) (make-string 1 178)
			       (make-string 2 0)))
					;0x07 0xb2 0x00 0x00
	lu ld off-d off-u)
    (when (string-match "@" user)
      (unless domain
	(setq domain (substring user (1+ (match-beginning 0)))))
      (setq user (substring user 0 (match-beginning 0))))
    ;; set fields offsets within the request struct
    (setq lu (length user))
    (setq ld (length domain))
    (setq off-u 32)			;offset to the string 'user
    (setq off-d (+ 32 lu))		;offset to the string 'domain
    ;; pack the request struct in a string
    (concat request-ident		;8 bytes
	    request-msgType	;4 bytes
	    request-flags		;4 bytes
	    (md4-pack-int16 lu)	;user field, count field
	    (md4-pack-int16 lu)	;user field, max count field
	    (md4-pack-int32 (cons 0 off-u)) ;user field, offset field
	    (md4-pack-int16 ld)	;domain field, count field
	    (md4-pack-int16 ld)	;domain field, max count field
	    (md4-pack-int32 (cons 0 off-d)) ;domain field, offset field
	    user			;bufer field
	    domain		;bufer field
	    )))

(eval-when-compile
  (defmacro ntlm-string-as-unibyte (string)
    (if (fboundp 'string-as-unibyte)
	`(string-as-unibyte ,string)
      string)))

(defun ntlm-build-auth-response (challenge user password-hashes)
  "Return the response string to a challenge string CHALLENGE given by
the NTLM based server for the user USER and the password hash list
PASSWORD-HASHES.  NTLM uses two hash values which are represented
by PASSWORD-HASHES.  PASSWORD-HASHES should be a return value of
 (list (ntlm-smb-passwd-hash password) (ntlm-md4hash password))"
  (let* ((rchallenge (ntlm-string-as-unibyte challenge))
	 ;; get fields within challenge struct
	 ;;(ident (substring rchallenge 0 8))	;ident, 8 bytes
	 ;;(msgType (substring rchallenge 8 12))	;msgType, 4 bytes
	 (uDomain (substring rchallenge 12 20))	;uDomain, 8 bytes
	 (flags (substring rchallenge 20 24))	;flags, 4 bytes
	 (challengeData (substring rchallenge 24 32)) ;challengeData, 8 bytes
	 uDomain-len uDomain-offs
	 ;; response struct and its fields
	 lmRespData			;lmRespData, 24 bytes
	 ntRespData			;ntRespData, 24 bytes
	 domain				;ascii domain string
	 lu ld off-lm off-nt off-d off-u off-w off-s)
    ;; extract domain string from challenge string
    (setq uDomain-len (md4-unpack-int16 (substring uDomain 0 2)))
    (setq uDomain-offs (md4-unpack-int32 (substring uDomain 4 8)))
    (setq domain
	  (ntlm-unicode2ascii (substring challenge
					 (cdr uDomain-offs)
					 (+ (cdr uDomain-offs) uDomain-len))
			      (/ uDomain-len 2)))
    ;; overwrite domain in case user is given in <user>@<domain> format
    (when (string-match "@" user)
      (setq domain (substring user (1+ (match-beginning 0))))
      (setq user (substring user 0 (match-beginning 0))))

    ;; generate response data
    (setq lmRespData
	  (ntlm-smb-owf-encrypt (car password-hashes) challengeData))
    (setq ntRespData
	  (ntlm-smb-owf-encrypt (cadr password-hashes) challengeData))

    ;; get offsets to fields to pack the response struct in a string
    (setq lu (length user))
    (setq ld (length domain))
    (setq off-lm 64)			;offset to string 'lmResponse
    (setq off-nt (+ 64 24))		;offset to string 'ntResponse
    (setq off-d (+ 64 48))		;offset to string 'uDomain
    (setq off-u (+ 64 48 (* 2 ld)))	;offset to string 'uUser
    (setq off-w (+ 64 48 (* 2 (+ ld lu)))) ;offset to string 'uWks
    (setq off-s (+ 64 48 (* 2 (+ ld lu lu)))) ;offset to string 'sessionKey
    ;; pack the response struct in a string
    (concat "NTLMSSP\0"			;response ident field, 8 bytes
	    (md4-pack-int32 '(0 . 3))	;response msgType field, 4 bytes

	    ;; lmResponse field, 8 bytes
	    ;;AddBytes(response,lmResponse,lmRespData,24);
	    (md4-pack-int16 24)		;len field
	    (md4-pack-int16 24)		;maxlen field
	    (md4-pack-int32 (cons 0 off-lm)) ;field offset

	    ;; ntResponse field, 8 bytes
	    ;;AddBytes(response,ntResponse,ntRespData,24);
	    (md4-pack-int16 24)		;len field
	    (md4-pack-int16 24)		;maxlen field
	    (md4-pack-int32 (cons 0 off-nt)) ;field offset

	    ;; uDomain field, 8 bytes
	    ;;AddUnicodeString(response,uDomain,domain);
	    ;;AddBytes(response, uDomain, udomain, 2*ld);
	    (md4-pack-int16 (* 2 ld))	;len field
	    (md4-pack-int16 (* 2 ld))	;maxlen field
	    (md4-pack-int32 (cons 0 off-d)) ;field offset

	    ;; uUser field, 8 bytes
	    ;;AddUnicodeString(response,uUser,u);
	    ;;AddBytes(response, uUser, uuser, 2*lu);
	    (md4-pack-int16 (* 2 lu))	;len field
	    (md4-pack-int16 (* 2 lu))	;maxlen field
	    (md4-pack-int32 (cons 0 off-u)) ;field offset

	    ;; uWks field, 8 bytes
	    ;;AddUnicodeString(response,uWks,u);
	    (md4-pack-int16 (* 2 lu))	;len field
	    (md4-pack-int16 (* 2 lu))	;maxlen field
	    (md4-pack-int32 (cons 0 off-w)) ;field offset

	    ;; sessionKey field, 8 bytes
	    ;;AddString(response,sessionKey,NULL);
	    (md4-pack-int16 0)		;len field
	    (md4-pack-int16 0)		;maxlen field
	    (md4-pack-int32 (cons 0 (- off-s off-lm))) ;field offset

	    ;; flags field, 4 bytes
	    flags			;

	    ;; buffer field
	    lmRespData			;lmResponse, 24 bytes
	    ntRespData			;ntResponse, 24 bytes
	    (ntlm-ascii2unicode domain	;unicode domain string, 2*ld bytes
				(length domain)) ;
	    (ntlm-ascii2unicode user	;unicode user string, 2*lu bytes
				(length user)) ;
	    (ntlm-ascii2unicode user	;unicode user string, 2*lu bytes
				(length user)) ;
	    )))

(defun ntlm-get-password-hashes (password)
  "Return a pair of SMB hash and NT MD4 hash of the given password PASSWORD"
  (list (ntlm-smb-passwd-hash password)
	(ntlm-md4hash password)))

(defun ntlm-ascii2unicode (str len)
  "Convert an ASCII string into a NT Unicode string, which is
little-endian utf16."
  (let ((utf (make-string (* 2 len) 0)) (i 0) val)
    (while (and (< i len)
		(not (zerop (setq val (aref str i)))))
      (aset utf (* 2 i) val)
      (aset utf (1+ (* 2 i)) 0)
      (setq i (1+ i)))
    utf))

(defun ntlm-unicode2ascii (str len)
  "Extract 7 bits ASCII part of a little endian utf16 string STR of length LEN."
  (let ((buf (make-string len 0)) (i 0) (j 0))
    (while (< i len)
      (aset buf i (logand (aref str j) 127)) ;(string-to-number "7f" 16)
      (setq i (1+ i)
	    j (+ 2 j)))
    buf))

(defun ntlm-smb-passwd-hash (passwd)
  "Return the SMB password hash string of 16 bytes long for the given password
string PASSWD.  PASSWD is truncated to 14 bytes if longer."
  (let ((len (min (length passwd) 14)))
    (ntlm-smb-des-e-p16
     (concat (substring (upcase passwd) 0 len) ;fill top 14 bytes with passwd
	     (make-string (- 15 len) 0)))))

(defun ntlm-smb-owf-encrypt (passwd c8)
  "Return the response string of 24 bytes long for the given password
string PASSWD based on the DES encryption.  PASSWD is of at most 14
bytes long and the challenge string C8 of 8 bytes long."
  (let ((len (min (length passwd) 16)) p22)
    (setq p22 (concat (substring passwd 0 len) ;fill top 16 bytes with passwd
		      (make-string (- 22 len) 0)))
    (ntlm-smb-des-e-p24 p22 c8)))

(defun ntlm-smb-des-e-p24 (p22 c8)
  "Return a 24 bytes hashed string for a 21 bytes string P22 and a 8 bytes
string C8."
  (concat (ntlm-smb-hash c8 p22 t)		;hash first 8 bytes of p22
	  (ntlm-smb-hash c8 (substring p22 7) t)
	  (ntlm-smb-hash c8 (substring p22 14) t)))

(defconst ntlm-smb-sp8 [75 71 83 33 64 35 36 37])

(defun ntlm-smb-des-e-p16 (p15)
  "Return a 16 bytes hashed string for a 15 bytes string P15."
  (concat (ntlm-smb-hash ntlm-smb-sp8 p15 t)	;hash of first 8 bytes of p15
	  (ntlm-smb-hash ntlm-smb-sp8		;hash of last 8 bytes of p15
			 (substring p15 7) t)))

(defun ntlm-smb-hash (in key forw)
  "Return the hash string of length 8 for a string IN of length 8 and
a string KEY of length 8.  FORW is t or nil."
  (let ((out (make-string 8 0))
	outb				;string of length 64
	(inb (make-string 64 0))
	(keyb (make-string 64 0))
	(key2 (ntlm-smb-str-to-key key))
	(i 0) aa)
    (while (< i 64)
      (unless (zerop (logand (aref in (/ i 8)) (lsh 1 (- 7 (% i 8)))))
	(aset inb i 1))
      (unless (zerop (logand (aref key2 (/ i 8)) (lsh 1 (- 7 (% i 8)))))
	(aset keyb i 1))
      (setq i (1+ i)))
    (setq outb (ntlm-smb-dohash inb keyb forw))
    (setq i 0)
    (while (< i 64)
      (unless (zerop (aref outb i))
	(setq aa (aref out (/ i 8)))
	(aset out (/ i 8)
	      (logior aa (lsh 1 (- 7 (% i 8))))))
      (setq i (1+ i)))
    out))

(defun ntlm-smb-str-to-key (str)
  "Return a string of length 8 for the given string STR of length 7."
  (let ((key (make-string 8 0))
	(i 7))
    (aset key 0 (lsh (aref str 0) -1))
    (aset key 1 (logior
		 (lsh (logand (aref str 0) 1) 6)
		 (lsh (aref str 1) -2)))
    (aset key 2 (logior
		 (lsh (logand (aref str 1) 3) 5)
		 (lsh (aref str 2) -3)))
    (aset key 3 (logior
		 (lsh (logand (aref str 2) 7) 4)
		 (lsh (aref str 3) -4)))
    (aset key 4 (logior
		 (lsh (logand (aref str 3) 15) 3)
		 (lsh (aref str 4) -5)))
    (aset key 5 (logior
		 (lsh (logand (aref str 4) 31) 2)
		 (lsh (aref str 5) -6)))
    (aset key 6 (logior
		 (lsh (logand (aref str 5) 63) 1)
		 (lsh (aref str 6) -7)))
    (aset key 7 (logand (aref str 6) 127))
    (while (>= i 0)
      (aset key i (lsh (aref key i) 1))
      (setq i (1- i)))
    key))

(defconst ntlm-smb-perm1 [57 49 41 33 25 17  9
		     1 58 50 42 34 26 18
		     10  2 59 51 43 35 27
		     19 11  3 60 52 44 36
		     63 55 47 39 31 23 15
		     7 62 54 46 38 30 22
		     14  6 61 53 45 37 29
		     21 13  5 28 20 12  4])

(defconst ntlm-smb-perm2 [14 17 11 24  1  5
		     3 28 15  6 21 10
		     23 19 12  4 26  8
		     16  7 27 20 13  2
		     41 52 31 37 47 55
		     30 40 51 45 33 48
		     44 49 39 56 34 53
		     46 42 50 36 29 32])

(defconst ntlm-smb-perm3 [58 50 42 34 26 18 10  2
		     60 52 44 36 28 20 12  4
		     62 54 46 38 30 22 14  6
		     64 56 48 40 32 24 16  8
		     57 49 41 33 25 17  9  1
		     59 51 43 35 27 19 11  3
		     61 53 45 37 29 21 13  5
		     63 55 47 39 31 23 15  7])

(defconst ntlm-smb-perm4 [32  1  2  3  4  5
		     4  5  6  7  8  9
		     8  9 10 11 12 13
		     12 13 14 15 16 17
		     16 17 18 19 20 21
		     20 21 22 23 24 25
		     24 25 26 27 28 29
		     28 29 30 31 32  1])

(defconst ntlm-smb-perm5 [16  7 20 21
		     29 12 28 17
		     1 15 23 26
		     5 18 31 10
		     2  8 24 14
		     32 27  3  9
		     19 13 30  6
		     22 11  4 25])

(defconst ntlm-smb-perm6 [40  8 48 16 56 24 64 32
		     39  7 47 15 55 23 63 31
		     38  6 46 14 54 22 62 30
		     37  5 45 13 53 21 61 29
		     36  4 44 12 52 20 60 28
		     35  3 43 11 51 19 59 27
		     34  2 42 10 50 18 58 26
		     33  1 41  9 49 17 57 25])

(defconst ntlm-smb-sc [1 1 2 2 2 2 2 2 1 2 2 2 2 2 2 1])

(defconst ntlm-smb-sbox [[[14  4 13  1  2 15 11  8  3 10  6 12  5  9  0  7]
		     [ 0 15  7  4 14  2 13  1 10  6 12 11  9  5  3  8]
		     [ 4  1 14  8 13  6  2 11 15 12  9  7  3 10  5  0]
		     [15 12  8  2  4  9  1  7  5 11  3 14 10  0  6 13]]
		    [[15  1  8 14  6 11  3  4  9  7  2 13 12  0  5 10]
		     [ 3 13  4  7 15  2  8 14 12  0  1 10  6  9 11  5]
		     [ 0 14  7 11 10  4 13  1  5  8 12  6  9  3  2 15]
		     [13  8 10  1  3 15  4  2 11  6  7 12  0  5 14  9]]
		    [[10  0  9 14  6  3 15  5  1 13 12  7 11  4  2  8]
		     [13  7  0  9  3  4  6 10  2  8  5 14 12 11 15  1]
		     [13  6  4  9  8 15  3  0 11  1  2 12  5 10 14  7]
		     [ 1 10 13  0  6  9  8  7  4 15 14  3 11  5  2 12]]
		    [[ 7 13 14  3  0  6  9 10  1  2  8  5 11 12  4 15]
		     [13  8 11  5  6 15  0  3  4  7  2 12  1 10 14  9]
		     [10  6  9  0 12 11  7 13 15  1  3 14  5  2  8  4]
		     [ 3 15  0  6 10  1 13  8  9  4  5 11 12  7  2 14]]
		    [[ 2 12  4  1  7 10 11  6  8  5  3 15 13  0 14  9]
		     [14 11  2 12  4  7 13  1  5  0 15 10  3  9  8  6]
		     [ 4  2  1 11 10 13  7  8 15  9 12  5  6  3  0 14]
		     [11  8 12  7  1 14  2 13  6 15  0  9 10  4  5  3]]
		    [[12  1 10 15  9  2  6  8  0 13  3  4 14  7  5 11]
		     [10 15  4  2  7 12  9  5  6  1 13 14  0 11  3  8]
		     [ 9 14 15  5  2  8 12  3  7  0  4 10  1 13 11  6]
		     [ 4  3  2 12  9  5 15 10 11 14  1  7  6  0  8 13]]
		    [[ 4 11  2 14 15  0  8 13  3 12  9  7  5 10  6  1]
		     [13  0 11  7  4  9  1 10 14  3  5 12  2 15  8  6]
		     [ 1  4 11 13 12  3  7 14 10 15  6  8  0  5  9  2]
		     [ 6 11 13  8  1  4 10  7  9  5  0 15 14  2  3 12]]
		    [[13  2  8  4  6 15 11  1 10  9  3 14  5  0 12  7]
		     [ 1 15 13  8 10  3  7  4 12  5  6 11  0 14  9  2]
		     [ 7 11  4  1  9 12 14  2  0  6 10 13 15  3  5  8]
		     [ 2  1 14  7  4 10  8 13 15 12  9  0  3  5  6 11]]])

(defsubst ntlm-string-permute (in perm n)
  "Return a string of length N for a string IN and a permutation vector
PERM of size N.  The length of IN should be height of PERM."
  (let ((i 0) (out (make-string n 0)))
    (while (< i n)
      (aset out i (aref in (- (aref perm i) 1)))
      (setq i (1+ i)))
    out))

(defsubst ntlm-string-lshift (str count len)
  "Return a string by circularly shifting a string STR by COUNT to the left.
length of STR is LEN."
  (let ((c (% count len)))
    (concat (substring str c len) (substring str 0 c))))

(defsubst ntlm-string-xor (in1 in2 n)
  "Return exclusive-or of sequences in1 and in2"
  (let ((w (make-string n 0)) (i 0))
    (while (< i n)
      (aset w i (logxor (aref in1 i) (aref in2 i)))
      (setq i (1+ i)))
    w))

(defun ntlm-smb-dohash (in key forw)
  "Return the hash value for a string IN and a string KEY.
Length of IN and KEY are 64.  FORW non nill means forward, nil means
backward."
  (let (pk1				;string of length 56
	c				;string of length 28
	d				;string of length 28
	cd				;string of length 56
	(ki (make-vector 16 0))		;vector of string of length 48
	pd1				;string of length 64
	l				;string of length 32
	r				;string of length 32
	rl				;string of length 64
	(i 0) (j 0) (k 0))
    (setq pk1 (ntlm-string-permute key ntlm-smb-perm1 56))
    (setq c (substring pk1 0 28))
    (setq d (substring pk1 28 56))

    (setq i 0)
    (while (< i 16)
      (setq c (ntlm-string-lshift c (aref ntlm-smb-sc i) 28))
      (setq d (ntlm-string-lshift d (aref ntlm-smb-sc i) 28))
      (setq cd (concat (substring c 0 28) (substring d 0 28)))
      (aset ki i (ntlm-string-permute cd ntlm-smb-perm2 48))
      (setq i (1+ i)))

    (setq pd1 (ntlm-string-permute in ntlm-smb-perm3 64))

    (setq l (substring pd1 0 32))
    (setq r (substring pd1 32 64))

    (setq i 0)
    (let (er				;string of length 48
	  erk				;string of length 48
	  (b (make-vector 8 0))		;vector of strings of length 6
	  cb				;string of length 32
	  pcb				;string of length 32
	  r2				;string of length 32
	  jj m n bj sbox-jmn)
      (while (< i 16)
	(setq er (ntlm-string-permute r ntlm-smb-perm4 48))
	(setq erk (ntlm-string-xor er
		       (aref ki (if forw i (- 15 i)))
		       48))
	(setq j 0)
	(while (< j 8)
	  (setq jj (* 6 j))
	  (aset b j (substring erk jj (+ jj 6)))
	  (setq j (1+ j)))
	(setq j 0)
	(while (< j 8)
	  (setq bj (aref b j))
	  (setq m (logior (lsh (aref bj 0) 1) (aref bj 5)))
	  (setq n (logior (lsh (aref bj 1) 3)
			  (lsh (aref bj 2) 2)
			  (lsh (aref bj 3) 1)
			  (aref bj 4)))
	  (setq k 0)
	  (setq sbox-jmn (aref (aref (aref ntlm-smb-sbox j) m) n))
	  (while (< k 4)
	    (aset bj k
		  (if (zerop (logand sbox-jmn (lsh 1 (- 3 k))))
		      0 1))
	    (setq k (1+ k)))
	  (setq j (1+ j)))

	(setq j 0)
	(setq cb nil)
	(while (< j 8)
	  (setq cb (concat cb (substring (aref b j) 0 4)))
	  (setq j (1+ j)))

	(setq pcb (ntlm-string-permute cb ntlm-smb-perm5 32))
	(setq r2 (ntlm-string-xor l pcb 32))
	(setq l r)
	(setq r r2)
	(setq i (1+ i))))
    (setq rl (concat r l))
    (ntlm-string-permute rl ntlm-smb-perm6 64)))

(defun ntlm-md4hash (passwd)
  "Return the 16 bytes MD4 hash of a string PASSWD after converting it
into a Unicode string.  PASSWD is truncated to 128 bytes if longer."
  (let (len wpwd)
    ;; Password cannot be longer than 128 characters
    (setq len (length passwd))
    (if (> len 128)
	(setq len 128))
    ;; Password must be converted to NT unicode
    (setq wpwd (ntlm-ascii2unicode passwd len))
    ;; Calculate length in bytes
    (setq len (* len 2))
    (md4 wpwd len)))

(provide 'ntlm)

;;; arch-tag: 348ace18-f8e2-4176-8fe9-d9ab4e96f296
;;; ntlm.el ends here
