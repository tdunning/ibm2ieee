Several tests here are based on several examples found on
[Wikipedia](https://en.wikipedia.org/wiki/IBM_hexadecimal_floating-point)
and in a book by Edward Bosworth to support his course on
[IBM Assembler](http://www.edwardbosworth.com/My3121Textbook_HTM/MyText3121_Ch13_V02.htm)

These tests were all verified using the Python package
[from Enthought](https://github.com/enthought/ibm2ieee).

In addition 10,000 random 32-bit patterns were generated and converted
using the Enthought library to both 32bit IEEE and 64bit IEEE form. 

There are currently no tests for converting from IEEE form back to IBM
floating point, nor are there tests for converting double precision
floating point.
