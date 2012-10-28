module tester;

import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
    std.string, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, formatter, parse.ast, parse.parser, parse.tokenizer, validate.remarks,
    validate.validation, interpret.preparer, interpret.evaluator;


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
        if (remark.text == "Missing start function")
            return;

        auto svr = remark.severity;

        if (svr == RemarkSeverity.blocker)
            hasBlocker = true;

        remarks ~= remark;
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

    const dstring visit (ValueText e){ return e.value; }

    const dstring visit (ValueChar e) { return e.value.to!dstring(); }

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



bool test (string filePath)
{
    auto testsExecuted = 0;
    auto testsFailed = 0;
    auto testsCrashed = 0;
    auto testsSkipped = 0;

    dstring testPrefix = "";

    auto tfv = new TestFormatVisitor;

    foreach (line; File(filePath).byLine())
    {
        if (line.length > 0 && line[0] == '@')
        {
            testPrefix = line[2 .. $ - 2].to!dstring();
            continue;
        }

        if (line.startsWith("--"))
        {
            ++testsSkipped;
            continue;
        }

        auto tabIx = line.countUntil('\t');

        if (tabIx == -1)
        {
            testPrefix = "";
            continue;
        }

        ++testsExecuted;

        auto expectedStr = line[1 .. tabIx - 1].to!dstring();
        auto expected = expectedStr.replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t");
        auto codeStart = line[tabIx + 1 .. $];
        auto code = line[tabIx + codeStart.countUntil('"') + 2 .. $ - 2].to!dstring();
        auto thisFailed = false;
        auto context = new TestInterpreterContext;
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
            
            
            auto val = new Validator(context);
            val.visit(astFile);

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

            if (evalFailed || context.remarks || context.exceptions)
            {
                ++testsFailed;
                errPrint(fullCode, context, expectedStr, resStr);
                continue;
            }
        }
        catch (Throwable t)
        {
            ++testsCrashed;
            thisFailed = true;
            writeln("Code:      ", fullCode);
            writeln("Expected:  ", "\"" ~ expected ~ "\"");
            writeln("Exception:  " ~ typeid(t).name ~ " - ", t.msg);
            writeln("-------------------------------------------------------------------------------");
        }
    }

    if (testsFailed == 0 && testsCrashed == 0)
        write("ALL OK, ");

    write(testsExecuted, " tests executed");

    if (testsFailed != 0)
        write(", ", testsFailed, " failed");

    if (testsCrashed != 0)
        write(", ", testsCrashed, " crashed");

    if (testsSkipped != 0)
        write(", ", testsSkipped, " skipped");

    writeln();

    return testsFailed == 0 && testsCrashed == 0;
}


void errPrint (dstring code, TestInterpreterContext context)
{
    errPrint (code, context, null, null);
}


void errPrint (dstring code, TestInterpreterContext context, dstring expected, dstring resStr)
{
    writeln("Code:     ", code);

    if (expected !is null && resStr !is null)
    {
        writeln("Expected: ", "\"" ~ expected ~ "\"");
        writeln("Result:   ", "\"" ~ resStr ~ "\"");
    }

    foreach (r; context.remarks)
        writeln("Remark:   ", r.severity, " - ", r.text);

    foreach (ex; context.exceptions)
        writeln("App Exception: ", ex);

    writeln("-------------------------------------------------------------------------------");
}
