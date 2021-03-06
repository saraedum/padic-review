include "../../ext/cdefs.pxi"

ctypedef mpz_t celement
from sage.libs.pari.gen cimport gen as pari_gen

include "FM_template_header.pxi"

cdef class pAdicFixedModElement(FMElement):
    cdef lift_c(self)
    cdef pari_gen _to_gen(self)
