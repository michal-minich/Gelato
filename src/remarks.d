module remarks;

import ast, validation;


@safe pure nothrow:


private mixin template r (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject) { return new Remark (\""
        ~ name ~ "\", subject); }");
}

private mixin template gr (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject, Remark[] children) { return new GroupRemark (\""
        ~ name ~ "\", subject, children); }");
}

mixin r!("SelfStandingUnderscore");
mixin r!("MissingStartFunction");

mixin gr!("NumberNotProperlyFormatted");
mixin r!("NumberStartsWithUnderscore");
mixin r!("NumberEndsWithUnderscore");
mixin r!("NumberContainsRepeatedUnderscore");
mixin r!("NumberStartsWithZero");