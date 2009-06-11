;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Package: STREAM -*-
;;;
;;; **********************************************************************
;;; This code was written by Paul Foley and has been placed in the public
;;; domain.
;;;
(ext:file-comment "$Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/pcl/simple-streams/external-formats/mac-cyrillic.lisp,v 1.2 2009/06/11 16:04:02 rtoy Rel $")

(in-package "STREAM")

(defconstant +mac-cyrillic+
  (make-array 128 :element-type '(unsigned-byte 16)
     :initial-contents #(1040 1041 1042 1043 1044 1045 1046 1047 1048 1049 1050
                         1051 1052 1053 1054 1055 1056 1057 1058 1059 1060 1061
                         1062 1063 1064 1065 1066 1067 1068 1069 1070 1071 8224
                         176 162 163 167 8226 182 1030 174 169 8482 1026 1106
                         8800 1027 1107 8734 177 8804 8805 1110 181 8706 1032
                         1028 1108 1031 1111 1033 1113 1034 1114 1112 1029 172
                         8730 402 8776 8710 171 187 8230 160 1035 1115 1036
                         1116 1109 8211 8212 8220 8221 8216 8217 247 8222 1038
                         1118 1039 1119 8470 1025 1105 1103 1072 1073 1074 1075
                         1076 1077 1078 1079 1080 1081 1082 1083 1084 1085 1086
                         1087 1088 1089 1090 1091 1092 1093 1094 1095 1096 1097
                         1098 1099 1100 1101 1102 164)))

(define-external-format :mac-cyrillic (:mac-roman)
  ((table +mac-cyrillic+)))
