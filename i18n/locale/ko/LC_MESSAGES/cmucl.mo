ή          ¬      <      °  7   ±  7   ι  (   !  7   J  9     n   Ό  -   +  Λ  Y  7   %  7   ]  "     \   Έ  x     A     S   Π  >   $  *   c      O     P   ζ  +   7	  P   c	  O   ΄	     
  /   
  Η  Ί
  P     P   Σ  /   $  e   T     Ί  [   :  [     \   ς  -   O                                   	                        
                                          Binding Stack Usage:    ~13:D bytes (out of ~4:D MB).~% Control Stack Usage:    ~13:D bytes (out of ~4:D MB).~% Depth of recursive descriptions allowed. Dynamic Space Usage:    ~13:D bytes (out of ~4:D MB).~% Garbage collection is currently ~:[enabled~;DISABLED~].~% No way man!  The optional argument to ROOM must be T, NIL, ~
		 or :DEFAULT.~%What do you think you are doing? Oh no.  The current dynamic space is missing! Prints to *STANDARD-OUTPUT* information about the state of internal
  storage and its management.  The optional argument controls the
  verbosity of ROOM.  If it is T, ROOM prints out a maximal amount of
  information.  If it is NIL, ROOM prints out a minimal amount of
  information.  If it is :DEFAULT or it is not supplied, ROOM prints out
  an intermediate amount of information.  See also VM:MEMORY-USAGE and
  VM:INSTANCE-USAGE for finer report control. Read-Only Space Usage:  ~13:D bytes (out of ~4:D MB).~% Static Space Usage:     ~13:D bytes (out of ~4:D MB).~% The current dynamic space is ~D.~% The total CPU time spend doing garbage collection (as reported by
   GET-INTERNAL-RUN-TIME.) This number specifies the minimum number of bytes of dynamic space
   that must be consed before the next gc will occur. ~&; [GC completed with ~:D bytes retained and ~:D bytes freed.]~% ~&; [GC threshold exceeded with ~:D bytes in use.  ~
             Commencing GC.]~% ~&; [GC will next occur when at least ~:D bytes are in use.]~% ~S and ~S do not have the same dimensions. Project-Id-Version: CMUCL 20b
Report-Msgid-Bugs-To: 
PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE
Last-Translator: FULL NAME <EMAIL@ADDRESS>
Language-Team: LANGUAGE <LL@li.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
 λ°μΈλ© μ€ν μ¬μ©:    ~13:D λ°μ΄νΈ (~4:D λ©κ°λ°μ΄νΈμ) μμ.~% μ»¨νΈλ‘€ μ€ν μ¬μ©:     ~13:D λ°μ΄νΈ (~4:D λ©κ°λ°μ΄νΈμ) μμ.~% νμ©λλ μ¬κ·μ μΈ λ¬μ¬μ κΉμ΄. λμ  κ³΅κ° μ¬μ©λ :    ~13:D λ°μ΄νΈ (~4:D λ©κ°λ°μ΄νΈμ) μμ.~% κ°λΉμ§ μ»¬λ μμ νμ¬ ~:[νμ±ν~;λΉνμ±ν~]λμ΄μμ΅λλ€.~% λ§λ μλΌ λ¨μ! ROOMμ μ νμ  μΈμ T, NIL,λμ΄μΌν©λλ€ ~
		λλ :DEFAULT.~% μ λΉμ μ΄ λ­ μκ°νλκ±°μΌ? νμ¬μ μ­λμ μΈ κ³΅κ°μ ~Dμλλ€.~% μ μνμ λν μ λ³΄λ₯Ό μΈμ *STANDARD-OUTPUT* λ΄λΆ μ€ν λ¦¬μ§ λ°
  κ΄λ¦¬. μ νμ  μΈμ μ»¨νΈλ‘€ ROOMμ λ€λ³. κ²½μ° Tμλλ€ μ΅λνμ κΈμ‘μ
  μΈμ ROOM μ λ³΄. λ§μ½ NILμλλ€ μ΅μνμ κΈμ‘μ μΈμ ROOM μ λ³΄. λ§μ½
  μ¬μ€μ΄λΌλ©΄ :DEFAULT λλ μ κ³΅νμ§ μμΌλ©΄ μΈμ ROOM μ  λ³΄μ μ€κ°
  κΈμ‘μλλ€. λν VM:MEMORY-USAGE λ°λ³΄κΈ° μμ§μ λ³΄κ³ μλ₯Ό μ μ΄
  VM:INSTANCE-USAGE. λμ  κ³΅κ° μ¬μ©λ :    ~13:D λ°μ΄νΈ (~4:D λ©κ°λ°μ΄νΈμ) μμ.~% λμ  κ³΅κ° μ¬μ©λ :    ~13:D λ°μ΄νΈ (~4:D λ©κ°λ°μ΄νΈμ) μμ.~% νμ¬μ μ­λμ μΈ κ³΅κ°μ ~Dμλλ€.~% μ΄ CPU μκ° (λ‘μ μν΄λ³΄κ³ λλ μ°λ κΈ°λ₯Ό μκ±°νκ³  μ§μΆ
   GET-INTERNAL-RUN-TIME.) λ°μ΄νΈ μ²μλΆν°μ΄ κΈ°λ₯μ consedμ μλ₯Ό λ°ν
  λΌκ³ νλ€. κ·Έκ²μ΄λΌκ³  μ²μμΌλ‘, 0μ λ°νν©λλ€. ~&; [μ μ§λλ ~:Dμ λ°μ΄νΈ λ° ν΄λ°©λλ ~:Dμ λ°μ΄νΈλ‘ μλ£λλ GC.]~% ~&; [GC λ¬Έν±μ ~:D λ°μ΄νΈλ‘ μ¬μ©μ€μΈ μ΄κ³Όνλ€.  ~
             μμ GC.]~% ~&; [GCλ λ€μ μ μ΄λ ~:Dμ λ°μ΄νΈκ° μ¬μ©μ€μΈ μΌ λ μΌμ΄λ  κ²μ΄λ€.]~% ~S μ ~S λ κ·Έ μμμ μκ° λ€λ₯΄λ€. 