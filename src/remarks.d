module remarks;

import common, ast, validation;



enum GeanyBug2 { none }


final class SelfStandingUnderscore : Remark
{
    this (Exp subject) { super (subject); }
}


final class MissingStartFunction : Remark
{
    this () { super (null); }
}


final class NumberStartsWithUnderscore : Remark
{
    this (Exp subject) { super (subject); }
}


final class NumberEndsWithUnderscore : Remark
{
    this (Exp subject) { super (subject); }
}


final class NumberContainsRepeatedUnderscore : Remark
{
    this (Exp subject) { super (subject); }
}


final class NumberStartsWithZero : Remark
{
    this (Exp subject) { super (subject); }
}
