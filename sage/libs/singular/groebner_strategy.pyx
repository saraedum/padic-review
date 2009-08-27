"""
Singular's Groebner Strategy Objects

AUTHORS:

- Martin Albrecht (2009-07): initial implementation
- Michael Brickenstein (2009-07): initial implementation
- Hans Schoenemann (2009-07): initial implementation
"""

#*****************************************************************************
#       Copyright (C) 2009 Martin Albrecht <M.R.Albrecht@rhul.ac.uk>
#       Copyright (C) 2009 Michael Brickenstein <brickenstein@mfo.de>
#       Copyright (C) 2009 Hans Schoenemann <hannes@mathematik.uni-kl.de>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#                  http://www.gnu.org/licenses/
#*****************************************************************************

cdef extern from "":
    int unlikely(int)
    int likely(int)

from sage.libs.singular.decl cimport ideal, ring, poly, currRing
from sage.libs.singular.decl cimport rChangeCurrRing
from sage.libs.singular.decl cimport new_skStrategy, delete_skStrategy, idRankFreeModule
from sage.libs.singular.decl cimport initEcartBBA, enterSBba, initBuchMoraCrit, initS, pNorm, id_Delete, kTest
from sage.libs.singular.decl cimport omfree, redNF, p_Copy, redtailBba

from sage.rings.polynomial.multi_polynomial_ideal import MPolynomialIdeal
from sage.rings.polynomial.multi_polynomial_ideal_libsingular cimport sage_ideal_to_singular_ideal
from sage.rings.polynomial.multi_polynomial_libsingular cimport MPolynomial_libsingular, MPolynomialRing_libsingular, new_MP

cdef class GroebnerStrategy(SageObject):
    """
    A Wrapper for Singular's Groebner Strategy Object.

    This object provides functions for normal form computations and
    other functions for Groebner basis computation.

    ALGORITHM:: Uses Singular via libSINGULAR
    """
    def __init__(self, L):
        """
        Create a new :class:`GroebnerStrategy` object for the
        generators of the ideal ``L``.

        INPUT:

        - ``L`` - a multivariate polynomial ideal

        EXAMPLES::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(QQ)
            sage: I = Ideal([x+z,y+z+1])
            sage: strat = GroebnerStrategy(I); strat
            Groebner Strategy for ideal generated by 2 elements 
            over Multivariate Polynomial Ring in x, y, z over Rational Field
        
        TESTS::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: strat = GroebnerStrategy(None)
            Traceback (most recent call last):
            ...
            TypeError: First parameter must be a multivariate polynomial ideal.

            sage: P.<x,y,z> = PolynomialRing(QQ,order='neglex')
            sage: I = Ideal([x+z,y+z+1])
            sage: strat = GroebnerStrategy(I)
            Traceback (most recent call last):
            ...
            NotImplementedError: The local case is not implemented yet.
            
            sage: P.<x,y,z> = PolynomialRing(CC,order='neglex')
            sage: I = Ideal([x+z,y+z+1])
            sage: strat = GroebnerStrategy(I)
            Traceback (most recent call last):
            ...
            TypeError: First parameter's ring must be multivariate polynomial ring via libsingular.

            sage: P.<x,y,z> = PolynomialRing(ZZ)
            sage: I = Ideal([x+z,y+z+1])
            sage: strat = GroebnerStrategy(I)
            Traceback (most recent call last):
            ...
            NotImplementedError: Only coefficient fields are implemented so far.
            
        """
        if not isinstance(L, MPolynomialIdeal):
            raise TypeError("First parameter must be a multivariate polynomial ideal.")

        if not isinstance(L.ring(), MPolynomialRing_libsingular):
            raise TypeError("First parameter's ring must be multivariate polynomial ring via libsingular.")

        self._ideal = L

        cdef MPolynomialRing_libsingular R = <MPolynomialRing_libsingular>L.ring()
        self._parent = R

        if not R.term_order().is_global():
            raise NotImplementedError("The local case is not implemented yet.")
        
        if not R.base_ring().is_field():
            raise NotImplementedError("Only coefficient fields are implemented so far.")
        
        if (R._ring != currRing):
            rChangeCurrRing(R._ring)

        cdef ideal *i = sage_ideal_to_singular_ideal(L)
        self._strat = new_skStrategy()

        self._strat.ak = idRankFreeModule(i, R._ring)
        #- creating temp data structures
        initBuchMoraCrit(self._strat)
        self._strat.initEcart = initEcartBBA
        self._strat.enterS = enterSBba
        #- set S
        self._strat.sl = -1
        #- init local data struct
        initS(i, NULL, self._strat)
        
        cdef int j
        if R.base_ring().is_field():
            for j in range(self._strat.sl+1)[::-1]:
                pNorm(self._strat.S[j])

        id_Delete(&i, R._ring)
        kTest(self._strat)

    def __dealloc__(self):
        """
        TEST::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(32003))
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: del strat
        """
        cdef ring *oldRing = NULL
        if self._strat:
            omfree(self._strat.sevS)
            omfree(self._strat.ecartS)
            omfree(self._strat.T)
            omfree(self._strat.sevT)
            omfree(self._strat.R)
            omfree(self._strat.S_2_R)
            omfree(self._strat.L)
            omfree(self._strat.B)
            omfree(self._strat.fromQ)
            id_Delete(&self._strat.Shdl, self._parent._ring)

            if self._parent._ring != currRing:
                oldRing = currRing
                rChangeCurrRing(self._parent._ring)
                delete_skStrategy(self._strat)
                rChangeCurrRing(oldRing)
            else:
                delete_skStrategy(self._strat)

    def _repr_(self):
        """
        TEST::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(32003))
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: strat # indirect doctest
            Groebner Strategy for ideal generated by 2 elements over 
            Multivariate Polynomial Ring in x, y, z over Finite Field of size 32003
        """
        return "Groebner Strategy for ideal generated by %d elements over %s"%(self._ideal.ngens(),self._parent)

    def ideal(self):
        """
        Return the ideal this strategy object is defined for.

        EXAMPLE::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(32003))
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: strat.ideal()
            Ideal (x + z, y + z) of Multivariate Polynomial Ring in x, y, z over Finite Field of size 32003
        """
        return self._ideal

    def ring(self):
        """
        Return the ring this strategy object is defined over.

        EXAMPLE::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(32003))
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: strat.ring()
            Multivariate Polynomial Ring in x, y, z over Finite Field of size 32003
        """
        return self._parent

    def __cmp__(self, other):
        """
        EXAMPLE::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(19))
            sage: I = Ideal([P(0)])
            sage: strat = GroebnerStrategy(I)
            sage: strat == GroebnerStrategy(I)
            True
            sage: I = Ideal([x+1,y+z])
            sage: strat == GroebnerStrategy(I)
            False
        """
        if not isinstance(other, GroebnerStrategy):
            return cmp(type(self),other(type))
        else:
            return cmp(self._ideal.gens(),(<GroebnerStrategy>other)._ideal.gens())

    def __reduce__(self):
        """
        EXAMPLE::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(GF(32003))
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: loads(dumps(strat)) == strat
            True
        """
        return unpickle_GroebnerStrategy0, (self._ideal,)

    cpdef MPolynomial_libsingular normal_form(self, MPolynomial_libsingular p):
        """
        Compute the normal form of ``p`` with respect to the
        generators of this object.

        EXAMPLE::

            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(QQ)
            sage: I = Ideal([x + z, y + z])
            sage: strat = GroebnerStrategy(I)
            sage: strat.normal_form(x*y) # indirect doctest
            z^2
            sage: strat.normal_form(x + 1)
            -z + 1

        TESTS::
        
            sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
            sage: P.<x,y,z> = PolynomialRing(QQ)
            sage: I = Ideal([P(0)])
            sage: strat = GroebnerStrategy(I)
            sage: strat.normal_form(x)
            x
            sage: strat.normal_form(P(0))
            0
        """
        if unlikely(p._parent is not self._parent):
            raise TypeError("parent(p) must be the same as this object's parent.")
        if unlikely(self._parent._ring != currRing): 
            rChangeCurrRing(self._parent._ring)

        cdef int max_ind
        cdef poly *_p = redNF(p_Copy(p._poly, self._parent._ring), max_ind, 0, self._strat)
        if likely(_p!=NULL):
            _p = redtailBba(_p, max_ind, self._strat)
        return new_MP(self._parent, _p)

def unpickle_GroebnerStrategy0(I):
    """
    EXAMPLE::

        sage: from sage.libs.singular.groebner_strategy import GroebnerStrategy
        sage: P.<x,y,z> = PolynomialRing(GF(32003))
        sage: I = Ideal([x + z, y + z])
        sage: strat = GroebnerStrategy(I)
        sage: loads(dumps(strat)) == strat
        True
    """
    return GroebnerStrategy(I)
