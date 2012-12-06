module common;


import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
       std.string, std.utf, std.path, std.traits, std.exception;
import std.file : readText, exists, isFile;

import settings, syntax.Formatter, syntax.ast, syntax.Parser, syntax.Tokenizer, validate.remarks,
       interpret.Interpreter;


Settings sett;
Formatter fv;


enum newLine = "\r\n";


@safe pure string commonPath (const string[] paths, 
                              immutable char sep = pathSeparator[0])
{
    enforce (paths.length);

    if (paths.length == 1)
        return paths[0];

    const restPaths = paths[1 .. $];
    size_t lenghtToSep;

    foreach (ix, testCh; paths[0][0 .. shortestLength(paths)])
    {
        if (testCh == sep)
            lenghtToSep = ix + 1;

        foreach (p; restPaths)
            if (testCh != p[ix])
                goto end;
    }

    end:
    return paths[0][0 .. lenghtToSep];
}


@safe pure nothrow size_t shortestLength (T) (const T[] items)
{
    size_t minLength = size_t.max;
    foreach (i; items)
        if (i.length < minLength)
            minLength = i.length;
    return minLength;
}


@trusted debug void dbg (T) (T a, bool nl = true)
{
    static if (is(T : Exp))
    {
        auto e = cast(Exp)a;
        write(e ? e.str(fv).toVisibleCharsText() : "NULL");

        if (nl)
            writeln();
    }
    else static if (is(T : Exp[]))
    {
        foreach (i, e; a)
        {
            write("|", i, "|");
            dbg(e);
        }
    }
    else
    {
        write(a.to!dstring().toVisibleCharsText());

        if (nl)
            writeln();
    }
}


@trusted nothrow string toString(dstring str)
{
    try
    {
        return str.to!string();
    }
    catch (Exception ex)
    {
        return ex.msg;
    }
}


@safe @property O[] of (O, I) (I[] objs)
{
    O[] res;
    foreach (o; objs)
    {
        auto ot = cast(O)o;
        if (ot)
            res ~= ot;
    }
    return res;
}


@trusted debug void dbg (T...) (T items)
{
    foreach (i; items)
        dbg(i, false);
    writeln();
}


int dbgCounter;
@trusted debug void dbg () ()
{
    writeln("DEBUG ", ++dbgCounter);
}


pure nothrow immutable(T)[] getReversed (T) (T[] arr)
{
    auto res = new Unqual!(T)[arr.length];
    foreach (ix, item; arr)
        res[arr.length - ix - 1] = item;
    return assumeUnique (res);
}


@safe pure nothrow bool myCanFind (dstring haystack, dstring needle)
{
    if (haystack.length < needle.length)
        return false;

    int i = 0;
    immutable max = haystack.length - needle.length;
    while (i <= max)
    {
        if (haystack[i .. i + needle.length] == needle)
            return true;
        ++i;
    }
    return false;
}


B sureCast (B, A) (A obj) { return cast(B)cast(void*)obj; }


Token[] tokenizeFile (string filePath)
{
    return (new Tokenizer(toUTF32(readText!string(filePath)))).tokenize();
}


ValueStruct parseString (IValidationContext vctx, const dstring src)
{
    return (new Parser(vctx, (new Tokenizer(src)).tokenize())).parseAll();
}


ValueStruct parseFile (IValidationContext vctx, string filePath)
{
    return (new Parser(vctx, tokenizeFile(filePath))).parseAll();
}


@safe interface IValidationContext
{
    void remark (Remark);
}


interface IPrinterContext
{
    void print (dstring);

    void println ();

    void println (dstring);

    dstring readln ();

    @property bool hasBlocker ();
}


interface IInterpreterContext : IValidationContext, IPrinterContext
{
    Exp eval (Exp exp);

    @property Exp[] exceptions ();

    nothrow void except (dstring ex);
}


void cmdPrint (string[] text ...)
{
    foreach (t; text)
        write (t);

    writeln();
}


@trusted dstring toVisibleCharsText (const dstring str)
{
    return str
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}

@trusted dstring toInvisibleCharsText (const dstring str)
{
    return str
        .replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
        .replace("\\\\", "\\")
        .replace("\\\"", "\"")
        .replace("\\\'", "\'");
}
/*
    switch (ptChar.capture[0])
    {
        case "\\n": t.value = '\n'; break;
        case "\\r": t.value = '\r'; break;
        case "\\t": t.value = '\t'; break;
        default: t.value = ptChar.capture[0][0];
    }*/
@safe pure nothrow dchar toInvisibleChar (const dchar escape)
{
    switch (escape)
    {
        case 'n': return '\n';
        case 'r': return '\r';
        case 't': return '\t';
        default:  return 0;
    }
}


@trusted dstring toVisibleCharsChar (dstring str)
{
    return str
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}