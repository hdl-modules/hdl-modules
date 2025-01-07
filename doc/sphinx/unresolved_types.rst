Unresolved types
================

The modules consistently use unresolved types
(e.g. ``std_ulogic`` instead of ``std_logic``, ``u_unsigned`` instead of ``unsigned``, etc.).
This means that accidental multiple drivers of a signal will result in an error when simulating
or synthesizing the design.

Since e.g. ``std_logic`` is a sub-type of ``std_ulogic`` in VHDL-2008, it is no problem if
hdl-modules components are integrated in a code base that still uses the resolved types.
E.g. a ``std_logic`` signal can be attached to a hdl-modules port of type ``std_ulogic``
(both ``in`` and ``out``) without problem.
