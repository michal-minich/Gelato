module common;


import std.stdio, std.array, std.algorithm, std.conv, std.utf, std.file;


dstring txt (T...) (T ts) @trusted
{
    return dtext (ts);
   /* dstring res;
    int c;
    foreach (t; ts)
        c += t.length;
    res.length = c;
    foreach (t; ts)
        res ~= t;
    return res;*/
}
