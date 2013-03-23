module test.TestInterpreterContext;


import common, validate.remarks, syntax.ast, interpret.Interpreter;


final class TestInterpreterContext : IInterpreterContext
{
    Remark[] remarks;
    Interpreter evaluator;

    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
        IPrinter pPrinter;
    }

    this () { pPrinter = new StringPrinter; }

    @property IPrinter printer () { return pPrinter; }

    Exp eval (Exp e) { return e.eval(evaluator); }

    @property bool hasBlocker () { return hasBlockerField; }

    @property Exp[] exceptions () { return exs; }


    @trusted void remark (Remark remark)
    {
        if (remark.text == "Missing start function")
            return;

        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlockerField = true;

        // remarks temporarily disabled
        //remarks ~= remark;
    }

    void except (dstring ex)
    {
        exs ~= new ValueText(null, ex);
    }
}
