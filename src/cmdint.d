module cmdint;


import std.stdio, std.algorithm, std.string, std.array, std.conv, std.file, std.path;
import common, settings, formatter, validate.remarks, validate.validation,
    parse.tokenizer, parse.parser, parse.ast, interpret.evaluator, interpret.preparer,
    validate.inferer;


final class ConsoleInterpreterContext : IInterpreterContext
{
    private
    {
        uint remarkCounter;
        bool hasBlocker;
    }


    void print (dstring str) { write (str); }

    void println () { writeln (); }

    void println (dstring str) { writeln (str); }

    dstring readln () { return std.stdio.readln().idup.to!dstring(); }


    void remark (Remark remark)
    {
        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlocker = true;

        std.stdio.write (++remarkCounter, "\t", svr, "\t", remark.text);

        if (remark.subject)
            std.stdio.write ("\t", remark.subject.tokensText);

        writeln();
    }

    nothrow void except (dstring ex)
    {
        try
        {
            return writeln("exception\t", ex);
        }
        catch (Exception ex)
        {
            assert (false, ex.msg);
        }
    }
}


final class ConsoleInterpreter
{
    ConsoleInterpreterContext context;

    int process (InterpretTask task)
    {
        context = new ConsoleInterpreterContext;

        foreach (f; task.files)
        {
            debug writeln("TOKENIZE");
            auto toks = tokenizeFile(f);

            //foreach (t; toks) dbg (t.toDebugString());

            debug writeln("PARSE");
            auto par = new Parser(context, toks);
            auto astFile = par.parseAll();

            if (context.hasBlocker)
                return 1;


            debug writeln("VALIDATE");
            auto val = new Validator(context);
            val.visit(astFile);

            if (context.hasBlocker)
                return 1;


            debug writeln("PREPARE");
            auto prep = new PreparerForEvaluator(context);
            prep.prepareFile(astFile);

            if (context.hasBlocker)
                return 1;


          /*  debug writeln("TYPE INFER");
            auto inf = new TypeInferer(context);
            inf.visit(astFile);

            if (context.hasBlocker)
                return 1;*/

            fv.useInferredTypes = false;
            writeln(fv.visit(astFile));

            debug writeln("EVALUATE");
            auto ev = new Evaluator(context);
            auto res = ev.eval(astFile);

            if (res)
                writeln("RESULT: " ~ res.str(fv));

            auto num = cast(ValueNum)res;
            if (num)
                return num.value.to!int();
        }

        return 0;
    }
}