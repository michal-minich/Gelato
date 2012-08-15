module remarks;

import common, ast, validation;


@safe pure nothrow:
enum GeanyBug2 { none }


final class SelfStandingUnderscore : Remark
{
    this (Exp subject) { super (subject); }
}


final class MissingStartFunction : Remark
{
    this () { super (null); }
}


final class NumberNotProperlyFormatted : GroupRemark
{
    this (Exp subject, Remark[] children) { super (subject, children); }
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
