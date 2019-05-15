
/**
 * bitpacking.cpp
 * Daniel Lemire, http://lemire.me/blog/
 *
 * Question: if you pack and unpack bits, is it much faster if you
 * pack into 8 or 16 bits than, say, 31 or 7 bits?
 *
 *
 * Hardware: 2011 macbook air with Intel Core i7
 * compiler GNU GCC 4.6.2 (code is optimized for GCC 4.6.2, please
 * don't use older compilers as there are pieces of code that
 * would need to be written more carefully for stupider compilers.)
 *
 * g++-4 -Ofast -o bitpacking bitpacking.cpp
 *
 * bits	packtime	unpacktime
 * 1	219			211
 * 2	215			216
 * 3	210			205
 * 4	198			194
 * 5	222			214
 * 6	229			218
 * 7	242			222
 * 8	167			202
 * 9	252			240
 * 10	243			225
 * 11	255			235
 * 12	246			231
 * 13	276			244
 * 14	279			245
 * 15	304			255
 * 16	183			223
 * 17	292			252
 * 18	297			256
 * 19	316			266
 * 20	300			256
 * 21	329			280
 * 22	321			274
 * 23	332			278
 * 24	299			257
 * 25	341			289
 * 26	340			298
 * 27	352			295
 * 28	336			284
 * 29	367			311
 * 30	357			299
 * 31	384			319
 * 32	256			261
 *
 */

 /*
  * As can be seen in the above comment block, this bit unpacking/packing code has been taken (and only very slightly adapted) from an excellent blogpost by Daniel Lemire:
  * https://lemire.me/blog/2012/03/06/how-fast-is-bit-packing/
  *
  */

#include <iostream>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <vector>
#include <cstdlib>
#include <stdio.h>
#include <string.h>

#include <LemireBitUnpacking.h>
#include <SWParquetReader.h>

using namespace std;


void __fastunpack1(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   & 1 ;
    out++;
    *out = ( (*in) >>  1  )   & 1 ;
    out++;
    *out = ( (*in) >>  2  )   & 1 ;
    out++;
    *out = ( (*in) >>  3  )   & 1 ;
    out++;
    *out = ( (*in) >>  4  )   & 1 ;
    out++;
    *out = ( (*in) >>  5  )   & 1 ;
    out++;
    *out = ( (*in) >>  6  )   & 1 ;
    out++;
    *out = ( (*in) >>  7  )   & 1 ;
    out++;
    *out = ( (*in) >>  8  )   & 1 ;
    out++;
    *out = ( (*in) >>  9  )   & 1 ;
    out++;
    *out = ( (*in) >>  10  )   & 1 ;
    out++;
    *out = ( (*in) >>  11  )   & 1 ;
    out++;
    *out = ( (*in) >>  12  )   & 1 ;
    out++;
    *out = ( (*in) >>  13  )   & 1 ;
    out++;
    *out = ( (*in) >>  14  )   & 1 ;
    out++;
    *out = ( (*in) >>  15  )   & 1 ;
    out++;
    *out = ( (*in) >>  16  )   & 1 ;
    out++;
    *out = ( (*in) >>  17  )   & 1 ;
    out++;
    *out = ( (*in) >>  18  )   & 1 ;
    out++;
    *out = ( (*in) >>  19  )   & 1 ;
    out++;
    *out = ( (*in) >>  20  )   & 1 ;
    out++;
    *out = ( (*in) >>  21  )   & 1 ;
    out++;
    *out = ( (*in) >>  22  )   & 1 ;
    out++;
    *out = ( (*in) >>  23  )   & 1 ;
    out++;
    *out = ( (*in) >>  24  )   & 1 ;
    out++;
    *out = ( (*in) >>  25  )   & 1 ;
    out++;
    *out = ( (*in) >>  26  )   & 1 ;
    out++;
    *out = ( (*in) >>  27  )   & 1 ;
    out++;
    *out = ( (*in) >>  28  )   & 1 ;
    out++;
    *out = ( (*in) >>  29  )   & 1 ;
    out++;
    *out = ( (*in) >>  30  )   & 1 ;
    out++;
    *out = ( (*in) >>  31  )   & 1 ;
}




void __fastunpack2(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  2  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  4  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 2 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  2  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  4  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 2 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 2 ) ;
}




void __fastunpack3(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  3  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  9  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 3 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 3 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  4  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  7  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 3 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 3 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  5  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  11  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 3 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 3 ) ;
}




void __fastunpack5(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  5  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 5 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 5 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 5 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 5 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  11  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 5 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 5 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  9  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 5 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 5 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  7  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 5 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 5 ) ;
}




void __fastunpack6(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 6 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 6 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 6 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 6 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 6 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  6  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 6 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 6 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 6 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 6 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 6 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 6 ) ;
}




void __fastunpack7(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  7  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 7 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 7 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 7 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  9  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 7 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 7 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  8  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 7 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 7 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  11  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 7 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 7 ) ;
}




void __fastunpack9(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  9  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 9 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 9 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 9 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 9 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 9 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  11  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 9 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 9 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 9 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 9 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 9 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 9 ) ;
}




void __fastunpack10(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 10 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 10 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 10 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 10 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 10 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  10  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 10 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 10 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 10 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 10 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 10 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 10 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 10 ) ;
}




void __fastunpack11(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  11  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 11 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 11 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 11 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 11 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 11 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 11 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 11 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 11 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 11 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 11 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 11 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 11 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 11 ) ;
}




void __fastunpack12(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 12 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 12 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 12 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 12 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 12 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 12 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 12 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 12 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 12 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  12  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 12 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 12 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 12 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 12 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 12 ) ;
}




void __fastunpack13(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  13  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 13 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 13 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 13 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 13 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 13 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 13 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 13 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 13 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 13 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 13 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 13 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 13 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 13 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 13 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 13 ) ;
}




void __fastunpack14(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 14 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 14 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 14 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 14 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 14 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 14 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 14 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  14  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 14 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 14 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 14 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 14 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 14 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 14 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 14 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 14 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 14 ) ;
}




void __fastunpack15(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  15  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 15 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 15 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 15 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 15 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 15 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 15 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 15 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  16  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 15 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 15 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 15 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 15 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 15 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 15 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 15 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 15 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 15 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 15 ) ;
}




void __fastunpack17(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  17  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 17 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 17 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 17 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 17 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 17 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 17 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 17 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 17 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 17 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 17 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 17 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 17 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 17 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 17 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 17 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 17 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 17 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 17 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 17 ) ;
}




void __fastunpack18(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 18 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 18 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 18 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 18 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 18 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 18 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 18 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 18 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 18 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  18  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 18 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 18 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 18 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 18 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 18 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 18 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 18 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 18 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 18 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 18 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 18 ) ;
}




void __fastunpack19(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  19  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 19 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 19 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 19 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 19 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 19 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 19 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 19 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 19 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 19 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 19 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 19 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 19 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 19 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 19 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 19 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 19 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 19 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 19 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 19 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 19 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 19 ) ;
}




void __fastunpack20(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 20 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 20 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 20 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 20 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 20 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 20 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 20 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 20 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 20 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 20 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 20 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 20 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 20 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 20 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 20 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  20  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 20 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 20 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 20 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 20 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 20 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 20 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 20 ) ;
}




void __fastunpack21(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  21  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 21 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 21 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 21 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 21 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 21 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 21 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 21 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 21 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 21 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 21 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 21 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 21 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 21 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 21 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 21 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 21 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 21 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 21 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 21 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 21 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 21 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 21 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 21 ) ;
}




void __fastunpack22(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 22 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 22 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 22 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 22 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 22 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 22 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 22 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 22 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 22 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 22 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 22 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  22  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 22 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 22 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 22 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 22 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 22 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 22 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 22 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 22 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 22 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 22 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 22 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 22 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 22 ) ;
}




void __fastunpack23(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  23  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 23 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 23 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 23 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 23 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 23 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 23 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 23 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 23 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 23 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 23 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 23 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 23 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 21 ))<<( 23 - 21 );
    out++;
    *out = ( (*in) >>  21  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 23 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 23 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 23 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 23 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 23 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 23 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 23 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 23 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 23 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 23 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 23 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 23 ) ;
}




void __fastunpack24(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 24 ) ;
    out++;
    *out = ( (*in) >>  24  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 24 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 24 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 24 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 24 ) ;
}




void __fastunpack25(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  25  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 25 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 25 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 25 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 25 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 25 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 25 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 25 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 25 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 25 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 25 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 23 ))<<( 25 - 23 );
    out++;
    *out = ( (*in) >>  23  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 25 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 25 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 25 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 25 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 25 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 25 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 25 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 25 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 25 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 25 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 25 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 21 ))<<( 25 - 21 );
    out++;
    *out = ( (*in) >>  21  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 25 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 25 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 25 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 25 ) ;
}




void __fastunpack26(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 26 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 26 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 26 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 26 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 26 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 26 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 26 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 26 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 26 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 26 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 26 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 26 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 26 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  26  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 26 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 26 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 26 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 26 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 26 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 26 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 26 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 26 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 26 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 26 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 26 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 26 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 26 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 26 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 26 ) ;
}




void __fastunpack27(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 27 ) ;
    out++;
    *out = ( (*in) >>  27  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 27 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 27 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 27 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 27 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 27 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 27 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 27 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 27 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 27 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 27 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 27 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 27 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 26 ))<<( 27 - 26 );
    out++;
    *out = ( (*in) >>  26  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 21 ))<<( 27 - 21 );
    out++;
    *out = ( (*in) >>  21  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 27 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 27 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 27 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 27 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 27 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 23 ))<<( 27 - 23 );
    out++;
    *out = ( (*in) >>  23  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 27 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 27 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 27 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 27 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 27 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 25 ))<<( 27 - 25 );
    out++;
    *out = ( (*in) >>  25  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 27 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 27 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 27 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 27 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 27 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 27 ) ;
}




void __fastunpack28(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 28 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 28 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 28 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 28 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 28 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 28 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 28 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 28 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 28 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 28 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 28 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 28 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 28 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 28 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 28 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 28 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 28 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 28 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 28 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 28 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 28 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 28 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 28 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 28 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 28 ) ;
    out++;
    *out = ( (*in) >>  28  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 28 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 28 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 28 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 28 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 28 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 28 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 28 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 28 ) ;
}




void __fastunpack29(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 29 ) ;
    out++;
    *out = ( (*in) >>  29  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 26 ))<<( 29 - 26 );
    out++;
    *out = ( (*in) >>  26  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 23 ))<<( 29 - 23 );
    out++;
    *out = ( (*in) >>  23  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 29 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 29 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 29 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 29 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 29 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 29 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 29 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 29 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 28 ))<<( 29 - 28 );
    out++;
    *out = ( (*in) >>  28  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 25 ))<<( 29 - 25 );
    out++;
    *out = ( (*in) >>  25  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 29 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 29 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 29 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 29 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 29 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 29 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 29 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 29 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 29 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 27 ))<<( 29 - 27 );
    out++;
    *out = ( (*in) >>  27  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 29 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 21 ))<<( 29 - 21 );
    out++;
    *out = ( (*in) >>  21  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 29 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 29 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 29 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 29 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 29 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 29 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 29 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 29 ) ;
}




void __fastunpack30(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 30 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 28 ))<<( 30 - 28 );
    out++;
    *out = ( (*in) >>  28  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 26 ))<<( 30 - 26 );
    out++;
    *out = ( (*in) >>  26  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 30 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 30 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 30 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 30 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 30 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 30 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 30 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 30 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 30 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 30 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 30 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 30 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 30 ) ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   % (1U << 30 ) ;
    out++;
    *out = ( (*in) >>  30  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 28 ))<<( 30 - 28 );
    out++;
    *out = ( (*in) >>  28  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 26 ))<<( 30 - 26 );
    out++;
    *out = ( (*in) >>  26  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 30 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 30 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 30 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 30 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 30 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 30 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 30 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 30 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 30 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 30 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 30 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 30 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 30 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 30 ) ;
}




void __fastunpack31(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   % (1U << 31 ) ;
    out++;
    *out = ( (*in) >>  31  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 30 ))<<( 31 - 30 );
    out++;
    *out = ( (*in) >>  30  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 29 ))<<( 31 - 29 );
    out++;
    *out = ( (*in) >>  29  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 28 ))<<( 31 - 28 );
    out++;
    *out = ( (*in) >>  28  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 27 ))<<( 31 - 27 );
    out++;
    *out = ( (*in) >>  27  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 26 ))<<( 31 - 26 );
    out++;
    *out = ( (*in) >>  26  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 25 ))<<( 31 - 25 );
    out++;
    *out = ( (*in) >>  25  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 24 ))<<( 31 - 24 );
    out++;
    *out = ( (*in) >>  24  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 23 ))<<( 31 - 23 );
    out++;
    *out = ( (*in) >>  23  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 22 ))<<( 31 - 22 );
    out++;
    *out = ( (*in) >>  22  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 21 ))<<( 31 - 21 );
    out++;
    *out = ( (*in) >>  21  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 20 ))<<( 31 - 20 );
    out++;
    *out = ( (*in) >>  20  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 19 ))<<( 31 - 19 );
    out++;
    *out = ( (*in) >>  19  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 18 ))<<( 31 - 18 );
    out++;
    *out = ( (*in) >>  18  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 17 ))<<( 31 - 17 );
    out++;
    *out = ( (*in) >>  17  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 16 ))<<( 31 - 16 );
    out++;
    *out = ( (*in) >>  16  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 15 ))<<( 31 - 15 );
    out++;
    *out = ( (*in) >>  15  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 14 ))<<( 31 - 14 );
    out++;
    *out = ( (*in) >>  14  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 13 ))<<( 31 - 13 );
    out++;
    *out = ( (*in) >>  13  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 12 ))<<( 31 - 12 );
    out++;
    *out = ( (*in) >>  12  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 11 ))<<( 31 - 11 );
    out++;
    *out = ( (*in) >>  11  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 10 ))<<( 31 - 10 );
    out++;
    *out = ( (*in) >>  10  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 9 ))<<( 31 - 9 );
    out++;
    *out = ( (*in) >>  9  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 8 ))<<( 31 - 8 );
    out++;
    *out = ( (*in) >>  8  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 7 ))<<( 31 - 7 );
    out++;
    *out = ( (*in) >>  7  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 6 ))<<( 31 - 6 );
    out++;
    *out = ( (*in) >>  6  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 5 ))<<( 31 - 5 );
    out++;
    *out = ( (*in) >>  5  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 4 ))<<( 31 - 4 );
    out++;
    *out = ( (*in) >>  4  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 3 ))<<( 31 - 3 );
    out++;
    *out = ( (*in) >>  3  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 2 ))<<( 31 - 2 );
    out++;
    *out = ( (*in) >>  2  )   % (1U << 31 ) ;
    ++in;
    *out |= ((*in) % (1U<< 1 ))<<( 31 - 1 );
    out++;
    *out = ( (*in) >>  1  )   % (1U << 31 ) ;
}




void __fastunpack32(const uint *  __restrict__ in, uint *  __restrict__  out) {
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
    ++in;
    out++;
    *out = ( (*in) >>  0  )   ;
}


void __fastunpack4(const uint *  __restrict__ in, uint *  __restrict__  out) {
  for(uint outer=0; outer< 4 ;++outer) {
    for( uint inwordpointer =  0 ;inwordpointer<32; inwordpointer +=  4 )
      *(out++) = ( (*in) >> inwordpointer )   % (1U << 4 ) ;
    ++in;
  }
}




void __fastunpack8(const uint *  __restrict__ in, uint *  __restrict__  out) {
  for(uint outer=0; outer< 8 ;++outer) {
    for( uint inwordpointer =  0 ;inwordpointer<32; inwordpointer +=  8 )
      *(out++) = ( (*in) >> inwordpointer )   % (1U << 8 ) ;
    ++in;
  }
}



void __fastunpack16(const uint *  __restrict__ in, uint *  __restrict__  out) {
  for(uint outer=0; outer< 16 ;++outer) {
    for( uint inwordpointer =  0 ;inwordpointer<32; inwordpointer +=  16 )
      *(out++) = ( (*in) >> inwordpointer )   % (1U << 16 ) ;
    ++in;
  }
}

void fastunpack(const uint *  __restrict__ in, uint *  __restrict__  out, const uint bit) {
	switch(bit) {
            case 0:
                // Case 0 added to deal with Parquet's zero width bit packing
                for(int i=0; i<(BLOCK_SIZE/MINIBLOCKS_IN_BLOCK); i++){
                    out[i]=0;
                }
                break;
			case 1:
				__fastunpack1(in,out);
				break;
			case 2:
				__fastunpack2(in,out);
				break;
			case 3:
				__fastunpack3(in,out);
				break;
			case 4:
				__fastunpack4(in,out);
				break;
			case 5:
				__fastunpack5(in,out);
				break;
			case 6:
				__fastunpack6(in,out);
				break;
			case 7:
				__fastunpack7(in,out);
				break;
			case 8:
				__fastunpack8(in,out);
				break;
			case 9:
				__fastunpack9(in,out);
				break;
			case 10:
				__fastunpack10(in,out);
				break;
			case 11:
				__fastunpack11(in,out);
				break;
			case 12:
				__fastunpack12(in,out);
				break;
			case 13:
				__fastunpack13(in,out);
				break;
			case 14:
				__fastunpack14(in,out);
				break;
			case 15:
				__fastunpack15(in,out);
				break;
			case 16:
				__fastunpack16(in,out);
				break;
			case 17:
				__fastunpack17(in,out);
				break;
			case 18:
				__fastunpack18(in,out);
				break;
			case 19:
				__fastunpack19(in,out);
				break;
			case 20:
				__fastunpack20(in,out);
				break;
			case 21:
				__fastunpack21(in,out);
				break;
			case 22:
				__fastunpack22(in,out);
				break;
			case 23:
				__fastunpack23(in,out);
				break;
			case 24:
				__fastunpack24(in,out);
				break;
			case 25:
				__fastunpack25(in,out);
				break;
			case 26:
				__fastunpack26(in,out);
				break;
			case 27:
				__fastunpack27(in,out);
				break;
			case 28:
				__fastunpack28(in,out);
				break;
			case 29:
				__fastunpack29(in,out);
				break;
			case 30:
				__fastunpack30(in,out);
				break;
			case 31:
				__fastunpack31(in,out);
				break;
			case 32:
				__fastunpack32(in,out);
				break;
			default:
				break;
	}
}

__attribute__ ((noinline))
void fastunpack(const vector<uint> & data, vector<uint> & out, const uint bit) {
		const uint N = out.size();
		for(uint k = 0; k<N/32;++k) {
				fastunpack(& data[0]+(32 * bit) * k / 32,&out[0]+32*k,bit);
		}
}