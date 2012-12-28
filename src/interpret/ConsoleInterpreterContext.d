module interpret.ConsoleInterpreterContext;


import std.stdio, std.conv, std.algorithm;
import common, syntax.ast, interpret.Interpreter, validate.remarks;


final class ConsoleInterpreterContext : IInterpreterContext
{
    Interpreter evaluator;

    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
    }


    Exp eval (Exp e) { return e.eval(evaluator); }

    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    dstring readln () { return std.stdio.readln().idup.to!dstring(); }

    @property bool hasBlocker () { return hasBlockerField; }

    @property Exp[] exceptions () { return exs; }


    @trusted void remark (Remark remark)
    {
        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlockerField = true;

        dstring location;

        if (remark.subject && remark.subject.tokens)
        {
            auto ts = remark.subject.tokens;
            location = dtext("Line ", ts[0].start.line + 1, " Column ", ts[0].start.column + 1);
        }
        else if (remark.token.type != TokenType.empty)
        {
            auto t = remark.token;
            location = dtext("Line ", t.start.line + 1, " Column ", t.start.column + 1);
        }

        std.stdio.write ("* ", location, ", ", svr.remarkSeverityText(), ": ", remark.text);

        if (remark.subject)
        {
            auto txt = remark.subject.tokensText;
            auto newLineIx = txt.countUntil('\r');
            if (newLineIx == -1)
                newLineIx = txt.countUntil('\n');

            std.stdio.write ("\t", txt[0 .. newLineIx != -1 ? newLineIx : $], newLineIx != -1 ? " ..." : "");
        }

        writeln();
    }


    nothrow void except (dstring ex)
    {
        try
        {
            exs ~= new ValueText(null, ex);
            return writeln("exception\t", ex);
        }
        catch (Exception ex)
        {
            assert (false, ex.msg);
        }
    }
}