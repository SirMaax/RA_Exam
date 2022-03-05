// ===========================================================================
// 
// stlsort.C --
// sorting with std::sort
// 
// Ralf Moeller
// 
//    Copyright (C) 2020
//    Computer Engineering Group
//    Faculty of Technology
//    Bielefeld University
//    www.ti.uni-bielefeld.de
// 
// 1.0 / 25. Nov 20 (rm)
// - from scratch
// 1.1 / 27. Nov 20 (rm)
// 1.2 /  3. Jan 22 (rm)
// - Hausarbeit RA WS 21/22
//
// ===========================================================================

// WICHTIGER HINWEIS:
// Bei den von stlsort sortieren Daten können Einträge mit identischen
// Keys in anderer Reihenfolge auftreten als bei der Sortierung mit
// bitweisem LSB-Radix-Sort.

#include <algorithm>    // std::sort
#include <vector>       // std::vector
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// ===========================================================================
// Definitionen
// ===========================================================================

// Anzahl der Elemente im Datenvektor data
#define ELEMS 10000000

// Initialwert Zufallszahlengenerator,
#define SEED 4263

// Sortierrichtung (1 = aufwärts, 0 = abwärts)
#define UP 1

// sorted_data abspeichern als Datei
#define STORE

// Dateiname bei der Ausgabe
#define SORTED_DAT_FN "stl_sorted.dat"

// ===========================================================================
// Data
// ===========================================================================

typedef struct {
  int32_t key;
  uint32_t payload;
} Data;

// ===========================================================================
// Vergleichsfunktion für Data
// ===========================================================================

#if UP == 1

inline bool
compare(const Data &d1, const Data &d2) {
  return d1.key < d2.key;
}

#else

inline bool
compare(const Data &d1, const Data &d2) {
  return d1.key > d2.key;
}

#endif

// ===========================================================================
// Zufallszahlen-Generator
// ===========================================================================

// https://en.wikipedia.org/wiki/Lehmer_random_number_generator
uint32_t state = SEED;

// modified
inline uint8_t
lcg_parkmiller()
{
  uint64_t product = (uint64_t)state * 48271;
  uint32_t x = (product & 0x7fffffff) + (product >> 31);
  state = (x & 0x7fffffff) + (x >> 31);
  return state;
}

inline int32_t
rnd2K()
{
  uint8_t rb[4];
  uint32_t r; 
  for (int i = 0; i < 4; i++)
    rb[i] = lcg_parkmiller();
  memcpy((void*) &r, (void*) rb, 4);
  return r;
}

// ===========================================================================
// zufällige Initialisierung der Daten
// ===========================================================================

Data*
genData()
{
  Data *data = new Data[ELEMS];
  for (uint32_t i = 0; i < ELEMS; i++) {
    data[i].key = rnd2K();
    data[i].payload = i;
  }
  return data;
}

// ===========================================================================
// main
// ===========================================================================

int
main(int argc, char *argv[])
{
  Data *d = genData();
  std::sort(d, d + ELEMS, compare);
#ifdef STORE
  // write output file
  FILE *fOut = fopen(SORTED_DAT_FN, "w");
  if (fOut == NULL) {
    fprintf(stderr, "couldn't open output file %s\n", SORTED_DAT_FN);
    exit(-1);
  }
  size_t elems = ELEMS;
  fwrite(&elems, sizeof(size_t), 1, fOut);
  fwrite(d, sizeof(Data), ELEMS, fOut);
  fclose(fOut);
#endif
  return 0;
}
