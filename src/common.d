module common;


import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
       std.string, std.utf, std.path, std.traits, std.exception;
import std.file : read, exists, isFile;

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


debug @trusted  void dbg (T) (T a, bool nl = true) nothrow
{
    try
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
    catch (Throwable t)
    {
        try
            write("dbg throws ", t.msg);
        catch
            assert(false, "dbg throws");
    }
}


@trusted pure nothrow dstring filterChar(dstring str, dchar ch)
{
    dchar[] res;
    res.length = str.length;
    uint ix;
    foreach (strch; str)
        if (strch != ch)
            res[ix++] = strch;
    return assumeUnique(res[0 .. ix]);
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



@trusted nothrow dstring toDString (T) (T item)
{
    try
    {
        return item.to!dstring();
    }
    catch (Exception ex)
    {
        return ex.msg.toDString();
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


dstring readtUtf8FileUtf32 (string filePath)
{
    return toUTF32(cast(char[])read(filePath));
}


Token[] tokenizeFile (string filePath)
{
    return (new Tokenizer(readtUtf8FileUtf32(filePath))).tokenize();
}


ValueStruct parseString (IValidationContext vctx, const dstring src)
{
    return (new Parser).parseAll(vctx, (new Tokenizer(src)).tokenize());
}


ValueStruct parseFile (IValidationContext vctx, string filePath)
{
    return (new Parser).parseAll(vctx, tokenizeFile(filePath));
}


@safe interface IValidationContext
{
    void remark (Remark);
}


interface IPrinter
{
    void print (dstring);

    void println ();

    void println (dstring);

    void dbg (dstring);

    dstring readln ();
}


final class ConsolePrinter : IPrinter
{
    bool dbgEnabled;

    void print (dstring str) { write(str); }

    void println () { writeln(); }

    void println (dstring str) { writeln(str); }

    void dbg (dstring str) { if (dbgEnabled) println(str); }

    dstring readln () { return std.stdio.readln().idup.to!dstring(); }
}


final class StringPrinter : IPrinter
{
    bool dbgEnabled;

    dstring str;

    void print (dstring str) { this.str ~= str; }

    void println () { this.str ~= '\n'; }

    void println (dstring str) { this.str ~= str ~ '\n'; }

    void dbg (dstring str) { if (dbgEnabled) println(str); }

    dstring readln () { assert (false); }
}


interface IInterpreterContext : IValidationContext
{
    @property IPrinter printer ();

    Exp eval (Exp exp);

    @property Exp[] exceptions ();

    void except (dstring ex);

    @property bool hasBlocker ();
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


@safe pure nothrow dchar toInvisibleChar (const dchar escape)
{
    switch (escape)
    {
        case 'n': return '\n';
        case 'r': return '\r';
        case 't': return '\t';
        case '\"': return '\"';
        case '\'': return '\'';
        case '\\': return '\\';
        default:  assert(false);
    }
}


@trusted dstring toVisibleCharsChar (dstring str)
{
    return str
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t");
}