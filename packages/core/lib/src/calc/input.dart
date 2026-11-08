import 'rational.dart';

final RegExp _numberPattern = RegExp(r'^-?(0|[1-9][0-9]{0,14})(\.[0-9]{1,8})?$');
final RegExp _integerPattern = RegExp(r'^(0|[1-9][0-9]{0,8})$');

/// A decimal STRING: optional minus, no plus sign, no leading zeros, at most 15 whole digits and 8 decimals,
/// no exponent, no thousands separator, no comma decimal. Anything else is `invalid_number`.
Rational parseNumber(String s, {bool nonNegative = false, bool positive = false}) {
  if (!_numberPattern.hasMatch(s)) {
    throw const CalcException('invalid_number');
  }
  final v = Rational.parse(s);
  if (positive && v <= Rational.zero) {
    throw const CalcException('must_be_positive');
  }
  if (nonNegative && v.isNegative) {
    throw const CalcException('negative_not_allowed');
  }
  return v;
}

/// A whole number of up to nine digits.
int parseInteger(String s, {bool positive = false}) {
  if (!_integerPattern.hasMatch(s)) {
    throw const CalcException('invalid_number');
  }
  final v = int.parse(s);
  if (positive && v <= 0) {
    throw const CalcException('must_be_positive');
  }
  return v;
}
