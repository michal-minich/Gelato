module tester;

import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
    std.string, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, formatter, parse.ast, parse.parser, parse.tokenizer, validate.remarks,
    interpret.preparer, interpret.evaluator;


final class TestInterpreterContext : IInterpreterContext
{
    private
    {
        uint remarkCounter;
        bool hasBlocker;
        Remark[] remarks;
        dstring[] exceptions;
    }


    void print (dstring str) { }

    void println () { }

    void println (dstring str) { }


    void remark (Remark remark)
    {
        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlocker = true;

        remarks ~= remarks;
    }

    void except (dstring ex)
    {
        exceptions ~= ex;
    }
}


@trusted pure final class TestFormatVisitor : IFormatVisitor
{
    const dstring visit (ValueNum e) { return e.value.to!dstring(); }

    const dstring visit (AstUnknown e) { return "AstUnknown"; }

    const dstring visit (ValueFile e) { return "ValueFile"; }

    const dstring visit (StmDeclr e) { return "StmDeclr"; }

    const dstring visit (ValueStruct e) { return "ValueStruct"; }

    const dstring visit (ValueFn e) { return "ExpLambda"; }

    const dstring visit (ExpFnApply e) { return "ExpFnApply"; }

    const dstring visit (ExpIdent i) { return "ExpIdent"; }

    const nothrow dstring visit (StmLabel e) { return "StmLabel"; }

    const dstring visit (StmReturn e) { return "StmReturn"; }

    const dstring visit (ValueText e){ return e.value.toVisibleCharsText(); }

    const dstring visit (ValueChar e) { return e.value.to!dstring().toVisibleCharsChar(); }

    const dstring visit (ExpIf e) { return "ExpIf"; }

    private dstring dtextExps(Exp[] exps, bool forceExpand) { return "ExpLambda"; }

    const nothrow dstring visit (StmGoto e) { return "StmGoto"; }

    const dstring visit (ExpLambda e) { return "ExpLambda"; }

    const dstring visit (ExpScope sc) { return "ExpScope"; }

    const dstring visit (ExpDot dot) { return "ExpDot"; }

    const dstring visit (TypeType tt) { return "TypeType"; }

    const dstring visit (TypeAny) { return "TypeAny"; }

    const dstring visit (TypeVoid) { return "TypeVoid"; }

    const dstring visit (TypeNum) { return "TypeNum"; }

    const dstring visit (TypeText) { return "TypeText"; }

    const dstring visit (TypeChar) { return "TypeChar"; }

    const dstring visit (TypeStruct) { return "TypeStruct"; }

    const dstring visit (BuiltinFn) { return "BuiltinFn"; }

    const dstring visit (TypeOr or) { return "TypeOr"; }

    const dstring visit (TypeFn tfn) { return "TypeFn"; }
}



void test ()
{
    auto testsExecuted = 0;
    auto testsFailed = 0;
    auto testsCrashed = 0;

    dstring testPrefix = "";

    auto tfv = new TestFormatVisitor;

    foreach (line; File("tests.csv").byLine())
    {
        if (line.length > 0 && line[0] == '@')
        {
            testPrefix = line[2 .. $ - 2].to!dstring();
            continue;
        }

        auto tabIx = line.countUntil('\t');

        if (tabIx == -1)
        {
            testPrefix = "";
            continue;
        }

        auto expected = line[1 .. tabIx - 1].to!dstring();
        auto codeStart = line[tabIx + 1 .. $];
        auto code = line[tabIx + codeStart.countUntil('"') + 2 .. $ - 2].to!dstring();

        switch (expected)
        {
            case "\n": expected = "\n"; break;
            case "\r": expected = "\r"; break;
            case "\t": expected = "\t"; break;
            default:
        }

        auto thisFailed = false;
        auto context = new TestInterpreterContext;

        ++testsExecuted;

        auto fullCode = testPrefix ~ code;

        try
        {
            auto astFile = parseString(context, fullCode);

            if (context.hasBlocker)
            {
                ++testsFailed;
                errPrint(fullCode, context);
                continue;
            }

            auto prep = new PreparerForEvaluator(context);
            prep.visit(astFile);

            if (context.hasBlocker)
            {
                ++testsFailed;
                errPrint(fullCode, context);
                continue;
            }

            auto ev = new Evaluator(context);
            auto res = ev.visit(astFile);
            
            if (res is null && expected == "\\0")
                continue;

            auto resStr = res.str(tfv);

            auto evalFailed = resStr != expected;

            if (evalFailed)
            {
                ++testsFailed;
                errPrint(fullCode, context, expected, resStr);
                continue;
            }
        }
        catch (Throwable t)
        {
            ++testsCrashed;
            thisFailed = true;
            writeln("Code: ", fullCode);
            writeln("Expected: ", "\"" ~ expected ~ "\"");
            writeln("Exception: ", t.msg);
            // writeln(t.stacktrace);
            writeln("-------------------------------------------------------------------------------");
        }
    }

    write("Tests executed: ", testsExecuted);

    if (testsFailed == 0 && testsCrashed == 0)
    {
        writeln("ALL OK");
    }
    else
    {
        writeln();
        writeln("Tests failed:   ", testsFailed);
        writeln("Tests crashed:  ", testsCrashed);
    }
}


void errPrint (dstring code, TestInterpreterContext context)
{
    writeln("Code: ", code);

    foreach (r; context.remarks)
        writeln("Remark: ", r.severity, " ", r.text);

    foreach (ex; context.exceptions)
        writeln("App Exception: ", ex);

    writeln("-------------------------------------------------------------------------------");
}


void errPrint (dstring code, TestInterpreterContext context, dstring expected, dstring resStr)
{
    writeln("Code: ", code);
    writeln("Expected: ", "\"" ~ expected ~ "\"");
    writeln("Result: ", "\"" ~ resStr ~ "\"");

    foreach (r; context.remarks)
        writeln("Remark: ", r.severity, " ", r.text);

    foreach (ex; context.exceptions)
        writeln("App Exception: ", ex);

    writeln("-------------------------------------------------------------------------------");
}
