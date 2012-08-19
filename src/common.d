module common;


import std.stdio, std.array, std.range, std.algorithm, std.conv, std.string, std.file, std.utf;
import settings, formatter, parse.ast, parse.parser, parse.tokenizer, validate.remarks,
    interpret.evaluator;


Settings sett;
FormatVisitor fv;


enum newLine = "\r\n";


int dbgCounter;
@trusted debug void dbg(T...) (T a)
{
    static if (!T.length)
    {
        writeln("DEBUG ", ++dbgCounter);
    }
    else
    {
        writeln(a);
    }
}


Token[] tokenizeFile (string filePath)
{
    return (new Tokenizer(toUTF32(readText!string(filePath)))).array();
}


AstFile parseString (IValidationContext vctx, const dstring src)
{
    return (new Parser(vctx, (new Tokenizer(src)).array())).parseAll();
}


AstFile parseFile (IValidationContext vctx, string filePath)
{
    return (new Parser(vctx, tokenizeFile(filePath))).parseAll();
}


void interpretFile (IInterpreterContext icontext, string filePath)
{
    (new Evaluator).interpret(icontext, parseFile(icontext, filePath));
}


void interpretString (IInterpreterContext icontext, dstring src)
{
    return (new Evaluator).interpret(icontext, parseString(icontext, src));
}


void interpretTokens (IInterpreterContext icontext, Token[] toks)
{
    return (new Evaluator).interpret(icontext, (new Parser(icontext, toks)).parseAll());
}


interface IValidationContext
{
    void remark (Remark);
}


interface IInterpreterContext : IValidationContext
{
    void print (dstring);

    void println ();

    void println (dstring);
}


final class ConsoleInterpreterContext : IInterpreterContext
{
    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    void remark (Remark remark)
    {
        std.stdio.write (remark.severity, "\t", remark.text);
        if (remark.subject)
            std.stdio.write ("\t", remark.subject.str(fv));
        writeln();
    }
}


struct Position
{
    uint line;
    uint column;
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