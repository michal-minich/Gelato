module tester;

import std.stdio, std.range, std.array, std.range, std.algorithm, std.conv,
    std.string, std.utf, std.path;
import std.file : readText, exists, isFile;
import common, settings, formatter, ast, parse.parser, parse.tokenizer, validate.remarks,
    validate.validation, interpret.preparer, interpret.evaluator, program;


final class TestInterpreterContext : IInterpreterContext
{
    private
    {
        uint remarkCounter;
        bool hasBlockerField;
        Remark[] remarks;
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


@trusted pure final class TestFormatVisitor : IFormatVisitor
{
    const dstring visit (ValueInt i) { return i.value.to!dstring(); }

    const dstring visit (ValueFloat f) { return f.value.to!dstring(); }

    const dstring visit (ValueUnknown e) { return "ValueUnknown"; }

    const dstring visit (ExpAssign e) { return "ExpAssign"; }

    const dstring visit (ValueStruct e) { return "ValueStruct"; }

    const dstring visit (ValueArray e) { return "ValueArray"; }

    const dstring visit (ValueFn e) { return "ValueFn"; }

    const dstring visit (ExpFnApply e) { return "ExpFnApply"; }

    const dstring visit (ExpIdent i) { return "ExpIdent"; }

    const nothrow dstring visit (StmLabel e) { return "StmLabel"; }

    const dstring visit (StmReturn e) { return "StmReturn"; }

    const dstring visit (ValueText e){ return e.value; }

    const dstring visit (ValueChar e) { return e.value.to!dstring(); }

    const dstring visit (ExpIf e) { return "ExpIf"; }

    const nothrow dstring visit (StmGoto e) { return "StmGoto"; }

    const dstring visit (Closure sc) { return "Closure"; }

    const dstring visit (ExpDot dot) { return "ExpDot"; }

    const dstring visit (TypeType tt) { return "TypeType"; }

    const dstring visit (TypeAny) { return "TypeAny"; }

    const dstring visit (TypeVoid) { return "TypeVoid"; }

    const dstring visit (TypeInt) { return "TypeInt"; }

    const dstring visit (TypeFloat) { return "TypeFloat"; }

    const dstring visit (TypeText) { return "TypeText"; }

    const dstring visit (TypeChar) { return "TypeChar"; }

    const dstring visit (TypeStruct) { return "TypeStruct"; }

    const dstring visit (ValueBuiltinFn) { return "ValueBuiltinFn"; }

    const dstring visit (TypeOr tor) { return "TypeOr"; }

    const dstring visit (TypeArray tor) { return "TypeArray"; }

    const dstring visit (TypeFn tfn) { return "TypeFn"; }

    const dstring visit (WhiteSpace ws) { return "WhiteSpace"; }
}


@trusted pure final class TokenTestFormatVisitor : IFormatVisitor
{
    const dstring visit (ValueInt i) { return i.tokensText ~ "|"; }

    const dstring visit (ValueFloat f) { return f.tokensText ~ "|"; }

    const dstring visit (ValueUnknown e) { return e.tokensText ~ "|"; }

    dstring visit (ExpAssign d)
    { 
        return d.tokensText ~ "|" ~ d.slot.str(this)
            ~ (d.type ? d.type.str(this) : "") 
            ~ (d.value ? d.value.str(this) : "");
    }


    dstring visit (ValueStruct e) { return e.tokensText ~ "|" ~ e.exps.map!(e2 => e2.str(this))().join(); }


    dstring visit (ValueFn fn)
    { 
        return fn.tokensText ~ "|"
            ~ fn.params.map!(p => p.str(this))().join()
            ~ fn.exps.map!(e => e.str(this))().join();
    }

    dstring visit (ExpFnApply fna)
    { 
        return fna.tokensText ~ "|"
            ~ fna.applicable.str(this)
            ~ fna.args.map!(a => a.str(this))().join();
    }


    const dstring visit (ExpIdent i) { return i.tokensText ~ "|"; }

    dstring visit (StmLabel e) { return e.tokensText ~ "|"; }

    dstring visit (StmReturn e) { return e.tokensText ~ "|" ~ (e.exp ? e.exp.str(this) : ""); }

    const dstring visit (ValueText e){ return e.tokensText ~ "|"; }

    const dstring visit (ValueChar e) { return e.tokensText ~ "|"; }

    const dstring visit (ValueArray e) { return e.tokensText ~ "|"; }

    const dstring visit (ExpIf e) { return e.tokensText ~ "|"; }

    const dstring visit (StmGoto e) { return e.tokensText ~ "|"; }

    const dstring visit (Closure sc) { return sc.tokensText ~ "|"; }

    dstring visit (ExpDot dot) { return dot.tokensText ~ "|" ~ dot.record.str(this) ~ dot.member.str(this); }

    const dstring visit (TypeType tt) { return tt.tokensText ~ "|"; }

    const dstring visit (TypeAny ta) { return ta.tokensText ~ "|"; }

    const dstring visit (TypeVoid tv) { return tv.tokensText ~ "|"; }

    const dstring visit (TypeInt i) { return i.tokensText ~ "|"; }

    const dstring visit (TypeFloat f) { return f.tokensText ~ "|"; }

    const dstring visit (TypeText tt) { return tt.tokensText ~ "|"; }

    const dstring visit (TypeChar tch) { return tch.tokensText ~ "|"; }

    const dstring visit (TypeStruct ts) { return ts.tokensText ~ "|"; }

    const dstring visit (ValueBuiltinFn bfn) { return bfn.tokensText ~ "|"; }

    const dstring visit (TypeOr tor) { return tor.tokensText ~ "|"; }

    const dstring visit (TypeArray arr) { return arr.tokensText ~ "|"; }

    const dstring visit (TypeFn tfn) { return tfn.tokensText ~ "|"; }

    const dstring visit (WhiteSpace ws) { return ws.tokensText ~ "|"; }
}



bool test (string filePath)
{
    auto testsExecuted = 0;
    auto testsFailed = 0;
    auto testsCrashed = 0;
    auto testsSkipped = 0;

    dstring testPrefix = "";

    auto tfv = new TestFormatVisitor;
    auto ttfv = new TokenTestFormatVisitor;

    foreach (ln; File(filePath).byLine())
    {
        auto line = ln.chomp().to!dstring();
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

        auto expectedStr = line[1 .. tabIx - 1];
        auto expected = expectedStr.replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t");
        auto codeStartIx = tabIx + line[tabIx .. $].countUntil('"') + 1;
        auto codeStart = line[codeStartIx .. $];
        auto codeEndIx = line.length - line.retro().countUntil('"') - 1;
        auto code = line[codeStartIx .. codeEndIx];
        auto tokTestStartIx = line[codeEndIx .. $].countUntil('|');
        dstring tokensExpected;
        if (tokTestStartIx != -1)
        {
            auto l = line[codeEndIx + tokTestStartIx .. $];
            tokensExpected ='|' ~ code.idup ~ l;
        }
        auto thisFailed = false;
        auto context = new TestInterpreterContext;
        auto fullCode = testPrefix ~ code;
        auto tokenFailed = false;
        dstring tokensParsed;

        try
        {
            auto p = new Program("test", fullCode);
            auto res = p.run(context);

            if (context.hasBlocker)
            {
                ++testsFailed;
                errPrint(fullCode, context);
                continue;
            }

            if (res is null && expected == "\\0")
                continue;

            auto tt = p.prog.exps[0].tokensText;

            auto resStr = res.str(tfv);

            auto evalFailed = resStr != expected;

            if (tokensExpected != tokensParsed || tokenFailed || evalFailed || context.remarks || context.exceptions)
            {
                if (tokensExpected.length)
                    tokensParsed = '|' ~ p.prog.exps[0].str(ttfv) ~ '|';
                else
                {
                    tokensExpected = '|' ~ fullCode ~ '|';
                    tokensParsed ='|' ~ p.prog.exps[0].tokensText ~ '|';
                }

                ++testsFailed;
                errPrint(fullCode, context, expectedStr, resStr, tokensExpected, tokensParsed);
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
    errPrint (code, context, null, null, null, null);
}


void errPrint (dstring code, TestInterpreterContext context, 
               dstring expected, dstring resStr, 
               dstring tokensExpected, dstring tokensParsed)
{
    writeln("Code:     ", code);

    if (expected !is null && resStr !is null)
    {
        writeln("Expected: ", "\"" ~ expected ~ "\"");
        writeln("Result:   ", "\"" ~ resStr ~ "\"");
    }

    if (tokensExpected != tokensParsed)
    {
        writeln("Expected Tokens: ", tokensExpected);
        writeln("Result Tokens:   ", tokensParsed);
    }

    foreach (r; context.remarks)
        writeln("Remark:   ", r.severity, " - ", r.text);

    foreach (ex; context.exceptions)
        writeln("App Exception: ", ex);

    writeln("-------------------------------------------------------------------------------");
}
