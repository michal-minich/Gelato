module interpret.ConsoleInterpreterContext;


import common, syntax.ast, interpret.Interpreter, validate.remarks;


final class ConsoleInterpreterContext : IInterpreterContext
{
    Interpreter evaluator;

    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
        IPrinter pPrinter;
    }


    this (IPrinter printer) { pPrinter = printer; }

    @property IPrinter printer () { return pPrinter; }

    Exp eval (Exp e) { return e.eval(evaluator); }

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
            location = mydtext("Line ", ts[0].start.line + 1, " Column ", ts[0].start.column + 1);
        }
        else if (remark.token.type != TokenType.empty)
        {
            auto t = remark.token;
            location = mydtext("Line ", t.start.line + 1, " Column ", t.start.column + 1);
        }

        pPrinter.print("* "d);
        pPrinter.print(location);
        pPrinter.print(", "d);
        pPrinter.print(svr.remarkSeverityText());
        pPrinter.print(": "d);
        pPrinter.print(remark.text);

        if (remark.subject)
        {
            auto txt = remark.subject.tokensText;
            auto newLineIx = txt.indexOf('\r');
            if (newLineIx == -1)
                newLineIx = txt.indexOf('\n');

            pPrinter.print("\t");
            pPrinter.print(txt[0 .. newLineIx != -1 ? newLineIx : $]);
            pPrinter.print(newLineIx != -1 ? " ..." : "");
        }

        pPrinter.println();
    }


    void except (dstring ex)
    {
        exs ~= new ValueText(null, ex);
        pPrinter.print("exception\t");
        pPrinter.print(ex);
    }
}