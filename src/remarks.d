module remarks;

import ast, validation;


@safe pure nothrow:


mixin template makeRemark (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject) { return new Remark (\""
        ~ name ~ "\", subject); }");
}

mixin template makeGroupRemark (string name)
{
    mixin ("Remark " ~ name ~ " (Exp subject, Remark[] children) { return new GroupRemark (\""
        ~ name ~ "\", subject, children); }");
}

mixin makeRemark!("SelfStandingUnderscore");
mixin makeRemark!("MissingStartFunction");

mixin makeGroupRemark!("NumberNotProperlyFormatted");
mixin makeRemark!("NumberStartsWithUnderscore");
mixin makeRemark!("NumberEndsWithUnderscore");
mixin makeRemark!("NumberContainsRepeatedUnderscore");
mixin makeRemark!("NumberStartsWithZero");