module test.TestInterpreterContext;


import common, validate.remarks, syntax.ast;


final class TestInterpreterContext : IInterpreterContext
{
    Remark[] remarks;

    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Exp[] exs;
    }


    Exp eval (Exp) { assert (false, "eval from TestInterpreterContext"); }

    void print (dstring str) { }

    void println () { }

    void println (dstring str) { }

    dstring readln () { return "TODO?"; }

    @property bool hasBlocker () { return hasBlockerField; }

    @property Exp[] exceptions () { return exs; }


    @trusted void remark (Remark remark)
    {
        if (remark.text == "Missing start function")
            return;

        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlockerField = true;

        remarks ~= remark;
    }

    void except (dstring ex)
    {
        exs ~= new ValueText(null, ex);
    }
}
