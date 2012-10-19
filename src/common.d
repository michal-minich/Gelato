module common;


import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
    std.string, std.utf, std.path;
import std.file : readText, exists, isFile;
import settings, formatter, parse.ast, parse.parser, parse.tokenizer, validate.remarks,
    interpret.evaluator;


Settings sett;
FormatVisitor fv;


enum newLine = "\r\n";


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


B sureCast (B, A) (A obj) { return cast(B)cast(void*)obj; }


Token[] tokenizeFile (string filePath)
{
    return (new Tokenizer(toUTF32(readText!string(filePath)))).array();
}


ValueFile parseString (IValidationContext vctx, const dstring src)
{
    return (new Parser(vctx, (new Tokenizer(src)).array())).parseAll();
}


ValueFile parseFile (IValidationContext vctx, string filePath)
{
    return (new Parser(vctx, tokenizeFile(filePath))).parseAll();
}


void interpretFile (IInterpreterContext icontext, string filePath)
{
    (new Evaluator(icontext)).visit(parseFile(icontext, filePath));
}


void interpretString (IInterpreterContext icontext, dstring src)
{
    (new Evaluator(icontext)).visit(parseString(icontext, src));
}


void interpretTokens (IInterpreterContext icontext, Token[] toks)
{
    (new Evaluator(icontext)).visit((new Parser(icontext, toks)).parseAll());
}


interface IValidationContext
{
    void remark (Remark);
}


interface IPrinterContext
{
    void print (dstring);

    void println ();

    void println (dstring);
}


interface IInterpreterContext : IValidationContext, IPrinterContext
{
    void except (dstring ex);
}


struct InterpretTask
{
    string[] files;

    static InterpretTask parse (string[] args)
    {
        InterpretTask task;

        foreach (a; args[1..$])
        {
            if (a.endsWith(".gel"))
            {
                immutable f = a.buildNormalizedPath();
                if (f.exists())
                {
                    if (f.isFile())
                    {
                        task.files ~= f;
                    }
                    else
                    {
                        cmdError ("Path \"", a, "\" not a file. It is folder or block device.",
                                  " Full path is \"", f, "\".");
                    }
                }
                else
                {
                    cmdError ("File \"", a, "\" could not be found. Full path is \"", f, "\".");
                }
            }
            else
            {
                if (a[0] == '-' || a[0] == '/')
                {
                    cmdError ("Unknown command line parameter \"", a, "\".");
                }
                else
                {
                    cmdError ("Olny \"*.gel\" files are supported as input.",
                              " Parameters can be prefixed with \"-\", \"--\" or \"/\".");
                }
            }
        }

        return task;
    }
}


void cmdError (string[] text ...)
{
    foreach (t; text)
        write (t);

    writeln();
}


@trusted dstring toVisibleCharsText (const dstring str)
{
    return str
        .replace("\\", "\\\\")
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
        .replace("\\\\", "\\");
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