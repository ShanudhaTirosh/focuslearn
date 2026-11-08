# Phase 5: calculators, formulas, assignments, analytics (calculator core only)

Roadmap exit criteria: **calculators pass the test vectors, and the educator formula workflow works.**
Status: **the calculator core is written and proven offline. Everything around it is not built:** no calculator screens, no history or saved
results, no formula library or educator draft, review and publish workflow, no exam mode, no analytics. The first criterion is met in logic
only (Python and Dart both written, Dart never compiled); the second is not met.

## What exists
| Piece | Where | Verified how |
|---|---|---|
| Exact arithmetic (no floating point): `Rational` over `BigInt`, one rounding at the end, **half away from zero**, never a negative zero | `packages/core/lib/src/calc/rational.dart`, `calc_reference.py` | Python port of the Dart helpers (emulating Dart's truncating `~/` and Euclidean `%`) compared with the reference on 4,000 + 3,000 random values including 30-digit numbers and negatives; a negative control with a naive `floor()` on negatives fails |
| Percentage: of, what percent, change, increase, decrease | `calculators.dart` | Vectors + properties |
| Ratio: simplify, split an amount (largest-remainder cents, shares always add up to the amount), proportion | same | Vectors + 400 random splits |
| Profit and loss, markup and margin prices | same | Vectors + 200 random price round trips within the one-cent bound |
| Simple and compound interest (whole numbers of periods) | same | Vectors checked against an independent 60-digit decimal computation |
| Break-even, accounting equation | same | Vectors |
| Statistics: mean, median, mode(s), range, population and sample variance and standard deviation (exact, integer square root) | `statistics.dart` | Vectors + 200 random data sets |
| Unit converter: length, mass, volume, area, time, speed, temperature (every factor an exact definition; 1 acre = 43,560 ft² falls out exactly) | `convert.dart` | Vectors + round-trip properties |
| Standard calculator: + - * / ^ ( ) and %, exact (0.1 + 0.2 = 0.3, 1/3 × 3 = 1) | `evaluate.dart` | 232 vectors in total, 300 random exactness checks |
| Steps and formula for every result (English text, to be localised) | all | Exact text checked for 5 calculators (6 cases); shape checked for all |
| Published test-vector file | `test-vectors/calculators.json` | Written by hand or from an independent computation, never from the code under test |

10 mutation checks on the reference (wrong rounding, wrong tie-breaking for cents, simple instead of compound interest, sample variance divided by n,
wrong unary-minus precedence, wrong Fahrenheit factor, break-even rounded down, wrong sign, negative zero, wrong even-count median) were each caught.

## Rules worth knowing
- Inputs are decimal **strings**: optional minus, `.` as the decimal point, no plus sign, no leading zeros, no exponent, at most 15 whole digits and 8 decimals.
  A user typing `1,5` or `1e3` gets `invalid_number`; the screen must normalise locale input before calling the core.
- Money results show 2 decimals; conversions and the standard calculator show up to 10 decimals with no trailing zeros, and say whether anything was rounded.
- Ratio splits: each share is rounded DOWN to cents, and the leftover cents go to the largest remainders (ties: the earlier part), so the shares always add up to exactly the amount.
- `percent` in the standard calculator only divides by 100 (`100 + 10%` is `100.1`).
- A unary minus binds weaker than a power (`-3^2` is `-9`); powers associate to the right; exponents must be whole numbers.
- Everything is labelled as a **study aid**. Nothing here claims examination approval, and marking schemes may round differently.

## Not built (the rest of Phase 5)
1. Scientific functions (sin, cos, tan, ln, log, roots, constants): they need floating point and a tolerance-based contract, which is a separate piece of work.
2. Calculator screens, history and saved results (local cache, then sync), exam-mode restrictions set by an administrator.
3. The **formula library and educator workflow**: `formula_entries` with versions, draft, review and publish states, stream collections, educator roles.
4. Financial extras the syllabus may need: loans and annuities, depreciation, discounting, tax.
5. Assignments screens and analytics (the `assignments` table exists from Phase 2).
6. Localised steps (the step text is English; Sinhala and Tamil need translated templates and a decision on number formatting).

## First real run
`(cd packages/core && dart pub get && dart test)` runs `calculators_test.dart` with the same 232 vectors. A failure points to a Dart-specific difference, and the Python port check already covers the integer-division and rounding ones.
